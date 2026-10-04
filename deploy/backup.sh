#!/bin/bash
# Nightly PostgreSQL backup for KinSync. Runs from the `kinsync` user's crontab:
#   15 2 * * * /opt/kinsync-api/deploy/backup.sh
# No password needed: runs as OS user `kinsync`, which PostgreSQL's default `local ... peer`
# rule maps to the DB role `kinsync` over the Unix socket. Never put a password in this file.
# Runbook: https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/postgres-backup-restore.md
set -euo pipefail

BACKUP_DIR=/var/backups/kinsync
RETENTION_DAYS=14

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pg_dump kinsync | gzip > "$BACKUP_DIR/kinsync_${TIMESTAMP}.sql.gz"
find "$BACKUP_DIR" -name '*.sql.gz' -mtime +"$RETENTION_DAYS" -delete
