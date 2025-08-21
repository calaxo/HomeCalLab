#!/usr/bin/env bash
set -euo pipefail

# ================================================================
# immich-backups.sh
# Gère le volume Docker des backups Immich (sans montages sur l'hôte)
#   - Liste:      ./immich-backups.sh --list
#   - Restore:    DB_USERNAME=... DB_PASSWORD=... ./immich-backups.sh --restore <fichier.sql.gz|fichier.dump>
#   - Copier in:  ./immich-backups.sh --copy-from ./mon-backup.sql.gz
#
# Par défaut:
#   VOLUME=immich_backups   (volume docker où Immich met ses exports)
#   NET=immich_net          (réseau docker interne de la stack Immich)
#   DBHOST=immich_postgres  (nom du conteneur DB)
#   DBNAME=postgres         (base cible pour le restore)
#   IMG=postgres:16         (image client psql/pg_restore)
#
# Tu peux override en env: VOLUME=... NET=... DBHOST=... DBNAME=... IMG=...
# ================================================================

VOLUME="${VOLUME:-immich_backups}"
NET="${NET:-immich_net}"
DBHOST="${DBHOST:-immich_postgres}"
DBNAME="${DBNAME:-postgres}"
IMG="${IMG:-postgres:16}"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --list
  DB_USERNAME=... DB_PASSWORD=... $(basename "$0") --restore <fichier.sql.gz|fichier.dump>
  $(basename "$0") --copy-from </chemin/local/vers/fichier>

Options env:
  VOLUME=$VOLUME   NET=$NET   DBHOST=$DBHOST   DBNAME=$DBNAME   IMG=$IMG
EOF
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "Commande '$1' introuvable"; exit 1; }; }

list_backups() {
  docker run --rm -v "${VOLUME}":/b alpine:3 sh -lc 'ls -lah /b || true'
}

copy_from() {
  local src="$1"
  [[ -f "$src" ]] || { echo "Fichier local introuvable: $src"; exit 1; }
  docker run --rm -v "$(pwd)":/from -v "${VOLUME}":/b alpine:3 \
    sh -lc 'cp -a "/from/'"$(basename "$src")"'" /b && ls -lh /b'
}

restore_backup() {
  local file="$1"
  [[ -n "${DB_USERNAME:-}" ]] || { echo "DB_USERNAME manquant (exporte-le en variable d'environnement)"; exit 1; }
  [[ -n "${DB_PASSWORD:-}" ]] || { echo "DB_PASSWORD manquant (exporte-le en variable d'environnement)"; exit 1; }

  echo "[*] Test présence du fichier dans le volume ${VOLUME}: $file"
  docker run --rm -v "${VOLUME}":/b alpine:3 sh -lc '[ -f "/b/'"$file"'" ] || { echo "Fichier absent dans le volume"; exit 2; }'

  if [[ "$file" == *.sql.gz ]]; then
    echo "[*] Restore .sql.gz -> psql (avec sed du search_path)"
    docker run --rm --network "${NET}" \
      -e "PGPASSWORD=${DB_PASSWORD}" \
      -v "${VOLUME}":/backup \
      "${IMG}" bash -lc \
      'gunzip -c "/backup/'"$file"'" \
       | sed "s/SELECT pg_catalog.set_config('\''search_path'\'', '\'''\'' , false);/SELECT pg_catalog.set_config('\''search_path'\'', '\''public, pg_catalog'\'', true);/g" \
       | psql -h '"${DBHOST}"' -U '"${DB_USERNAME}"' -d '"${DBNAME}"''
  elif [[ "$file" == *.dump ]]; then
    echo "[*] Restore .dump -> pg_restore"
    docker run --rm --network "${NET}" \
      -e "PGPASSWORD=${DB_PASSWORD}" \
      -v "${VOLUME}":/backup \
      "${IMG}" pg_restore -h "${DBHOST}" -U "${DB_USERNAME}" -d "${DBNAME}" --clean --if-exists "/backup/${file}"
  else
    echo "Extension non supportée (attendu .sql.gz ou .dump)"; exit 1
  fi

  echo "[OK] Restore terminé."
}

main() {
  need docker
  [[ $# -ge 1 ]] || { usage; exit 1; }

  case "${1:-}" in
    --list)
      list_backups
      ;;
    --copy-from)
      [[ $# -ge 2 ]] || { echo "--copy-from <fichier_local>"; exit 1; }
      copy_from "$2"
      ;;
    --restore)
      [[ $# -ge 2 ]] || { echo "--restore <fichier.sql.gz|fichier.dump>"; exit 1; }
      restore_backup "$2"
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage; exit 1 ;;
  esac
}

main "$@"
