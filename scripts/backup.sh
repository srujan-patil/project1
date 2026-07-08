#!/bin/bash
# Creates a timestamped custom-format pg_dump of the local database.
#
# Usage:
#   ./scripts/backup.sh
#
# Env overrides (all optional, defaults match docker-compose.yml):
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, PGPASSWORD

set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-hotelapp}"
DB_USER="${DB_USER:-app_admin}"
export PGPASSWORD="${PGPASSWORD:-app_password}"

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

echo ">> Backing up '${DB_NAME}' from ${DB_HOST}:${DB_PORT} to ${BACKUP_FILE}"

pg_dump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="$BACKUP_FILE" \
  "$DB_NAME"

echo ">> Backup complete: ${BACKUP_FILE}"
echo ">> Size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Keep a stable symlink to the most recent backup for convenience.
ln -sf "$BACKUP_FILE" "${BACKUP_DIR}/latest.dump"
echo ">> Updated ${BACKUP_DIR}/latest.dump -> $(basename "$BACKUP_FILE")"
