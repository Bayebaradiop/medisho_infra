variable "subscription_id" {
  description = "Identifiant de la souscription Azure"
  type        = string
}

variable "prefix" {
  description = "Prefixe applique au nom de toutes les ressources"
  type        = string
  default     = "medishop"
}

variable "location" {
  description = "Region Azure ou deployer l'infrastructure"
  type        = string
  default     = "switzerlandnorth"

  validation {
    condition = contains([
      "spaincentral",
      "swedencentral",
      "switzerlandnorth",
      "italynorth",
      "brazilsouth",
    ], var.location)
    error_message = "Region interdite par la politique Azure for Students. Autorisees : spaincentral, swedencentral, switzerlandnorth, italynorth, brazilsouth."
  }
}

variable "vm_size" {
  description = "Taille des VMs (B2ls_v2 = 2 vCPU, 4 Go, burstable)"
  type        = string
  default     = "Standard_B2ls_v2"
}

variable "admin_username" {
  description = "Utilisateur administrateur cree sur les VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Chemin de la cle publique SSH deposee sur les VMs"
  type        = string
  default     = "~/.ssh/id_medishop.pub"
}

variable "admin_source_ip" {
  description = "IP publique de l'administrateur, seule autorisee a se connecter en SSH au Front"
  type        = string
}

variable "vnet_cidr" {
  description = "Plage d'adresses du reseau virtuel"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Sous-reseau public : le Front"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Sous-reseau prive : le Back et la DB"
  type        = string
  default     = "10.0.2.0/24"
}

variable "front_private_ip" {
  description = "IP privee fixe de la VM Front"
  type        = string
  default     = "10.0.1.10"
}

variable "back_private_ip" {
  description = "IP privee fixe de la VM Back"
  type        = string
  default     = "10.0.2.10"
}

variable "db_private_ip" {
  description = "IP privee fixe de la VM DB"
  type        = string
  default     = "10.0.2.20"
}

variable "backend_port" {
  description = "Port ecoute par l'API sur la VM Back"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port ecoute par PostgreSQL sur la VM DB"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Tags appliques a toutes les ressources"
  type        = map(string)
  default = {
    projet = "medishop-todoapp"
    cours  = "devops-ecole221"
  }
}
