# OPA Gatekeeper — Policy Enforcement

## Was ist OPA Gatekeeper?

OPA Gatekeeper ist ein **Admission Controller** für Kubernetes. Er prüft bei jedem Deployment ob die Manifeste gegen definierte Regeln verstoßen.

```
User deployt Manifest
         │
         ▼
Kubernetes API Server
         │
         ▼ Gatekeeper (ValidatingWebhook)
         │
    Regeln geprüft?
      │
  Ja │ Nein
  ▼   ▼
Allow │ Deny (mit Grund)
```

## Komponenten

Gatekeeper Policies bestehen aus:
1. **ConstraintTemplate** — Die Regellogik (Rego)
2. **Constraint** — Die konkrete Anwendung auf Cluster/Namespaces

## Installation (funktionierende Version)

**Wichtig:** Gatekeeper v3.15.0 hat einen Bug mit Kubernetes 1.27 (kind). Bei uns funktioniert v3.14.0.

### Schritt 1: Gatekeeper deployen

```bash
# Alte Version entfernen falls vorhanden
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.15.0/deploy/gatekeeper.yaml
kubectl delete ns gatekeeper-system --force --grace-period=0

# Gatekeeper 3.14.0 installieren
kubectl apply --server-side -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml

# Prüfen dass alle Pods laufen (dauert ~20 Sekunden)
kubectl get pods -n gatekeeper-system
```

Erwartete Ausgabe:
```
NAME                                             READY   STATUS    RESTARTS     AGE
gatekeeper-audit-659dd569bb-rp7xh                1/1     Running   0           20s
gatekeeper-controller-manager-6675d68c55-9vrq9     1/1     Running   0           20s
gatekeeper-controller-manager-6675d68c55-t2s7r     1/1     Running   0           20s
gatekeeper-controller-manager-6675d68c55-zh2h4   1/1     Running   0           20s
```

## ConstraintTemplate installieren (offizielle Library)

Statt eigene Rego-Templates zu schreiben, nutzen wir die offiziellen Templates vom gatekeeper-library Repository.

### Registry-Whitelist Template

```bash
# Offizielles Template installieren
curl -sL https://raw.githubusercontent.com/open-policy-agent/gatekeeper-library/master/library/general/allowedrepos/template.yaml | kubectl apply -f -
```

### Prüfen ob Template geladen ist

```bash
kubectl get constrainttemplates
```

Erwartete Ausgabe:
```
NAME              AGE
k8sallowedrepos   10s
```

## Constraint erstellen

### Schritt 2: Constraint YAML erstellen

```yaml
# infra/gatekeeper/constraints/allowed-repos.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-docker-repos
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - "wasserbilanz"
      - "abwasser"
      - "agripower"
      - "stadtwerke-hh"
  parameters:
    repos:
      - "docker.io/"
      - "quay.io/"
      - "kindest.io/"
      - "registry.k8s.io/"
      - "nginx"
```

### Schritt 3: Constraint anwenden

```bash
kubectl apply -f infra/gatekeeper/constraints/allowed-repos.yaml
```

### Prüfen

```bash
kubectl get constraints
```

## Policy testen

### Verbotene Registry blockieren

```bash
# gcr.io ist nicht erlaubt → sollte rejected werden
kubectl run test-disallowed --image=gcr.io/test/test:latest --dry-run=server
```

Erwartete Fehlermeldung:
```
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: 
[allowed-docker-repos] container <test-disallowed> has an invalid image repo <gcr.io/test/test:latest>, 
allowed repos are ["docker.io/", "quay.io/", ...]
```

### Erlaubte Registry durchlassen

```bash
# docker.io/nginx ist erlaubt → sollte funktionieren
kubectl run test-allowed --image=docker.io/nginx:alpine --dry-run=server
```

Erwartete Ausgabe:
```
pod/test-allowed created (server dry run)
```

## Troubleshooting

### Problem: ConstraintTemplate wird nicht erstellt

**Fehler:** `invalid ConstraintTemplate: invalid rego`

**Ursache:** Meistens ein Syntax-Fehler im Rego-Code oder inkompatible Gatekeeper-Version.

**Lösung:**
1. Gatekeeper Version prüfen: `kubectl get deployment -n gatekeeper-system -o jsonpath='{.items[*].spec.template.spec.containers[*].image}'`
2. Falls v3.15.0 → Downgrade auf v3.14.0 (siehe Installation oben)
3. Offizielle Templates aus gatekeeper-library nutzen statt eigene zu schreiben

### Problem: ConstraintTemplate erstellt, aber Constraint schlägt fehl

**Fehler:** `unable to compile modules`

**Ursache:** Das ConstraintTemplate hat einen internen OPA-Library-Bug.

**Lösung:** Andere Version verwenden oder offizielle Templates nutzen.

### Logs checken

```bash
# Controller Logs
kubectl logs -n gatekeeper-system deployment/gatekeeper-controller-manager -c manager

# Audit Logs  
kubectl logs -n gatekeeper-system deployment/gatekeeper-audit
```

### Alle Constraints anzeigen

```bash
kubectl get constraints -A
```

### Einzelnen Constraint prüfen

```bash
kubectl describe constraint allowed-docker-repos
```

## Flux Integration

Policies werden in Git gespeichert und via Flux deployed:

```
infra/gatekeeper/
  templates/
    k8sallowedrepos-template.yaml    # ConstraintTemplate
  constraints/
    allowed-repos.yaml               # Constraint
```

Flux erkennt neue Constraints automatisch und synced sie zum Cluster.

## Flux mit Telegram Alert (optional)

Wenn eine Policy verletzt wird, kann Flux per Telegram benachrichtigen:

```bash
# Notification Controller muss installiert sein (war bei Flux bootstrap dabei)
# Prüfen:
kubectl get pods -n flux-system | grep notification
```

## Versionshistorie

| Datum | Version | Änderung |
|-------|---------|----------|
| 2026-04-21 | 3.15.0 | Installation fehlgeschlagen (OPA Library Bug mit K8s 1.27) |
| 2026-04-21 | 3.14.0 | ✅ Funktioniert. ConstraintTemplates laden korrekt. |

## Nächste Schritte

1. [x] Gatekeeper 3.14.0 installiert
2. [x] ConstraintTemplate k8sallowedrepos installiert (offizielle Library)
3. [x] Constraint allowed-docker-repos erstellt
4. [x] Test: gcr.io blocked, docker.io/nginx allowed
5. [ ] Weitere Policies: no-privileged-containers, require-labels, require-resources
6. [ ] Telegram Alert bei Policy-Deny

---

## Compliance Referenzen

### NIS2 (Art. 21)

NIS2 fordert **Security Measures** including:
- Vulnerability Management (keine bekannten CVEs in Images)
- Container Hardening (keine privileged Container)
- Network Security (keine HostPorts, kein HostNetwork)

**OPA Policies die NIS2 addressieren:**
| NIS2 Anforderung | OPA Policy |
|------------------|-----------|
| Zugangskontrolle | require-authentication |
| Netzwerksicherheit | no-host-network, no-host-port |
| Container-Sicherheit | no-privileged-container, read-only-rootfs |
| Image-Sicherheit | allowed-registry (nur vertrauenswürdige Images) |

### BSI IT-Grundschutz CON.1

**Container Härtung (CON.1)**:
- M1: Minimal base image (keine unnötigen Tools)
- M2: Keine privilegierten Container
- M3: Resource Limits gegen DoS
- M4: NetworkPolicies gegen Lateral Movement
- M5: Secrets nicht in Env Vars (sondern Volume Mounts)

**OPA Policies für CON.1:**
```rego
# CON.1 M2: Keine privileged Container
deny[msg] {
  input.request.kind.kind == "Deployment"
  container := input.request.object.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := "Privileged containers are not allowed (BSI CON.1 M2)"
}

# CON.1 M3: Resource Limits
deny[msg] {
  input.request.kind.kind == "Deployment"
  container := input.request.object.spec.template.spec.containers[_]
  not container.resources.limits
  msg := "Container must have resource limits (BSI CON.1 M3)"
}
```

### DSGVO (Art. 32)

**Technische Maßnahmen:**
- Verschlüsselung: OPA garantiert keine Secrets in Plain-Text
- Zugangskontrolle: Kein exec in Container ohne RBAC
- Integrität: Keine Manipulation von Deployments ohne Audit Trail

### CIS Kubernetes Benchmark

OPA Gatekeeper implementiert Teile von:
- CIS 5.2.1: Ensure default namespace is not used
- CIS 5.2.5: Ensure that the Seccomp Profile is set to RuntimeDefault
- CIS 5.2.6: Ensure that the SecurityContext limits are set

---

*Quellen:*
* https://open-policy-agent.github.io/gatekeeper/
* https://github.com/open-policy-agent/gatekeeper-library
* https://www.openpolicyagent.org/docs/kubernetes/debugging
* BSI IT-Grundschutz Kompendium: CON.1 Container
* NIS2 Directive (EU) 2022/2555

*Erstellt: 2026-04-21*
