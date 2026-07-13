# MediShop — Infrastructure

Infrastructure as Code de la Todo App MediShop, deployee sur **Azure**.

- **Terraform** : reseau, pare-feux et machines virtuelles
- **Ansible** : configuration des machines (Docker, Nginx, PostgreSQL)

Les applications vivent dans deux autres depots :
[devops_b](https://github.com/Bayebaradiop/devops_b) (backend) et
[devops_f](https://github.com/Bayebaradiop/devops_f) (frontend).

## Architecture

```
                        Internet
                           |
                      [ NSG Front ]  22 (admin seul) / 80 / 443
                           |
  Sous-reseau PUBLIC   +---------+
  10.0.1.0/24          |  FRONT  |  Nginx (reverse proxy) + conteneur React
                       | .1.10   |  IP publique
                       +---------+
                           |  8080
                      [ NSG Back ]   depuis le Front uniquement
                           |
  Sous-reseau PRIVE    +---------+
  10.0.2.0/24          |  BACK   |  API Spring Boot
                       | .2.10   |  AUCUNE IP publique
                       +---------+
                           |  5432
                      [ NSG DB ]     depuis le Back uniquement
                           |
                       +---------+
                       |   DB    |  PostgreSQL 16
                       | .2.20   |  AUCUNE IP publique
                       +---------+

  Les VMs privees sortent sur Internet via une NAT Gateway (sortant seulement),
  ce qui leur permet de faire "docker pull" sans jamais etre joignables.
```

## Prerequis

- Terraform >= 1.5, Ansible >= 2.16, Azure CLI (`az login`)
- Une cle SSH : `ssh-keygen -t ed25519 -f ~/.ssh/id_medishop -N ""`

## 1. Provisionner l'infrastructure (Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # puis renseigner ses valeurs
terraform init
terraform plan      # toujours regarder avant d'appliquer
terraform apply
```

Sorties : IP publique du Front, IP privees du Back et de la DB.

### Contraintes Azure for Students (verifiees a nos depens)

1. **Regions limitees** par une Azure Policy : seules `spaincentral`, `swedencentral`,
   `switzerlandnorth`, `italynorth`, `brazilsouth` sont autorisees. Sinon :
   `403 RequestDisallowedByAzure`. Un bloc `validation` bloque l'erreur en local.

2. **Le Standard_B1s n'est pas disponible** dans ces regions pour ce type de
   souscription (`409 SkuNotAvailable`). On utilise `Standard_B2ls_v2`.
   Cette penurie est **dynamique** : aucune commande ne la predit, seule une
   creation reelle de VM permet de la verifier.

3. **Quota : 6 vCPU au total.** 3 VMs x 2 vCPU = 6. Aucune marge.

## 2. Configurer les machines (Ansible)

```bash
cd ansible
./generate-inventory.sh          # lit terraform output, ecrit inventory.ini + ssh.cfg
export DB_PASSWORD='...'         # aucun secret n'est versionne
ansible-playbook playbook.yml
```

Le playbook est **idempotent** : le rejouer affiche `changed=0`.

| Role | Cible | Ce qu'il fait |
|------|-------|---------------|
| `docker` | les 3 VMs | Docker Engine + Compose (depot officiel) |
| `database` | DB | PostgreSQL 16 en conteneur, volume persistant, schema initial |
| `nginx` | Front | Reverse proxy : `/` vers le conteneur React, `/api/` vers le Back |

Le Back et la DB n'ayant pas d'IP publique, Ansible les atteint en **rebondissant
par le Front** (ProxyJump), configure automatiquement dans `ssh.cfg`.

## Securite

- SSH sur le Front : **uniquement depuis l'IP de l'administrateur**
- Back et DB : **aucune IP publique**, joignables seulement via le bastion
- **Piege Azure corrige** : chaque NSG contient une regle implicite
  `AllowVnetInBound` (priorite 65000) qui autorise TOUT le trafic interne au
  reseau virtuel. Les regles `Allow` seules ne protegent donc de rien : le Front
  pouvait joindre PostgreSQL directement. Un `Deny` explicite en priorite 4000
  (donc AVANT le 65000) neutralise ce comportement.
- Aucun secret dans le depot : mots de passe par variables d'environnement,
  `terraform.tfvars` et `.secrets.env` ignores par Git.

## Detruire l'infrastructure

```bash
cd terraform && terraform destroy
```

La suppression du groupe de ressources est **asynchrone** cote Azure : attendre
la confirmation (`az group exists -n medishop-rg` doit renvoyer `false`) avant
de recreer, sinon les ressources entrent en conflit.
