#!/bin/bash
# backup-registry.sh — Docker Registry backup
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-/backups/idp/registry}
DATE=$(date +%Y-%m-%d)
REGISTRY_CONTAINER=${REGISTRY_CONTAINER:-registry}

mkdir -p "$BACKUP_DIR/$DATE"

echo "[$(date)] Starting Registry backup..."

# Check if registry container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${REGISTRY_CONTAINER}$"; then
    echo "ERROR: Registry container '$REGISTRY_CONTAINER' not running"
    exit 1
fi

# Get registry data volume
REGISTRY_VOLUME=$(docker inspect "$REGISTRY_CONTAINER" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}')

if [ -z "$REGISTRY_VOLUME" ]; then
    # Fallback: use path from container
    REGISTRY_PATH="/var/lib/registry"
else
    REGISTRY_PATH="/var/lib/registry"
fi

# Copy registry data
echo "Copying registry data..."
docker cp "$REGISTRY_CONTAINER:/docker/registry" "$BACKUP_DIR/$DATE/registry-data" 2>/dev/null || \
  docker run --rm -v "${REGISTRY_VOLUME}:/data" -v "$(pwd):/backup" alpine \
    tar czf "/backup/$DATE/registry-data.tar.gz" -C /data .

# Create manifest of images
docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' > "$BACKUP_DIR/$DATE/images-manifest.txt"

# Compress
tar -czf "$BACKUP_DIR/registry-backup-$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"
rm -rf "$BACKUP_DIR/$DATE"

# Keep only last 4 backups
ls -t "$BACKUP_DIR"/registry-backup-*.tar.gz 2>/dev/null | tail -n +5 | xargs -r rm

echo "[$(date)] Registry backup complete: $BACKUP_DIR/registry-backup-$DATE.tar.gz"
