#!/bin/bash
# Restores a backup produced by backup.sh into a FRESH database (dropped and
# recreated), so restore correctness never depends on the state of an
# existing database.
#
# Usage:
#   ./scripts/restore.sh [path/to/backup.dump] [target_db_name]
#
# Defaults:
#   backup file  -> backups/latest.dump  (symlink created by backup.sh)
#   target db    -> ${DB_NAME}_restore   (so it never clobbers the live DB)
#
# Env overrides: DB_HOST, DB_PORT, DB_NAME, DB_USER, PGPASSWORD

set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-hotelapp}"
DB_USER="${DB_USER:-app_admin}"
export PGPASSWORD="${PGPASSWORD:-app_password}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_FILE="${1:-${REPO_ROOT}/backups/latest.dump}"
TARGET_DB="${2:-${DB_NAME}_restore}"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "!! Backup file not found: $BACKUP_FILE" >&2
  echo "!! Run ./scripts/backup.sh first, or pass a path explicitly." >&2
  exit 1
fi

echo ">> Restoring '${BACKUP_FILE}' into fresh database '${TARGET_DB}' on ${DB_HOST}:${DB_PORT}"

echo ">> Dropping '${TARGET_DB}' if it exists..."
dropdb --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --if-exists "$TARGET_DB"

echo ">> Creating fresh database '${TARGET_DB}'..."
createdb --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" "$TARGET_DB"

echo ">> Running pg_restore..."
pg_restore \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname="$TARGET_DB" \
  --no-owner \
  --no-privileges \
  "$BACKUP_FILE"

echo ">> Restore complete. Verifying row counts..."
psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname="$TARGET_DB" -c "
  SELECT 'hotel_bookings' AS table_name, COUNT(*) FROM hotel_bookings
  UNION ALL
  SELECT 'booking_events', COUNT(*) FROM booking_events;
"

echo ">> Restore verified into database: ${TARGET_DB}"
