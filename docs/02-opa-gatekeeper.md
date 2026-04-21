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

## Gatekeeper Installation

```bash
# Gatekeeper deployen
kubectl apply --server-side -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.15.0/deploy/gatekeeper.yaml

# Prüfen dass er läuft
kubectl get pods -n gatekeeper-system
```

## ConstraintTemplates

Gatekeeper Policies bestehen aus:
1. **ConstraintTemplate** — Die Regellogik (rego)
2. **Constraint** — Die konkrete Anwednung auf Cluster/Namespaces

## Unsere Policies

### 1. Registry Whitelist — Nur erlaubte Container Registries

```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Deployment"
  container := input.request.object.spec.template.spec.containers[_]
  not startswith(container.image, "registry.company.com/")
  not startswith(container.image, "docker.io/")
  not startswith(container.image, "quay.io/")
  msg := sprintf("Image '%v' not from allowed registry", [container.image])
}
```

### 2. Keine privileged Container

```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Deployment"
  container := input.request.object.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := "Privileged containers are not allowed"
}
```

### 3. Keine Root-Container

```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Deployment"
  container := input.request.object.spec.template.spec.containers[_]
  not container.securityContext.runAsNonRoot == true
  not container.securityContext.runAsNonRoot == false
  msg := "Container must set runAsNonRoot: true or false"
}
```

### 4. Labels erforderlich

```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Deployment"
  not input.request.object.metadata.labels.app
  msg := "Deployment must have label 'app'"
}
```

### 5. Resourcen-Limits erforderlich

```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Deployment"
  container := input.request.object.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf("Container '%v' must have resource limits", [container.name])
}
```

## Constraint als YAML

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRegistry
metadata:
  name: allowed-registry
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
  parameters:
    registries:
      - "docker.io"
      - "quay.io"
      - "registry.company.com"
```

## Flux Integration

Policies werden in Git gespeichert und via Flux deployed:

```
infra/gatekeeper/
  constraints/
    allowed-registry.yaml
    no-privileged-containers.yaml
    require-labels.yaml
  templates/
    k8sallowedregistry-template.yaml
```

## Testen ob Policy greift

```bash
# Verbotenes Image deployen → sollte rejected werden
kubectl run nginx-test --image=nginx:latest --dry-run=server
# Expected: Error ... denied by allowed-registry

# Erlaubtes Image deployen → sollte funktionieren
kubectl run nginx-test --image=docker.io/nginx:latest --dry-run=server
# Expected: Success (oder Deployment created)
```

## Troubleshooting

### Policy greift nicht
```bash
# Logs vom Controller checken
kubectl logs -n gatekeeper-system deployment/gatekeeper-controller-manager -c controller-manager

# Constraint Status checken
kubectl get constraints
kubectl describe constraint <name>
```

### Mutation statt Validation
Gatekeeper kann auch mutieren (automatisch korrigieren). Das ist optional.

## Nächste Schritte

1. [x] Gatekeeper installiert
2. [ ] Policies als YAML in Git speichern
3. [ ] ConstraintTemplates + Constraints erstellen
4. [ ] Test: Policy greift bei verbotenen Deployments
5. [ ] Telegram Alert wenn Policy denied

---

*Quelle: open-policy-agent.github.io/gatekeeper*
*Erstellt: 2026-04-21*
