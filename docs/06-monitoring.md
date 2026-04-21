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

*Erstellt: 2026-04-21*
