locals {
  output_attributes = {
    detector_id                  = aws_guardduty_detector.main.id
    detector_arn                 = aws_guardduty_detector.main.arn
    account_id                   = data.aws_caller_identity.current.account_id
    s3_protection_enabled        = true
    malware_protection_enabled   = var.instance.spec.enable_malware_protection
    finding_publishing_frequency = aws_guardduty_detector.main.finding_publishing_frequency
    notification_topic_arn       = var.instance.spec.notification_enabled ? aws_sns_topic.guardduty_findings[0].arn : null
    protection_level             = var.instance.spec.s3_protection_level
    threat_severity_threshold    = var.instance.spec.threat_severity_threshold
  }
}