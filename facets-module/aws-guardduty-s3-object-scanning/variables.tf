variable "instance" {
  description = "Enables Amazon GuardDuty with S3 object scanning and malware protection"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      enable_malware_protection = bool
      s3_protection_level       = string
      notification_enabled      = bool
      auto_enable_s3_logs       = bool
      finding_retention_days    = number
      threat_severity_threshold = string
    })
  })

  # Default for local testing; Facets injects this in production
  default = {
    kind    = "aws-guardduty-s3-object-scanning"
    flavor  = "s3-object-scanning"
    version = "1.0"
    spec = {
      enable_malware_protection = true
      s3_protection_level       = "ALL"
      notification_enabled      = false
      auto_enable_s3_logs       = true
      finding_retention_days    = 90
      threat_severity_threshold = "MEDIUM"
    }
  }
}
variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string

  # Default for local testing; Facets injects this at runtime in production
  default     = "guardduty-s3-scan"
}
variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })

  # Default for local testing; Facets injects this at runtime in production
  default = {
    name        = "dev"
    unique_name = "dev"
    cloud_tags  = {}
  }
}
