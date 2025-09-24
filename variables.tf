variable "aws_region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "ap-south-1"
}

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket name (must be globally unique after AWS adds a suffix)"
  type        = string
  default     = "terraform-learnings-"
}

