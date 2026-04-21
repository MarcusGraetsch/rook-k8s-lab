# IDP Plattform — Leitplanken

> Was darf man, was darf man nicht, und warum.

---

## Warum Leitplanken?

Eine IDP soll Developer nicht einschränken — sie soll ihnen **schnell arbeiten ermöglichen**, während das Platform Team **Sicherheit und Compliance** gewährleistet.

Leitplanken sind die **Regeln die das ermöglichen**:

```
┌─────────────────────────────────────────────────────────────┐
│                      Developer (Self-Service)                 │
│                                                               │
│   ✅ Darf ich in meinem Namespace deployen?                   │
│   ✅ Darf ich Services erstellen?                             │
│   ✅ Darf ich ConfigMaps ändern?                             │
│                                                               │
│   ❌ Darf ich in andere Namespaces? Nein                      │
│   ❌ Darf ich privileged Container? Nein                      │
│   ❌ Darf ich Secrets lesen? Nein                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      OPA Gatekeeper                          │
│                      (Automatically enforced)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Die Leitplanken

### 1. Namespace Isolation

**Regel:** Jeder Team/Developer hat nur Zugriff auf seinen eigenen Namespace.

```
Wasserbilanz Team   → Namespace: wasserbilanz     ✅
Abwasser Team       → Namespace: abwasser         ✅
Agripower (Kunde)   → Namespace: agripower        ✅
Stadtwerke HH       → Namespace: stadtwerke-hh    ✅

Wasserbilanz Team   → Namespace: stadtwerke-hh    ❌ BLOCKIERT
```

**Warum?**
- Datenschutz (Kundendaten dürfen nicht gemischt werden)
- NIS2: Separation of Duties
- DSGVO: Vertraulichkeit

---

### 2. Container Registry Whitelist

**Regel:** Nur Images aus erlaubten Registries dürfen deployed werden.

```
✅ Erlaubt:
   - docker.io/<image>       (Docker Hub, offizielle Images)
   - quay.io/<image>         (Red Hat Registry)
   - registry.k8s.io/<image> (Kubernetes Official)
   - kindest.io/<image>      (kind cluster images)

❌ Verboten:
   - gcr.io/<image>          (Google Container Registry)
   - ghcr.io/<image>         (GitHub Container Registry — nur mit Review)
   - <unbekannte-registry>   (alles andere)
```

**Warum?**
- Vertrauenswürdige Quellen nur
- NIS2: Supply Chain Security
- Avoid Malicious Images

---

### 3. Keine privilegierten Container

**Regel:** Container dürfen nicht als Root laufen oder privilegierte Rechte haben.

```yaml
# VERBOTEN ❌
securityContext:
  privileged: true

# ERLAUBEN ✅
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
```

**Warum?**
- Privilegierte Container können Host-System kompromittieren
- BSI CON.1 M2: Container Härtung
- NIS2: Security by Design

---

### 4. Resource Limits erforderlich

**Regel:** Jeder Container muss CPU und Memory Limits haben.

```yaml
# VERBOTEN ❌
resources: {}

# ERLAUBEN ✅
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

**Warum?**
- Verhindert "Noisy Neighbor" (ein Container frisst alle Ressourcen)
- DoS Protection
- BSI CON.1 M3: Resource Limits

---

### 5. Health Checks

**Regel:** Jeder Service braucht Liveness und Readiness Probes.

```yaml
# ERLAUBEN ✅
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Warum?**
- Kubernetes kann nur gesunde Pods bedienen
- Zero-Downtime Deployments
- BSI CON.1 M6: Verfügbarkeit

---

### 6. Keine Secrets in Environment Variables

**Regel:** Credentials gehören in Kubernetes Secrets, nicht in Env Vars.

```yaml
# VERBOTEN ❌
env:
  - name: DATABASE_PASSWORD
    value: "mein-kennwort"

# ERLAUBEN ✅
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: password
```

**Warum?**
- Env Vars sind in Logs sichtbar
- DSGVO: Keine Credentials in Klartext
- Secrets über Volume Mounts sicherer

---

### 7. Keine HostPorts oder HostNetwork

**Regel:** Container dürfen nicht direkt auf Host-Ports zugreifen.

```yaml
# VERBOTEN ❌
ports:
  - containerPort: 8080
    hostPort: 8080    # Nein!

# ERLAUBEN ✅
Service:
  type: ClusterIP    # Oder LoadBalancer
```

**Warum?**
- Port-Konflikte vermeiden
- Network Isolation
- NIS2: Netzwerksicherheit

---

### 8. Network Policies

**Regel:** Namespaces brauchen Network Policies (Standard: deny all).

```yaml
# infra/namespaces/<ns>/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: wasserbilanz
spec:
  podSelector: {}  # Alle Pods
  policyTypes:
    - Ingress
    - Egress
```

**Warum?**
- Lateral Movement verhindern
- Wenn ein Pod kompromittiert wird, kann er nicht andere erreichen
- BSI CON.1 M5: Network Policies

---

## Zusammenfassung: Erlaubt vs. Verboten

| Aktion | Developer | Customer | Platform Admin |
|--------|-----------|----------|----------------|
| Deploy in eigenen Namespace | ✅ | ✅ | ✅ |
| Secrets lesen | ❌ | ❌ | ✅ |
| In andere Namespaces | ❌ | ❌ | ✅ |
| Cluster-Admin nutzen | ❌ | ❌ | ✅ |
| privileged Container | ❌ | ❌ | ❌ (nur mit Review) |
| Externe Registry nutzen | ❌ | ❌ | ❌ |
| Resource Limits weglassen | ❌ | ❌ | ❌ |
| Ohne Health Check deployen | ❌ | ❌ | ❌ |

---

## Ausnahmen (mit Review)

Manchmal gibt es gute Gründe für Ausnahmen:

| Exception | Wann erlaubt | Wer entscheidet |
|-----------|--------------|-----------------|
| privileged Container | Monitoring/Logging Tools | Platform Team |
| External Registry | Bestimmte Enterprise Tools | Security Team |
| HostNetwork | CNI Plugins | Architecture Team |
| exec in Container | Debugging (zeitlich begrenzt) | Platform Team |

**Prozess für Ausnahmen:**
1. Developer stellt Anfrage (GitHub Issue)
2. Platform Team bewertet Risk
3. Temporäre Genehmigung (TTL)
4. Review nach 30 Tagen

---

## Was passiert bei Verstößen?

```
 Verstoss gegen Leitplanke
        │
        ▼
OPA Gatekeeper BLOCKIERT Deployment
        │
        ▼
Developer bekommt Fehlermeldung:
"Deployment rejected: no-privileged-container"
        │
        ▼
Developer korrigiert Manifest
        │
        ▼
Retry → Erfolg ✅
```

**Kein Deployment ohne Genehmigung möglich.**

---

## Wie werden Leitplanken durchgesetzt?

| Leitplanke | Tool | Automatisch? |
|------------|------|--------------|
| Namespace Isolation | RBAC + OPA | ✅ Ja |
| Registry Whitelist | OPA Gatekeeper | ✅ Ja |
| Keine privileged Container | OPA Gatekeeper | ✅ Ja |
| Resource Limits | Polaris (Warning) | ⚠️ Warning |
| Health Checks | Polaris (Warning) | ⚠️ Warning |
| Keine Secrets in Env | OPA Gatekeeper | ✅ Ja |
| Network Policies | CNI | ⚠️ Manuell |

---

## Leitplanken ändern

Leitplanken sind **Git--managed**:

```bash
# Änderungsvorschlag
git checkout -b feature/new-registry-allow
# Änderung in infra/gatekeeper/constraints/
git commit -m "docs: Add trusted registry for enterprise-tools"
git push

# Pull Request → Review durch Platform Team
# Merge → Flux synced neue Policy
```

**Warum Git?**
- Jede Änderung ist dokumentiert
- Review durch Platform Team
- Audit Trail für Compliance

---

## Compliance Mapping

| Leitplanke | NIS2 | BSI CON.1 | DSGVO |
|------------|------|-----------|-------|
| Namespace Isolation | Art. 21 | M1 | Art. 32 |
| Registry Whitelist | Art. 21 | M4 | — |
| No privileged | Art. 21 | M2 | — |
| Resource Limits | Art. 21 | M3 | — |
| Health Checks | Art. 21 | M6 | — |
| Secrets in Env | — | M5 | Art. 32 |
| Network Policies | Art. 21 | M5 | — |

---

*Dokument erstellt: 2026-04-21*
*Reviewzyklus: Quartalsweise durch Platform Team*

---

## Compliance Referenzen (Detailliert)

### NIS2 (EU Directive 2022/2555)

NIS2 Art. 21 fordert Security Measures für Betreiber wesentlicher Dienste:

| NIS2 Anforderung | Leitplanke | Tool |
|------------------|-----------|------|
| Zugangskontrolle | Namespace Isolation | RBAC + OPA |
| Supply Chain Security | Registry Whitelist | OPA |
| Container Security | No privileged | OPA |
| Netzwerksicherheit | Network Policies | CNI |
| Vulnerability Management | CVE Scanning | Trivy |

### BSI IT-Grundschutz CON.1

| BSI Maßnahme | Unsere Leitplanke |
|--------------|------------------|
| M1 (Minimal Images) | Registry Whitelist |
| M2 (Privileged) | No privileged Container |
| M3 (Resource Limits) | Resource Limits Required |
| M4 (Patches) | CVE Scanning + Workflow |
| M5 (Secrets) | Secrets via SOPS |
| M6 (Verfügbarkeit) | Health Checks |

### ISO/IEC 27001

- A.9.1.1: Access control policy
- A.9.2.1: User registration
- A.9.4.1: Information access restriction
- A.12.6.1: Management of technical vulnerabilities

### DSGVO Art. 32

Technische Maßnahmen für personenbezogene Daten:
- Zugangskontrolle (RBAC)
- Vertraulichkeit (Secrets via SOPS)
- Integrität (GitOps Immutable)
