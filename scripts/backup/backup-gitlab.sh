#!/bin/bash
# backup-gitlab.sh — GitLab backup (Docker)
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-/backups/idp/gitlab}
DATE=$(date +%Y-%m-%d)
GITLAB_CONTAINER=${GITLAB_CONTAINER:-gitlab}

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting GitLab backup..."

# Check if GitLab container exists and is running
if ! docker ps --format '{{.Names}}' | grep -q "^${GITLAB_CONTAINER}$"; then
    echo "ERROR: GitLab container '$GITLAB_CONTAINER' not running"
    exit 1
fi

# Create GitLab backup (creates file in /var/opt/gitlab/backups inside container)
docker exec "$GITLAB_CONTAINER" gitlab-backup create STRATEGY=copy SKIP=artifacts,builds

# Find latest backup file - GitLab naming: <timestamp>_2026_04_28_XX.X-ee_gitlab_backup.tar
BACKUP_FILE=$(docker exec "$GITLAB_CONTAINER" sh -c "ls -t /var/opt/gitlab/backups/*_gitlab_backup.tar 2>/dev/null | head -1")

if [ -z "$BACKUP_FILE" ]; then
    echo "ERROR: No GitLab backup file found in /var/opt/gitlab/backups/"
    exit 1
fi

# Copy backup to local storage with date rename
docker cp "$GITLAB_CONTAINER:$BACKUP_FILE" "$BACKUP_DIR/gitlab-backup-$DATE.tar.gz"

echo "[$(date)] GitLab backup complete: $BACKUP_DIR/gitlab-backup-$DATE.tar.gz"

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/gitlab-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo "[$(date)] Cleanup complete. Kept last 7 backups."
