#!/usr/bin/env bash
set -euo pipefail
# ================================================================
# immich-backups.sh
# Gère le volume Docker des backups Immich (sans montages hôte)
#
# Usage :
#   ./immich-backups.sh --list
#   ./immich-backups.sh --copy-from ./mon-backup.sql.gz
#   ./immich-backups.sh --restore export-2025-08-21.sql.gz --user postgres --password postgres
#
# Options (par défaut, override via --flags) :
#   --volume   Nom du volume (defaut: immich_backups)
#   --net      Réseau docker (defaut: immich_net)
#   --host     Nom du conteneur DB (defaut: immich_postgres)
#   --db       Nom de la base (defaut: postgres)
#   --user     Utilisateur DB
#   --password Mot de passe DB
# ================================================================

VOLUME="immich_backups"
NET="immich_net"
DBHOST="immich_postgres"
DBNAME="postgres"
DBUSER=""
DBPASS=""
FILE=""
MODE=""

usage() {
  cat <<EOF
Usage:
  $0 --list
  $0 --copy-from <fichier_local>
  $0 --restore <fichier.sql.gz|fichier.dump> --user <DB_USER> --password <DB_PASS>

Options :
  --volume <nom>    Volume docker (defaut: $VOLUME)
  --net <nom>       Réseau docker (defaut: $NET)
  --host <nom>      Conteneur DB (defaut: $DBHOST)
  --db <nom>        Base de données (defaut: $DBNAME)
EOF
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) MODE="list"; shift ;;
    --copy-from) MODE="copy"; FILE="${2:-}"; shift 2 ;;
    --restore) MODE="restore"; FILE="${2:-}"; shift 2 ;;
    --volume) VOLUME="${2:-}"; shift 2 ;;
    --net) NET="${2:-}"; shift 2 ;;
    --host) DBHOST="${2:-}"; shift 2 ;;
    --db) DBNAME="${2:-}"; shift 2 ;;
    --user) DBUSER="${2:-}"; shift 2 ;;
    --password) DBPASS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Arg inconnu: $1"; usage; exit 1 ;;
  esac
done

# --- Fonctions ---
list_backups() {
  docker run --rm -v "${VOLUME}":/b alpine:3 sh -lc 'ls -lah /b || true'
}

copy_from() {
  [[ -n "$FILE" ]] || { echo "Chemin local manquant"; exit 1; }
  [[ -f "$FILE" ]] || { echo "Fichier introuvable: $FILE"; exit 1; }
  docker run --rm -v "$(pwd)":/from -v "${VOLUME}":/b alpine:3 \
    sh -lc 'cp -a "/from/'"$(basename "$FILE")"'" /b && ls -lh /b'
}

restore_backup() {
  [[ -n "$FILE" ]] || { echo "--restore <fichier> requis"; exit 1; }
  [[ -n "$DBUSER" ]] || { echo "--user requis"; exit 1; }
  [[ -n "$DBPASS" ]] || { echo "--password requis"; exit 1; }

  echo "[*] Restore $FILE depuis $VOLUME → $DBHOST/$DBNAME"
  if [[ "$FILE" == *.sql.gz ]]; then
    docker run --rm --network "$NET" -e PGPASSWORD="$DBPASS" -v "$VOLUME":/backup postgres:16 \
      bash -lc 'gunzip -c "/backup/'"$FILE"'" \
      | sed "s/SELECT pg_catalog.set_config('\''search_path'\'', '\'''\'' , false);/SELECT pg_catalog.set_config('\''search_path'\'', '\''public, pg_catalog'\'', true);/g" \
      | psql -h '"$DBHOST"' -U '"$DBUSER"' -d '"$DBNAME"''
  elif [[ "$FILE" == *.dump ]]; then
    docker run --rm --network "$NET" -e PGPASSWORD="$DBPASS" -v "$VOLUME":/backup postgres:16 \
      pg_restore -h "$DBHOST" -U "$DBUSER" -d "$DBNAME" --clean --if-exists "/backup/$FILE"
  else
    echo "Extension non supportée (attendu .sql.gz ou .dump)"; exit 1
  fi
  echo "[OK] Restore terminé."
}

# --- Dispatcher ---
case "$MODE" in
  list) list_backups ;;
  copy) copy_from ;;
  restore) restore_backup ;;
  *) usage; exit 1 ;;
esac
