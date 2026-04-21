# Kubernetes Lab — IDP Plattform

> Lokales Kubernetes-IDP (Internal Developer Platform) auf kind für Cloud-native Kunden-POCs.

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
```

## Tool-Übersicht

### Core Platform
| Tool | Version | Status | Port |
|------|---------|--------|------|
| kind Cluster | 0.20+ | ✅ Running | — |
| kubectl | latest | ✅ | — |
| Helm | 3.12+ | ✅ | — |

### GitOps & Developer Experience
| Tool | Version | Status | Port |
|------|---------|--------|------|
| Flux | 2.8.5 | ✅ | — |
| ArgoCD | 2.13.2 | ✅ | 9080 |
| Keycloak | 17.0.1 | ✅ | 9081 |

### Security & Compliance
| Tool | Version | Status | Docs |
|------|---------|--------|------|
| OPA Gatekeeper | 3.14.0 | ✅ | 02-opa-gatekeeper.md |
| Trivy Operator | 0.21+ | ✅ | 10-trivy-operator.md |
| kube-bench | 0.15+ | ✅ | 09-compliance-security.md |
| Polaris | 10.1+ | ✅ | 09-compliance-security.md |

### Monitoring & Notifications
| Tool | Version | Status | Port |
|------|---------|--------|------|
| Prometheus | 0.73+ | ✅ | 9090 |
| Grafana | 10.4+ | ✅ | 3000 |
| AlertManager | 0.27+ | ✅ | 9093 |
| Ingress NGINX | 1.10+ | ✅ | 31439 |

## Dokumentation

```
docs/
├── 00-stack-comparison.md           # Docker vs Podman vs kind
├── 01-rbac-design.md                # RBAC + Teams
├── 02-opa-gatekeeper.md            # Policy Enforcement
├── 03-flux-intro.md                # GitOps Einführung
├── 03-flux-install-step-by-step.md  # Flux Installation
├── 04-argocd.md                    # ArgoCD Developer UI ✅
├── 05-keycloak.md                  # Keycloak OIDC ✅
├── 06-monitoring.md                # Prometheus + Grafana ✅
├── 07-flux-telegram-notifications.md
├── 08-idp-platform-architecture.md
├── 09-compliance-security.md       # Compliance Stack ✅
├── 10-trivy-operator.md            # Image Scanning ✅
├── 11-dashboard-access.md          # Alle URLs ✅
└── 12-vulnerability-workflow.md   # Security Workflow ✅
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
│ Best Practice    │ Compliance                                   │
│                   │                                              │
│ Polaris ─────────►│ kube-bench                                   │
│ (Workload Check)  │ (CIS/BSI Audit)                              │
│                   │                                              │
│ Dashboard für     │ Report: 61 PASS                              │
│ Developer         │              11 FAIL                          │
│                   │              58 WARN                          │
├───────────────────┴─────────────────────────────────────────────┤
│ Monitoring & Alerting                                            │
│                                                                   │
│ Prometheus + Grafana ───► AlertManager ───► Telegram             │
│ (Metriken)              (Alert Routing)    (Notification)        │
└──────────────────────────────────────────────────────────────────┘
```

## Login Credentials

| Service | Username | Password Command |
|---------|----------|------------------|
| ArgoCD | admin | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| Keycloak | admin | `admin` (default, PROD ändern!) |
| Grafana | admin | `kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" \| base64 --decode` |

## Monitoring Stack

```
┌──────────────────────────────────────────────────────────────────┐
│                    Monitoring & Alerting                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Prometheus ◄──── kube-state-metrics                             │
│       │              (Cluster State)                               │
│       │              node-exporter                                │
│       │              (Node Resources)                              │
│       │                                                             │
│       ▼                                                             │
│  Grafana Dashboards ◄── Vorinstallierte Dashboards                │
│                                                                   │
│       │                                                             │
│       ▼                                                             │
│  AlertManager ◄──── Alert Rules                                    │
│       │                                                             │
│       ▼                                                             │
│  Telegram ───► Team Benachrichtigungen                            │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Offene Punkte (nicht installiert)

| Item | Reason | Aufwand |
|------|--------|---------|
| midPoint (IGA) | Overkill für POC | Hoch |
| Harbor Registry | Brauchen wir vorerst nicht (trivy reicht) | Mittel |
| External URLs | kind Cluster unterstützt keine LoadBalancer | Niedrig |

---

*Letztes Update: 2026-04-21*
