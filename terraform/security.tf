# ============================================================
#  Security Groups : un par couche (Front / Back / DB)
#
#  PIEGE AZURE A CONNAITRE : chaque NSG embarque TROIS regles par defaut,
#  et pas seulement le DenyAll :
#
#    65000  AllowVnetInBound              <-- autorise TOUT le trafic interne au VNet
#    65001  AllowAzureLoadBalancerInBound
#    65500  DenyAllInBound
#
#  La regle 65000 laisse donc passer, par defaut, TOUTE communication entre
#  machines du meme reseau virtuel. Se contenter de regles "Allow" ne protege
#  de rien en interne : le Front pourrait joindre PostgreSQL directement.
#  (Verifie : c'etait bien le cas avant l'ajout des regles Deny ci-dessous.)
#
#  On ajoute donc, sur le Back et la DB, un "Deny" explicite en priorite 4000 :
#  il passe AVANT le AllowVnetInBound (65000), mais APRES nos regles Allow
#  (100, 110). Resultat : seules les communications listees sont possibles.
#  Internet, lui, reste bloque par le DenyAllInBound.
#
#  Les NSG sont attaches aux CARTES RESEAU et non aux sous-reseaux : le Back
#  et la DB partagent le meme sous-reseau prive, or un sous-reseau ne peut
#  porter qu'un seul NSG. Le niveau carte reseau permet une regle par couche.
# ============================================================

# ------------------------------------------------------------
#  FRONT : seule machine joignable depuis Internet
# ------------------------------------------------------------
resource "azurerm_network_security_group" "front" {
  name                = "${var.prefix}-nsg-front"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  # SSH : uniquement depuis l'IP de l'administrateur, jamais depuis Internet
  security_rule {
    name                       = "AllowSshFromAdmin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_ip
    destination_address_prefix = "*"
  }

  # HTTP : ouvert a tous. Sert le site, et permet a Certbot de valider
  # le domaine (challenge HTTP-01 de Let's Encrypt).
  security_rule {
    name                       = "AllowHttpFromInternet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # HTTPS : ouvert a tous, c'est par la que passeront les visiteurs
  security_rule {
    name                       = "AllowHttpsFromInternet"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

# ------------------------------------------------------------
#  BACK : joignable UNIQUEMENT par le Front
# ------------------------------------------------------------
resource "azurerm_network_security_group" "back" {
  name                = "${var.prefix}-nsg-back"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  # L'API n'accepte que le trafic venant de l'IP privee du Front
  security_rule {
    name                       = "AllowApiFromFront"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.backend_port)
    source_address_prefix      = var.front_private_ip
    destination_address_prefix = "*"
  }

  # SSH depuis le Front seulement : le Front sert de rebond (bastion) pour
  # qu'Ansible et Jenkins atteignent cette machine, qui n'a pas d'IP publique.
  security_rule {
    name                       = "AllowSshFromFront"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.front_private_ip
    destination_address_prefix = "*"
  }

  # Neutralise le AllowVnetInBound (65000) : sans cette regle, n'importe quelle
  # machine du VNet pourrait joindre n'importe quel port du Back.
  security_rule {
    name                       = "DenyAllOtherVnetTraffic"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# ------------------------------------------------------------
#  DB : joignable UNIQUEMENT par le Back
# ------------------------------------------------------------
resource "azurerm_network_security_group" "db" {
  name                = "${var.prefix}-nsg-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  # PostgreSQL n'accepte que le trafic venant de l'IP privee du Back.
  # Le Front ne peut PAS joindre la base : il n'en a pas besoin.
  security_rule {
    name                       = "AllowPostgresFromBack"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.db_port)
    source_address_prefix      = var.back_private_ip
    destination_address_prefix = "*"
  }

  # SSH depuis le Front : necessaire pour qu'Ansible provisionne cette machine
  security_rule {
    name                       = "AllowSshFromFront"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.front_private_ip
    destination_address_prefix = "*"
  }

  # Neutralise le AllowVnetInBound (65000). Sans cette regle, le Front pouvait
  # ouvrir une connexion directe a PostgreSQL, ce que le sujet interdit :
  # "Le Back peut acceder a la DB. Aucune autre communication n'est autorisee."
  security_rule {
    name                       = "DenyAllOtherVnetTraffic"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}
