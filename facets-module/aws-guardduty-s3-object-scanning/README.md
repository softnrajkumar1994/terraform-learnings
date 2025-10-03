# AWS GuardDuty S3 Protection

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://github.com/your-org/facets-modules)
[![Cloud](https://img.shields.io/badge/cloud-AWS-orange.svg)](https://aws.amazon.com/)

## Overview

This module enables Amazon GuardDuty with specialized S3 object scanning and malware protection capabilities. It provides developer-friendly configuration options for implementing comprehensive security monitoring of S3 data without requiring deep AWS security expertise.

## Environment as Dimension

This module is environment-aware through the following mechanisms:
- **Unique naming**: Resources are prefixed with `var.environment.unique_name` to ensure global uniqueness across environments
- **Environment tagging**: All resources automatically inherit `var.environment.cloud_tags` for consistent governance
- **Retention policies**: Finding retention settings can be adjusted per environment needs
- **Notification thresholds**: Threat severity thresholds can be customized based on environment criticality (e.g., stricter in production)

## Resources Created

- **GuardDuty Detector**: Core threat detection service with S3-focused configuration
- **S3 Protection Feature**: Enables data event monitoring and analysis for S3 buckets
- **Malware Protection Feature**: Optional scanning of S3 objects for malicious content (when enabled)
- **SNS Topic**: Notification channel for security findings (when notifications are enabled)
- **CloudWatch Event Rule**: Filters findings based on configurable severity threshold
- **CloudWatch Event Target**: Routes filtered findings to SNS for alerting
- **SNS Topic Policy**: Grants CloudWatch Events permission to publish notifications

## Security Considerations

### Data Privacy
- GuardDuty performs metadata analysis and does not access actual file contents for most scans
- Malware protection may analyze file samples - ensure compliance with data handling policies
- All findings are retained within your AWS account with configurable retention periods

### Access Control
- The module creates IAM policies automatically for service-to-service communication
- SNS topic access is restricted to the specific AWS account and CloudWatch Events service
- No cross-account access is configured by default

### Compliance
- Supports configurable finding retention (1-365 days) to meet regulatory requirements
- All resources are tagged for governance and cost allocation
- Event filtering helps reduce alert fatigue while maintaining security coverage

### Cost Management
- Enhanced protection level increases costs due to more frequent scans
- Malware protection incurs additional charges per object scanned
- Consider protection level and notification settings based on environment needs

## Configuration Notes

The module uses intelligent defaults optimized for developer productivity:
- **Basic protection level** provides cost-effective monitoring suitable for most use cases
- **Enhanced protection** enables ML-based deep inspection with 15-minute finding updates
- **Selective notifications** prevent alert overload by filtering on severity thresholds
- **Automatic S3 logging** ensures comprehensive coverage without manual configuration