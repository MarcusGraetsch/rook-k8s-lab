# Kubernetes Lab — IDP Plattform

> Lokales Kubernetes-IDP (Internal Developer Platform) auf kind für Cloud-native Kunden-POCs.

## Ziel

Eine vollständige IDP-Plattform aufbauen die zeigt:
- Wie ein Platform Team Kubernetes für Developer Teams managed
- Security & Compliance (NIS2, BSI, DSGVO)
- GitOps mit Flux
- Developer Self-Service via ArgoCD
- Identity & Access Management via Keycloak

## Sofort loslegen

```bash
# Cluster Status
kubectl get nodes && kubectl get pods -A | wc -l

# ArgoCD UI (läuft auf Port 9080)
kubectl port-forward -n argocd svc/argocd-server 9080:443

# Keycloak Admin (läuft auf Port 9081)
kubectl port-forward -n keycloak svc/keycloak-http 9081:80

# Polaris Dashboard (Best Practice)
kubectl port-forward -n polaris svc/polaris-dashboard 8080:80
```

## Tool-Übersicht

### Core Platform
| Tool | Version | Status | Port |
|------|---------|--------|------|
| kind Cluster | 0.20+ | ✅ | — |
| kubectl | latest | ✅ | — |
| Helm | 3.12+ | ✅ | — |

### GitOps & Developer Experience
| Tool | Version | Status | Port |
|------|---------|--------|------|
| Flux | 2.8.5 | ✅ | — |
| ArgoCD | 2.13.2 | ✅ | 9080 |
| Keycloak | 17.0.1 | ✅ | 9081 |
| Ingress NGINX | 1.10+ | ✅ | 31439 |

### Security & Compliance
| Tool | Status | Docs |
|------|--------|------|
| OPA Gatekeeper | ✅ | 02-opa-gatekeeper.md |
| Trivy Operator | ✅ | 10-trivy-operator.md |
| kube-bench | ✅ | 09-compliance-security.md |
| Polaris | ✅ | 09-compliance-security.md |

### Monitoring & Notifications
| Tool | Status | Port |
|------|--------|------|
| Prometheus | 📋 OFFEN | — |
| Grafana | 📋 OFFEN | — |
| Telegram Alerts | ✅ | — |

## Dokumentation

```
docs/
├── 00-stack-comparison.md        # Docker vs Podman vs kind
├── 01-rbac-design.md             # RBAC + Teams
├── 02-opa-gatekeeper.md          # Policy Enforcement
├── 03-flux-intro.md              # GitOps Einführung
├── 03-flux-install-step-by-step.md
├── 04-argocd.md                  # ArgoCD Developer UI ✅
├── 05-keycloak.md                # Keycloak OIDC ✅
├── 06-health-checks.md           # Health Endpoints
├── 07-flux-telegram-notifications.md
├── 08-idp-platform-architecture.md
├── 09-compliance-security.md      # Compliance Stack
├── 10-trivy-operator.md         # Image Scanning
├── 11-dashboard-access.md         # Alle URLs
└── 12-vulnerability-workflow.md # Security Workflow
```

## Compliance Standards

| Standard | Status | Tool |
|----------|--------|------|
| NIS2 | ✅ Policy Framework | OPA Gatekeeper |
| BSI IT-Grundschutz CON.1 | ✅ Checks | kube-bench |
| CIS Kubernetes Benchmark | ✅ 61 PASS, 11 FAIL | kube-bench |
| DSGVO (Secrets) | ✅ Policy | OPA Gatekeeper |

## Team-Namespaces & RBAC

| Namespace | Team (GitHub) | Rolle |
|-----------|---------------|-------|
| wasserbilanz | wasserbilanz-developers | app-developer |
| abwasser | abwasser-developers | app-developer |
| agripower | agripower-customer | customer-app-operator |
| stadtwerke-hh | stadtwerke-hh-customer | customer-app-operator |
| wasserbilanz | wasserbilanz-ops | platform-admin (cluster) |

## Vulnerability Status (Scans vom 2026-04-21)

| Image | Critical | High | Medium | Status |
|-------|----------|------|--------|--------|
| etcd | 32 | 202 | 282 | ⚠️ Cluster-namespace |
| nginx | 16 | 73 | 160 | ⚠️ Zu updaten |
| kindnet | 5 | 46 | 136 | ⚠️ Cluster-namespace |
| kube-proxy | 7 | 53 | 140 | ⚠️ Cluster-namespace |
| gatekeeper | 4 | 17 | 45 | ✅ OK |
| flux components | 1-2 | 9-18 | 14-18 | ✅ OK |

→ Workflow: `docs/12-vulnerability-workflow.md`

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
│ Developer         │              11 FAIL                        │
│                   │              58 WARN                          │
└───────────────────┴─────────────────────────────────────────────┘
```

## Infrastructure

```
rook-k8s-lab/
├── infra/
│   ├── flux/              # Flux GitRepo + Kustomization
│   ├── gatekeeper/        # OPA Policies
│   │   ├── constraints/
│   │   └── templates/
│   ├── rbac/              # Roles + RoleBindings
│   │   ├── roles/
│   │   └── rolebindings/
│   ├── namespaces/        # Team Namespaces
│   └── scripts/           # Automation
│       └── vuln-remediation-workflow.sh
├── apps/
│   └── nginx/             # Sample App (GitOps)
└── docs/                  # Diese Dokumentation
```

## Login Credentials

| Tool | Username | Password | URL |
|------|----------|----------|-----|
| ArgoCD | admin | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` | localhost:9080 |
| Keycloak | admin | admin | localhost:9081 |
| Polaris | — | kein Login | localhost:8080 |

## Troubleshooting

### Alle Pods anzeigen
```bash
kubectl get pods -A -o wide | sort -k4
```

### Logs für Problem
```bash
#tool=logs -f -n <namespace> <pod-name>
kubectl logs -n argocd deployment/argocd-server -f
```

### Logs Ingress NGINX
```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f
```

---

*Letztes Update: 2026-04-21*
