# Backup & Disaster Recovery

## Überblick

Dieses Dokument beschreibt das Backup- und Wiederherstellungskonzept für die IDP-Plattform.

## Was muss gesichert werden?

| Komponente | Daten | Priorität | Backup-Frequenz |
|------------|-------|-----------|-----------------|
| **Kubernetes Config** | Git Repo | 🔴 Kritisch | Continuous (Git) |
| **Flux State** | Kustomizations, Sources | 🔴 Kritisch | Continuous (Git) |
| **OPA Policies** | Git Repo | 🔴 Kritisch | Continuous (Git) |
| **RBAC** | Roles, Bindings (Git) | 🔴 Kritisch | Continuous (Git) |
| **ArgoCD** | Applications, Settings | 🟡 Hoch | Täglich |
| **midPoint** | Users, Roles, Orgs | 🔴 Kritisch | Wöchentlich |
| **Grafana** | Dashboards, Datasources | 🟡 Hoch | Wöchentlich |
| **Prometheus** | Metriken (kurzfristig) | 🟢 Mittel | Nicht nötig |
| **Keycloak** | Users, Realms | 🔴 Kritisch | Wöchentlich |
| **etcd** | Cluster State | 🔴 Kritisch | Continuous (Stacked etcd) |

## Backup Strategie

### Git als Primary Backup (Config as Code)

Da alle Konfigurationen in Git verwaltet werden (Flux GitOps), ist das Recovery einfach:

```
Neuer Cluster
    │
    ▼
Git Repo klonen
    │
    ▼
Flux bootstrap
    │
    ▼
Alle Namespaces, Deployments, Policies werden rekonstruiert
```

**Vorteil:**
- Kein Backup-Tool nötig für Konfigurationen
- Jede Änderung ist versioniert
- Rollback in Sekunden

### etcd Backup (Cluster State)

```bash
# Snapshot erstellen (auf jedem Control Plane Node)
ETCDCTL_API=3 etcdctl snapshot save snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Backup automatisieren (CronJob)
kubectl apply -f - << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 2 * * *"  # Täglich 02:00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: etcd-backup
            image: k8s.gcr.io/etcd:3.5.9
            command: ["/bin/sh"]
            args:
              - -c
              - |
                ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
                  --endpoints=https://127.0.0.1:2379 \
                  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                  --cert=/etc/kubernetes/pki/etcd/server.crt \
                  --key=/etc/kubernetes/pki/etcd/server.key
                # Alternativ: Zu S3/Blob Storage uploaden
            volumeMounts:
              - name: etcd-certs
                mountPath: /etc/kubernetes/pki/etcd
                readOnly: true
              - name: backup
                mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
          - name: backup
            hostPath:
              path: /var/backups/etcd
      hostNetwork: true
      serviceAccountName: etcd-backup
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
EOF
```

### midPoint Backup

```bash
# midPoint hat eingebaute Export-Funktion
kubectl exec -n midpoint deployment/midpoint -- \
  /opt/midpoint/bin/midpoint.sh backup \
  --url http://localhost:8080/midpoint \
  --user administrator \
  --passwordfile /tmp/pwd.txt \
  --file /backups/midpoint-backup.xml

# CronJob für wöchentliches Backup
kubectl apply -f - << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: midpoint-backup
  namespace: midpoint
spec:
  schedule: "0 3 * * 0"  # Sonntags 03:00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: curlimages/curl:latest
            command: ["/bin/sh", "-c"]
            args:
              - |
                # Export via REST API
                curl -u administrator:$MP_PASSWORD \
                  http://midpoint:8080/midpoint/ws/rest/v3/backup \
                  -o /backups/midpoint-$(date +%Y%m%d).xml
            env:
              - name: MP_PASSWORD
                valueFrom:
                  secretKeyRef:
                    name: midpoint-admin
                    key: password
          restartPolicy: OnFailure
EOF
```

### Keycloak Backup

```bash
# Keycloak Export (Keycloak muss laufen)
kubectl exec -n keycloak keycloak-0 -- \
  /opt/keycloak/binkcadm.sh \
  config credentials \
  --server http://localhost:8080/auth \
  --realm master \
  --user admin \
  --password admin

# Realm exportieren
kubectl exec -n keycloak keycloak-0 -- \
  /opt/keycloak/binkcadm.sh \
  export \
  --realm master \
  --file /tmp/backup.json

# Backup aus Pod kopieren
kubectl cp keycloak/keycloak-0:/tmp/backup.json ./backups/keycloak-$(date +%Y%m%d).json
```

### Grafana Backup

```bash
# Grafana Dashboard Export
curl -s -H "Accept: application/json" \
  -u admin:$GF_PASSWORD \
  http://grafana:3000/api/dashboards \
  | jq '.' > grafana-dashboards.json

# Datasource Export
curl -s -H "Accept: application/json" \
  -u admin:$GF_PASSWORD \
  http://grafana:3000/api/datasources \
  | jq '.' > grafana-datasources.json
```

## Disaster Recovery Szenarien

### Szenario 1: Kompletter Cluster-Ausfall

```
VM/Cluster ist nicht mehr verfügbar
        │
        ▼
1. Neuen Cluster erstellen (kind create cluster)
        │
        ▼
2. Flux bootstrap
   curl -s https://fluxcd.io/install.sh | sh
   flux bootstrap github \
     --owner=$GITHUB_USER \
     --repository=rook-k8s-lab \
     --path=./infra/flux
        │
        ▼
3. GitOps stellt alles wieder her (ca. 5-10 min)
        │
        ▼
4. Cluster ist wieder Online ✅
```

### Szenario 2: Fehlerhafte Konfiguration (Human Error)

```
Fehlerhafte Änderung wurde gepusht
        │
        ▼
1. Git History prüfen
   git log --oneline
   git show <bad-commit>
        │
        ▼
2. Revert der Änderung
   git revert <bad-commit>
   git push
        │
        ▼
3. Flux reconciled automatisch (ca. 1 min)
        │
        ▼
4. Korrekte Konfiguration wiederhergestellt ✅
```

### Szenario 3: Ransomware/Angriff

```
Angriff erkannt (Alert von Prometheus/Trivy)
        │
        ▼
1. NIST Incident Response starten
   - Isolate betroffene Namespaces
   - Netzwerk-Policies verschärfen
        │
        ▼
2. forensics Analyse
   - Logs auswerten (kubectl logs, Fluentd)
   - Git History prüfen (wurde Code manipuliert?)
        │
        ▼
3. Recovery
   kubectl delete namespace <betroffener-ns>
   git revert <angreifer-commit>
   git push
        │
        ▼
4. Alle Namespaces neu synchronized
        │
        ▼
5. Post-Incident Review
```

## RTO/RPO Ziele

| System | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
|--------|------------------------------|------------------------------|
| Kubernetes Config | < 15 min | 0 (Git hat alles) |
| Flux State | < 15 min | 0 |
| OPA Policies | < 15 min | 0 |
| RBAC | < 15 min | 0 |
| midPoint | < 4 Stunden | 1 Woche |
| Keycloak | < 4 Stunden | 1 Woche |
| ArgoCD | < 1 Stunde | 1 Tag |
| Grafana | < 1 Stunde | 1 Woche |

## Backup Storage

Backups sollten NICHT auf dem gleichen System gespeichert werden:

```
Lokaler Cluster    →    Externe Storage
     │                      │
     ├── etcd Snapshots  →  S3/MinIO/Blob Storage
     ├── midPoint XML    →  S3/MinIO/Blob Storage
     └── Grafana JSON    →  S3/MinIO/Blob Storage
```

### S3 Backup Beispiel

```bash
# AWS S3 oder MinIO als Backup Target
aws s3 cp /backup/etcd-snapshot.db s3://my-backups/etcd/

# Oder mit rclone (für beliebige Storage-Backends)
rclone copy /backup/etcd-snapshot.db remote:backups/etcd/
```

---

## Compliance Referenzen

### BSI IT-Grundschutz

**CON.3 (Datensicherung):**
- M1: Datensicherungen müssen regelmäßig durchgeführt werden
- M2: Datensicherungen müssen an einem anderen Ort aufbewahrt werden
- M3: Wiederherstellung muss regelmäßig getestet werden
- M4: Datensicherungen müssen verschlüsselt aufbewahrt werden

** Umsetzung:**
| Anforderung | Umsetzung |
|-------------|-----------|
| Regelmäßige Backups | CronJobs für etcd, midPoint, Keycloak |
| Anderer Ort | S3/MinIO Storage (extern vom Cluster) |
| Wiederherstellung testen | DR Tests quartalsweise |
| Verschlüsselung | TLS für Transport, ggf. AES-256 at Rest |

### ISO 27001

**A.12.3 (Informationssicherungs-Backup):**
- A.12.3.1: Informations-Backup werden gemäß der festgelegten Backup-Policy erstellt
- A.12.3.2: Wiederherstellung wird regelmäßig getestet

### NIS2 Art. 21

> "Maßnahmen zur Beherrschung von Risiken... einschließlich... Backup-Politik"

NIS2 fordert explizit Business Continuity Management.

### DSGVO Art. 32

> "Ein Verfahren zur regelmäßigen Überprüfung, Bewertung und Evaluierung der Wirksamkeit..."

Backups sind Teil der technischen Maßnahmen nach DSGVO.

---

*Erstellt: 2026-04-21*
