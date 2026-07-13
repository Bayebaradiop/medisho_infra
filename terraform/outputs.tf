# Sorties exigees par le sujet. Elles serviront a generer l'inventaire Ansible
# (etape 2) et a configurer Jenkins (etape 4).

output "front_public_ip" {
  description = "IP publique du Front : c'est elle que le domaine DuckDNS doit pointer"
  value       = azurerm_public_ip.front.ip_address
}

output "front_private_ip" {
  description = "IP privee du Front"
  value       = azurerm_network_interface.front.private_ip_address
}

output "back_private_ip" {
  description = "IP privee du Back (aucune IP publique)"
  value       = azurerm_network_interface.back.private_ip_address
}

output "db_private_ip" {
  description = "IP privee de la DB (aucune IP publique)"
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
  description = "Commande pour se connecter au Front"
  value       = "ssh -i ~/.ssh/id_medishop ${var.admin_username}@${azurerm_public_ip.front.ip_address}"
}

output "ssh_back" {
  description = "Commande pour se connecter au Back, en rebondissant par le Front"
  value       = "ssh -i ~/.ssh/id_medishop -J ${var.admin_username}@${azurerm_public_ip.front.ip_address} ${var.admin_username}@${var.back_private_ip}"
}
