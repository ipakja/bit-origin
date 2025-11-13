# BIT-Lab Terraform Outputs
# Ausgabewerte nach terraform apply

# VM-IPs
output "bit_core_ip" {
  description = "IP-Adresse von bit-core"
  value       = try(module.bit_core[0].public_ip, module.bit_core[0].private_ip, "")
}

output "bit_flow_ip" {
  description = "IP-Adresse von bit-flow"
  value       = try(module.bit_flow[0].public_ip, module.bit_flow[0].private_ip, "")
}

output "bit_vault_ip" {
  description = "IP-Adresse von bit-vault"
  value       = try(module.bit_vault[0].public_ip, module.bit_vault[0].private_ip, "")
}

output "bit_gateway_ip" {
  description = "IP-Adresse von bit-gateway"
  value       = try(module.bit_gateway[0].public_ip, module.bit_gateway[0].private_ip, "")
}

# Zugriff-Informationen
output "ssh_command" {
  description = "SSH-Befehl für Zugriff"
  value       = "ssh admin@${try(module.bit_core[0].public_ip, module.bit_core[0].private_ip, "")}"
}

# Network-Informationen
output "vpc_id" {
  description = "VPC-ID (Cloud-spezifisch)"
  value       = try(module.network.vpc_id, "")
}

output "subnet_id" {
  description = "Subnet-ID"
  value       = try(module.network.subnet_id, "")
}

# Status-URLs (wenn Load-Balancer vorhanden)
output "status_url" {
  description = "URL für Status-Seite"
  value       = try("http://${module.bit_core[0].public_ip}:19999", "")
}







