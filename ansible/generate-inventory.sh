#!/usr/bin/env bash
set -euo pipefail

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF="$ICI/../terraform"

FRONT_IP=$(terraform -chdir="$TF" output -raw front_public_ip)
FRONT_PRIVATE_IP=$(terraform -chdir="$TF" output -raw front_private_ip)
BACK_IP=$(terraform -chdir="$TF" output -raw back_private_ip)
DB_IP=$(terraform -chdir="$TF" output -raw db_private_ip)
USER=$(terraform -chdir="$TF" output -raw admin_username)
KEY="$HOME/.ssh/id_medishop"

cat > "$ICI/ssh.cfg" <<EOF
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

cat > "$ICI/inventory.ini" <<EOF
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
