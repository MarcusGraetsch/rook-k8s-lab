# Flux — GitOps Toolkit (Einführung)

## Was ist Flux?

Flux ist ein **GitOps Toolkit** für Kubernetes. Es sorgt dafür dass der Cluster-Zustand immer dem entspricht was in Git steht.

Der Reconciliation-Loop:
```
Git Repo → Flux erkennt Änderung → Apply auf Cluster → Status-Abgleich → Wiederholen
```

## Die 3 Kernkonzepte

### 1. Source (Woher kommt das Manifest?)

Definiert die Quelle der Kubernetes-Manifeste.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: rook-lab
  namespace: flux-system
spec:
  url: https://github.com/MarcusGraetsch/rook-k8s-lab
  branch: main
  interval: 1m
```

Alternativen: `HelmRepository`, `Bucket`

### 2. Kustomization (Was soll deployt werden?)

Definiert welche Manifeste angewendet werden sollen.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  sourceRef:
    kind: GitRepository
    name: rook-lab
  path: ./apps/nginx
  prune: true
  interval: 2m
```

### 3. Reconciliation (Der Loop)

Flux vergleicht kontinuierlich den Git-Zustand mit dem Cluster-Zustand:

- **Prune:** Nicht mehr in Git = wird aus Cluster gelöscht
- **Interval:** Wie oft Flux prüft (default: 5m)
- **Garbage Collection:** Orphaned Resources werden entfernt

## Flux Installation

```bash
# 1. Flux CLI installieren
curl -s https://fluxcd.io/install.sh | bash

# 2. Auf Cluster anwenden (Bootstrap)
flux bootstrap github \
  --owner=MarcusGraetsch \
  --repository=rook-k8s-lab \
  --branch=main \
  --path=./infra/flux \
  --token-auth
```

## Typische Flux-Manifest-Struktur

```
rook-k8s-lab/
  infra/
    flux/
      flux-system/           # Flux selbst (NS, SA, Roles)
      repos.yaml             # GitRepository Source
      apps.yaml              # Kustomization für Apps
  apps/
    nginx/
      kustomization.yaml    # nginx Deployment + Service
    podinfo/
      kustomization.yaml    # podinfo Demo-App
```

## Wichtige Flux Commands

```bash
# Status prüfen
flux get sources git
flux get kustomizations

# Logs
flux logs --level=debug

# Erzwingen eines Reconcile
flux reconcile source git rook-lab
flux reconcile kustomization apps

# Resume/Suspend
flux suspend kustomization apps
flux resume kustomization apps
```

## Warum Flux für Rook?

Vorteile für unseren Use Case:
1. **Declarativ** — Alles ist YAML, Agent kann das schreiben
2. **Kein UI nötig** — KI-Agent spricht nur Flux CLI + kubectl
3. **Kein extra Server** — Flux läuft im Cluster als Operator
4. **Multi-Tenancy** — Flux kann verschiedene Namespaces steuern

## Nächste Schritte

1. [ ] Flux Bootstrap auf rook-lab
2. [ ] GitRepository definieren
3. [ ] Erste Kustomization für nginx
4. [ ] Rook lernt flux get/reconcile

---

*Quelle: fluxcd.io*
