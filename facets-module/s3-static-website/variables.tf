// Facets standard inputs. Do not add other input variables.
variable "instance" {
  description = "Developer-supplied configuration from facets.yaml."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      bucket_name            = string
      bucket_prefix          = string
      acl                    = string
      versioning             = bool
      sse_algorithm          = string
      enable_website         = bool
      website_index_document = string
      website_error_document = string
      enable_public_policy   = bool
      force_destroy          = bool
      tags                   = map(string)
    })
  })
}

variable "instance_name" {
  description = "Globally unique instance name provided by Facets."
  type        = string
}

variable "environment" {
  description = "Environment metadata provided by Facets."
  type = object({
    name        = string
    unique_name = string
  })
}

variable "inputs" {
  description = "Cross-module inputs (providers, accounts, etc.)."
  type = object({
    cloud_account = object({
      region = string
    })
  })
}

