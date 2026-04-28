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

# Create GitLab backup (keeps data in /var/opt/gitlab/backups inside container)
docker exec "$GITLAB_CONTAINER" gitlab-backup create STRATEGY=copy SKIP=artifacts,builds

# Find latest backup file inside container
BACKUP_FILE=$(docker exec "$GITLAB_CONTAINER" ls -t /var/opt/gitlab/backups/*.tar 2>/dev/null | head -1 || true)

if [ -z "$BACKUP_FILE" ]; then
    echo "ERROR: No GitLab backup file found"
    exit 1
fi

# Copy backup to local storage
docker cp "$GITLAB_CONTAINER:$BACKUP_FILE" "$BACKUP_DIR/gitlab-backup-$DATE.tar.gz"

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/gitlab-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo "[$(date)] GitLab backup complete: $BACKUP_DIR/gitlab-backup-$DATE.tar.gz"
