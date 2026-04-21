# midPoint — Identity Governance & Administration (IGA)

## Was es macht

midPoint ist ein **Identity Governance and Administration (IGA)** Tool. Es verwaltet:
- **Benutzer-Lebenszyklus** (Joiner/Mover/Leaver)
- **Role Mining** (welche Rollen braucht wer?)
- **Access Reviews** (wer hat wann welche Rechte?)
- **Compliance Reports** (Audit-Trails für NIS2, BSI, DSGVO)
- **Policy Enforcement** (z.B. Passwort-Policy, Abteilungs-Zuordnung)

## Installation

```bash
kubectl create namespace midpoint
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: midpoint
  namespace: midpoint
spec:
  replicas: 1
  selector:
    matchLabels:
      app: midpoint
  template:
    metadata:
      labels:
        app: midpoint
    spec:
      containers:
      - name: midpoint
        image: docker.io/evolveum/midpoint:4.8
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
---
apiVersion: v1
kind: Service
metadata:
  name: midpoint
  namespace: midpoint
spec:
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  selector:
    app: midpoint
EOF
```

**Warten bis ready (~3 min):**
```bash
kubectl wait --namespace midpoint --for=condition=ready pod --selector=app=midpoint --timeout=300s
```

## Zugriff

### Port-Forward

```bash
kubectl port-forward -n midpoint svc/midpoint 9090:8080
```

### Login

- **URL**: http://localhost:9090/midpoint
- **Username**: `administrator`
- **Password**: `5ecr3t` (Default — IN PRODUKTION ÄNDERN!)

Nach erstem Login sollte das Passwort geändert werden.

## midPoint Konzepte

### Objects

| Object | Beschreibung |
|--------|--------------|
| **User** | Personen (Mitarbeiter, Contractor) |
| **Role** | Definiert eine Berechtigung (z.B. "Kubernetes-Developer") |
| **Org** | Organisationseinheiten (Abteilungen, Teams) |
| **Service** | Technische Ressourcen (Kubernetes Cluster, AWS Accounts) |
| **Archetype** | Vorlagen für Object-Typen |

### Workflow-Typen

| Workflow | Beschreibung |
|----------|--------------|
| **Approval** | Anfrage → Genehmigung → Provisioning |
| **Joiner** | Neuer Mitarbeiter → Account wird erstellt |
| **Mover** | Abteilungswechsel → Rechte werden angepasst |
| **Leaver** | Austritt → Alle Accounts werden deaktiviert |

## Workflows für IDP

### 1. Role Mining (Automatische Rollen-Erkennung)

```
Developer Team kommt neu
        │
        ▼
Kubernetes Namespaces werden erstellt
        │
        ▼
midPoint erkennt neue Ressourcen
        │
        ▼
Role wird vorgeschlagen basierend auf:
  - Bestehende Teams mit ähnlichen Ressourcen
  - Abteilungs-Zugehörigkeit
        │
        ▼
Platform Team reviewt und approved Rolle
        │
        ▼
Rolle wird freigegeben
```

### 2. Access Request (Developer)

```
Developer braucht Zugriff auf neuen Namespace
        │
        ▼
Developer geht zu midPoint Self-Service
        │
        ▼
Stellt Access Request:
  - Ressource: "agripower-prod Namespace"
  - Begründung: "Migration Projekt"
        │
        ▼
midPoint prüft Policy:
  - Ist Namespace erlaubt für diese Abteilung?
  - Hat Developer schon ähnliche Rechte?
  - Ist eine Genehmigung nötig?
        │
        Ja → Request geht an Platform Team
        Nein → Request wird abgelehnt
        │
        ▼
Platform Team approved
        │
        ▼
Kubernetes RoleBinding wird erstellt
```

### 3. Compliance Report (für Audit)

```
BSI / NIS2 Auditor braucht Report
        │
        ▼
midPoint generiert:
  - Wer hat Zugang zu welchen Namespaces?
  - Wann wurde der letzte Access Review durchgeführt?
  - Welche Genehmigungen sind offen?
        │
        ▼
Report wird exportiert (PDF/CSV)
        │
        ▼
Auditor prüft → Findings werden dokumentiert
```

## Integration mit Kubernetes

### Service Account erstellen

midPoint braucht einen Kubernetes Service Account um RBAC zu managen:

```bash
# Service Account für midPoint
kubectl create serviceaccount midpoint-k8s -n midpoint

# ClusterRole für midPoint
kubectl create clusterrole midpoint-manager \
  --verb=get,list,watch,create,update,delete \
  --resource=namespaces,rolebindings,clusterrolebindings,serviceaccounts

# ClusterRoleBinding
kubectl create clusterrolebinding midpoint-k8s-binding \
  --clusterrole=midpoint-manager \
  --serviceaccount=midpoint:midpoint-k8s
```

### Token holen

```bash
SECRET=$(kubectl get serviceaccount midpoint-k8s -n midpoint -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret $SECRET -n midpoint -o jsonpath='{.data.token}' | base64 -d)
kubectl config set-credentials midpoint --token=$TOKEN
```

## RBAC Workflows mit Keycloak

### User Federation (Keycloak → midPoint)

1. **Keycloak**: User werden erstellt (HR-System)
2. **midPoint**: Erkennt neue User via Keycloak OIDC
3. **Provisioning**: User bekommt Default-Rolle

### Role Assignment

```
User kommt neu (via Keycloak)
        │
        ▼
midPoint erkennt Abteilung (aus Keycloak Attribut)
        │
        ▼
System-Object "Kubernetes Cluster" wird gelesen
        │
        ▼
Automatische Role Assignment:
  - Developer → app-developer Role
  - Admin → platform-admin Role
        │
        ▼
Kubernetes RoleBinding wird erstellt
```

## Dashboards

midPoint hat eingebaute Dashboards für:

| Dashboard | Zeigt |
|-----------|-------|
| **Users** | Alle User, Status, Letzter Login |
| **Roles** | Rollen-Übersicht, Verwendung |
| **Access Requests** | Offene Requests, History |
| **Compliance** | Reports, Audits |
| **Orgs** | Organisationstruktur |

## Troubleshooting

### Login funktioniert nicht
```bash
# Logs checken
kubectl logs -n midpoint deployment/midpoint -f

# Default Credentials
# Username: administrator
# Password: 5ecr3t
```

### Performance Probleme
```bash
# midPoint braucht mindestens 2GB RAM
kubectl top pods -n midpoint
```

### Datenbank (H2)
Diese Installation nutzt embedded H2 — nur für DEV/POC!
Für Production: PostgreSQL konfigurieren.

## Security Considerations

⚠️ **Wichtig für Production:**

1. **Passwort ändern** nach erstem Login
2. **TLS** konfigurieren (cert-manager)
3. **PostgreSQL** statt H2
4. **Backup** konfigurieren
5. **Network Policies** setzen

## Nächste Schritte

1. [x] midPoint installiert (4.8)
2. [x] Login möglich
3. [ ] Kubernetes Service Account + RBAC
4. [ ] Keycloak Integration
5. [ ] Role Mining Workflow
6. [ ] Compliance Reports
7. [ ] Production: PostgreSQL + TLS

---

*Erstellt: 2026-04-21*

---

## Compliance Referenzen

### NIS2 Art. 20 + 21 — Identity Governance

NIS2 fordert:
> "Maßnahmen für das Management... von Identitäten und Zugriffsrechten"

| NIS2 Anforderung | midPoint Feature |
|-----------------|------------------|
| Benutzer-Lebenszyklus | Joiner/Mover/Leaver Workflows |
| Zugriffskontrolle | Role-Based Access Control |
| Access Reviews | Periodic Certification Campaigns |
| Audit Trail | Compliance Reports für Auditoren |

### BSI CON.2 — Identity und Access Management

**M3: Verwaltung von Identitäten und Berechtigungen**

midPoint implementiert:
- Zentrales User Management
- Role Mining (automatische Rollen-Erkennung)
- Compliance Reports
- Access Certification

**M4: Berechtigungsnachweise**

> "Regelmäßige Überprüfung der Berechtigungen"

midPoint Campaigns prüfen:
- Wer hat Zugriff auf welche Systeme?
- Ist der Zugriff noch justified?
- Sind die Genehmigungen dokumentiert?

### ISO 27001 A.9.2 + A.9.3

- A.9.2.1: User registration and de-registration
- A.9.2.2: User access provisioning
- A.9.3.1: Use of privileged access rights
- A.9.3.3: Management of sensitive information

### DSGVO Art. 30 — Records of Processing Activities

midPoint kann als Basis für Art. 30 Records dienen:
- Wer hat Zugriff auf welches System?
- Welche Rollen existieren?
- Wann wurde der letzte Access Review durchgeführt?

---

*Erstellt: 2026-04-21*
