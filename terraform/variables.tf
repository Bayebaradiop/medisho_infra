# Aucune valeur sensible ou specifique a l'environnement n'est ecrite en dur :
# tout passe par des variables, renseignees dans terraform.tfvars (non versionne).

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

  # Deux contraintes se cumulent sur une souscription "Azure for Students" :
  #
  # 1. La politique "Allowed resource deployment regions" limite le deploiement
  #    aux 5 regions listees ci-dessous (sinon : 403 RequestDisallowedByAzure).
  # 2. Parmi ces 5 regions, la taille B1s n'est pas partout disponible pour ce
  #    type de souscription (sinon : 409 SkuNotAvailable). Verifie a Madrid et
  #    a Stockholm : bloquee. Zurich : disponible.
  #
  # Verifier avant tout apply :
  #   az vm list-skus -l <region> --size Standard_B1s --all \
  #     --query "[0].restrictions[].reasonCode" -o tsv
  # Une sortie VIDE signifie "disponible".
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

  # Le Standard_B1s a ete abandonne : Azure le refuse en 409 SkuNotAvailable
  # ("Capacity Restrictions") a Zurich comme a Madrid pour cette souscription.
  #
  # ATTENTION : ce type de penurie est DYNAMIQUE. Ni "az vm list-sizes" ni
  # "az vm list-skus" ne permettent de la prevoir : la seule verification fiable
  # est de creer reellement une VM de test.
  #
  # Le B2ls_v2 (famille Bsv2, quota 10 vCPU) a ete valide par une creation reelle.
  # 3 VMs x 2 vCPU = 6 vCPU, soit exactement la limite regionale (6). Aucune marge :
  # une 4e VM serait refusee.
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

# --- Plan d'adressage ---

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

# IP privees fixes : elles permettent d'ecrire des regles de pare-feu
# precises (telle machine vers telle machine) plutot que "tout le sous-reseau".

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

# --- Ports applicatifs ---

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
