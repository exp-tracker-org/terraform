
terraform {
  backend "s3" {
    bucket         = "minnu-terraform-state-bucket"      # matches your backend setup
    key            = "k8s/terraform.tfstate"             # path inside the bucket
    region         = "us-east-1"                         # match your bucket region
    dynamodb_table = "minnu-terraform-state-lock"        # matches your lock table
    encrypt        = true
  }
}



provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "k8s_master" {
  ami           = "ami-04f59c565deeb2199"
  instance_type = "t2.large"
  key_name      = "minnunv"

  user_data = templatefile("${path.module}/userdata.sh", {
    node_port      = var.node_port
    k8s_content    = file("${path.module}/k8s.sh")
    argocd_content = file("${path.module}/argocd.sh")
  })

  tags = {
    Name = "Minnu-K8s-Master"
  }
}

