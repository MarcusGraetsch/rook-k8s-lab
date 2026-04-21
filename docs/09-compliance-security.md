# Compliance & Security Scanner

## Überblick

Dieses Dokument beschreibt die Security- und Compliance-Tools die wir im IDP-POC einsetzen:

| Tool | Zweck | Status |
|------|-------|--------|
| **kube-bench** | CIS Kubernetes Benchmark + BSI Checks | ✅ Installiert |
| **Polaris** | Best-Practice Validierung | ✅ Installiert |
| **Trivy** | Image Vulnerability Scanning | 📋 Nächster Schritt |
| **OPA Gatekeeper** | Policy Enforcement | ✅ Installiert |
| **Harbor** | Container Registry + Scanning | Option (für später) |

## kube-bench

### Was es macht

kube-bench prüft ob der Kubernetes Cluster gegen das **CIS Kubernetes Benchmark** konfiguriert ist. Das ist auch die Grundlage für BSI IT-Grundschutz (Baustein CON.1).

### Installation

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Prüfen dass der Job läuft
kubectl get pods -n default | grep kube-bench
```

### Ausführen

```bash
# Logs des letzten Runs anzeigen
kubectl logs job/kube-bench

# Oder als CronJob für regelmäßige Checks
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/cronjob.yaml
```

### Ergebnis interpretieren

```
== Summary policies ==
61 checks PASS     ← Sicherheitscheck bestanden
11 checks FAIL     ← Hier nachbessern!
58 checks WARN     ← Manual Checks beachten
0 checks INFO
```

**FAILs sind kritisch** — diese müssen behoben werden.
**WARNs sind Empfehlungen** — optional aber empfohlen.

### Typische FAILs bei kind-Clustern

| FAIL | Ursache | Behebung |
|------|---------|----------|
| 1.1.12 etcd ownership | kind verwendet root | In Produktion: chown etcd:etcd |
| 1.2.5 kubelet-ca not set | kind kein full cert setup | In Produktion: CA setzen |
| 1.2.16 --audit-log-path | kind kein Audit konfiguriert | Für_prod: Logging aktivieren |
| 1.3.2 profiling | Controller Manager profiling an | In Produktion: --profiling=false |

### Für BSI Grundschutz relevante Checks

kube-bench mapped zu BSI CON.1:

- **CON.1.1.M4** (Container hardened Images) → IMAGE_SCANNING via Trivy
- **CON.1.1.M5** (Network Policies) → OPA Gatekeeper
- **CON.1.1.M7** (Resource Limits) → Polaris prüft resource limits
- **CON.1.1.M8** (Secrets Management) → OPA verhindert secrets in env vars
- **CON.1.1.M9** (Audit Logging) → kube-bench checkt 1.2.16-1.2.19

## Polaris

### Was es macht

Polaris validiert Kubernetes Workloads gegen Best-Practice-Standards. Es gibt Warning bei:
- Fehlende Resource Limits
- Privilegierte Container
- Kein Security Context
- Fehlende Readiness/Liveness Probes
- Gefährliche Container Images

### Installation via Helm

```bash
# Helm installieren falls nicht vorhanden
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Polaris deployen
helm repo add fairwinds https://charts.fairwinds.com/stable
helm repo update
helm install polaris fairwinds/polaris -n polaris --create-namespace
```

### Dashboard öffnen

```bash
# Port-Forward starten
kubectl port-forward -n polaris svc/polaris-dashboard 8080:80

# Im Browser: http://localhost:8080
```

Das Dashboard zeigt eine Übersicht aller Namespaces mit Best-Practice-Score.

### Validation Dashboard nutzen (für DevOps Team)

1. **Übersicht:** Welche Namespaces haben die meisten Issues?
2. **Einzelansicht:** Klick auf Namespace → Welche Deployments haben Probleme?
3. **Filter:** Nur WARN/ERROR anzeigen
4. **Export:** Reports als JSON für Compliance-Dokumentation

### Polaris Konfiguration

Eigene Checks in `polaris-config.yaml`:

```yaml
checks:
  # Resource Limits
  cpuRequests: warning
  memoryRequests: warning
  cpuLimits: warning
  memoryLimits: warning
  
  # Security
  privileged: danger
  runAsRoot: danger
  runAsRootAuto: danger
  
  # Health
  readinessProbeMissing: warning
  livenessProbeMissing: warning
```

## Trivy (Image Scanning)

### Was es macht

Trivy scannt Container Images auf bekannte Vulnerabilities (CVEs). Es ist der Nachfolger von Clair und deutlich einfacher zu bedienen.

### Installation

```bash
# Trivy installieren
curl -fsSL https://aquasecurity.github.io/trivy-repo/pkg/deb/public.key | apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/trivy.list
apt-get update && apt-get install trivy

# Oder standalone:
curl -fsSL https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.57.0_Linux-64bit.tar.gz -o trivy.tar.gz
tar -xzf trivy.tar.gz && mv trivy /usr/local/bin/
```

### Einzelenes Image scannen

```bash
trivy image docker.io/nginx:alpine
```

### Trivy Operator für kontinuierliches Scanning

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml
```

Der Operator scannt neue Images automatisch wenn sie in den Cluster kommen.

### Compliance Reports

Trivy kann Reports im HTML, JSON, oder SARIF Format exportieren:

```bash
trivy image --format html --output report.html docker.io/nginx:alpine
trivy image --format sarif --output report.sarif docker.io/nginx:alpine
```

## Harbor (Option für später)

### Was es ist

Harbor ist eine **self-hosted Container Registry** mit integriertem Vulnerability Scanning. Unternehmen nutzen Harbor als zentrale Bildregistry hinter der Firewall.

### Warum Harbor statt docker.io?

| Aspekt | docker.io / quay.io | Harbor |
|--------|---------------------|--------|
| Host | Extern | Intern/Cloud |
| Scanning | Optional, extern | Eingebaut, automatisch |
| Zugriffskontrolle | Limited | RBAC, Projekt-basiert |
| Firewall | Öffentlich | Privates Netzwerk |
| Retention | Keine Garantie | volle Kontrolle |

### Nutzungsszenario

```
Developer baut Image
        │
        ▼
Harbor Registry (intern)
        │
        ▼
Harbor scannt automatisch auf CVEs
        │
        ✓ Keine kritischen Vulnerabilities?
            │
        Ja → Image darf in Produktion
        Nein → Image wird rejected
```

### Installation (später)

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
helm install harbor harbor/harbor -n harbor \
  --set expose.type=loadBalancer \
  --set persistence.persistentVolumeClaim.registry.size=100Gi
```

### Integration mit OPA Gatekeeper

Harbor kann per Webhook bei neuen Images benachrichtigen. Gatekeeper kann dann prüfen ob nur gescannte Images deployt werden dürfen.

## Zusammenfassung: Compliance Stack

```
┌──────────────────────────────────────────────────────────────────┐
│                    Compliance & Security                          │
├──────────────────────────────────────────────────────────────────┤
│  Image Layer                    │  Cluster Layer                 │
│                                  │                               │
│  Trivy / Harbor                 │  OPA Gatekeeper               │
│  (CVE Scanning)                 │  (Policy Enforcement)         │
│                                  │                               │
│  Developers bauen Images        │  Policies prüfen Deployments  │
│  → Harbor scannt automatisch     │  → Verbietet nicht-compliante │
│  → Nur saubere Images kommen    │    Deployments               │
├──────────────────────────────────────────────────────────────────┤
│  Best Practice                    │  CIS Benchmark               │
│                                  │                               │
│  Polaris                        │  kube-bench                   │
│  (Workload Validation)           │  (Cluster Audit)              │
│                                  │                               │
│  Prüft resource limits,         │  Prüft CIS Controls:         │
│  security context, probes       │  61 PASS, 11 FAIL, 58 WARN    │
│  → Warnungen im Dashboard       │  → Compliance Report          │
└──────────────────────────────────────────────────────────────────┘
```

## Nächste Schritte

1. [x] kube-bench installiert + dokumentiert
2. [x] Polaris installiert + Dashboard
3. [ ] Trivy Operator installieren
4. [ ] Trivy trivy-image-scan als CronJob
5. [ ] Harbor als Option dokumentieren (für später)
6. [ ] Compliance Report Workflow bauen

---

*Erstellt: 2026-04-21*
