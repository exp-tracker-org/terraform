#!/bin/bash
set -euo pipefail

# --------------------------
# ArgoCD + Monitoring Setup Script (non-interactive)
# --------------------------

NODE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
NODE_PORT=${NODE_PORT:-32673}

echo "[*] Ensuring core Kubernetes pods are ready..."
kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=180s || true
kubectl wait --for=condition=Ready nodes --all --timeout=180s || true


# --- STEP 1: INSTALL ARGO CD IN CLUSTER ---
echo "[*] Creating ArgoCD namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "[*] Installing ArgoCD components..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# --- STEP 2: WAIT FOR SERVER POD ---
echo "[*] Waiting for ArgoCD server pod to be ready..."
for i in {1..30}; do
  READY=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  if [[ "$READY" == "true" ]]; then
    echo "[✔] ArgoCD server pod is ready!"
    break
  fi
  echo "[*] Waiting for ArgoCD server pod... ($i/30)"
  sleep 10
done

echo "[*] Exposing ArgoCD server on NodePort $NODE_PORT with TLS passthrough disabled..."
kubectl patch svc argocd-server -n argocd \
  -p "{\"spec\": {\"ports\": [{\"port\": 80, \"nodePort\": $NODE_PORT, \"protocol\": \"TCP\", \"targetPort\": 8080}], \"type\": \"NodePort\"}}"

kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value":["--insecure"]}]'

# --- STEP 3: INSTALL ARGOCD CLI ---
echo "[*] Installing ArgoCD CLI..."
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# --- STEP 4: LOGIN ---
echo "[*] Logging into ArgoCD..."
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd login "$NODE_IP:$NODE_PORT" \
  --username admin \
  --password "$ARGOCD_PWD" \
  --insecure

# --- STEP 5: REGISTER GITHUB REPOS ---
echo "[*] Registering GitHub repositories..."
argocd repo add https://github.com/exp-tracker-org/infra.git 
argocd repo add https://github.com/exp-tracker-org/frontend-new.git 
argocd repo add https://github.com/exp-tracker-org/user-service.git 
argocd repo add https://github.com/exp-tracker-org/expense-service.git 

# --- STEP 6: BOOTSTRAP ROOT APPLICATION ---
echo "[*] Bootstrapping root-app.yaml from GitHub..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/exp-tracker-org/infra/main/argo-apps/root-app.yaml

echo "[✔] ArgoCD installed and accessible at: http://$NODE_IP:$NODE_PORT"
echo "[✔] Root application bootstrapped — ArgoCD will now sync your apps!"


# --------------------------
# STEP 7: INSTALL HELM + PROMETHEUS STACK
# --------------------------
echo "[*] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

echo "[*] Adding Prometheus community repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "[*] Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "[*] Installing kube-prometheus-stack..."
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring

echo "[*] Patching Grafana service to NodePort..."
kubectl patch svc prometheus-grafana -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'

echo "[✔] Prometheus + Grafana installed in 'monitoring' namespace"


# --------------------------
# STEP 8: INSTALL METRICS-SERVER
# --------------------------
echo "[*] Installing metrics-server..."

sudo -u ubuntu kubectl apply -f https://raw.githubusercontent.com/vilasvarghese/docker-k8s/refs/heads/master/yaml/hpa/components.yaml


sudo -u ubuntu kubectl -n kube-system wait --for=condition=Available \
  deploy/metrics-server --timeout=300s || \
sudo -u ubuntu kubectl -n kube-system wait --for=condition=Available \
  deploy -l k8s-app=metrics-server --timeout=300s

