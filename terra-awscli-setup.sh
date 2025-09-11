#!/bin/bash
set -e

# Update packages
sudo apt update -y

# Install prerequisites
sudo apt install -y unzip curl tree

# ----------------------
# Install AWS CLI v2
# ----------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# Verify AWS CLI installation
aws --version

# ----------------------
# Install Terraform
# ----------------------
TERRAFORM_VERSION="1.9.6"
curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform.zip
unzip terraform.zip
sudo mv terraform /usr/local/bin/
rm terraform.zip

# Verify Terraform installation
terraform -v

# ----------------------
# Verify tree installation
# ----------------------
tree --version

echo "Installation completed successfully!"

