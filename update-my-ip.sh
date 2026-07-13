#!/usr/bin/env bash
set -euo pipefail

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF="$ICI/terraform"

echo "==> Recherche de l'IP publique actuelle..."
IP=$(curl -s -m 15 https://api.ipify.org || true)

if [ -z "$IP" ]; then
    echo "!!! Impossible de determiner l'IP publique. Y a-t-il un acces Internet ?"
    exit 1
fi

ANCIENNE=$(grep -oP 'admin_source_ip\s*=\s*"\K[^"]+' "$TF/terraform.tfvars" 2>/dev/null || echo "aucune")

echo "    IP autorisee actuellement : $ANCIENNE"
echo "    IP publique detectee      : $IP"

if [ "$IP" = "$ANCIENNE" ]; then
    echo "==> Rien a faire : l'IP n'a pas change."
    exit 0
fi

echo "==> Mise a jour de terraform.tfvars"
sed -i "s|^admin_source_ip.*|admin_source_ip = \"$IP\"|" "$TF/terraform.tfvars"

echo "==> terraform apply"
terraform -chdir="$TF" apply -auto-approve -no-color | grep -E "will be updated|Apply complete|Error"

echo "==> Verification : le SSH fonctionne-t-il ?"
FRONT=$(terraform -chdir="$TF" output -raw front_public_ip)
USER=$(terraform -chdir="$TF" output -raw admin_username)

sleep 10

if ssh -i ~/.ssh/id_medishop \
       -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=20 -o BatchMode=yes \
       "$USER@$FRONT" "true" 2>/dev/null; then
    echo "==> OK : acces SSH retabli depuis $IP"
else
    echo "!!! Le SSH ne repond toujours pas. Verifier que la VM est bien demarree."
    exit 1
fi
