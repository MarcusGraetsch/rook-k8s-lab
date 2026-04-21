# Secrets Management

## Das Problem

Kubernetes Secrets sind **Base64-kodiert, nicht verschlüsselt**:

```bash
# Das ist KEINE Verschlüsselung!
echo "mein-passwort" | base64
bWVpbi1wYXNzd29ydAo=

# Decodieren ist trivial:
echo "bWVpbi1wYXNzd29ydAo=" | base64 -d
mein-passwort
```

**Jeder der Zugriff auf etcd hat, kann Secrets lesen.**

## Lösungen

### Option 1: Kubernetes Sealed Secrets

**Was es macht:** Secrets werden verschlüsselt in Git gespeichert. Nur der Sealed Secrets Controller kann sie entschlüsseln.

```
Developer erstellt Secret
        │
        ▼
kubeseal verschlüsselt
        │
        ▼
SealedSecret (verschlüsselt) → in Git committed
        │
        ▼
Sealed Secrets Controller im Cluster entschlüsselt
        │
        ▼
Kubernetes Secret (entschlüsselt) → im Cluster
```

### Option 2: HashiCorp Vault

**Was es macht:** Zentrales Secrets Management. Applikationen holen Secrets zur Laufzeit.

```
App startet
        │
        ▼
Vault Agent Injector erkennt Annotation
        │
        ▼
Secret wird als Volume Mount bereitgestellt
        │
        ▼
App liest Secret aus Datei
```

### Option 3: External Secrets Operator (ESO)

**Was es macht:** Synchronisiert Secrets von AWS Secrets Manager / GCP Secret Manager / Azure Key Vault nach Kubernetes.

```
External Secrets Operator
        │
        ├──► AWS Secrets Manager
        ├──► GCP Secret Manager  
        └──► Azure Key Vault
        │
        ▼
Kubernetes Secret (im Cluster)
```

## Unsere Empfehlung für POC

**Sealed Secrets** — weil:
- Einfach zu installieren
- Kein externer Service nötig
- GitOps-kompatibel
- Für die meisten Use Cases ausreichend

## Sealed Secrets Installation

```bash
# Controller installieren
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml

# kubeseal CLI installieren (für Developer)
curl -sL https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/kubeseal-linux-amd64.tar.gz | tar xz
sudo mv kubeseal /usr/local/bin/
```

## Secrets erstellen

###Workflow: Developer erstellt Secret

```bash
# 1. Normales Kubernetes Secret erstellen
kubectl create secret generic db-credentials \
  --from-literal=username=appuser \
  --from-literal=password=geheim \
  -n wasserbilanz \
  -o yaml --dry-run=client > secret.yaml

# 2. Mit kubeseal verschlüsseln
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml

# 3. sealed-secret.yaml in Git committen
git add sealed-secret.yaml
git commit -m "feat: add db-credentials for wasserbilanz"
git push
```

### Das verschlüsselte Secret

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-credentials
  namespace: wasserbilanz
spec:
  encryptedData:
    username: AgA2...  # verschlüsselt
    password: AgB3...  # verschlüsselt
```

**Das kann bedenkenlos in Git! Niemand kann es lesen ohne den Sealed Secrets Controller.**

## Application: Secret nutzen

### Variante A: Volume Mount (empfohlen)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: meine-app
  namespace: wasserbilanz
spec:
  template:
    spec:
      containers:
      - name: app
        image: meine-app:latest
        volumeMounts:
        - name: db-credentials
          mountPath: /secrets
          readOnly: true
      volumes:
      - name: db-credentials
        secret:
          secretName: db-credentials
```

### Variante B: Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: meine-app
  namespace: wasserbilanz
spec:
  template:
    spec:
      containers:
      - name: app
        image: meine-app:latest
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

**Empfehlung:** Volume Mounts sind sicherer (Env Vars können in Logs landen).

## Rotations-Strategie

### Secret Rotation (Neues Secret, alte Version ungültig)

```bash
# Neues Secret erstellen
kubectl create secret generic db-credentials \
  --from-literal=username=appuser \
  --from-literal=password=neues-geheim \
  -n wasserbilanz \
  -o yaml --dry-run=client | kubeseal --format=yaml > sealed-secret.yaml

# Git push → Sealed Secrets Controller updatet automatisch
git add sealed-secret.yaml
git commit -m "chore: rotate db-credentials"
git push
```

### Automatische Rotation mit Vault (Production)

Vault kann Secrets automatisch rotieren:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: wasserbilanz
spec:
  refreshInterval: 1h  # Automatisch alle Stunde updaten
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: db-credentials
  data:
  - secretKey: username
    remoteRef:
      key: database/wasserbilanz
      property: username
  - secretKey: password
    remoteRef:
      key: database/wasserbilanz
      property: password
```

## Troubleshooting

### SealedSecret wird nicht entschlüsselt

```bash
# Controller Logs prüfen
kubectl logs -n kube-system deployment/sealed-secrets-controller

# Status prüfen
kubectl get SealedSecret -n wasserbilanz
kubectl describe SealedSecret db-credentials -n wasserbilanz
```

### Falsches Zertifikat

```bash
# Certificate neu generieren (wenn Cluster neu erstellt wurde)
kubeseal --regenerate-certificates --cert public-key.pem
```

## Security Best Practices

| Praxis | Warum | Umsetzung |
|--------|-------|-----------|
| Keine Secrets in Env Vars | Können in Logs landen | Volume Mounts |
| Keine Secrets in Git (unverschlüsselt) | Jeder kann lesen | Sealed Secrets |
| Regelmäßige Rotation | Reduziert Impact bei Leak | Vault oder CronJob |
| Least Privilege | Nur Zugriff auf benötigte Secrets | RBAC |
| Audit Logs | Wissen wer auf was zugreift | Vault Audit Device |

---

## Compliance Referenzen

### BSI IT-Grundschutz CON.1

**M5: Secrets Management**
> "Secrets wie Passwörter, API-Keys, Zertifikate müssen sicher gespeichert und transportiert werden"

| BSI Anforderung | Umsetzung |
|-----------------|-----------|
| Verschlüsselung at Rest | Sealed Secrets (RSA encryption) |
| Zugriffskontrolle | RBAC + Sealed Secrets Controller |
| Transport | TLS für alle API-Kommunikation |

### DSGVO Art. 32

**Technische Maßnahmen:**
- Verschlüsselung personenbezogener Daten
- Pseudonymisierung (Secrets als UUIDs wo möglich)
- Zugangskontrolle (RBAC)

### ISO 27001

**A.9.4 (Privileged Access Rights):**
- A.9.4.1: Information access restrictions
- A.9.4.2: Secure log-on procedures
- A.9.4.3: Password management system

Vault/Sealed Secrets implementiert diese Anforderungen.

### NIS2 Art. 21

> "Maßnahmen für den Schutz... gegen Diebstahl... von Daten"

Secrets Management verhindert Diebstahl von Credentials.

---

*Erstellt: 2026-04-21*
