#!/bin/bash
# Runs once, on first container start (when the data volume is empty), because
# it lives in /docker-entrypoint-initdb.d and is picked up by the official
# postgres image's entrypoint. Applies migrations first, then seed data, both
# in filename sort order.
set -euo pipefail

echo ">> Applying migrations..."
for f in /docker-entrypoint-initdb.d/migrations/*.sql; do
  echo "   -> $f"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

echo ">> Loading seed data..."
for f in /docker-entrypoint-initdb.d/seed/*.sql; do
  echo "   -> $f"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

echo ">> Done."
