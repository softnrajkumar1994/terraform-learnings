resource "aws_s3_bucket" "this" {
  bucket        = var.instance.spec.bucket_name != "" ? var.instance.spec.bucket_name : null
  bucket_prefix = var.instance.spec.bucket_name == "" ? var.instance.spec.bucket_prefix : null
  acl           = var.instance.spec.acl
  force_destroy = var.instance.spec.force_destroy
  tags          = var.instance.spec.tags

  // Terraform AWS provider v3 style website config
  dynamic "website" {
    for_each = var.instance.spec.enable_website ? [1] : []
    content {
      index_document = var.instance.spec.website_index_document
      error_document = var.instance.spec.website_error_document
    }
  }

  // Terraform AWS provider v3 style versioning block
  versioning {
    enabled = var.instance.spec.versioning
  }

  // Default encryption (SSE) - v3 style
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = var.instance.spec.sse_algorithm
      }
    }
  }

}


locals {
  output_interfaces = {}

  output_attributes = {
    bucket_name      = aws_s3_bucket.this.bucket
    bucket_arn       = aws_s3_bucket.this.arn
    website_endpoint = aws_s3_bucket.this.website_endpoint
    website_domain   = aws_s3_bucket.this.website_domain
  }
}

# Control S3 Block Public Access settings for the bucket (v3 compatible)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.instance.spec.enable_public_policy ? false : true
  ignore_public_acls      = var.instance.spec.enable_public_policy ? false : true
  block_public_policy     = var.instance.spec.enable_public_policy ? false : true
  restrict_public_buckets = var.instance.spec.enable_public_policy ? false : true
}

# Public read policy for website content (v3 compatible)
resource "aws_s3_bucket_policy" "public_read" {
  count  = var.instance.spec.enable_public_policy ? 1 : 0
  bucket = aws_s3_bucket.this.id

  # Ensure public access block is disabled before attaching policy
  depends_on = [aws_s3_bucket_public_access_block.this]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = "${aws_s3_bucket.this.arn}/*"
      }
    ]
  })
}

