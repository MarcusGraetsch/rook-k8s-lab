# Secrets Management mit SOPS

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

## Unsere Lösung: SOPS + Age

```
Developer erstellt Secret (Klartext)
        │
        ▼
SOPS verschlüsselt mit Age Key
        │
        ▼
Verschlüsseltes Secret → in Git committed
        │
        ▼
Flux erkennt Änderung
        │
        ▼
Decrypt im Cluster via SOPS
        │
        ▼
Kubernetes Secret (entschlüsselt) → im Cluster
```

## Tools

| Tool | Was es macht |
|------|--------------|
| **Age** | Moderne, einfache Verschlüsselung |
| **SOPS** | Secrets Operations — verschlüsselt YAML/JSON/ENV |

## Installation

```bash
# Age installieren
curl -sL https://github.com/FiloSottile/age/releases/download/v1.3.1/age-v1.3.1-linux-amd64.tar.gz | tar -xz -C /tmp
sudo mv /tmp/age /tmp/age-keygen /usr/local/bin/

# SOPS installieren
curl -sL -o /tmp/sops https://github.com/getsops/sops/releases/download/v3.12.2/sops-v3.12.2.linux.amd64
sudo mv /tmp/sops /usr/local/bin/
```

## Schlüssel generieren

```bash
# Age Key Pair generieren
age-keygen -o infra/secrets/age-key.txt

# Public Key merken (für .sops.yaml)
cat infra/secrets/age-key.txt
# age1zvvmhtmlsltgz6ml7kdlfu8ttkvew8yd4l6dcxyflzq306mvnensh742ut
```

**WICHTIG:** Den Private Key (`age1...`) sicher speichern — NIEMALS in Git committen!

## SOPS Konfiguration (.sops.yaml)

```yaml
# Im Repo Root: .sops.yaml
creation_rules:
  - path_regex: infra/secrets/.*
    encrypted_regex: "^(data|stringData)$"
    age: age1zvvmhtmlsltgz6ml7kdlfu8ttkvew8yd4l6dcxyflzq306mvnensh742ut
```

## Secret erstellen

### Schritt 1: Unverschlüsseltes Secret erstellen

```bash
mkdir -p infra/secrets
cat > infra/secrets/db-credentials.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: wasserbilanz
type: Opaque
stringData:
  username: appuser
  password: supergeheim123
EOF
```

### Schritt 2: Verschlüsseln

```bash
# Mit SOPS (nutzt .sops.yaml automatisch)
sops --encrypt infra/secrets/db-credentials.yaml > infra/secrets/db-credentials.enc.yaml

# Oder explizit mit Age Key
export SOPS_AGE_KEY=$(cat infra/secrets/age-key.txt | grep "AGE-SECRET-KEY")
sops --encrypt --age age1zvvmhtmlsltgz6ml7kdlfu8ttkvew8yd4l6dcxyflzq306mvnensh742ut \
  infra/secrets/db-credentials.yaml > infra/secrets/db-credentials.enc.yaml
```

### Schritt 3: In Git committen

```bash
# Unverschlüsselte Version löschen (nie committen!)
rm infra/secrets/db-credentials.yaml

# Nur verschlüsselte Version committen
git add infra/secrets/db-credentials.enc.yaml
git commit -m "feat: add encrypted db-credentials for wasserbilanz"
git push
```

## Verschlüsseltes Secret sieht so aus

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: db-credentials
    namespace: wasserbilanz
type: Opaque
stringData:
    username: ENC[AES256_GCM,data:XnnCsqqO7A==,iv:...,type:str]
    password: ENC[AES256_GCM,data:pwNyxKufYY8...,iv:...,type:str]
sops:
    age:
        - recipient: age1zvvmhtmlsltgz6ml7kdlfu8ttkvew8yd4l6dcxyflzq306mvnensh742ut
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
            -----END AGE ENCRYPTED FILE-----
    lastmodified: "2026-04-21T14:47:03Z"
    encrypted_regex: "^(data|stringData)$"
    version: 3.12.2
```

**Das kann bedenkenlos in Git! Niemand kann es lesen ohne den Age Private Key.**

## Secret decrypten (zum Lesen)

```bash
export SOPS_AGE_KEY=$(cat infra/secrets/age-key.txt | grep "AGE-SECRET-KEY")
sops --decrypt infra/secrets/db-credentials.enc.yaml
```

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

## Flux + SOPS Integration

### Flux SOPS Provider (später)

Flux kann SOPS-verschlüsselte Secrets direkt in den Cluster bringen:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: wasserbilanz
  annotations:
    fluxcd.io/ignore: "false"
```

### Aktuell: Decrypt im CI/CD

```bash
# In GitHub Actions:
export SOPS_AGE_KEY=${{ secrets.SOPS_AGE_KEY }}
sops --decrypt infra/secrets/db-credentials.enc.yaml | kubectl apply -f -
```

## Key Rotation

### Neuen Key generieren

```bash
age-keygen -o infra/secrets/age-key-new.txt
```

### Alte Secrets neu verschlüsseln

```bash
export SOPS_AGE_KEY=$(cat infra/secrets/age-key-old.txt | grep "AGE-SECRET-KEY")
sops --encrypt --age $(cat infra/secrets/age-key-new.txt | grep "^Public" | awk '{print $3}') \
  infra/secrets/db-credentials.enc.yaml > infra/secrets/db-credentials-new.enc.yaml
```

## Security Best Practices

| Praxis | Warum | Umsetzung |
|--------|-------|-----------|
| Keine Secrets in Env Vars | Können in Logs landen | Volume Mounts |
| Private Key NIEMALS in Git | Jeder kann entschlüsseln | .gitignore + sichere Verwahrung |
| Regelmäßige Rotation | Reduziert Impact bei Leak | Age Key jährlich rotieren |
| Separate Keys pro Umgebung | PROD ≠ STAGING | Ein Key pro Cluster |
| Audit Logs | Wissen wer auf was zugreift | Git History + kubectl events |

## Files die NIEMALS in Git dürfen

```bash
# .gitignore
infra/secrets/age-key.txt          # Private Key
infra/secrets/*.yaml              # Unverschlüsselte Secrets
*.decrypted                       # Temp Files
```

---

## Compliance Referenzen

### BSI IT-Grundschutz CON.1

**M5: Secrets Management**
> "Secrets wie Passwörter, API-Keys, Zertifikate müssen sicher gespeichert und transportiert werden"

| BSI Anforderung | Umsetzung |
|-----------------|-----------|
| Verschlüsselung at Rest | SOPS + Age (AES-256-GCM) |
| Zugriffskontrolle | Private Key nur auf sicheren Systemen |
| Transport | TLS für alle API-Kommunikation |

### DSGVO Art. 32

**Technische Maßnahmen:**
- Verschlüsselung personenbezogener Daten
- Pseudonymisierung
- Zugangskontrolle (RBAC)

### ISO 27001

**A.9.4 (Privileged Access Rights):**
- A.9.4.1: Information access restrictions
- A.9.4.2: Secure log-on procedures
- A.9.4.3: Password management system

### NIS2 Art. 21

> "Maßnahmen für den Schutz... gegen Diebstahl... von Daten"

SOPS + Age verhindert Diebstahl von Credentials.

---

*Erstellt: 2026-04-21*
