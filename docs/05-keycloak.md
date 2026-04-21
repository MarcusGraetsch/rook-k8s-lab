# Keycloak — Identity Provider (OIDC)

## Was es macht

Keycloak ist der zentrale Identity Provider für die IDP-Plattform. Er bietet:
- **SSO** (Single Sign-On) für alle Tools
- **OIDC** (OpenID Connect) für Kubernetes API
- **OAuth2** für ArgoCD, Grafana, etc.
- **User Management** mit Rollen

## Installation

```bash
helm repo add codecentric https://codecentric.github.io/helm-charts
helm install keycloak codecentric/keycloak -n keycloak --create-namespace \
  --set postgresql.enabled=false \
  --set keycloak.extraEnv=-name=KEYCLOAK_ADMIN,value=admin
```

**Wichtig:** `postgresql.enabled=false` nutzt embedded H2 Database — nur für DEV/POC geeignet, NICHT für Production!

## Zugriff

### Port-Forward

```bash
kubectl port-forward -n keycloak svc/keycloak-http 9081:80

# Im Browser: http://localhost:9081
# Admin Console: http://localhost:9081/admin
```

### Login

- **URL**: http://localhost:9081
- **Username**: `admin`
- **Password**: `admin`

## OIDC für Kubernetes

### Client in Keycloak erstellen

1. Keycloak Admin Console öffnen
2. **Clients** → **Create**
3. Client ID: `kubernetes`
4. Client Protocol: `openid-connect`
5. Access Type: `confidential`
6. Valid Redirect URIs: `http://localhost:8000/*`

### Service Account erstellen

1. **Service Account Roles** → Role Mapper aktivieren
2. **Clients** → `kubernetes` → **Service Account** Tab
3. Role: `cluster-admin` (für Admin) oder eigene Rolle

### kubectl konfigurieren

```bash
# OIDC Token holen
KEYCLOAK_TOKEN=$(curl -s -X POST http://localhost:9081/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=kubernetes" \
  -d "client_secret=<SECRET>" \
  -d "username=admin" \
  -d "password=admin" | jq -r '.access_token')

# kubectl mit OIDC
kubectl --token=$KEYCLOAK_TOKEN get pods
```

## ArgoCD SSO mit Keycloak

### Keycloak: Client erstellen

1. **Clients** → **Create**
2. Client ID: `argocd`
3. Client Protocol: `openid-connect`
4. Access Type: `confidential`
5. Valid Redirect URIs: `http://localhost:9080/auth/callback`

### ArgoCD: OIDC konfigurieren

```bash
kubectl edit configmap argocd-cm -n argocd
```

```yaml
data:
  url: http://localhost:9080/
  oidc.config: |
    name: Keycloak
    issuer: http://localhost:9081/realms/master
    clientID: argocd
    clientSecret: <SECRET>
    requestedScopes: ["openid", "profile", "email", "groups"]
```

## RBAC mit Keycloak Groups

### Groups erstellen

In Keycloak:
- `idp-admins` — Platform Team
- `idp-developers` — Developer Teams
- `idp-viewers` — Read-only

### Keycloak Role zu Kubernetes Binding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keycloak-idp-admins
roleRef:
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: Group
  name: idp-admins
  apiGroup: rbac.authorization.k8s.io
```

## Production Considerations

⚠️ **Dieser Setup ist nur für POC/DEV!**

Für Production:
- PostgreSQL enable (`--set postgresql.enabled=true`)
- TLS konfigurieren (z.B. via cert-manager)
- Backup Strategy
- High Availability

## Troubleshooting

### Pod hängt in Init
```bash
kubectl describe pod keycloak-0 -n keycloak
# Meistens: Registry Rate Limit (docker.io)
```

### Image Pull Fehler
```bash
# Alternative: quay.io statt docker.io
helm upgrade keycloak codecentric/keycloak -n keycloak \
  --set keycloak.image.repository=quay.io/keycloak/keycloak
```

### Kein Login möglich
```bash
# Admin Password reset
kubectl exec -n keycloak keycloak-0 -- /opt/keycloak/bin/kcadm.sh reset-password \
  --server http://localhost:8080/auth \
  --realm master \
  --user admin \
  --new-password admin
```

## Nächste Schritte

1. [x] Keycloak installiert (ohne PostgreSQL)
2. [x] Login möglich
3. [ ] OIDC Client für Kubernetes erstellen
4. [ ] ArgoCD SSO konfigurieren
5. [ ] RBAC Groups erstellen
6. [ ] Production: PostgreSQL enable

---

*Erstellt: 2026-04-21*
