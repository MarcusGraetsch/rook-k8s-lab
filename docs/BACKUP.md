# IDP Platform — Backup & Recovery Strategy

> Stand: 2026-04-28

## Overview

Backup strategy for the IDP platform following the principle: **"Everything in Git, everything reproducible"**

---

## Backup Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    IDP Platform                              │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  Kubernetes │  │   GitLab    │  │  Registry   │        │
│  │   Cluster   │  │    (VM)     │  │  (Docker)   │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────────────────────────────────────┐           │
│  │              Backup Targets                  │           │
│  │  - etcd snapshots (K8s)                    │           │
│  │  - GitLab data volume (/opt/gitlab)        │           │
│  │  - Registry images (backup to file)        │           │
│  └──────────────────┬──────────────────────────┘           │
│                     │                                        │
│                     ▼                                        │
│         ┌───────────────────────┐                          │
│         │    Backup Storage      │                          │
│         │   (/backups/idp/)     │                          │
│         │                       │                          │
│         │  ├── kubernetes/       │                          │
│         │  ├── gitlab/          │                          │
│         │  ├── registry/        │                          │
│         │  └── config/         │                          │
│         └───────────┬───────────┘                          │
│                     │                                       │
│                     ▼                                       │
│         ┌───────────────────────┐                          │
│         │   Offsite Backup      │                          │
│         │   (GitHub Releases)   │                          │
│         └───────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

---

## What to Backup

| Component | Data | Method | Frequency | Retention |
|----------|------|--------|-----------|-----------|
| **Kubernetes** | etcd state, resources | Velero, kubectl dump | Daily | 7 days local, 30 days offsite |
| **GitLab** | Repos, DB, configs | GitLab backup rake | Daily | 7 days local, 30 days offsite |
| **Docker Registry** | Images | crane/regctl export | Weekly | 4 weeks |
| **Platform Configs** | Flux GitOps repo | Git (already in GitHub) | Real-time | Infinite |
| **User Data** | PostgreSQL DB | pg_dump | Daily | 7 days local, 30 days offsite |
| **Critical Files** | Certs, secrets (encrypted) | rclone to S3 | Weekly | 4 weeks |

---

## Backup Scripts

### Kubernetes: Velero Setup

```bash
# Install Velero
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --backup-location-config region=minio,s3ForcePathStyle=true \
  --snapshot-location-config region=minio \
  --secret-file ./credentials-velero

# Create daily backup schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --ttl 168h \
  --include-namespaces platform-dev,portal
```

### Kubernetes: kubectl dump (fallback)

```bash
#!/bin/bash
# backup-k8s.sh
BACKUP_DIR=/backups/idp/kubernetes
DATE=$(date +%Y-%m-%d)

mkdir -p $BACKUP_DIR/$DATE

# Dump all resources
kubectl get all -A -o yaml > $BACKUP_DIR/$DATE/resources.yaml

# Dump persistent volumes
kubectl get pv -o yaml > $BACKUP_DIR/$DATE/persistentvolumes.yaml

# Dump ingress
kubectl get ingress -A -o yaml > $BACKUP_DIR/$DATE/ingress.yaml

# Dump secrets (encrypted)
kubectl get secrets -A -o yaml | sops --encrypt > $BACKUP_DIR/$DATE/secrets.yaml

# Compress
tar -czf $BACKUP_DIR/$DATE.tar.gz -C $BACKUP_DIR $DATE
rm -rf $BACKUP_DIR/$DATE

echo "Backup: $BACKUP_DIR/$DATE.tar.gz"
```

### GitLab Backup

```bash
#!/bin/bash
# backup-gitlab.sh
BACKUP_DIR=/backups/idp/gitlab
DATE=$(date +%Y-%m-%d)
GITLAB_CONTAINER=gitlab

mkdir -p $BACKUP_DIR

# GitLab backup (includes DB, repos, attachments)
docker exec $GITLAB_CONTAINER gitlab-backup create STRATEGY=copy

# Copy backup to local storage
docker exec $GITLAB_CONTAINER tar czf /tmp/gitlab-backup-$DATE.tar.gz /var/opt/gitlab/backups
docker cp $GITLAB_CONTAINER:/tmp/gitlab-backup-$DATE.tar.gz $BACKUP_DIR/

# Keep only last 7 backups
ls -t $BACKUP_DIR/*.tar.gz | tail -n +8 | xargs -r rm

echo "GitLab backup: $BACKUP_DIR/gitlab-backup-$DATE.tar.gz"
```

### Registry Backup

```bash
#!/bin/bash
# backup-registry.sh
BACKUP_DIR=/backups/idp/registry
DATE=$(date +%Y-%m-%d)
REGISTRY_NAME=registry

mkdir -p $BACKUP_DIR/$DATE

# Export all images to tar files
docker images --format "{{.Repository}}:{{.Tag}}" | while read img; do
  fname=$(echo $img | tr '/:' '__')
  docker save $img -o $BACKUP_DIR/$DATE/${fname}.tar
done

# Alternative: Use crane to copy to another registry
# crane copy source-registry:5000/* backup-registry:5000/*

tar -czf $BACKUP_DIR/registry-$DATE.tar.gz -C $BACKUP_DIR $DATE
rm -rf $BACKUP_DIR/$DATE

echo "Registry backup: $BACKUP_DIR/registry-$DATE.tar.gz"
```

---

## Offsite Backup: GitHub Releases

For critical data, push to GitHub Releases as artifacts:

```bash
#!/bin/bash
# backup-to-github.sh
GITHUB_REPO=MarcusGraetsch/idp-backups
BACKUP_DATE=$(date +%Y-%m-%d)

# Package backups
cd /backups/idp
tar -czf idp-backup-$BACKUP_DATE.tar.gz kubernetes/ gitlab/ registry/

# Upload to GitHub Release (using gh CLI)
gh release create backup-$BACKUP_DATE \
  --title "IDP Backup $BACKUP_DATE" \
  --notes "Automated backup" \
  ./idp-backup-$BACKUP_DATE.tar.gz

# Or via rclone to S3/GCS
rclone copy /backups/idp/kubernetes s3:idp-backups/kubernetes/$BACKUP_DATE/
```

---

## Recovery Procedures

### Kubernetes Recovery

```bash
# From Velero backup
velero restore create --from-backup daily-backup-$(date +%Y-%m-%d)

# From kubectl dump
kubectl apply -f /backups/idp/kubernetes/resources.yaml

# Restore secrets (decrypt first)
sops --decrypt /backups/idp/kubernetes/secrets.yaml | kubectl apply -f -
```

### GitLab Recovery

```bash
# Stop GitLab
docker stop gitlab

# Restore from backup
docker exec -i gitlab tar xzf /tmp/gitlab-backup.tar.gz -C /

# Reconfigure GitLab
docker exec gitlab gitlab-ctl reconfigure
docker exec gitlab gitlab-ctl restart

# Verify
curl -s http://localhost:8080/-/health | jq .
```

### Full Platform Recovery

```bash
#!/bin/bash
# recover-idp.sh
BACKUP_DATE=$1

# 1. Restore Kubernetes
kubectl apply -f /backups/idp/kubernetes/$BACKUP_DATE/resources.yaml

# 2. Restore GitLab
docker stop gitlab
tar -xzf /backups/idp/gitlab/gitlab-backup-$BACKUP_DATE.tar.gz -C /
docker start gitlab

# 3. Restore Registry images
for img in /backups/idp/registry/$BACKUP_DATE/*.tar; do
  docker load -i $img
done

echo "Recovery complete for $BACKUP_DATE"
```

---

## Cron Schedule

```bash
# /etc/cron.d/idp-backups
# Kubernetes: Daily at 02:00
0 2 * * * root /opt/idp/scripts/backup-k8s.sh >> /var/log/idp-backup.log 2>&1

# GitLab: Daily at 03:00
0 3 * * * root /opt/idp/scripts/backup-gitlab.sh >> /var/log/idp-backup.log 2>&1

# Registry: Weekly on Sunday at 04:00
0 4 * * 0 root /opt/idp/scripts/backup-registry.sh >> /var/log/idp-backup.log 2>&1

# Offsite Sync: Daily at 05:00
0 5 * * * root /opt/idp/scripts/backup-to-github.sh >> /var/log/idp-backup.log 2>&1
```

---

## Retention Policy

| Backup Type | Local | Offsite |
|-------------|-------|---------|
| Kubernetes (Velero) | 7 days | 30 days |
| GitLab | 7 days | 30 days |
| Registry images | 4 weeks | 4 weeks |
| Config/Secrets | 7 days | 30 days |

---

## Testing Recovery

**IMPORTANT: Test backups regularly!**

```bash
# Test Kubernetes restore in dev cluster
velero restore create --from-backup daily-backup-TEST --namespace-mappings production:dev

# Test GitLab restore in staging
# (Same procedure as recovery, but to staging environment)
```

---

## Directory Structure

```
/backups/idp/
├── kubernetes/
│   ├── 2026-04-28.tar.gz
│   ├── 2026-04-27.tar.gz
│   └── ...
├── gitlab/
│   ├── gitlab-backup-2026-04-28.tar.gz
│   └── ...
├── registry/
│   ├── registry-2026-04-28.tar.gz
│   └── ...
└── config/
    └── ...
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `./backup-k8s.sh` | Backup all K8s resources |
| `./backup-gitlab.sh` | Backup GitLab (repos + DB) |
| `./backup-registry.sh` | Backup all container images |
| `./backup-to-github.sh` | Push backups to GitHub Releases |
| `velero backup create daily` | Create Velero backup |
| `velero restore create --from-backup <name>` | Restore from Velero |

---

*Erstellt: 2026-04-28*
*Letzte Änderung: Initial*
