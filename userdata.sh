#!/bin/bash
set -euo pipefail

# -----------------------------
# Set NodePort with default
# -----------------------------
NODE_PORT="$${node_port:-32673}"  # Terraform injects node_port safely

# -----------------------------
# Write k8s.sh
# -----------------------------
cat > /home/ubuntu/k8s.sh <<'EOK8S'
${k8s_content}
EOK8S
chmod +x /home/ubuntu/k8s.sh

# -----------------------------
# Write argocd.sh
# -----------------------------
cat > /home/ubuntu/argocd.sh <<'EOARGO'
${argocd_content}
EOARGO
chmod +x /home/ubuntu/argocd.sh

# -----------------------------
# Run scripts as ubuntu user
# -----------------------------
echo "[*] Running k8s.sh..."
sudo -i -u ubuntu bash /home/ubuntu/k8s.sh 2>&1 | tee /home/ubuntu/k8s.log

echo "[*] Running argocd.sh..."
sudo -i -u ubuntu env NODE_PORT="$NODE_PORT" bash /home/ubuntu/argocd.sh 2>&1 | tee /home/ubuntu/argocd.log

echo "[✔] EC2 first-boot setup complete."

