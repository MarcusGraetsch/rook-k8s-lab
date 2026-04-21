# ArgoCD SSO mit Keycloak — Einrichtunganleitung

## Überblick

Single Sign-On (SSO) ermöglicht Developer, sich **einmal bei Keycloak anzumelden** und dann alle Tools (ArgoCD, Grafana, etc.) ohne erneutes Login zu nutzen.

```
Developer öffnet ArgoCD
        │
        ▼
ArgoCD redirectet zu Keycloak
        │
        ▼
Developer gibt Keycloak Credentials ein
        │
        ▼
Keycloak gibt Token zurück
        │
        ▼
ArgoCD akzeptiert Token → Eingeloggt ✅
```

## Voraussetzungen

- Keycloak läuft auf `http://localhost:9081`
- ArgoCD läuft auf `http://localhost:9080`

## Schritt 1: Keycloak Client für ArgoCD erstellen

### Via Keycloak UI

1. **Keycloak Admin Console** öffnen: http://localhost:9081/admin

2. **Login** mit:
   - Username: `admin`
   - Password: `admin` (oder aktuelles Passwort)

3. **Realm auswählen**: `master`

4. **Client erstellen**:
   - Links: **Clients** → **Create**
   - Client ID: `argocd`
   - Client Protocol: `openid-connect`
   - Access Type: `confidential`
   - Valid Redirect URIs: `http://localhost:9080/auth/callback`
   - Web Origins: `http://localhost:9081`

5. **Client Secret holen**:
   - Tab **Credentials** → Client Secret kopieren
   - Wird später in ArgoCD eingetragen

### Via REST API

```bash
# Admin Token holen
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:9081/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" | jq -r '.access_token')

# ArgoCD Client erstellen
curl -s -X POST "http://localhost:9081/auth/admin/realms/master/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "argocd",
    "name": "ArgoCD",
    "enabled": true,
    "clientProtocol": "openid-connect",
    "publicClient": false,
    "bearerOnly": false,
    "directAccessGrantsEnabled": true,
    "standardFlowEnabled": true,
    "implicitFlowEnabled": false,
    "redirectUris": ["http://localhost:9080/auth/callback"],
    "webOrigins": ["http://localhost:9081"],
    "attributes": {
      "access.token.lifespan": "600"
    }
  }'
```

## Schritt 2: ArgoCD OIDC Configuration

### ConfigMap patchen

```bash
kubectl patch configmap argocd-cm -n argocd -p '
{
  "data": {
    "url": "http://localhost:9080",
    "oidc.config": "name: Keycloak\nissuer: http://localhost:9081/realms/master\nclientID: argocd\nclientSecret: DEIN_CLIENT_SECRET_HIER\nrequestedScopes: [\"openid\", \"profile\", \"email\", \"groups\"]"
  }
}
'
```

### ArgoCD Server neu starten

```bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

## Schritt 3: ArgoCD RBAC für Keycloak Groups

### admin Scope für Keycloak Groups

ArgoCD nutzt Keycloak Groups für RBAC:

```bash
kubectl patch configmap argocd-rbac-cm -n argocd -p '
{
  "data": {
    "policy.csv": "g, idp-admins, role, admin\np, idp-admins, *, *, allow\n\ng, idp-developers, role, argocd-admin\np, idp-developers, *, *, allow\n\ng, idp-viewers, role, readonly\np, idp-viewers, get, *, allow"
  }
}
'
```

### Bedeutung

| Keycloak Group | ArgoCD Role | Permissions |
|----------------|--------------|-------------|
| `idp-admins` | admin | Alles |
| `idp-developers` | argocd-admin | Alle Actions, eigene Namespaces |
| `idp-viewers` | readonly | Nur lesen |

## Schritt 4: Keycloak Groups erstellen

### Groups in Keycloak

1. **Keycloak Admin Console** → **Groups** → **New**
2. Groups erstellen:
   - `idp-admins` (Platform Team)
   - `idp-developers` (Developer)
   - `idp-viewers` (Externe Auditoren)

### User zu Groups hinzufügen

1. **Users** → User auswählen → **Groups** Tab
2. Group zuweisen

## Schritt 5: Testen

### Login Flow testen

1. ArgoCD öffnen: http://localhost:9080
2. Login Button klickt auf "Login with Keycloak"
3. Keycloak Login Page erscheint
4. Credentials eingeben
5. Zurück zu ArgoCD → Eingeloggt

### ArgoCD Login Page zeigt SSO Option

Nach der Konfiguration sollte ArgoCD's Login Page zwei Optionen zeigen:
- **Local** (admin/password)
- **Keycloak** (SSO)

## Troubleshooting

### "Invalid scope" Fehler

```bash
# Prüfe ob requestedScopes korrekt sind
# Keycloak muss "openid" Scope haben
```

### "Client not found" Fehler

Prüfe:
1. Client ID in Keycloak = `argocd`
2. Valid Redirect URIs enthält `http://localhost:9080/auth/callback`

### Token wird nicht akzeptiert

```bash
# Logs prüfen
kubectl logs -n argocd deployment/argocd-server | grep -i oidc
```

## Production Considerations

⚠️ Für Production:

1. **TLS aktivieren** (HTTPS statt HTTP)
   - ArgoCD: `argocd-server` Service mit TLS
   - Keycloak: via Ingress + cert-manager

2. **Client Secret sicher speichern**
   ```bash
   kubectl create secret generic argocd-keycloak-secret \
     -n argocd \
     --from-literal=client-secret=DEIN_SECRET
   ```

3. **Gruppen-Mapping permanent machen**
   - In Keycloak: Client Scope "groups" hinzufügen
   - Token enthält dann Gruppen

## Compliance Referenzen

### NIS2 Art. 21 — Access Control

SSO ermöglicht:
- Zentrale Zugriffskontrolle via Keycloak
- Audit Trail (wer hat sich wann eingeloggt)
- schnelles Deaktivieren bei Incident

### BSI CON.2 — Identitäts- und Access Management

Keycloak SSO erfüllt:
- M2: Starke Authentifizierung (MFA möglich)
- M3: Identity Federation
- Zentrales User Management

### ISO 27001 A.9.2

> "A regular user registration and de-registration process must be in place"

SSO mit Keycloak = zentrales User Management für alle Tools.

---

*Erstellt: 2026-04-21*
