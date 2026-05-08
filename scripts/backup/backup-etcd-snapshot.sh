#!/bin/bash
# backup-etcd-snapshot.sh — KIND etcd state snapshot
# Part of P1-R1: etcd-Snapshot-Cron fuer KIND
# Uses kubectl exec + etcdctl inside etcd container
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-/backups/idp/etcd}
DATE=$(date +%Y-%m-%dT%H%M%S)
ETCD_POD="etcd-rook-lab-control-plane"
ETCD_NS="kube-system"
ETCD_ENDPOINT="https://127.0.0.1:2379"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting etcd snapshot for KIND cluster..."

# Verify cluster is accessible
if ! kubectl cluster-info --context kind-rook-lab &>/dev/null; then
  echo "ERROR: kind-rook-lab cluster not accessible"
  exit 1
fi

# Verify etcd pod is running
if ! kubectl get pod -n "$ETCD_NS" "$ETCD_POD" 2>/dev/null | grep -q "Running"; then
  echo "ERROR: etcd pod $ETCD_POD not running"
  exit 1
fi

SNAPSHOT_NAME="etcd-snapshot-${DATE}.db"
SNAPSHOT_TMP="/tmp/${SNAPSHOT_NAME}"

# Run etcd snapshot inside the etcd container
echo "Creating etcd snapshot..."
kubectl exec -n "$ETCD_NS" "$ETCD_POD" -- etcdctl \
  --endpoints="$ETCD_ENDPOINT" \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  snapshot save "$SNAPSHOT_TMP" 2>&1 | tail -3

# Get snapshot size for logging
ETCD_SIZE=$(kubectl exec -n "$ETCD_NS" "$ETCD_POD" -- stat -c%s "$SNAPSHOT_TMP" 2>/dev/null || echo "unknown")
echo "Snapshot size: $ETCD_SIZE bytes"

# Transfer snapshot to host via base64 (no tar in etcd container)
echo "Transferring snapshot to host..."
kubectl exec -n "$ETCD_NS" "$ETCD_POD" -- base64 "$SNAPSHOT_TMP" | \
  base64 -d > "$BACKUP_DIR/$SNAPSHOT_NAME"

# Verify transferred file
if [ ! -s "$BACKUP_DIR/$SNAPSHOT_NAME" ]; then
  echo "ERROR: Snapshot transfer failed or empty file"
  exit 1
fi

# Compress
echo "Compressing..."
gzip -f "$BACKUP_DIR/$SNAPSHOT_NAME"
COMPRESSED="$BACKUP_DIR/${SNAPSHOT_NAME}.gz"

# Cleanup temp in etcd container
kubectl exec -n "$ETCD_NS" "$ETCD_POD" -- rm -f "$SNAPSHOT_TMP" 2>/dev/null || true

# Sync to off-site (if rclone configured)
if command -v rclone &>/dev/null && rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
  echo "Syncing to Google Drive..."
  rclone copy "$COMPRESSED" gdrive:DigitalCapitalismBackups/rook-runtime/$HOSTNAME/etcd/ --quiet 2>&1 || true
fi

# Keep only last 14 snapshots
ls -t "$BACKUP_DIR"/etcd-snapshot-*.db.gz 2>/dev/null | tail -n +15 | xargs -r rm

echo "[$(date)] etcd snapshot complete: $COMPRESSED ($(ls -lh "$COMPRESSED" | awk '{print $5}'))"