# Kubernetes Lab

> Lokales Kubernetes-Lab für KI-Agent-GitOps-Experimente.

## Ziel

Erforschen ob und wie KI-Agenten (Rook) Kubernetes-Umgebungen bauen, steuern und als GitOps-Engine nutzen können.

## Use Cases

- **Beratung:** Echte Showcases für Cloud-native Kunden
- **Forschung:** KI-Agent als Kubernetes-Operator
- **Training:** Locales Lernen ohne Cloud-Kosten

## Struktur

```
kubernetes-lab/
  infra/          # Cluster-Configs, Flux/ArgoCD, Namespaces
  apps/           # Sample Apps zum Deployen
  scripts/        # Automation (cluster setup, deploy, etc.)
  .github/        # GitHub Actions für CI/CD
```

## Setup

```bash
# kind installieren
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/

# Cluster erstellen
kind create cluster --name rook-lab

# kubectl installieren
sudo apt install kubectl

# Flux installieren
curl -s https://fluxcd.io/install.sh | sh
```

## Tools

- **kind** — Kubernetes in Docker (kein MiniKube nötig)
- **kubectl** — Kubernetes CLI
- **Flux** — GitOps Toolkit
- **Helm** — Package Manager für Kubernetes

## Status

- [ ] kind installiert
- [ ] erster Test-Cluster erstellt
- [ ] erste App deployed
- [ ] Rook kann mit kubectl sprechen

---

*Kotlin in Anlehnung an: Rook als KI-Agent für DevOps/GitOps — Markus Grätsch, 2026*
