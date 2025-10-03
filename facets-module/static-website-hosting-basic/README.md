# Static Website Hosting S3 Bucket

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](./facets.yaml)

## Overview

This module creates an Amazon S3 bucket optimized for static website hosting with comprehensive lifecycle management and security controls. The module provides a production-ready solution for hosting static websites with configurable caching policies, versioning, and automated object lifecycle management.

## Environment as Dimension

This module is environment-aware and adapts its configuration based on the deployment environment:

- **Bucket naming**: Uses `bucket_name` combined with `environment.unique_name` for resource tagging
- **Tagging strategy**: Applies environment-specific cloud tags from `var.environment.cloud_tags`
- **Resource naming**: All resources are tagged with the environment name for proper resource organization
- **Lifecycle policies**: Apply consistently across environments but can be customized per deployment

## Resources Created

- **S3 Bucket**: Primary storage container with custom naming and force destroy protection
- **Website Configuration**: Static website hosting with customizable index and error documents
- **Versioning Configuration**: Object versioning management with configurable state
- **Public Access Block**: Fine-grained public access controls for security
- **Bucket Policy**: IAM policy for public read access when static hosting is enabled
- **CORS Configuration**: Cross-origin resource sharing rules with customizable origins
- **Lifecycle Management**: Automated object transitions and expiration policies
  - Standard to Infrequent Access transition
  - Infrequent Access to Glacier transition  
  - Current version expiration
  - Non-current version cleanup (when versioning enabled)

## Security Considerations

- **Public Access Control**: Public read access can be disabled for private static sites
- **Bucket Policy**: Only applies when public read access is explicitly enabled
- **Force Destroy Protection**: Bucket includes `prevent_destroy = true` lifecycle rule
- **CORS Configuration**: Configurable allowed origins to prevent unauthorized cross-origin requests
- **Versioning Security**: Non-current versions are automatically cleaned up to prevent storage bloat and potential data exposure

The module follows AWS security best practices by defaulting to secure configurations while providing flexibility for specific use cases.