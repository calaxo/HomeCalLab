#!/usr/bin/env bash
set -euo pipefail
# ================================================================
# immich-backups.sh (in-place)
# Gère le volume immich_backups monté dans le conteneur immich_postgres
#
# Usage :
#   ./immich-backups.sh --list
#   ./immich-backups.sh --restore <fichier.sql.gz|fichier.dump> --user <DB_USER> --password <DB_PASS> [--db <DBNAME>]
#
# Par défaut :
#   CONTAINER=immich_postgres
#   DBNAME=postgres
#   BACKUP_DIR=/backup
# ================================================================

CONTAINER="immich_postgres2"
DBNAME="postgres"
DBUSER=""
DBPASS=""
FILE=""
MODE=""

usage() {
  cat <<EOF
Usage:
  $0 --list
  $0 --restore <fichier.sql.gz|fichier.dump> --user <DB_USER> --password <DB_PASS> [--db <DBNAME>]

Options :
  --container <nom>   (defaut: $CONTAINER)
  --db <nom>          (defaut: $DBNAME)
EOF
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) MODE="list"; shift ;;
    --restore) MODE="restore"; FILE="${2:-}"; shift 2 ;;
    --user) DBUSER="${2:-}"; shift 2 ;;
    --password) DBPASS="${2:-}"; shift 2 ;;
    --db) DBNAME="${2:-}"; shift 2 ;;
    --container) CONTAINER="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Arg inconnu: $1"; usage; exit 1 ;;
  esac
done

list_backups() {
  docker exec -i "$CONTAINER" sh -lc "ls -lah /backup || true"
}

restore_backup() {
  [[ -n "$FILE" ]] || { echo "--restore <fichier> requis"; exit 1; }
  [[ -n "$DBUSER" ]] || { echo "--user requis"; exit 1; }
  [[ -n "$DBPASS" ]] || { echo "--password requis"; exit 1; }

  echo "[*] Restore $FILE depuis $CONTAINER:/backup → DB $DBNAME"
  if [[ "$FILE" == *.sql.gz ]]; then
    docker exec -i -e PGPASSWORD="$DBPASS" "$CONTAINER" sh -lc \
      'gunzip -c "/backup/'"$FILE"'" \
       | sed "s/SELECT pg_catalog.set_config('\''search_path'\'', '\'''\'' , false);/SELECT pg_catalog.set_config('\''search_path'\'', '\''public, pg_catalog'\'', true);/g" \
       | psql -h 127.0.0.1 -U '"$DBUSER"' -d '"$DBNAME"''
  elif [[ "$FILE" == *.dump ]]; then
    docker exec -i -e PGPASSWORD="$DBPASS" "$CONTAINER" sh -lc \
      'pg_restore -h 127.0.0.1 -U '"$DBUSER"' -d '"$DBNAME"' --clean --if-exists "/backup/'"$FILE"'"'
  else
    echo "Extension non supportée (attendu .sql.gz ou .dump)"; exit 1
  fi
  echo "[OK] Restore terminé."
}

case "$MODE" in
  list) list_backups ;;
  restore) restore_backup ;;
  *) usage; exit 1 ;;
esac
