# BIT-Lab Terraform Beispiel-Konfiguration
# Zeigt, wie VMs in der Cloud erstellt werden können
#
# HINWEIS: Dies ist ein Skeleton. Passe die Konfiguration an deine Cloud an.

# Beispiel für AWS EC2 Instances
# Uncomment und passe an:

# module "bit_core" {
#   count  = var.bit_core_enabled ? 1 : 0
#   source = "./modules/ec2-instance"
#   
#   instance_name = "bit-core"
#   instance_type = var.vm_instance_type["bit-core"]
#   subnet_id     = module.network.subnet_id
#   ssh_key       = var.ssh_public_key
#   
#   tags = merge(var.common_tags, {
#     Role = "dns-dhcp-syslog"
#   })
# }
#
# module "bit_flow" {
#   count  = var.bit_flow_enabled ? 1 : 0
#   source = "./modules/ec2-instance"
#   
#   instance_name = "bit-flow"
#   instance_type = var.vm_instance_type["bit-flow"]
#   subnet_id     = module.network.subnet_id
#   ssh_key       = var.ssh_public_key
#   
#   tags = merge(var.common_tags, {
#     Role = "automation-apis"
#   })
# }
#
# module "bit_vault" {
#   count  = var.bit_vault_enabled ? 1 : 0
#   source = "./modules/ec2-instance"
#   
#   instance_name = "bit-vault"
#   instance_type = var.vm_instance_type["bit-vault"]
#   subnet_id     = module.network.subnet_id
#   ssh_key       = var.ssh_public_key
#   
#   tags = merge(var.common_tags, {
#     Role = "storage-backups"
#   })
# }
#
# module "network" {
#   source = "./modules/vpc"
#   
#   vpc_cidr     = var.network_subnet
#   subnet_cidrs = ["10.0.1.0/24"]
#   
#   tags = var.common_tags
# }

# Beispiel für Azure VMs
# Uncomment und passe an:

# resource "azurerm_virtual_machine" "bit_core" {
#   count               = var.bit_core_enabled ? 1 : 0
#   name                = "bit-core"
#   location            = azurerm_resource_group.bit_lab.location
#   resource_group_name = azurerm_resource_group.bit_lab.name
#   vm_size             = var.vm_instance_type["bit-core"]
#   
#   # ... weitere Konfiguration
# }

# Beispiel für GCP Compute Instances
# Uncomment und passe an:

# resource "google_compute_instance" "bit_core" {
#   count        = var.bit_core_enabled ? 1 : 0
#   name         = "bit-core"
#   machine_type = var.vm_instance_type["bit-core"]
#   zone         = "${var.gcp_region}-a"
#   
#   # ... weitere Konfiguration
# }







