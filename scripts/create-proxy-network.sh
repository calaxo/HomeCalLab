#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
NET_NAME="${NET_NAME:-proxy}"       # nom du réseau docker
SUBNET_CIDR="${SUBNET_CIDR:-}"      # ex: "172.23.0.0/24" (laisser vide pour auto)
GATEWAY_IP="${GATEWAY_IP:-}"        # ex: "172.23.0.1"    (laisser vide pour auto)
MTU="${MTU:-}"                      # ex: "1500"          (laisser vide pour défaut)
# ==========================

# On vérifie que docker est dispo
command -v docker >/dev/null 2>&1 || { echo "Docker introuvable. Installe-le d'abord."; exit 1; }

# Existe déjà ?
if docker network inspect "$NET_NAME" >/dev/null 2>&1; then
  echo "[OK] Réseau '$NET_NAME' existe déjà."
  # Affiche l'IPAM actuel
  docker network inspect "$NET_NAME" --format '{{json .IPAM.Config}}' | jq 2>/dev/null || true
  exit 0
fi

echo "[*] Création du réseau '$NET_NAME'..."

create_args=( "network" "create" "--driver" "bridge" "$NET_NAME" )

# Subnet/gateway si fournis
if [[ -n "$SUBNET_CIDR" ]]; then
  create_args+=( "--subnet" "$SUBNET_CIDR" )
fi
if [[ -n "$GATEWAY_IP" ]]; then
  create_args+=( "--gateway" "$GATEWAY_IP" )
fi

# MTU si fourni (via option com.docker.network.driver.mtu)
if [[ -n "$MTU" ]]; then
  create_args+=( "--opt" "com.docker.network.driver.mtu=${MTU}" )
fi

docker "${create_args[@]}"

echo "[OK] Réseau '$NET_NAME' créé."
docker network inspect "$NET_NAME" --format '{{json .IPAM.Config}}' | jq 2>/dev/null || true
