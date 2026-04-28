# GitLab CE Setup Guide

> Stand: 2026-04-28

## Overview

GitLab CE runs as a Docker container on the VM (not in Kubernetes). This provides a lightweight GitLab instance for development and learning.

**Why not in Kubernetes:**
- GitLab EE/CE is heavyweight (~4GB+ RAM)
- Kubernetes would require significant resources
- VM deployment is sufficient for learning purposes

**Future:** GitLab can be moved to Kubernetes via Helm Chart when needed.

---

## Quick Start

### Access

| Service | URL |
|---------|-----|
| Web UI | http://localhost:8090 |
| SSH | localhost:8022 |

### Initial Setup

1. Open http://localhost:8090
2. Create admin account on welcome page
3. Login with your new credentials

### Login via CLI

```bash
# Get initial root password (if needed)
docker exec gitlab cat /etc/gitlab/initial_root_password

# Or check container logs
docker exec gitlab gitlab-ctl status
```

---

## Access from External (SSH Tunnel)

From your local machine or phone:

```bash
ssh -p 6262 -N -L 8090:localhost:8090 root@178.18.254.21
```

Then open: http://localhost:8090

---

## Configuration

### Memory Optimization

Location: `/opt/gitlab/config/gitlab.rb` (on VM)

```ruby
# Reduce Puma workers
puma['worker_processes'] = 2
puma['min_threads'] = 2
puma['max_threads'] = 4

# Reduce memory per worker
gitlab_rails['max_worker_memory'] = 512000

# Reduce Sidekiq
sidekiq['concurrency'] = 5

# Disable unused
prometheus['enable'] = false
alertmanager['enable'] = false
```

After changes:
```bash
docker exec gitlab gitlab-ctl reconfigure
docker restart gitlab
```

---

## Commands

```bash
# Check status
docker exec gitlab gitlab-ctl status

# View logs
docker exec gitlab gitlab-ctl tail

# Restart
docker restart gitlab

# Reconfigure (after changes)
docker exec gitlab gitlab-ctl reconfigure
```

---

## Backup

See: `scripts/backup/backup-gitlab.sh`

Backups run daily at 03:00 via cron.

```bash
# Manual backup
/opt/idp/scripts/backup-gitlab.sh

# Backup location
/backups/idp/gitlab/
```

---

## Ports

| Port | Service | External |
|------|---------|----------|
| 8090 | HTTP | Via SSH tunnel |
| 8443 | HTTPS | Via SSH tunnel |
| 8022 | SSH | Via SSH tunnel |

---

## Future: GitLab in Kubernetes

When resources allow, GitLab can be deployed to Kubernetes:

```bash
# Using Helm
helm install gitlab gitlab/gitlab \
  --set global.hosts.domain=platform-dev.idp.local \
  --set certmanager.enabled=false \
  --namespace gitlab \
  --create-namespace
```

Requirements:
- 8GB+ RAM for GitLab in K8s
- Persistent storage (10GB+)
- External database (PostgreSQL)

---

*Last updated: 2026-04-28*
