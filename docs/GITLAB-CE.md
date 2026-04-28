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

## Import Sources (GitHub, etc.)

By default, import sources may be disabled. Enable via PostgreSQL:

```bash
# Enable import sources (GitHub, Bitbucket, etc.)
docker exec gitlab gitlab-psql -d gitlabhq_production -c "UPDATE application_settings SET import_sources = 'github,bitbucket,gitlab,google_code,fogbugz';"

# Restart GitLab to apply
docker restart gitlab
```

Then: **New Project → Import → GitHub**

---

## Import from GitHub (Pull Mirror)

GitLab can pull repos from GitHub:

1. **Admin Area → Applications** → Create GitHub OAuth App
   - Homepage URL: `http://localhost:8090`
   - Callback URL: `http://localhost:8090/-/github_import/userAuthorize`

2. **New Project → Import → GitHub** → Authenticate with GitHub

3. Select repos to import

**Alternative: GitHub as Primary, GitLab as Read-Only Mirror**
- Import repos from GitHub
- In GitLab: **Settings → Repository → Mirroring**
- Set to "Pull" direction
- GitLab syncs automatically every few minutes

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

# Get initial root password
docker exec gitlab cat /etc/gitlab/initial_root_password

# PostgreSQL console
docker exec gitlab gitlab-psql -d gitlabhq_production
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

## Admin Hardening (Best Practices)

### Security Settings

```ruby
# Disable sign-up (use GitHub OAuth or LDAP instead)
gitlab_rails['signup_enabled'] = false

# Password requirements
gitlab_rails['password_minimum_length'] = 12

# Session security
gitlab_rails['session_expire_delay'] = 60  # minutes

gitlab_rails['session_expire_seconds'] = 28800  # 8 hours

# Restrict visibility levels
gitlab_rails['restricted_visibility_levels'] = ['public']

# Disable Gravatar
gitlab_rails['gravatar_enabled'] = false

# Disable user cap
gitlab_rails['user_cap_enabled'] = false
```

### Recommended Admin Actions (Web UI)

1. **Admin Area → Settings → General**
   - ✅ Sign-up restrictions
   - ✅ Default project visibility: Private
   - ✅ Session timeout

2. **Admin Area → Settings → Metrics and profiling**
   - Prometheus metrics (optional, needs RAM)

3. **Admin Area → Settings → CI/CD**
   - Restrict pipeline for forked projects
   - Limit CI/CD variables scope

4. **Admin Area → Settings → Network**
   - Outbound requests: whitelist domains
   - Disable webhook SSL verification bypass

5. **Admin Area → Settings → Usage Statistics**
   - Disable usage ping if privacy needed

### Production Hardening (when going live)

```bash
# Enable automatic backups
gitlab_rails['auto_backup_enabled'] = true

# Set backup retention
gitlab_rails['backup_keep_time'] = 604800  # 7 days

# Enable 2FA enforcement for admins
gitlab_rails['require_admin_two_factor_authentication'] = true

# Restrict OAuth providers
gitlab_rails['oauth_providers'] = []  # Allow specific providers only
```

---

## Troubleshooting

### "No import options available"

Enable import sources via PostgreSQL (see section above).

### User blocked with "pending approval"

```bash
docker exec gitlab gitlab-psql -d gitlabhq_production -c "UPDATE users SET state='active' WHERE username='username';"
```

### Password reset

```bash
docker exec gitlab gitlab-rails console -e production
# In console:
user = User.find_by_username('username')
user.password = 'NewPassword123!'
user.password_confirmation = 'NewPassword123!'
user.save!
```

---

*Last updated: 2026-04-28*
