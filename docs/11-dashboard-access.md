# Dashboard Access Guide

## Übersicht aller Services

| Service | Namespace | Local Port | Ingress Host | Beschreibung |
|---------|-----------|------------|--------------|--------------|
| **ArgoCD** | argocd | 9080 | argocd.idp.local | GitOps UI |
| **Keycloak** | keycloak | 9081 | keycloak.idp.local | Identity Provider |
| **Polaris** | polaris | 8080 | polaris.local | Best Practice Dashboard |
| **Grafana** | monitoring | 3000 | grafana.local | Metriken & Dashboards |
| **Prometheus** | monitoring | 9090 | prometheus.local | Metriken Backend |
| **AlertManager** | monitoring | 9093 | alertmanager.local | Alert Management |
| **Ingress NGINX** | ingress-nginx | 31439 | — | Ingress Controller |

## Schnellzugriff (Port-Forward)

Alle Services auf einmal starten:

```bash
# ArgoCD GitOps UI
kubectl port-forward -n argocd svc/argocd-server 9080:443 &

# Keycloak Identity
kubectl port-forward -n keycloak svc/keycloak-http 9081:80 &

# Polaris Best Practice
kubectl port-forward -n polaris svc/polaris-dashboard 8080:80 &

# Grafana Metriken
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
```

## Login Credentials

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| ArgoCD | admin | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` | |
| Keycloak | admin | admin | Default, in PROD ändern! |
| Grafana | admin | `kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" \| base64 --decode` | |
| Polaris | — | kein Login | Read-only Dashboard |

## Ingress URLs (braucht /etc/hosts)

Für Production-Clusters mit LoadBalancer:

```
192.168.1.100  argocd.idp.local
192.168.1.100  keycloak.idp.local
192.168.1.100  polaris.local
192.168.1.100  grafana.local
192.168.1.100  prometheus.local
```

In `/etc/hosts` eintragen:
```bash
echo "192.168.1.100 argocd.idp.local keycloak.idp.local polaris.local grafana.local prometheus.local" | sudo tee -a /etc/hosts
```

## NodePort Access (kind Cluster)

Falls kein Ingress verfügbar (lokale Entwicklung):

| Service | NodePort | URL |
|---------|----------|-----|
| Ingress NGINX | 31439 | http://localhost:31439 |
| ArgoCD | 30080 | https://localhost:30080 |
| Keycloak | 30081 | http://localhost:30081 |

NodePorts aktivieren:
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc keycloak-http -n keycloak -p '{"spec":{"type":"NodePort"}}'
```

## Health Checks

Alle Services health check:

```bash
# Alle Pods nach Status
kubectl get pods -A --sort-by='.status.conditions[?(@.type=="Ready")].status'

# Alle Services
kubectl get svc -A
```

## Linksammlung für Rook Dashboard

Im Rook Dashboard einbauen:

```json
{
  "kubernetes": {
    "label": "Kubernetes Lab",
    "links": [
      {"name": "ArgoCD", "url": "http://localhost:9080", "icon": "argo"},
      {"name": "Keycloak", "url": "http://localhost:9081", "icon": "keycloak"},
      {"name": "Polaris", "url": "http://localhost:8080", "icon": "polaris"},
      {"name": "Grafana", "url": "http://localhost:3000", "icon": "grafana"},
      {"name": "Prometheus", "url": "http://localhost:9090", "icon": "prometheus"}
    ]
  }
}
```

---

*Erstellt: 2026-04-21*
