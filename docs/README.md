# IDP Plattform — Vollständige Dokumentation

> Alle Dokumente, Compliance-Referenzen, und Anleitungen für die IDP-Plattform.

---

## 📚 Dokumentationsübersicht

### Einführung & Überblick

| Dokument | Beschreibung |
|----------|--------------|
| [20-idp-leitfaden.md](./20-idp-leitfaden.md) | **START HIER** — Leitfaden für alle (Developer, Platform, Security) |
| [21-leitplanken.md](./21-leitplanken.md) | Die Regeln: Was darf man, was nicht |
| [00-stack-comparison.md](./00-stack-comparison.md) | Docker vs Podman vs kind |

### Architektur

| Dokument | Beschreibung |
|----------|--------------|
| [08-idp-platform-architecture.md](./08-idp-platform-architecture.md) | Gesamtübersicht der Plattform |
| [01-rbac-design.md](./01-rbac-design.md) | RBAC Design + Teams |

### GitOps & Deployment

| Dokument | Beschreibung |
|----------|--------------|
| [03-flux-intro.md](./03-flux-intro.md) | GitOps Einführung |
| [03-flux-install-step-by-step.md](./03-flux-install-step-by-step.md) | Flux Installation |
| [07-flux-telegram-notifications.md](./07-flux-telegram-notifications.md) | Telegram Alerts bei Events |
| [04-argocd.md](./04-argocd.md) | ArgoCD Developer UI |

### Security & Compliance

| Dokument | Beschreibung | Compliance |
|----------|--------------|------------|
| [02-opa-gatekeeper.md](./02-opa-gatekeeper.md) | Policy Enforcement | NIS2, BSI, DSGVO |
| [09-compliance-security.md](./09-compliance-security.md) | Security Stack Übersicht | Alle |
| [10-trivy-operator.md](./10-trivy-operator.md) | CVE Scanning | NIS2, BSI, ISO |
| [12-vulnerability-workflow.md](./12-vulnerability-workflow.md) | Security Workflow | NIS2, BSI, ISO |
| [21-leitplanken.md](./21-leitplanken.md) | Plattform-Regeln | NIS2, BSI, ISO |

### Identität & Zugriff

| Dokument | Beschreibung | Compliance |
|----------|--------------|------------|
| [05-keycloak.md](./05-keycloak.md) | Keycloak OIDC Provider | DSGVO, NIS2, ISO |
| [17-argocd-keycloak-sso.md](./17-argocd-keycloak-sso.md) | ArgoCD SSO Einrichtung | NIS2 |
| [13-midpoint.md](./13-midpoint.md) | Identity Governance (IGA) | NIS2, BSI, ISO |

### CI/CD & Images

| Dokument | Beschreibung | Compliance |
|----------|--------------|------------|
| [14-ci-cd-pipeline.md](./14-ci-cd-pipeline.md) | GitHub Actions Pipeline | NIS2, BSI, ISO |

### Daten & Secrets

| Dokument | Beschreibung | Compliance |
|----------|--------------|------------|
| [16-secrets-management.md](./16-secrets-management.md) | SOPS + Age Secrets | BSI, DSGVO |
| [15-backup-dr.md](./15-backup-dr.md) | Backup & Disaster Recovery | BSI, ISO |

### Operations & Monitoring

| Dokument | Beschreibung |
|----------|--------------|
| [06-monitoring.md](./06-monitoring.md) | Prometheus + Grafana |
| [11-dashboard-access.md](./11-dashboard-access.md) | Alle URLs + Zugang |
| [06-health-checks.md](./06-health-checks.md) | Health Endpoints |

---

## 🎯 Schnelleinstieg

### Für Developer

1. **[20-idp-leitfaden.md](./20-idp-leitfaden.md)** lesen
2. ArgoCD öffnen: `http://localhost:9080`
3. Code ändern → Git push → Flux deployed automatisch
4. Bei Problemen: Platform Team kontaktieren

### Für Platform Team

1. **[21-leitplanken.md](./21-leitplanken.md)** verstehen
2. Neue Namespaces: `kubectl create namespace <name>`
3. RBAC in `infra/rbac/` pflegen
4. OPA Policies in `infra/gatekeeper/` anpassen

### Für Security/Compliance

1. **[09-compliance-security.md](./09-compliance-security.md)** lesen
2. Compliance Reports: `kubectl logs job/kube-bench`
3. CVE Reports: `kubectl get vulnerabilityreports -A`
4. Access Reviews: midPoint öffnen (`http://localhost:9090`)

---

## 📋 Compliance Matrix

| Standard | Dokumentiert in | Tools |
|----------|----------------|-------|
| **NIS2** (EU) | 02, 09, 10, 12, 13, 14, 17, 21 | OPA, Trivy, Keycloak, Flux |
| **BSI IT-Grundschutz** | 01, 02, 09, 10, 12, 13, 15, 16, 21 | kube-bench, Polaris, OPA |
| **DSGVO** (Art. 32) | 02, 05, 16 | Keycloak, SOPS |
| **ISO 27001** | 01, 05, 09, 10, 12, 13, 14, 15, 21 | midPoint, Keycloak, Flux |
| **CIS Benchmark** | 02, 09 | kube-bench |
| **EU Cyber Resilience Act** | 12, 14 | Trivy |

---

## 🔧 Infrastructure as Code

```
rook-k8s-lab/
├── apps/
│   └── nginx/              # Demo App
│       ├── Dockerfile
│       ├── deployment.yaml
│       └── kustomization.yaml
├── infra/
│   ├── flux/               # Flux GitOps
│   ├── gatekeeper/         # OPA Policies
│   │   ├── constraints/
│   │   └── templates/
│   ├── rbac/              # Roles + Bindings
│   │   ├── roles/
│   │   └── rolebindings/
│   ├── namespaces/         # Team Namespaces
│   └── secrets/            # SOPS-verschlüsselt (NICHT committen!)
│       └── *.enc.yaml      # Verschlüsselte Secrets
├── .github/
│   └── workflows/          # CI/CD Pipeline
│       └── build-deploy.yaml
├── .sops.yaml              # SOPS Konfiguration
└── docs/                   # Diese Dokumentation
```

---

## 🔑 Credentials

| Service | Username | Password |
|---------|----------|----------|
| ArgoCD | admin | `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" \| base64 -d` |
| Keycloak | admin | `admin` (ändern!) |
| Grafana | admin | `kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" \| base64 -decode` |
| midPoint | administrator | `5ecr3t` (ändern!) |

---

## 🌐 URLs (Port-Forwards)

```bash
# Alle Services starten
kubectl port-forward -n argocd svc/argocd-server 9080:443 &     # ArgoCD
kubectl port-forward -n keycloak svc/keycloak-http 9081:80 &    # Keycloak
kubectl port-forward -n polaris svc/polaris-dashboard 8080:80 & # Polaris
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 & # Grafana
kubectl port-forward -n midpoint svc/midpoint 9090:8080 &      # midPoint
```

| Service | URL |
|---------|-----|
| ArgoCD | http://localhost:9080 |
| Keycloak | http://localhost:9081 |
| Polaris | http://localhost:8080 |
| Grafana | http://localhost:3000 |
| midPoint | http://localhost:9090/midpoint |

---

## ⚠️ Wichtige Dateien (NIEMALS in Git)

```
# .gitignore-secrets
infra/secrets/age-key.txt         # Age Private Key
infra/secrets/*.yaml              # Unverschlüsselte Secrets
.sops.yaml                        # Im Repo OK (nur Public Key)
```

---

## 📞 Support

| Problem | Kontakt |
|---------|---------|
| Deployment schlägt fehl | Platform Team |
| Zugriff auf Namespace | Platform Team |
| CVE gefunden | Security Team |
| Compliance Frage | Security Team |
| Neuer Namespace | Platform Team |

---

*Letztes Update: 2026-04-21*
*Repo: https://github.com/MarcusGraetsch/rook-k8s-lab*
