# BIT-Lab Terraform Konfiguration
# Skeleton für spätere Cloud-Migration (AWS/Azure/GCP)
#
# Verwendung:
#   terraform init
#   terraform plan
#   terraform apply

terraform {
  required_version = ">= 1.0"
  
  # Optional: Remote State Backend
  # backend "s3" {
  #   bucket = "bit-lab-terraform-state"
  #   key    = "bit-lab/terraform.tfstate"
  #   region = "eu-central-1"
  # }
  
  required_providers {
    # Beispiel für AWS
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    # Beispiel für Azure
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    
    # Beispiel für GCP
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Provider-Konfiguration
# Uncomment den Provider, den du verwenden möchtest

# provider "aws" {
#   region = var.aws_region
#   
#   default_tags {
#     tags = {
#       Project     = "BIT-Lab"
#       Environment = "development"
#       ManagedBy   = "Terraform"
#     }
#   }
# }

# provider "azurerm" {
#   features {}
# }

# provider "google" {
#   project = var.gcp_project
#   region  = var.gcp_region
# }

# Variablen werden in variables.tf definiert
# Siehe variables.tf







