provider "aws" {
  region = "us-east-1"
}

# S3 bucket
resource "aws_s3_bucket" "tf_state" {
  bucket = "minnu-terraform-state-bucket"

  tags = {
    Name = "Minnu-Terraform-State"
  }
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket SSE
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_sse" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB lock table
resource "aws_dynamodb_table" "tf_lock" {
  name         = "minnu-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Minnu-Terraform-Lock"
  }
}

