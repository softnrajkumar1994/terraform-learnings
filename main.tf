resource "aws_s3_bucket" "this" {
  bucket_prefix = var.bucket_prefix

  tags = {
    Project   = "terraform-learnings"
    ManagedBy = "terraform"
  }
}

