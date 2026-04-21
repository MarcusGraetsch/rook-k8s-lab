# Trivy Operator — Image Vulnerability Scanning

## Was es macht

Der Trivy Operator scannt automatisch alle Container Images im Cluster auf bekannte Vulnerabilities (CVEs). Er läuft als Kubernetes Operator und erstellt VulnerabilityReports als CRDs.

## Installation

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml
```

Nach ~2 Minuten sind alle Pods ready:

```bash
kubectl get pods -n trivy-system
```

## Scans anzeigen

Der Operator hat bereits alle Images im Cluster gescannt. Ergebnisse anzeigen:

```bash
# Alle Scans über alle Namespaces
kubectl get vulnerabilityreports -A

# Schön formatiert (Critical/High/Medium)
kubectl get vulnerabilityreports -A -o jsonpath='{range .items[*]}
{.metadata.namespace}/{.metadata.name}: {.report.artifact.repository}
  {.report.summary.criticalCount}C {.report.summary.highCount}H {.report.summary.mediumCount}M
{end}' | sort
```

## Beispiel Output

```
default/job-kube-bench-kube-bench: aquasec/kube-bench
  1C 17H 23M
default/replicaset-nginx-5cc5f8544d-nginx: library/nginx
  16C 73H 160M
gatekeeper-system/replicaset-gatekeeper-audit-659dd569bb-manager: openpolicyagent/gatekeeper
  4C 17H 45M
kube-system/pod-etcd-rook-lab-control-plane-etcd: etcd
  32C 202H 282M
```

## Einzelenes Image scannen (CLI)

Falls du ein bestimmtes Image manuell scannen willst:

```bash
# Trivy installieren
curl -fsSL https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.57.0_Linux-64bit.tar.gz -o trivy.tar.gz
tar -xzf trivy.tar.gz && mv trivy /usr/local/bin/

# Image scannen
trivy image docker.io/nginx:alpine
trivy image --format html --output report.html docker.io/nginx:alpine
```

## CI/CD Integration

In einer echten Pipeline würde Trivy bei jedem Image-Build laufen:

```yaml
# .gitlab-ci.yml Beispiel
trivy:
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL myregistry/myapp:latest
```

## Severity Levels

| Level | Bedeutung | Aktion |
|-------|-----------|--------|
| CRITICAL | Sofort beheben | Deployment blockieren |
| HIGH | Bald beheben | Alarm +tracking |
| MEDIUM | Planung | In Backlog |
| LOW | Optional | Nice-to-have |
| UNKNOWN | Unbekannt | Investigieren |

## Konfiguration

Der Trivy Operator installiert einen VulnerabilityReport für jede Workload. Wenn ein Deployment einen Scan mit CRITICALs hat, kann OPA Gatekeeper das Deployment blockieren.

## Nächste Schritte

1. [x] Trivy Operator installiert + gescannt
2. [ ] Pipeline: Trivy blockt Images mit CRITICALs
3. [ ] Reports exportieren für Compliance

---

*Erstellt: 2026-04-21*
---

## Compliance Referenzen

### NIS2 Art. 21 — Vulnerability Management

NIS2 fordert:
> "Maßnahmen zur Beherrschung von Risiken... einschließlich... Schwachstellenmanagement"

| NIS2 Anforderung | Umsetzung |
|-----------------|-----------|
| Kontinuierliches Scanning | Trivy Operator scannt alle Images |
| Risikobewertung | Severity Levels (CRITICAL/HIGH/MEDIUM) |
| Behebung | Auto-PR oder Human-in-the-Loop |

### BSI CON.1 M4 — Schwachstellenmanagement

> "Prozesse zur Erkennung und Behebung von Schwachstellen in Container-Images"

Trivy findet:
- CVEs in Base Images
- Outdated Packages
- Security Misconfigurations

### ISO 27001 A.12.6 — Technical Vulnerabilities

- A.12.6.1: Schwachstellen werden zeitnah identifiziert
- A.12.6.2: Relevanz wird bewertet
- A.12.6.3: Maßnahmen zur Behebung

### EU Cyber Resilience Act (CRA)

Ab 2027: Pflicht-Scans für Produkte mit digitalen Elementen.

---

*Erstellt: 2026-04-21*
