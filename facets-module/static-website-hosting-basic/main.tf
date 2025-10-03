# S3 bucket for static website hosting
resource "aws_s3_bucket" "main" {
  bucket        = var.instance.spec.bucket_name
  force_destroy = var.instance.spec.force_destroy

  tags = merge(
    var.environment.cloud_tags,
    {
      Name        = "${var.instance_name}-${var.environment.unique_name}"
      Environment = var.environment.name
      Purpose     = "static-website-hosting"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# S3 bucket versioning configuration
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = var.instance.spec.enable_versioning ? "Enabled" : "Suspended"
  }
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = var.instance.spec.index_document
  }

  error_document {
    key = var.instance.spec.error_document
  }
}

# S3 bucket public access block configuration
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = !var.instance.spec.enable_public_read_access
  block_public_policy     = !var.instance.spec.enable_public_read_access
  ignore_public_acls      = !var.instance.spec.enable_public_read_access
  restrict_public_buckets = !var.instance.spec.enable_public_read_access
}

# S3 bucket policy for public read access
resource "aws_s3_bucket_policy" "main" {
  count      = var.instance.spec.enable_public_read_access ? 1 : 0
  bucket     = aws_s3_bucket.main.id
  depends_on = [aws_s3_bucket_public_access_block.main]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })
}

# S3 bucket CORS configuration
locals {
  cors_origins = var.instance.spec.cors_allowed_origins == "*" ? ["*"] : split(",", replace(var.instance.spec.cors_allowed_origins, " ", ""))
}

resource "aws_s3_bucket_cors_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = local.cors_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "lifecycle_rule"
    status = "Enabled"

    # Transition to IA
    transition {
      days          = var.instance.spec.lifecycle_rules.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier
    transition {
      days          = var.instance.spec.lifecycle_rules.transition_to_glacier_days
      storage_class = "GLACIER"
    }

    # Current version expiration
    expiration {
      days = var.instance.spec.lifecycle_rules.expiration_days
    }

    # Non-current version expiration (if versioning is enabled)
    dynamic "noncurrent_version_expiration" {
      for_each = var.instance.spec.enable_versioning ? [1] : []
      content {
        noncurrent_days = var.instance.spec.lifecycle_rules.noncurrent_version_expiration_days
      }
    }
  }
}