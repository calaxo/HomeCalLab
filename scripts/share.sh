#!/bin/bash
set -euo pipefail

# === PARAMÈTRES ===
TRUENAS_IP="${1:-}"
POOL_PATH="${2:-}"
MOUNT_BASE="/mnt"                            # où monter sur ta VM Ubuntu
SHARES=("WEB" "RISK" "SECU" "PERSO")         # tes 4 exports

# === CHECK PARAMS ===
if [[ -z "$TRUENAS_IP" || -z "$POOL_PATH" ]]; then
  echo "❌ Usage: $0 <TRUENAS_IP> <POOL_PATH>"
  echo "Exemple: $0 192.168.1.100 /mnt/main/pleindepartage"
  exit 1
fi

# === PRÉREQUIS ===
sudo apt-get update -y
sudo apt-get install -y nfs-common

# === CRÉER LES POINTS DE MONTAGE ===
for share in "${SHARES[@]}"; do
  sudo mkdir -p "${MOUNT_BASE}/${share}"
done

# === SAUVEGARDE DE FSTAB ===
sudo cp /etc/fstab /etc/fstab.bak.$(date +%F-%H%M)

# === AJOUT DANS /etc/fstab SI MANQUANT ===
for share in "${SHARES[@]}"; do
  LINE="${TRUENAS_IP}:${POOL_PATH}/${share}  ${MOUNT_BASE}/${share}  nfs4  rw,soft,timeo=50,_netdev  0  0"
  if ! grep -q "${MOUNT_BASE}/${share}" /etc/fstab; then
    echo "$LINE" | sudo tee -a /etc/fstab
  else
    echo "ℹ️  Entrée déjà présente pour ${MOUNT_BASE}/${share}, skip."
  fi
done

# === MONTER ===
sudo mount -a

echo "✅ Partages montés :"
mount | grep "${MOUNT_BASE}"
