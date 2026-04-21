# Kubernetes Lab — IDP Plattform

> Lokales Kubernetes-IDP (Internal Developer Platform) auf kind für Cloud-native Kunden-POCs.

## ⚠️ WICHTIG: Dokumentation

**Alle Dokumente unter:** [`docs/`](./docs/)

**Schnelleinstieg:**
- **[docs/README.md](./docs/README.md)** — Vollständige Übersicht aller Dokumente
- **[docs/20-idp-leitfaden.md](./docs/20-idp-leitfaden.md)** — Für Developer, Platform Team, Security
- **[docs/21-leitplanken.md](./docs/21-leitplanken.md)** — Plattform-Regeln

---

## Ziel

Eine vollständige IDP-Plattform aufbauen die zeigt:
- Wie ein Platform Team Kubernetes für Developer Teams managed
- Security & Compliance (NIS2, BSI, DSGVO)
- GitOps mit Flux
- Developer Self-Service via ArgoCD
- Identity & Access Management via Keycloak

## Quick Start

```bash
# Cluster Status
kubectl get nodes && kubectl get pods -A | wc -l

# Services starten (Port-Forwards)
kubectl port-forward -n argocd svc/argocd-server 9080:443 &
kubectl port-forward -n keycloak svc/keycloak-http 9081:80 &
kubectl port-forward -n polaris svc/polaris-dashboard 8080:80 &
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
kubectl port-forward -n midpoint svc/midpoint 9090:8080 &
```

## Tool-Übersicht

### Core Platform
| Tool | Version | Status | Port |
|------|---------|--------|------|
| kind Cluster | 0.20+ | ✅ Running | — |
| kubectl | latest | ✅ | — |
| Helm | 3.12+ | ✅ | — |

### GitOps & Developer Experience
| Tool | Version | Status | Docs |
|------|---------|--------|------|
| Flux | 2.8.5 | ✅ | 03-flux-*.md |
| ArgoCD | 2.13.2 | ✅ | 04-argocd.md |
| Keycloak | 17.0.1 | ✅ | 05-keycloak.md |
| Ingress NGINX | 1.10+ | ✅ | — |

### Security & Compliance
| Tool | Version | Status | Docs |
|------|---------|--------|------|
| OPA Gatekeeper | 3.14.0 | ✅ | 02-opa-gatekeeper.md |
| Trivy Operator | 0.21+ | ✅ | 10-trivy-operator.md |
| kube-bench | 0.15+ | ✅ | 09-compliance-security.md |
| Polaris | 10.1+ | ✅ | 09-compliance-security.md |
| SOPS + Age | 3.12 / 1.3 | ✅ | 16-secrets-management.md |

### CI/CD & Build
| Tool | Version | Status | Docs |
|------|---------|--------|------|
| GitHub Actions | — | ✅ | 14-ci-cd-pipeline.md |
| Docker | — | ✅ | 14-ci-cd-pipeline.md |

### Monitoring & Operations
| Tool | Version | Status | Port |
|------|---------|--------|------|
| Prometheus | 0.73+ | ✅ | 9090 |
| Grafana | 10.4+ | ✅ | 3000 |
| AlertManager | 0.27+ | ✅ | 9093 |

### Identity & Governance
| Tool | Version | Status | Docs |
|------|---------|--------|------|
| Keycloak | 17.0.1 | ✅ | 05-keycloak.md |
| midPoint | 4.8 | ✅ | 13-midpoint.md |

## Dokumentation

```
docs/
├── README.md                      # DIESES DOKUMENT — Übersicht
├── 00-stack-comparison.md        # Docker vs Podman vs kind
├── 01-rbac-design.md             # RBAC + Teams ✅
├── 02-opa-gatekeeper.md          # Policy Enforcement ✅
├── 03-flux-intro.md             # GitOps Einführung ✅
├── 03-flux-install-step-by-step.md
├── 04-argocd.md                 # ArgoCD UI ✅
├── 05-keycloak.md               # Keycloak OIDC ✅
├── 06-health-checks.md          # Health Endpoints ✅
├── 06-monitoring.md             # Prometheus + Grafana ✅
├── 07-flux-telegram-notifications.md ✅
├── 08-idp-platform-architecture.md
├── 09-compliance-security.md    # Compliance Stack ✅
├── 10-trivy-operator.md         # Image Scanning ✅
├── 11-dashboard-access.md       # Alle URLs ✅
├── 12-vulnerability-workflow.md # Security Workflow ✅
├── 13-midpoint.md              # Identity Governance ✅
├── 14-ci-cd-pipeline.md        # CI/CD Pipeline ✅
├── 15-backup-dr.md             # Backup & DR ✅
├── 16-secrets-management.md    # SOPS + Age ✅
├── 17-argocd-keycloak-sso.md  # SSO Einrichtung ✅
├── 20-idp-leitfaden.md         # FÜR ALLE ✅
└── 21-leitplanken.md          # REGELN ✅
```

## Compliance Standards

| Standard | Tools | Docs |
|----------|-------|------|
| **NIS2** (EU) | OPA, Trivy, Keycloak, Flux | 02, 09, 10, 12, 13, 14, 17, 21 |
| **BSI IT-Grundschutz** | kube-bench, Polaris, OPA | 01, 02, 09, 10, 12, 13, 15, 16, 21 |
| **DSGVO** (Art. 32) | Keycloak, SOPS | 02, 05, 16 |
| **ISO 27001** | midPoint, Keycloak, Flux | 01, 05, 09, 10, 12, 13, 14, 15, 21 |
| **CIS Benchmark** | kube-bench | 02, 09 |
| **EU Cyber Resilience Act** | Trivy | 12, 14 |

## Security Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security & Compliance                          │
├───────────────────┬─────────────────────────────────────────────┤
│ Image Layer       │ Cluster Layer                                │
│                   │                                              │
│ Trivy ──────────►│ OPA Gatekeeper                               │
│ (CVE Scanning)   │ (Policy Enforcement)                         │
│                   │                                              │
│ Scannt Images    │ Blockiert nicht-compliante                    │
│ kontinuierlich   │ Deployments                                   │
├───────────────────┼─────────────────────────────────────────────┤
│ Best Practice     │ Compliance                                   │
│                   │                                              │
│ Polaris ─────────►│ kube-bench                                   │
│ (Workload Check)  │ (CIS/BSI Audit)                              │
│                   │                                              │
│ Dashboard für     │ Report: 61 PASS                              │
│ Developer         │              11 FAIL                          │
│                   │              58 WARN                          │
├───────────────────┴─────────────────────────────────────────────┤
│ Secrets & Backup                                                │
│                                                                   │
│ SOPS + Age ──────────► Vault-like Secrets                       │
│ (Verschlüsselung)          (niemals in Git unverschlüsselt)    │
│                                                                   │
│ Backup ────────────────► Disaster Recovery                       │
│ (Git als Primary)         (etcd, midPoint, Keycloak)          │
└──────────────────────────────────────────────────────────────────┘
```

## Login Credentials

| Service | Username | Password |
|---------|----------|----------|
| ArgoCD | admin | `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" \| base64 -d` |
| Keycloak | admin | `admin` (ändern!) |
| Grafana | admin | `kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" \| base64 --decode` |
| midPoint | administrator | `5ecr3t` (ändern!) |

## Vulnerability Status (Scans vom 2026-04-21)

| Image | Critical | High | Medium | Status | Remediation |
|-------|----------|------|--------|--------|-------------|
| etcd | 32 | 202 | 282 | ⚠️ Cluster-namespace | Kubernetes Version updaten |
| keycloak | 17 | 187 | 563 | ⚠️ IdP | Version 26.6.1 nutzen |
| nginx | 16 | 73 | 160 | ⚠️ App | Auf nginx:1.27-alpine updaten |
| midPoint | 11 | 50 | 325 | ⚠️ IGA | Auf 4.10 updaten |
| argocd | 10 | 56 | 218 | ⚠️ UI | Auf v2.14 updaten |
| kindnet | 5 | 46 | 136 | ⚠️ Cluster-namespace | kind Version updaten |
| kube-proxy | 7 | 53 | 140 | ⚠️ Cluster-namespace | K8s Version updaten |
| kube-apiserver | 6 | 34 | 88 | ⚠️ Cluster-namespace | K8s Version updaten |
| kube-scheduler | 6 | 33 | 87 | ⚠️ Cluster-namespace | K8s Version updaten |
| kube-controller-manager | 6 | 40 | 90 | ⚠️ Cluster-namespace | K8s Version updaten |
| coredns | 6 | 29 | 50 | ⚠️ Cluster-namespace | K8s Version updaten |
| gatekeeper | 4 | 17 | 45 | ⚠️ Security | Version prüfen, ggf. updaten |
| Polaris | 3 | 18 | 52 | ⚠️ Dashboard | Version prüfen |
| ingress-nginx | 0 | 17 | 23 | ✅ OK | — |
| node-exporter | 0 | 4 | 3 | ✅ OK | — |
| prometheus | 0 | 4 | 3 | ✅ OK | — |
| alertmanager | 0 | 2 | 2 | ✅ OK | — |
| kube-bench | 1 | 17 | 23 | ✅ OK | — |

→ Workflow: `docs/12-vulnerability-workflow.md`
→ CLI: `trivy image --severity CRITICAL,HIGH <image>` für Details

## Infrastructure

```
rook-k8s-lab/
├── apps/
│   └── nginx/              # Demo App mit Dockerfile
├── infra/
│   ├── flux/               # Flux GitOps
│   ├── gatekeeper/         # OPA Policies
│   │   ├── constraints/
│   │   └── templates/
│   ├── rbac/              # Roles + Bindings
│   │   ├── roles/
│   │   └── rolebindings/
│   ├── namespaces/         # Team Namespaces
│   └── secrets/            # SOPS-verschlüsselt
│       └── *.enc.yaml     # Verschlüsselte Secrets
├── .github/
│   └── workflows/         # CI/CD Pipeline
├── .sops.yaml             # SOPS Konfiguration
└── docs/                  # Dokumentation
```

## Offene Punkte

| Item | Status | Aufwand |
|------|--------|---------|
| ArgoCD ↔ Keycloak SSO | Dokumentiert, manueller Schritt nötig | Niedrig |
| Telegram Monitoring Alerts | Dokumentiert, Token nötig | Mittel |
| Sealed Secrets (statt SOPS) | NICHT nötig, SOPS ist besser | — |
| Harbor Registry | Brauchen wir nicht | — |
| Service Mesh (Linkerd/Istio) | Für Production relevant | Hoch |

---

*Letztes Update: 2026-04-21*
*Repo: https://github.com/MarcusGraetsch/rook-k8s-lab*
