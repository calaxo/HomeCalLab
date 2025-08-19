#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "Exécute en root: sudo bash scripts/bootstrap.sh"
  exit 1
fi

USER_NAME="${SUDO_USER:-${USER}}"
PORTAINER_VERSION="2.21.5"
DOCKER_CHANNEL="stable"

echo "[*] Installation Docker (script officiel)..."
curl -fsSL https://get.docker.com | sh -s -- --channel ${DOCKER_CHANNEL}

systemctl enable --now docker
usermod -aG docker "${USER_NAME}"

echo "[*] Démarrage Portainer CE..."
docker volume create portainer_data >/dev/null
docker run -d \
  -p 8000:8000 -p 9000:9000 -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:${PORTAINER_VERSION}

echo "=== DONE ==="
echo "Portainer: https://<IP_VM>:9443  (créé ton compte admin au premier accès)"
echo "Déconnecte/Reconnecte ta session pour le groupe docker."
