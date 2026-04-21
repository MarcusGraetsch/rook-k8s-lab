# Dashboard Access Guide

## Übersicht aller Tools und ihre URLs

| Tool | Namespace | Port-Forward | Ingress URL | Beschreibung |
|------|-----------|--------------|-------------|--------------|
| **Polaris** | polaris | :8080 | polaris.local | Best Practice Validierung |
| **Kubernetes Dashboard** | kubernetes-dashboard | :8443 | k8s.local | Cluster Management |
| **ArgoCD** | argocd | :8080 | argocd.local | GitOps UI |
| **Keycloak** | keycloak | :8080 | keycloak.local | Identity Provider |
| **Grafana** | monitoring | :3000 | grafana.local | Metriken |
| **Prometheus** | monitoring | :9090 | prometheus.local | Monitoring |

## Schnellzugriff (Port-Forward Scripts)

```bash
# Polaris Dashboard
kubectl port-forward -n polaris svc/polaris-dashboard 8080:80

# Kubernetes Dashboard
kubectl proxy

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

## Ingress Zugriff (über Ingress-NGINX)

Damit Ingress-URLs funktionieren, muss die `/etc/hosts` angepasst werden:

```bash
# IP des Clusters
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "$NODE_IP polaris.local argocd.local keycloak.local grafana.local prometheus.local k8s.local"

# In /etc/hosts eintragen:
echo "$NODE_IP polaris.local" >> /etc/hosts
```

Dann: `http://polaris.local` im Browser.

## Ingress Controller aktivieren (kind)

Für localClusters muss der Ingress-Controller auf NodePort laufen:

```bash
# Ingress NGINX auf NodePort
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Service auf NodePort prüfen
kubectl get svc -n ingress-nginx
```

Ausgabe zeigt z.B.: `80:31439/TCP,443:32127/TCP`

Dann im Browser: `http://<node-ip>:31439/`

## Tools ohne Dashboard

Diese Tools haben kein Web-UI, sondern werden per CLI verwendet:

| Tool | CLI |
|------|-----|
| **Trivy** | `kubectl get vulnerabilityreports -A` |
| **kube-bench** | `kubectl logs job/kube-bench` |
| **OPA Gatekeeper** | `kubectl get constraints` |
| **Flux CLI** | `flux get sources` |

## Alle Pods im Überblick

```bash
kubectl get pods -A --sort-by='.metadata.namespace'
```

---

*Erstellt: 2026-04-21*