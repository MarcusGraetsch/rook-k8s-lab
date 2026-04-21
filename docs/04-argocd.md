# ArgoCD — Developer UI für GitOps

## Was es macht

ArgoCD ist das GUI-Interface für Flux. Developer können darüber ihre Applications sehen, Deployment-Status prüfen und Syncs manuell auslösen.

## Installation

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml
```

Warten bis alle Pods ready sind (~3 min):

```bash
kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=180s
kubectl get pods -n argocd
```

## Zugriff

### Port-Forward (lokal)

```bash
# ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 9080:443

# Im Browser: https://localhost:9080
```

### Login

- **Username**: `admin`
- **Password**: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

### Ingress (Production)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
```

## ArgoCD vs Flux

| Aspekt | ArgoCD | Flux |
|--------|--------|------|
| UI | ✅ GUI | ❌ CLI |
| Self-Service | ✅ Developer können Syncen | ❌ Nur Admins |
| GitOps | ✅ | ✅ |
| Installation | Schwer (viele Pods) | Leicht |
| Kubernetes Version | Braucht TLS | Braucht TLS nicht |

**Empfehlung:** Flux für Automation, ArgoCD für Developer-UI.

## Application erstellen

ArgoCD erkennt Applications automatisch wenn Flux sie erstellt. Kein extra Schritt nötig.

## Troubleshooting

### Pod startet nicht
```bash
kubectl logs -n argocd deployment/argocd-server
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server
```

### Login funktioniert nicht
```bash
# Admin Password neu setzen
kubectl -n argocd patch secret argocd-initial-admin-secret \
  -p '{"stringData":{"password":"mein-neues-passwort"}}'
```

### Dex Server Probleme (OAuth)
```bash
kubectl logs -n argocd deployment/argocd-dex-server
```

## Nächste Schritte

1. [x] ArgoCD installiert
2. [x] Login möglich
3. [ ] SSO via Keycloak konfigurieren
4. [ ] Applications im UI sichtbar machen
5. [ ] RBAC für Developer konfigurieren

---

## Compliance Referenzen

### NIS2 — Developer Self-Service

NIS2 Art. 21 fordert **Incident Response** und **Zugriffskontrolle**:
- Developer können Deployments selbst prüfen (Self-Service)
- Keine Direkt-Zugriffe auf Kubernetes API nötig
- Änderungen werden über ArgoCD getrackt

### RBAC für ArgoCD

ArgoCD kann RBAC umsetzen für Developer:

| Policy | Beschreibung | Für |
|--------|--------------|-----|
| `role:readonly` | Nur lesen | Auditor |
| `role:guest` | Deployments sehen | Externe Contractor |
| `role:admin` | Alles | Platform Team |

### BSI IT-Grundschutz CON.2

**M4: Berechtigungsnachweise**
- ArgoCD hat eingebaute Audit Logs (wer hat was deployed)
- Export als CSV für Compliance Reports

### ISO 27001 A.9.4

**Privileged Access Management:**
- ArgoCD admin sollte nur für Platform Team sein
- Developer nutzen `readonly` oder `guest` Rolle
- SSO über Keycloak ermöglicht zentrale Kontrolle

---

*Erstellt: 2026-04-21*
