# Health Checks — Was ist das?

## Überblick

Health Checks sind Mechanismen um sicherzustellen dass:
1. Eine Anwendung **läuft** (Liveness)
2. Eine Anwendung **bereit ist, Traffic anzunehmen** (Readiness)
3. Ein Cluster-Service **erreichbar und funktionsfähig** ist (Health)

## Die 3 Typen in Kubernetes

### 1. Liveness Probe
**Frage: Ist die App noch am Leben und soll neu gestartet werden?**

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 80
  initialDelaySeconds: 3
  periodSeconds: 10
```
- Wenn der Check fehlschlägt → Kubernetes startet den Pod neu
- Für statische Apps: selten nötig

### 2. Readiness Probe
**Frage: Kann die App schon Traffic annehmen?**

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```
- Wenn der Check fehlschlägt → Kubernetes nimmt Pod aus Service-Endpunkten raus
- App kann sich warmlaufen bevor sie Traffic kriegt
- **Am wichtigsten für Web-Apps**

### 3. Startup Probe
**Für langsam startende Apps (z.B. Java/Spring)**

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 80
  failureThreshold: 30
  periodSeconds: 10
```
- Gibt App Zeit zum Starten bevor Liveness/Readiness greifen

## Health Checks in Flux

Flux kann die Health von Managed Resources überwachen:

| Flux Feature | Was es tut |
|-------------|-----------|
| `spec.healthChecks` | Definiert Health Check für eine Kustomization |
| `status.conditions` | Zeigt READY=True/False |
| Flux Notifications | Alerting bei Changes |

```yaml
# Beispiel: Flux Kustomization mit Health Check
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: nginx
spec:
  healthChecks:
    - kind: Deployment
      apiVersion: apps/v1
      name: nginx
      namespace: default
```

## Warum Health Checks?

### Ohne Health Checks:
- Pod läuft, ist aber kaputt → User bekommen 500er
- Du merkst es nicht → SLA gebrochen
- Kein automatisiertes Feedback

### Mit Health Checks:
- Kubernetes meldet Problems früh
- Flux weiß ob alles "gesund" ist
- Notification-Controller kann Alerts schicken
- Du kannst Automation bauen ("wenn X nicht gesund → fix")

## Health Check für nginx

nginx hat zwei Endpoints:

| Endpoint | Gibt | Bedeutung |
|----------|------|----------|
| `/healthz` | 200 OK | nginx selbst läuft |
| `/status/ngx_http_check_status` | status page | aktive connections |

Wir nutzen `/healthz` für Liveness + Readiness:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 3
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Flux Health Checks aktivieren

In Flux kannst du für jede Kustomization definieren worauf gewartet werden soll:

```bash
# Kustomization mit Health Checks
flux create kustomization nginx \
  --source=rook-lab \
  --path="./apps/nginx" \
  --health-check=true \
  --prune=true \
  --interval=1m
```

Oder direkt im YAML:

```yaml
spec:
  healthChecks:
    - kind: Deployment
      name: nginx
```

## Flux Status lesen

```bash
# Kustomization Health Status
flux get kustomizations

# Detaillierte Infos
kubectl get kustomization rook-lab -o yaml

# Events bei Problemen
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

## Health Checks für die nginx App

Die nginx Deployment bekommt Liveness + Readiness Probes.
Flux Kustomization bekommt einen healthCheck der auf das Deployment zeigt.

## Nächste Schritte

1. [x] Health Check Dokumentation (dieser Artikel)
2. [ ] nginx Deployment mit Probes updaten
3. [ ] Flux Kustomization mit healthChecks versehen
4. [ ] Verification dass Flux "READY=True" zeigt
5. [ ] Notification Controller für Alerts

---

## Compliance Referenzen

### NIS2 Art. 21 — Verfügbarkeit

NIS2 fordert Maßnahmen zur **Sicherstellung der Verfügbarkeit**:
- Resilience gegen Ausfälle (Readiness Probes)
- Automatische Wiederherstellung (Liveness Probes)
- Monitoring der Service-Verfügbarkeit

**Health Checks als NIS2 Maßnahme:**
| NIS2 Anforderung | Umsetzung |
|------------------|-----------|
| Verfügbarkeit | Readiness Probe → Traffic nur an gesunde Pods |
| Resilience | Liveness Probe → Restart bei Hänger |
| Monitoring | Flux health checks → Cluster-Zustand sichtbar |

### BSI IT-Grundschutz CON.1

**M6: Verfügbarkeit von Containern**
- Ressourcen-Limits gegen Memory/CPU Exhaustion
- Readiness/Liveness Probes für Hochverfügbarkeit
- Health Endpoints für Load Balancer

### ISO 27001 A.12.3

**Schutz vor Ausfall von Informationssystemen:**
- A.12.3.1: Informations-Backup
- A.12.3.2: Redundanz von Systemen (Kubernetes HPA)

Health Checks sind Voraussetzung für:
- Horizontal Pod Autoscaler (HPA) funktioniert nur mit Readiness
- Load Balancer leiten Traffic nur an gesunde Pods

---

*Quelle: kubernetes.io/docs, fluxcd.io/docs*
*Erstellt: 2026-04-21*
