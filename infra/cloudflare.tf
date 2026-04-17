###############################################################################
# Cloudflare edge — WAF, DNS, rate limits, strict TLS.
#
# One Cloudflare zone, N tenant hostnames. Each university (tenant) gets
# its own CNAME into the shared App Service, proxied through Cloudflare
# so every request passes through the WAF before touching Azure.
###############################################################################

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.35"
    }
  }
}

variable "universities" {
  description = "Per-tenant custom hostnames. Key = tenant ID, value = FQDN."
  type        = map(string)
  default     = {}
}

variable "zone_id" {
  description = "Cloudflare zone ID for the shared apex domain."
  type        = string
}

variable "app_hostname" {
  description = "App Service default hostname that every tenant CNAMEs into."
  type        = string
}

# ---------- Per-tenant DNS --------------------------------------------------
resource "cloudflare_record" "tenant" {
  for_each = var.universities
  zone_id  = var.zone_id
  name     = each.value
  value    = var.app_hostname
  type     = "CNAME"
  proxied  = true
}

# ---------- WAF — OWASP managed ruleset -------------------------------------
resource "cloudflare_ruleset" "waf" {
  zone_id = var.zone_id
  name    = "sidecoach-waf"
  kind    = "zone"
  phase   = "http_request_firewall_managed"

  rules {
    action      = "execute"
    expression  = "true"
    description = "OWASP core ruleset"
    enabled     = true
    action_parameters {
      id = "efb7b8c949ac4650a09736fc376e9aee"
    }
  }
}

# ---------- Rate limit on auth endpoints ------------------------------------
# 20 POSTs to /api/auth/* per minute, per IP, else challenge.
resource "cloudflare_rate_limit" "signin" {
  zone_id   = var.zone_id
  threshold = 20
  period    = 60

  match {
    request {
      url_pattern = "*/api/auth/*"
      methods     = ["POST"]
    }
  }

  action {
    mode    = "challenge"
    timeout = 60
  }
}

# ---------- Strict TLS posture for the whole zone ---------------------------
resource "cloudflare_zone_settings_override" "strict_tls" {
  zone_id = var.zone_id

  settings {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"
  }
}
