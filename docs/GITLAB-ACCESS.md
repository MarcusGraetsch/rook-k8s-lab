# GitLab Access Guide

> Stand: 2026-04-28

## URLs & Ports

| Service | Local URL | SSH Port |
|---------|----------|----------|
| **Web UI (HTTPS)** | https://localhost:8443 |
| **Web UI (HTTP)** | http://localhost:8088 |
| **SSH** | localhost:8022 |

## Initial Setup

### 1. Get Root Password

```bash
docker exec gitlab cat /etc/gitlab/initial_root_password
```

### 2. Access Web UI

Open: **http://localhost:8088** (or https://localhost:8443 for HTTPS)

Login:
- Username: `root`
- Password: `<from step 1>`

### 3. Change Root Password (recommended)

After first login, go to:
**Settings → Password → Change password**

### 4. Create Personal Access Token

For GitLab API / CI-CD:

1. Login as root
2. **Settings → Access Tokens**
3. Create token with scopes:
   - `api` (full API)
   - `write_repository`
   - `read_repository`

Save the token securely — you won't see it again!

## SSH Key Setup

### 1. Generate SSH Key (if not exists)

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub
```

### 2. Add Key to GitLab

1. Login to GitLab
2. **Settings → SSH Keys**
3. Paste your public key

### 3. Test SSH

```bash
ssh -T -p 8022 git@localhost
# Should respond: "Welcome to GitLab, @username!"
```

## Create First Project

1. Click **"Create a project"** or **"New project"**
2. Choose **"Create blank project"**
3. Fill in:
   - Project name: `test-project`
   - Visibility: Private (or Internal for testing)
4. Click **Create project**

## Connect to GitLab from CLI

```bash
# Configure git remote
git remote add gitlab ssh://git@localhost:8022/root/test-project.git

# Or HTTPS (if SSH blocked)
git remote add gitlab https://localhost:8443/root/test-project.git
```

## Useful GitLab Commands

```bash
# Check GitLab status
docker exec gitlab gitlab-ctl status

# View logs
docker exec gitlab gitlab-ctl tail

# Reconfigure (after changes)
docker exec gitlab gitlab-ctl reconfigure

# Restart GitLab
docker exec gitlab gitlab-ctl restart
```

## Troubleshooting

### "Connection refused" on web UI

```bash
# Check if GitLab is running
docker ps | grep gitlab

# Check logs
docker exec gitlab gitlab-ctl tail
```

### SSH connection refused

```bash
# Check SSH port
docker port gitlab | grep 22
```

### SSL Certificate Warning

Self-signed cert — accept it in browser or add to trusted certificates.

---

*Last updated: 2026-04-28*
