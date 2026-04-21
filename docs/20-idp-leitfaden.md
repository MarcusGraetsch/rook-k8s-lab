# IDP Plattform — Leitfaden für Alle

> Was wir gebaut haben, warum es wichtig ist, und wie man es benutzt.

---

## TL;DR

Wir haben eine **Internal Developer Platform (IDP)** aufgebaut — eine Sammlung von Tools die:
- **Developer Teams** ermöglicht, selbstständig Anwendungen zu deployen
- **Platform Teams** entlastet von manuellen Ops-Aufgaben
- **Sicherheit & Compliance** automatisch sicherstellt ( NIS2, BSI, DSGVO )

> Alle Änderungen am Cluster laufen über **Git** (GitOps). Kein direkter Zugriff auf Kubernetes API für Developer.

---

## Was ist eine IDP?

Eine IDP ist das Bindeglied zwischen Developer und Kubernetes. Stelle dir vor:

| Ohne IDP | Mit IDP |
|----------|---------|
| Developer braucht Namespace → Ticket an Ops | Developerrequest →automatisches Provisioning |
| Ops muss jeden Deploy manuell machen | Developer pushed Code → Flux deployed automatisch |
| Security Prüfung wird vergessen | OPA Gatekeeper blockiert nicht-konforme Deployments |
| Wer hat was deployed? | Git Log zeigt jede Änderung |

---

## Die Tools die wir nutzen

### Flux — GitOps Engine

**Was es macht:** Wenn etwas in Git steht, wird es automatisch im Cluster angewendet.

```
Developer push Code
        │
        ▼
GitHub (Code Repository)
        │
        ▼ Flux erkennt Änderung
Flux wendet Manifeste an
        │
        ▼
Kubernetes Cluster
```

**Warum GitOps?** 
- Jede Änderung ist nachvollziehbar (Git = Audit Trail)
- Keine "Fly-by-Night" Änderungen mehr
- Rollback in 5 Sekunden

### ArgoCD — Dashboard für Developer

**Was es macht:** Visuelles Interface zu Flux. Developer können sehen was deployed ist und manuell syncen.

**Für wen:** Developer die kein CLI mögen.

### Keycloak — Identity Provider

**Was es macht:** Zentrales Login für alle Tools. Einmal anmelden, alles nutzen.

**Warum Keycloak?**
- SSO (Single Sign-On) 
- Rollen werden automatisch aus Groups abgeleitet
- Dein Kubernetes Token sagt wer du bist

### OPA Gatekeeper — Policy Police

**Was es macht:** Prüft ob Deployments sicher sind bevor sie durchkommen.

**Beispiele für Regeln:**
- Container dürfen nur aus erlaubten Registries kommen (docker.io, quay.io)
- Keine privilegierten Container
- Resource Limits müssen gesetzt sein

```
Deployment kommt rein
        │
        ▼ Gatekeeper prüft
符合 Regeln? → Erlaubt ✅
        │
   Verstößt gegen Regeln → Blockiert + Alert ❌
```

### Trivy — Vulnerability Scanner

**Was es macht:** Scannt alle Container Images auf Sicherheitslücken (CVEs).

**Was passiert mit Findings?**
1. Trivy findet CVE → Script prüft ob Fix verfügbar
2. Fix verfügbar? → Auto-PR erstellt
3. Kein Fix? → Alert an Platform Team

### kube-bench — Compliance Checker

**Was es macht:** Prüft den Cluster gegen CIS Kubernetes Benchmark.

**Report zeigt:**
- ✅ Was ist korrekt konfiguriert
- ❌ Was muss gefixt werden
- ⚠️ Warnings für Manual Review

### Polaris — Best Practice Validator

**Was es macht:** Prüft ob Deployments Best Practices einhalten.

**Checks:**
- Readiness/Liveness Probes gesetzt?
- Resource Limits vorhanden?
- Security Context korrekt?

### Prometheus + Grafana — Monitoring

**Was es macht:** Zeigt Metriken, Dashboards, Alerts.

**Für wen:**
- Platform Team: Cluster-Health, Kapazitäten
- Developer: Meine App läuft? CPU/Memory?
- Management: SLA-Einhaltung

### midPoint — Identity Governance

**Was es macht:** Verwaltet wer Zugriff hat — mit Audit Trail für Compliance.

**Typische Workflows:**
- **Joiner:** Neue Person kommt → midPoint erstellt alle Accounts
- **Mover:** Person wechselt Abteilung → Rechte werden angepasst
- **Leaver:** Person geht → Alle Accounts werden deaktiviert

---

## Für wen ist was?

| Person | Nutzt | Für |
|--------|-------|-----|
| **Developer (Wasserbilanz)** | ArgoCD, Git | Meine Apps deployen, Status sehen |
| **Developer (Kunde extern)** | ArgoCD (nur eigene NS) | Nur meine App sehen |
| **Platform Team** | Alles | Cluster managen, Policies setzen |
| **Security/Compliance** | midPoint, Grafana, kube-bench | Reports, Audits |
| **Management** | Grafana Dashboards | Überblick, SLA |

---

## Bedienungsanleitung

### Developer: App deployen

**Schritt 1: Code ändern**
```bash
# In deinem App Repository
git checkout main
git pull
# Deine Änderungen machen
git push
```

**Schritt 2: Flux erkennt automatisch**
- Flux pullt neue Manifeste aus Git
- Wenn alles OK → Deployment startet
- Wenn Fehler → Alert an Platform Team

**Schritt 3: Status prüfen (optional)**
```bash
# Im ArgoCD Dashboard
# Oder CLI:
flux get kustomizations

# Namespace Status
kubectl get pods -n <dein-namespace>
```

### Developer: Neuen Service anfordern

```
1. Ticket/Request an Platform Team
   → Namespace wird erstellt
   → RBAC wird konfiguriert
   → GitRepo Structure wird bereitgestellt

2. Du bekommst:
   → Zugang zu deinem Namespace
   → Anleitung wie du deployst

3. Ab jetzt: Self-Service über GitOps
```

### Developer: Zugriffsproblem melden

```
1. ArgoCD öffnen → Siehst du deine App?
2. Falls nein → Platform Team informieren
3. Problem wird über RBAC/Keycloak geprüft
```

### Platform Team: Neuen Kunden/Team onboaden

**Schritt 1: Namespace erstellen**
```bash
kubectl create namespace <team-name>
```

**Schritt 2: RBAC konfigurieren (in Git)**
```yaml
# infra/rbac/rolebindings/<team>.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <team>-developers
  namespace: <team-name>
subjects:
  - kind: Group
    name: github:<org>/<team>
roleRef:
  kind: Role
  name: app-developer
```

**Schritt 3: Flux synced automatisch**
```bash
# Innerhalb von 1 Minute:
flux reconcile kustomization infra
```

**Schritt 4: Kunde informieren**
```
→ Dein Namespace ist ready
→ GitHub Team wurde berechtigt
→ ArgoCD URL für dich: http://argocd.local
```

### Security: Compliance Report erstellen

**Schritt 1: kube-bench Report**
```bash
kubectl logs job/kube-bench
```

**Schritt 2: Vulnerability Report**
```bash
kubectl get vulnerabilityreports -A
```

**Schritt 3: midPoint Access Review**
```
1. midPoint öffnen
2. Reports → Access Certification
3. Neuen Review erstellen für <Namespace>
4. Reviewer benennen
5. Report exportieren
```

**Schritt 4: Findings dokumentieren**
```
→ Findings werden als GitHub Issues erstellt
→ Platform Team assigned
→ Follow-up in nächster Woche
```

---

## Support & Troubleshooting

### Wo finde ich Hilfe?

| Problem | Lösung |
|---------|--------|
| Deployment schlägt fehl | `kubectl describe pod <name> -n <ns>` |
| Flux erkennt Änderung nicht | `flux reconcile source git <name>` |
| ArgoCD zeigt "Out of Sync" | `flux reconcile kustomization <name>` |
| Zugriff verweigert | Platform Team fragen (Keycloak/RBAC) |
| CVE gefunden — was tun? | Vulnerability Workflow (docs/12-vulnerability-workflow.md) |

###歇

### Escalation Pfad

```
1. Developer 发现问题 → Platform Team (Slack/Telegram)
2. Platform Team kann nicht lösen → Architecture Team
3. Security Issue → Security Team + Incident Response
```

---

## Compliance auf einen Blick

| Standard | Was wir tun |
|----------|-------------|
| **NIS2** | OPA Gatekeeper (Policy), Trivy (CVE), Prometheus (Monitoring) |
| **BSI IT-Grundschutz** | kube-bench (CIS), Polaris (Best Practice), RBAC (Zugriff) |
| **DSGVO** | Keycloak (Auth), Secrets nicht in Env Vars, Audit Logs |
| **ISO 27001** | Flux (Change Mgmt), Prometheus (Incident Mgmt), midPoint (Access) |

---

## Glossar

| Begriff | Bedeutung |
|---------|-----------|
| **GitOps** | Git ist Source of Truth für Infrastruktur |
| **OPA Gatekeeper** | Policy Enforcement im Cluster |
| **CVE** | Common Vulnerabilities and Exposures |
| **RBAC** | Role-Based Access Control |
| **SSO** | Single Sign-On (ein Login für alles) |
| **Namespace** | Isolierter Bereich im Cluster |
| **Flux** | GitOps Engine die Manifeste anwendet |
| **midPoint** | Identity Governance (Zugriffsrechte verwalten) |
| **Trivy** | Vulnerability Scanner für Container |

---

## Ansprechpartner

| Rolle | Für |
|-------|-----|
| Platform Team | Cluster-Zugriff, neue Namespaces, RBAC |
| Security Team | CVE Reports, Compliance, midPoint |
| Architecture | Entscheidungen über Tool-Stack |

---

*Dokument erstellt: 2026-04-21*
*Letzte Änderung: Kommentare willkommen als GitHub Issue*
