#!/bin/bash
# backup-k8s.sh — Kubernetes resources backup
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-/backups/idp/kubernetes}
DATE=$(date +%Y-%m-%d)
KUBECONTEXT=${KUBECONTEXT:-kind-rook-lab}

mkdir -p "$BACKUP_DIR/$DATE"

echo "[$(date)] Starting Kubernetes backup..."

# Set kubeconfig
export KUBECONFIG=${KUBECONFIG:-$HOME/.kube/config}

# Dump all resources
echo "Dumping cluster resources..."
kubectl --context "$KUBECONTEXT" get all -A -o yaml > "$BACKUP_DIR/$DATE/resources.yaml"

# Dump persistent volumes
kubectl --context "$KUBECONTEXT" get pv -o yaml > "$BACKUP_DIR/$DATE/persistentvolumes.yaml"

# Dump ingress
kubectl --context "$KUBECONTEXT" get ingress -A -o yaml > "$BACKUP_DIR/$DATE/ingress.yaml"

# Dump storageclasses
kubectl --context "$KUBECONTEXT" get storageclass -o yaml > "$BACKUP_DIR/$DATE/storageclass.yaml"

# Dump namespaces
kubectl --context "$KUBECONTEXT" get namespaces -o yaml > "$BACKUP_DIR/$DATE/namespaces.yaml"

# Dump configmaps (non-secret)
kubectl --context "$KUBECONTEXT" get configmap -A -o yaml > "$BACKUP_DIR/$DATE/configmaps.yaml"

# Compress
tar -czf "$BACKUP_DIR/k8s-backup-$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"
rm -rf "$BACKUP_DIR/$DATE"

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/k8s-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo "[$(date)] Kubernetes backup complete: $BACKUP_DIR/k8s-backup-$DATE.tar.gz"
