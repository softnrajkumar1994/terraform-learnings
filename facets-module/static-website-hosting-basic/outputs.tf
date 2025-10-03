locals {
  output_attributes = {
    bucket_id                   = aws_s3_bucket.main.id
    bucket_arn                  = aws_s3_bucket.main.arn
    bucket_domain_name          = aws_s3_bucket.main.bucket_domain_name
    bucket_regional_domain_name = aws_s3_bucket.main.bucket_regional_domain_name
    website_endpoint            = aws_s3_bucket_website_configuration.main.website_endpoint
    website_domain              = aws_s3_bucket_website_configuration.main.website_domain
    hosted_zone_id              = aws_s3_bucket.main.hosted_zone_id
    region                      = aws_s3_bucket.main.region
    versioning_enabled          = var.instance.spec.enable_versioning
  }
  output_interfaces = {
    bucket_name   = aws_s3_bucket.main.id
    website_url   = aws_s3_bucket_website_configuration.main.website_endpoint
    bucket_domain = aws_s3_bucket.main.bucket_domain_name
  }
}