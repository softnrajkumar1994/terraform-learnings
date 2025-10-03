terraform {
  required_version = "1.13.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# GuardDuty Detector
resource "aws_guardduty_detector" "main" {
  enable = true

  # Set finding publishing frequency based on protection level
  finding_publishing_frequency = var.instance.spec.s3_protection_level == "enhanced" ? "FIFTEEN_MINUTES" : "SIX_HOURS"

  # Configure S3 protection datasources
  datasources {
    s3_logs {
      enable = var.instance.spec.auto_enable_s3_logs
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = false
        }
      }
    }
  }

  tags = merge(
    var.environment.cloud_tags,
    {
      Name        = "${var.instance_name}-guardduty-detector"
      Environment = var.environment.name
      ManagedBy   = "Facets"
    }
  )
}

# S3 Protection Configuration
resource "aws_guardduty_detector_feature" "s3_protection" {
  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "DISABLED"
  }
}

# Malware Protection for EBS (detects malware on EC2 instances that may interact with S3)
resource "aws_guardduty_detector_feature" "malware_protection" {
  count = var.instance.spec.enable_malware_protection ? 1 : 0

  detector_id = aws_guardduty_detector.main.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"

  additional_configuration {
    name   = "EC2_AGENT_MANAGEMENT"
    status = "DISABLED"
  }
}

# SNS Topic for notifications (if enabled)
resource "aws_sns_topic" "guardduty_findings" {
  count = var.instance.spec.notification_enabled ? 1 : 0

  name = "${var.instance_name}-guardduty-findings"

  tags = merge(
    var.environment.cloud_tags,
    {
      Name        = "${var.instance_name}-guardduty-findings"
      Environment = var.environment.name
      ManagedBy   = "Facets"
    }
  )
}

# CloudWatch Event Rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = var.instance.spec.notification_enabled ? 1 : 0

  name        = "${var.instance_name}-guardduty-findings-rule"
  description = "Capture GuardDuty findings with severity ${var.instance.spec.threat_severity_threshold} and above"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = {
        numeric = [">", lookup({
          "LOW"    = 1.0
          "MEDIUM" = 4.0
          "HIGH"   = 7.0
        }, var.instance.spec.threat_severity_threshold, 4.0)]
      }
    }
  })

  tags = merge(
    var.environment.cloud_tags,
    {
      Name        = "${var.instance_name}-guardduty-findings-rule"
      Environment = var.environment.name
      ManagedBy   = "Facets"
    }
  )
}

# CloudWatch Event Target (SNS)
resource "aws_cloudwatch_event_target" "guardduty_findings_sns" {
  count = var.instance.spec.notification_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "GuardDutyFindingsTarget"
  arn       = aws_sns_topic.guardduty_findings[0].arn
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "guardduty_findings" {
  count = var.instance.spec.notification_enabled ? 1 : 0

  arn = aws_sns_topic.guardduty_findings[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.guardduty_findings[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

