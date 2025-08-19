#!/usr/bin/env bash
set -euo pipefail
NET_NAME="${NET_NAME:-proxy}"

command -v docker >/dev/null 2>&1 || { echo "Docker introuvable."; exit 1; }

if ! docker network inspect "$NET_NAME" >/dev/null 2>&1; then
  echo "Le réseau '$NET_NAME' n'existe pas."
  exit 1
fi

echo "=== $NET_NAME INFO ==="
docker network inspect "$NET_NAME" --format 'Name: {{.Name}} | Driver: {{.Driver}} | Scope: {{.Scope}}'
echo "--- IPAM ---"
docker network inspect "$NET_NAME" --format '{{json .IPAM.Config}}' | jq
echo "--- Containers ---"
docker network inspect "$NET_NAME" --format '{{json .Containers}}' | jq
