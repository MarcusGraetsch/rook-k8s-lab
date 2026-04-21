# Monitoring — Prometheus + Grafana

## Was es macht

Prometheus sammelt Metriken von allen Services im Cluster. Grafana visualisiert sie in Dashboards.

## Installation

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

## Zugriff

### Port-Forward

```bash
# Grafana Dashboard
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Prometheus (Metriken)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

### Login Grafana

- **URL**: http://localhost:3000
- **Username**: `admin`
- **Password**: `kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode`

## Vorinstallierte Dashboards

Grafana kommt mit Dashboards für:

| Dashboard | Zeigt |
|-----------|-------|
| Kubernetes / Compute Resources / Cluster | CPU, Memory, Network |
| Kubernetes / Compute Resources / Namespace | Per-Namespace Stats |
| Kubernetes / Compute Resources / Pod | Per-Pod Stats |
| Kubernetes / Networking / Namespace | Netzwerk-Traffic |
| Alertmanager | Aktive Alerts |

## Prometheus Queries (PromQL)

Metriken direkt abfragen:

```bash
# kubectl top für einfache Metriken (ohne Prometheus)
kubectl top nodes
kubectl top pods -A

# Prometheus Query API
curl -s http://localhost:9090/api/v1/query?query=up
```

## Wichtige Metriken

| Metrik | Bedeutung |
|--------|----------|
| `up{job="kube-state-metrics"}` | Ist der Cluster healthy? |
| `container_cpu_usage_seconds_total` | CPU Nutzung pro Container |
| `container_memory_usage_bytes` | RAM Nutzung pro Container |
| `kube_pod_status_phase` | Pod Status (Running, Pending, etc.) |
| `kube_deployment_status_replicas` | Gewünschte vs. tatsächliche Replicas |

## Alerts konfigurieren

Prometheus kommt mit vordefinierten Alert Rules. Anzeigen:

```bash
kubectl get prometheusrules -n monitoring
```

Alerts werden zu AlertManager geschickt. Von dort können sie weitergeleitet werden:
- Slack
- Telegram (via webhook)
- Email
- PagerDuty

## Troubleshooting

### Grafana Pod startet nicht
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana
# Meist: PVC Problem (Persistence)
```

### Prometheus Metriken fehlen
```bash
# Ist kube-state-metrics erreichbar?
kubectl logs -n monitoring deployment/prometheus-kube-state-metrics
# Metriken testen:
curl -s localhost:8080/metrics | head
```

### Keine Daten im Dashboard
1. Dashboard → Zeitraum auf "Last 5 minutes" stellen
2. Datenquelle prüfen: Connections → Data Sources → Prometheus
3. Target prüfen: Status → Targets

## Nächste Schritte

1. [x] Prometheus + Grafana installiert
2. [x] Login funktioniert
3. [ ] Telegram Alert für Critical Alerts
4. [ ] Custom Dashboard für IDP-Metriken
5. [ ] Ingress für externe URLs (braucht Cluster-Neustart)

---

## Compliance Referenzen

### NIS2 Art. 21 — Incident Detection & Response

NIS2 fordert:
> "Prozesse zur Erkennung, Bewertung und Meldung von Sicherheitsvorfällen"

Prometheus + AlertManager ermöglichen:
- **Erkennung**: Metriken zeigen Anomalien (hohe CPU, Crash-Loops)
- **Bewertung**: Alert Severity (critical/warning/info)
- **Meldung**: AlertManager routet zu Telegram, Email, PagerDuty

### BSI IT-Grundschutz CON.1 + OPS.1.1.3

**CON.1 M8: Monitoring und Protokollierung**
- kube-state-metrics: Cluster-Zustand wird erfasst
- node-exporter: CPU, Memory, Network pro Node
- Prometheus: Zentrale Metriken-Sammlung

**OPS.1.1.3 M4: Alarmierung**
> "Bei Überschreitung von Schwellwerten muss automatisch alarmiert werden"

Prometheus Alertmanager setzt das um:
```yaml
# Beispiel: Critical Alert bei Pod Crash
- alert: KubePodCrashLooping
  expr: rate(kube_pod_container_status_restarts[5m]) > 0.3
  labels:
    severity: critical
  annotations:
    summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is restarting"
```

### DSGVO Art. 33 — Breach Notification

> "Bei einer Verletzung des Schutzes personenbezogener Daten... Benachrichtigung innerhalb von 72 Stunden"

Prometheus + AlertManager stellen sicher:
- Sicherheitsvorfälle werden sofort erkannt
- Alert geht an zuständiges Team
- Incident Response kann innerhalb von 72h starten

### ISO 27001 A.16 — Information Security Incident Management

- A.16.1.1: Management of incidents and weaknesses
- A.16.1.2: Reporting information security events

Prometheus Alerting = technische Umsetzung für A.16.1.1/2

---

*Erstellt: 2026-04-21*
