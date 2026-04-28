# GitLab Installation Guide

This directory contains the GitLab installation automation for the IDP platform.

## Primary: Podman + Quadlet (Recommended)

Podman with Quadlet is the recommended installation method:
- **Daemonless** — no root Docker daemon required
- **Systemd-native** — integrates with systemd (WantedBy=default.target)
- **Rootless** — runs as unprivileged user
- **OCI compliant** — works with any OCI image

### Quick Start (Podman)

```bash
# 1. Install Podman
sudo apt install podman podman-docker

# 2. Create directories
sudo mkdir -p /opt/gitlab/{data,config,logs}
sudo chown -R $USER:$USER /opt/gitlab

# 3. Create quadlet file
cat > ~/.config/containers/systemd/gitlab.container << 'EOF'
[Unit]
Description=GitLab EE
After=network.target

[Container]
Image=gitlab/gitlab-ee:latest
PublishPort=22:22
PublishPort=80:80
PublishPort=443:443
Volume=/opt/gitlab/data:/var/opt/gitlab
Volume=/opt/gitlab/config:/etc/gitlab
Volume=/opt/gitlab/logs:/var/log/gitlab
GITLAB_ROOT_EMAIL=admin@gitlab.platform-dev.idp.local
GITLAB_HOST=gitlab.platform-dev.idp.local
GITLAB_PORT=443
GITLAB_HTTPS=true
AutoUpdate=container

[Install]
WantedBy=default.target
EOF

# 4. Enable and start
systemctl --user daemon-reload
systemctl --user enable --now gitlab

# 5. Wait for startup (5-10 min first time)
systemctl --user status gitlab
journalctl --user -u gitlab -f
```

### Ansible Deployment

```bash
# Install GitLab on target host via Ansible
cd infra/ansible
cp inventory.ini.example inventory.ini
# Edit inventory.ini with your target host
ansible-playbook -i inventory.ini site.yml -e "install_method=podman"
```

---

## Fallback: Docker Compose

Docker Compose is the alternative if Podman is not available.

### Quick Start (Docker)

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 2. Create directories
sudo mkdir -p /opt/gitlab/{data,config,logs}
sudo chown -R $USER:$USER /opt/gitlab

# 3. Create docker-compose.yml
cat > /opt/gitlab/docker-compose.yml << 'EOF'
version: '3.8'
services:
  gitlab:
    image: gitlab/gitlab-ee:latest
    container_name: gitlab
    restart: unless-stopped
    hostname: gitlab.platform-dev.idp.local
    ports:
      - "22:22"
      - "80:80"
      - "443:443"
    volumes:
      - /opt/gitlab/data:/var/opt/gitlab
      - /opt/gitlab/config:/etc/gitlab
      - /opt/gitlab/logs:/var/log/gitlab
    environment:
      GITLAB_ROOT_EMAIL: admin@gitlab.platform-dev.idp.local
      GITLAB_ROOT_PASSWORD: changeme123!
    shm_size: '256m'
EOF

# 4. Start
cd /opt/gitlab
docker compose up -d

# 5. Wait for startup
docker exec gitlab gitlab-ctl status
```

### Why Podman over Docker?

| Feature | Docker | Podman + Quadlet |
|---------|--------|------------------|
| Root required | Yes (daemon) | No (rootless) |
| Systemd integration | No (needs compose) | Yes (native quadlet) |
| Security | Root daemon risk | User namespace isolation |
| Image source | Docker Hub | Docker Hub + others (OCI) |

---

## Post-Installation

### 1. Get Initial Root Password

```bash
# For Podman/Quadlet
sudo cat /opt/gitlab/config/initial_root_password

# For Docker
docker exec gitlab cat /etc/gitlab/initial_root_password
```

### 2. Access GitLab

```
URL: https://gitlab.platform-dev.idp.local
User: root
Pass: <from initial_root_password>
```

### 3. Configure GitLab Runner (for CI/CD)

```bash
# Register a runner
sudo gitlab-runner register \
  --url https://gitlab.platform-dev.idp.local \
  --registration-token <TOKEN_FROM_GITLAB> \
  --executor docker \
  --docker-image alpine:latest \
  --description "k8s-runner"
```

### 4. Next Steps

1. Create your first project
2. Add SSH key to GitLab
3. Set up CI/CD pipeline (`.gitlab-ci.yml`)
4. Connect ArgoCD to GitLab for GitOps

---

## Production Considerations

For production deployments, consider:

- **External PostgreSQL** — use managed DB instead of built-in
- **External Redis** — use managed Redis for large deployments
- **TLS** — use Let's Encrypt or proper certificates
- **Backups** — configure automated backups
- **Resources** — GitLab needs 8GB+ RAM minimum

---

## Troubleshooting

### GitLab won't start

```bash
# Check logs
journalctl --user -u gitlab -e

# For Docker
docker logs gitlab

# Check disk space (GitLab needs ~10GB)
df -h
```

### Ports already in use

```bash
# Edit quadlet/docker-compose to use different ports
# e.g., 8022:22 instead of 22:22 for SSH
```

### Initial password not working

```bash
# Reset root password
sudo gitlab-rake gitlab:backup:create
sudo gitlab-rake gitlab:password:reset
```
