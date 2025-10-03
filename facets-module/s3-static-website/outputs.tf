output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "website_endpoint" {
  description = "S3 static website endpoint (only valid when website is enabled)"
  value       = aws_s3_bucket.this.website_endpoint
}

output "website_domain" {
  description = "S3 static website domain (only valid when website is enabled)"
  value       = aws_s3_bucket.this.website_domain
}

