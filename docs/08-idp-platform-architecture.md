# IDP Platform — Governance & Compliance Stack

> Internal Developer Platform (IDP) mit Kubernetes + GitOps + Identity Governance
> Gebaut als POC für Beratungsprojekt

## Überblick

Dieses Projekt baut eine Plattform die es Mandanten ermöglicht, Applikationen auf Kubernetes zu deployen — ohne selbst K8s managen zu müssen. Mit voller Governance, Compliance und Audit-Fähigkeit.

## Architektur

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PLATTFORM                                     │
│                                                                       │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────┐     │
│  │   ArgoCD     │     │    Flux      │     │   OPA Gatekeeper │     │
│  │  (Web UI)    │     │  (GitOps)    │     │    (Policies)    │     │
│  └──────┬───────┘     └──────┬───────┘     └────────┬─────────┘     │
│         │                   │                        │               │
│         │                   │                        │               │
│  ┌──────▼───────────────────▼────────────────────────▼─────────┐     │
│  │                     Kubernetes Cluster                     │     │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────────────┐   │     │
│  │  │ Trivy   │  │  RBAC   │  │ Names-  │  │  Monitoring  │   │     │
│  │  │ Scan    │  │         │  │ paces   │  │ (Prometheus) │   │     │
│  │  └─────────┘  └─────────┘  └─────────┘  └──────────────┘   │     │
│  └─────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌─────────────────────┐              ┌───────────────────────────┐   │
│  │      Keycloak       │◄───────────►│       midPoint            │   │
│  │   (Auth/SSO/OIDC)   │              │  (IGA/Governance/Audit)  │   │
│  └─────────────────────┘              └───────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Fiktives Kundenszenario

### Unternehmen

**Berlinwasser GmbH** — Betreiber von Wasserinfrastruktur in Berlin
- Hat eigene Entwicklerteams
- Bietet digitale Services für externe Kunden (z.B. Landwirte)

### Teams & Berechtigungen

| Team | Rolle | Rechte im Cluster |
|------|-------|--------------------|
| **Platform Team** | PlatformAdmin | Alles: NS erstellen, Policies, Cluster-Ressourcen |
| **Dev Team Wasserbilanz** | AppDeveloper |NS: wasserbilanz (deployen, lesen, logs) |
| **Dev Team Abwasser** | AppDeveloper | NS: abwasser (deployen, lesen, logs) |
| **Kunde AgrarPower** | Customer | NS: agripower (nur eigene Apps lesen/deployen) |
| **Kunde Stadtwerke Hamburg** | Customer | NS: stadtwerke-hh (nur eigene Apps) |

### Externe Kunden (Customer)

| Kunde | Namespace | Darf |
|-------|-----------|------|
| AgrarPower | agripower | Apps deployen, Logs lesen, KEIN kubectl exec |
| Stadtwerke Hamburg | stadtwerke-hh | Apps deployen, Logs lesen, KEIN kubectl exec |

## Komponenten

### Core Platform
| Komponente | Status | Beschreibung |
|-----------|--------|---------------|
| kind Cluster | ✅ Ready | Lokaler K8s Cluster |
| Flux v2 | ✅ Ready | GitOps Engine |
| ArgoCD | 📋 Todo | Web UI für Developer |
| nginx Demo App | ✅ Ready | Test App via Flux deployed |

### Security & Governance
| Komponente | Status | Beschreibung |
|-----------|--------|---------------|
| OPA Gatekeeper | 📋 Todo | Policy Enforcement |
| Trivy Operator | 📋 Todo | Image Vulnerability Scanning |
| RBAC Policies | 📋 Todo | Rollen + RoleBindings |
| Keycloak | 📋 Todo | OIDC Provider |
| midPoint | 📋 Todo | Identity Governance |

### Monitoring & Compliance
| Komponente | Status | Beschreibung |
|-----------|--------|---------------|
| Prometheus | 📋 Todo | Metriken sammeln |
| Grafana | 📋 Todo | Dashboards |
| Compliance Reports | 📋 Todo | midPoint Reports |

## Rollen-Architektur (RBAC)

```
ClusterRole (PlatformAdmin)
  └── can manage all namespaces, can create CRDs, can manage RBAC

Role (AppDeveloper in namespace X)
  └── can deploy, can read logs, can read configmaps
  └── CANNOT exec into pods, CANNOT access other namespaces

Role (Customer in namespace Y)
  └── can deploy own apps only
  └── CANNOT exec, CANNOT list all pods, CANNOT access other namespaces
```

## Policy Beispiel (OPA Gatekeeper)

```rego
# Nur erlaubte Images deployen
deny[msg] {
  input.request.kind.kind == "Deployment"
  not startswith(input.request.object.spec.template.spec.containers[0].image, "registry.company.com/")
  msg := "Only images from company registry allowed"
}

# Keine privileged Container
deny[msg] {
  input.request.kind.kind == "Deployment"
  input.request.object.spec.template.spec.containers[_].securityContext.privileged == true
  msg := "Privileged containers not allowed"
}
```

## Dokumentation

| Datei | Inhalt |
|-------|--------|
| `docs/00-platform-uebersicht.md` | Diese Datei |
| `docs/01-rbac-design.md` | RBAC Rollen + RoleBindings |
| `docs/02-opa-gatekeeper.md` | Policy Enforcement Setup |
| `docs/03-trivy-scanning.md` | Image Scanning |
| `docs/04-keycloak-setup.md` | Keycloak OIDC Integration |
| `docs/05-midpoint-setup.md` | midPoint IGA |
| `docs/06-argocd-setup.md` | ArgoCD als Developer UI |
| `docs/07-compliance-reports.md` | Compliance + Audit |

## Fortschritt

- [x] kind Cluster "rook-lab" aufgesetzt
- [x] Flux GitOps installiert + konfiguriert
- [x] Demo App (nginx) via Flux deployed
- [x] Health Checks für nginx
- [x] Telegram Notifications für Flux Events
- [x] Dashboard Page für Kubernetes Status
- [ ] RBAC Policies für fiktive Teams
- [ ] OPA Gatekeeper Policies
- [ ] Trivy Image Scanner
- [ ] ArgoCD Developer UI
- [ ] Keycloak OIDC
- [ ] midPoint Identity Governance
- [ ] Compliance Reports
- [ ] Leitplanken Dokument (final)

---

*Erstellt: 2026-04-21*
