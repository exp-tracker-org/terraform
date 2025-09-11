variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string    
  default     = "us-east-1"

}

variable "node_port" {
  default = 32673
}

