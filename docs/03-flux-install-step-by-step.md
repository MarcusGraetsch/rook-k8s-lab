# Flux Installation Tutorial — Step by Step

> Kommentierte Schritt-für-Schritt Anleitung zur Flux-Installation auf kind "rook-lab".
> Geschrieben für Lernzwecke: Jeder Befehl wird erklärt.

## Voraussetzungen (already done)

- [x] kind Cluster "rook-lab" läuft
- [x] kubectl funktioniert mit context "kind-rook-lab"
- [x] Docker ist installiert

## Ziel

```
Host (kubectl/flux)  →  Flux Operators im Cluster  →  Git Repo  →  Reconciliation Loop
```

## Schritt 1: Flux CLI installieren

### Was passiert hier?
Die Flux CLI ist das Command-Line-Tool das wir auf unserem Host (der VM) installieren.
Es dient zur Verwaltung von Flux (kubectl ist das allgemeine K8s-Tool, flux ist speziell für Flux).

```bash
# Download des offiziellen Flux Installers
curl -s https://fluxcd.io/install.sh | bash

# Verification: Ist Flux installiert und welche Version?
flux --version
```

**Erklärung:**
- `curl -s` = Silent Mode (kein Progress-Spagetti)
- `| bash` = Direkter Durchlauf des Installerscripts
- Die Flux-Leute hosten ein Install-Script auf ihrer Website

## Schritt 2: Flux im Cluster installieren

### Was passiert hier?
Die Flux CLI spricht mit unserem Kubernetes Cluster (über kubectl) und installiert
die Flux-Operatoren. Das sind Custom Resources + Controllers die im Namespace
"flux-system" laufen.

```bash
# Installation aller Flux-Komponenten im Namespace flux-system
flux install --namespace=flux-system
```

### Was sind die Flux-Komponenten?

| Component | Role |
|----------|------|
| source-controller | Verwaltet Sources (Git, Helm, Bucket) |
| kustomize-controller | Wendet Kustomize-Manifeste an |
| helm-controller | Verwaltet Helm Releases |
| notification-controller | Handlet Events und Alerts |
| image-automation-controller | Auto-Update von Container Images |

### Verification nach Installation

```bash
# Prüfe alle Flux Pods — alle sollten "Running" sein
kubectl get pods -n flux-system

# Erwartete Ausgabe (ca. 5 Pods):
# source-controller-xxxxx-xxxxx   1/1 Running
# kustomize-controller-xxxxx-xxxxx  1/1 Running
# helm-controller-xxxxx-xxxxx      1/1 Running
# notification-controller-xxxxx-xxxxx 1/1 Running
```

## Schritt 3: Git Repository als Source definieren

### Was passiert hier?
Flux muss wissen WO in Git die Manifeste liegen. Das definieren wir als "GitRepository" Resource.
Das ist noch NICHT das Repo mit unseren Apps — das kommt in Schritt 4.

```bash
# GitRepository erstellen
# Erklärung der Parameter:
# --url: GitHub URL unseresRepos
# --branch: Welcher Branch soll beobachtet werden?
# --interval: Wie oft soll Flux nach neuen Commits prüfen?

flux create source git rook-lab \
  --url=https://github.com/MarcusGraetsch/rook-k8s-lab \
  --branch=main \
  --interval=1m \
  --export > infra/flux/source.yaml
```

**Erklärung:**
- `--export` = Gibt das YAML aus statt es direkt anzuwenden
- `> infra/flux/source.yaml` = Speichert das YAML in eine Datei
- Wir speichern es in Git damt Flux es beim Bootstrap mitbekommt

### Warum speichern wir in Git?
Flux selbst ist die Source of Truth für den Cluster.
Die Manifesto in Git beschreiben den gewünschten Zustand.
Flux liest Git und wendet Änderungen an.

## Schritt 4: Kustomization erstellen

### Was passiert hier?
Die Kustomization sagt Flux: "Aus diesem GitRepository, in diesem Pfad,
sollen die Manifeste angewendet werden."

```bash
# Kustomization erstellen
# --source: Verweis auf das GitRepository aus Schritt 3
# --path: Der Pfad im Repo wo Apps liegen
# --prune: Nicht mehr in Git vorhandene Resources löschen
# --interval: Wie oft soll reconciliation laufen?

flux create kustomization rook-lab \
  --source=rook-lab \
  --path="./apps" \
  --prune=true \
  --interval=1m \
  --export > infra/flux/kustomization.yaml
```

## Schritt 5: Alles in Git speichern und pushen

### Warum ist das nötig?
Flux liest seine Konfiguration aus dem Cluster UND aus Git.
Wenn wir die Konfiguration in Git speichern:
1. Ist sie versioniert
2. Kann Flux sie bei Changes automatisch neu ausrollen
3. Haben wir ein Backup

```bash
# Änderungen stagen
git add infra/flux/

# Commit mit aussagekräftiger Message
git commit -m "feat: Flux GitOps eingerichtet

- GitRepository 'rook-lab' zeigt auf rook-k8s-lab
- Kustomization 'rook-lab' deployed ./apps
- Namespace: flux-system"

# Push zu GitHub
git push origin main
```

## Schritt 6: Verification

```bash
# Alle Sources anzeigen (sollte我们的 GitRepository zeigen)
flux get sources git

# Alle Kustomizations anzeigen
flux get kustomizations

# Logs ansehen falls was schiefgeht
flux logs --level=debug
```

## Die Reconciliation Loop (das Herz von Flux)

```
                    ┌─────────────────────────┐
                    │    GitHub Repository    │
                    │  infra/flux/apps/       │
                    └───────────┬─────────────┘
                                │ Pull (interval: 1m)
                                ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│   source-controller     │   │  kustomize-controller   │
│  (GitRepository CR)     │──▶│  (Kustomization CR)     │
└─────────────────────────┘   └───────────┬─────────────┘
                                          │
                                          ▼
                              ┌─────────────────────────┐
                              │   Kubernetes Cluster   │
                              │   Deployment/Service    │
                              └─────────────────────────┘
```

## Troubleshooting

### Flux Pods starten nicht
```bash
# Logs checken
kubectl logs -n flux-system deployment/source-controller

# Events im Namespace
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### GitRepository zeigt "connection refused"
- GitHub Token prüfen (falls private Repo)
- SSH vs HTTPS prüfen
- Netzwerk-Zugriff vom Cluster auf GitHub

### Kustomization stuck
```bash
# Reconciliation manuell triggern
flux reconcile source git rook-lab
flux reconcile kustomization rook-lab
```

## Nächste Schritte

1. [ ] Nginx App via Flux deployen
2. [ ] Monitoring mit Flux Dashboard (fluxtree oder WebUI)
3. [ ] Mehr Apps hinzufügen
4. [ ] Health Checks konfigurieren

---

*Quelle: fluxcd.io/docs, erstellt 2026-04-21*
