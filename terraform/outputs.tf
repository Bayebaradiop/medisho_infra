output "front_public_ip" {
  description = "IP publique du Front"
  value       = azurerm_public_ip.front.ip_address
}

output "front_private_ip" {
  description = "IP privee du Front"
  value       = azurerm_network_interface.front.private_ip_address
}

output "back_private_ip" {
  description = "IP privee du Back"
  value       = azurerm_network_interface.back.private_ip_address
}

output "db_private_ip" {
  description = "IP privee de la DB"
  value       = azurerm_network_interface.db.private_ip_address
}

output "nat_gateway_ip" {
  description = "IP de sortie des VMs privees vers Internet"
  value       = azurerm_public_ip.nat.ip_address
}

output "admin_username" {
  description = "Utilisateur SSH des VMs"
  value       = var.admin_username
}

output "ssh_front" {
  description = "Commande de connexion au Front"
  value       = "ssh -i ~/.ssh/id_medishop ${var.admin_username}@${azurerm_public_ip.front.ip_address}"
}

output "ssh_back" {
  description = "Commande de connexion au Back, via rebond par le Front"
  value       = "ssh -i ~/.ssh/id_medishop -J ${var.admin_username}@${azurerm_public_ip.front.ip_address} ${var.admin_username}@${var.back_private_ip}"
}
