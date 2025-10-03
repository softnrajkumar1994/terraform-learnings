variable "instance" {
  description = "Creates an S3 bucket configured for static website hosting with lifecycle policies, versioning, and customizable bucket naming"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      bucket_name       = string
      enable_versioning = optional(bool, true)
      index_document    = optional(string, "index.html")
      error_document    = optional(string, "error.html")
      lifecycle_rules = optional(object({
        transition_to_ia_days              = optional(number, 30)
        transition_to_glacier_days         = optional(number, 90)
        expiration_days                    = optional(number, 365)
        noncurrent_version_expiration_days = optional(number, 30)
        }), {
        transition_to_ia_days              = 30
        transition_to_glacier_days         = 90
        expiration_days                    = 365
        noncurrent_version_expiration_days = 30
      })
      enable_public_read_access = optional(bool, true)
      cors_allowed_origins      = optional(string, "*")
      force_destroy             = optional(bool, false)
    })
  })

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.instance.spec.bucket_name)) && length(var.instance.spec.bucket_name) >= 3 && length(var.instance.spec.bucket_name) <= 63
    error_message = "Bucket name must be 3-63 characters, lowercase alphanumeric with hyphens, cannot start/end with hyphen."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+\\.[a-zA-Z0-9]+$", var.instance.spec.index_document))
    error_message = "Index document must be a valid filename with extension."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+\\.[a-zA-Z0-9]+$", var.instance.spec.error_document))
    error_message = "Error document must be a valid filename with extension."
  }

  validation {
    condition     = var.instance.spec.lifecycle_rules.transition_to_ia_days >= 1 && var.instance.spec.lifecycle_rules.transition_to_ia_days <= 365
    error_message = "IA transition days must be between 1 and 365."
  }

  validation {
    condition     = var.instance.spec.lifecycle_rules.transition_to_glacier_days >= 1 && var.instance.spec.lifecycle_rules.transition_to_glacier_days <= 365
    error_message = "Glacier transition days must be between 1 and 365."
  }

  validation {
    condition     = var.instance.spec.lifecycle_rules.expiration_days >= 1 && var.instance.spec.lifecycle_rules.expiration_days <= 3650
    error_message = "Expiration days must be between 1 and 3650."
  }

  validation {
    condition     = var.instance.spec.lifecycle_rules.noncurrent_version_expiration_days >= 1 && var.instance.spec.lifecycle_rules.noncurrent_version_expiration_days <= 365
    error_message = "Non-current version expiration days must be between 1 and 365."
  }
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
  })
}