# Kubernetes Stack Comparison — Docker vs Podman

> Praxislerner-Methode: Erst den bewährten Stack verstehen, dann die Alternativen evaluieren.

## Warum dieses Dokument?

Ziel ist es, moderne Kubernetes-Plattformen zu verstehen und zu vergleichen:

**Phase 1: Docker Stack** (April 2026)
- Docker als Container Runtime
- kind für lokales Kubernetes
- Flux für GitOps
-learning: Wie funktioniert GitOps in der Praxis?

**Phase 2: Podman Stack** (später)
- Podman + Quadlet als Container Runtime
- podman-compose oder kind mit Podman
- Gleiche GitOps-Pipeline mit Flux
-learning: Was sind die Unterschiede? Was ist besser?

## Doku-Struktur

```
kubernetes-lab/
  docs/
    01-docker-stack.md       # Phase 1: Docker + kind + Flux
    02-podman-stack.md        # Phase 2: Podman + kind + Flux  
    03-flux-intro.md          # Flux Konzepte + Tutorial
    04-container-runtimes.md  # Docker vs Podman vs Crictl
    05-gitops-patterns.md     # Patterns die wir lernen
  infra/
    docker/                   # Docker-spezifische Configs
    podman/                   # Podman-spezifische Configs
    flux/                     # Flux-spezifische Configs (gemeinsam)
```

## Leitfragen

1. **Docker Stack:** Funktioniert GitOps mit Flux + Docker + kind wie erwartet?
2. **Podman Stack:** Laufen die gleichen Flux-Configs unter Podman?
3. **Unterschiede:** Wo hakt es? Was bricht? Was ist einfacher?
4. **Entscheidung:** Am Ende: Docker oder Podman für den Beratungs-Use Case?

## Technologie-Stacks

### Phase 1: Docker Stack
| Component | Tool | Version |
|----------|------|---------|
| Container Runtime | Docker | 29.x |
| Local K8s | kind | 0.20 |
| Kubernetes | kubeadm/kind | 1.27 |
| GitOps | Flux (v2) | 2.x |
| Package Manager | Helm | 3.x |
| Infrastructure | Ansible | 2.x |

### Phase 2: Podman Stack
| Component | Tool | Version |
|----------|------|---------|
| Container Runtime | Podman | 5.x |
| Container Init | Quadlet | newest |
| Local K8s | kind (podman) | 0.20+ |
| Kubernetes | kubeadm/kind | 1.27 |
| GitOps | Flux (v2) | 2.x |
| Package Manager | Helm | 3.x |
| Infrastructure | Ansible | 2.x |

## Fortschritt

- [x] Docker Stack: kind Cluster "rook-lab" läuft
- [ ] Docker Stack: Flux installiert
- [ ] Docker Stack: Erste App via Flux deployed
- [ ] Docker Stack: Dokumentation Phase 1 komplett
- [ ] Podman Stack: Podman + Quadlet installiert
- [ ] Podman Stack: kind Cluster mit Podman Runtime
- [ ] Podman Stack: Flux installiert  
- [ ] Podman Stack: Vergleichs-Doku
- [ ] Entscheidung: Docker oder Podman?

---

*Erstellt: 2026-04-21*
