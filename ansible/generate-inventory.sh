#!/usr/bin/env bash
# Genere l'inventaire Ansible ET la config SSH a partir des sorties Terraform.
# Le sujet exige un inventaire "genere a partir des sorties Terraform" : c'est ici.
#
# Usage : ./generate-inventory.sh
set -euo pipefail

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF="$ICI/../terraform"

# --- Lecture des sorties Terraform (source unique de verite) ---
FRONT_IP=$(terraform -chdir="$TF" output -raw front_public_ip)
FRONT_PRIVATE_IP=$(terraform -chdir="$TF" output -raw front_private_ip)
BACK_IP=$(terraform -chdir="$TF" output -raw back_private_ip)
DB_IP=$(terraform -chdir="$TF" output -raw db_private_ip)
USER=$(terraform -chdir="$TF" output -raw admin_username)
KEY="$HOME/.ssh/id_medishop"

# --- Config SSH ---
# Le Back et la DB n'ont pas d'IP publique : on les atteint en rebondissant
# par le Front (ProxyJump). C'est le principe du bastion.
cat > "$ICI/ssh.cfg" <<EOF
# Fichier GENERE par generate-inventory.sh - ne pas editer a la main

Host medishop-front
    HostName $FRONT_IP
    User $USER
    IdentityFile $KEY
    StrictHostKeyChecking accept-new
    UserKnownHostsFile $ICI/known_hosts

Host medishop-back
    HostName $BACK_IP
    User $USER
    IdentityFile $KEY
    ProxyJump medishop-front
    StrictHostKeyChecking accept-new
    UserKnownHostsFile $ICI/known_hosts

Host medishop-db
    HostName $DB_IP
    User $USER
    IdentityFile $KEY
    ProxyJump medishop-front
    StrictHostKeyChecking accept-new
    UserKnownHostsFile $ICI/known_hosts
EOF

# --- Inventaire Ansible ---
# Les noms d'hotes de l'inventaire sont les ALIAS definis dans ssh.cfg, et non
# les IP : c'est indispensable pour que SSH applique le ProxyJump. S'il voyait
# "10.0.2.10", aucun bloc "Host" ne correspondrait, le rebond serait ignore et
# la connexion expirerait (la machine n'a pas d'IP publique).
cat > "$ICI/inventory.ini" <<EOF
# Fichier GENERE par generate-inventory.sh - ne pas editer a la main
# Source : terraform output

[front]
medishop-front public_ip=$FRONT_IP private_ip=$FRONT_PRIVATE_IP

[back]
medishop-back private_ip=$BACK_IP

[db]
medishop-db private_ip=$DB_IP

[all:vars]
ansible_user=$USER
ansible_python_interpreter=/usr/bin/python3
EOF

echo "Genere depuis terraform output :"
echo "  Front : $FRONT_IP (public)"
echo "  Back  : $BACK_IP  (prive, via rebond)"
echo "  DB    : $DB_IP  (prive, via rebond)"
echo
echo "  -> $ICI/ssh.cfg"
echo "  -> $ICI/inventory.ini"
