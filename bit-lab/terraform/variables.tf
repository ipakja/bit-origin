# BIT-Lab Terraform Variablen
# Alle konfigurierbaren Parameter

variable "bit_core_enabled" {
  description = "Erstelle bit-core VM"
  type        = bool
  default     = true
}

variable "bit_flow_enabled" {
  description = "Erstelle bit-flow VM"
  type        = bool
  default     = true
}

variable "bit_vault_enabled" {
  description = "Erstelle bit-vault VM"
  type        = bool
  default     = true
}

variable "bit_gateway_enabled" {
  description = "Erstelle bit-gateway VM"
  type        = bool
  default     = false
}

# VM-Ressourcen
variable "vm_instance_type" {
  description = "Instance-Typ für VMs (Cloud-spezifisch)"
  type        = map(string)
  default = {
    bit-core   = "t3.small"    # AWS
    bit-flow   = "t3.small"
    bit-vault  = "t3.medium"
    bit-gateway = "t3.micro"
  }
}

# Netzwerk
variable "network_subnet" {
  description = "Subnetz für BIT-Lab"
  type        = string
  default     = "192.168.50.0/24"
}

variable "network_domain" {
  description = "Domain-Name"
  type        = string
  default     = "bitlab.local"
}

# Cloud-spezifische Variablen
variable "aws_region" {
  description = "AWS-Region"
  type        = string
  default     = "eu-central-1"
}

variable "gcp_project" {
  description = "GCP-Projekt-ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP-Region"
  type        = string
  default     = "europe-west1"
}

# SSH-Keys
variable "ssh_public_key" {
  description = "Öffentlicher SSH-Key für VMs"
  type        = string
  sensitive   = true
}

# Security
variable "enable_security_group" {
  description = "Aktiviere Security-Groups"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR für SSH-Zugriff"
  type        = string
  default     = "0.0.0.0/0"  # WARNUNG: In Produktion einschränken!
}

# Tags
variable "common_tags" {
  description = "Gemeinsame Tags für alle Ressourcen"
  type        = map(string)
  default = {
    Project     = "BIT-Lab"
    Environment = "development"
    ManagedBy   = "Terraform"
  }
}







