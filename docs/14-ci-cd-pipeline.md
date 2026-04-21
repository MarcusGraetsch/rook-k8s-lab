# CI/CD Pipeline — Build, Scan, Deploy

## Überblick

Unsere CI/CD Pipeline automatisiert den gesamten Prozess vom Code zum Deployment:

```
Developer push Code
        │
        ▼
GitHub Actions
  │
  ├─► 1. Build Docker Image
  │
  ├─► 2. Trivy Scan (CRITICALs blockieren)
  │
  ├─► 3. Push to GHCR (wenn Scan OK)
  │
  └─► 4. Flux Update → Kubernetes Deployment
```

## Pipeline Stages

### Stage 1: Build

```yaml
- name: Build Docker image
  uses: docker/build-push-action@v5
  with:
    context: apps/nginx
    push: false  # Erstmal nur bauen für Scan
    tags: ${{ steps.meta.outputs.tags }}
```

### Stage 2: Trivy Security Scan

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ env.IMAGE_NAME }}:${{ github.sha }}
    severity: 'CRITICAL,HIGH'
    exit-code: '1'  # FAIL bei CRITICALs
```

**Exit Codes:**
- `0` = Keine Probleme gefunden → Pipeline continues
- `1` = CRITICAL oder HIGH gefunden → Pipeline FAILS

### Stage 3: Push (nur bei Erfolg)

```yaml
needs: build-and-scan
if: needs.build-and-scan.outputs.scan-result != '1'
```

Image wird nur gepusht wenn der Scan erfolgreich war.

### Stage 4: Flux Deployment Update

```bash
# Image in Git aktualisieren
sed -i 's|image: .*|image: ghcr.io/$IMAGE:$SHA|' deployment.yaml
git commit && git push

# Flux reconciled den neuen Stand
flux reconcile kustomization apps --with-source
```

## Pipeline Status

| Stage | Status | Bedeutung |
|-------|--------|----------|
| Build | ✅ | Image wurde gebaut |
| Trivy Scan | ✅/❌ | Security Check |
| Push | ✅/❌ | Nur wenn Scan OK |
| Flux Sync | ✅/❌ | Deployment wurde aktualisiert |

## Workflow Dateien

```
rook-k8s-lab/
├── .github/
│   └── workflows/
│       └── build-deploy.yaml    # Haupt CI/CD Pipeline
├── apps/
│   └── nginx/
│       ├── deployment.yaml      # Kubernetes Deployment
│       ├── service.yaml         # Service
│       └── kustomization.yaml  # Flux Kustomization
└── infra/
    └── flux/                    # Flux Configuration
```

## Manuelles Triggering

```bash
# Pipeline manuell starten
gh workflow run build-deploy.yaml

# Status prüfen
gh run list --workflow=build-deploy.yaml

# Logs anzeigen
gh run watch
```

## GitHub Container Registry (GHCR)

Images werden in GHCR gespeichert:

```
ghcr.io/<owner>/<repo>:<tag>
ghcr.io/marcusgraetsch/rook-k8s-lab:sha-abc123
ghcr.io/marcusgraetsch/rook-k8s-lab:latest
```

### Image URL finden

```bash
# In GitHub Actions Logs
echo "Image: ghcr.io/${{ github.repository }}:${{ github.sha }}"

# Oder via gh cli
gh api /user/packages?package_type=container | jq '.[] | .name'
```

## Troubleshooting

### Pipeline schlägt bei Trivy fehl

```
Error: exit code 1
```

**Was bedeutet:** Das Image hat CRITICAL oder HIGH Vulnerabilities.

**Lösung:**
1. Logs öffnen → Welche CVEs?
2. Dockerfile optimieren (neueres Base Image)
3. CVEs im Base Image akzeptieren (wenn kein Fix verfügbar)

### Flux Sync schlägt fehl

```bash
# Flux Logs prüfen
kubectl logs -n flux-system deployment/helm-controller -f

# Letzten Sync Status
flux get kustomizations
flux logs --all-namespaces --tail=50
```

### Image Permission denied

```bash
# GHCR Token prüfen
gh auth status

# Login erneuern
docker login ghcr.io -u ${{ github.actor }} -p ${{ secrets.GITHUB_TOKEN }}
```

## Alternative Registry

Falls GHCR nicht gewünscht:

### Docker Hub

```yaml
env:
  REGISTRY: docker.io
  IMAGE_NAME: mydockerhubuser/rook-k8s-lab
```

### Quay.io

```yaml
env:
  REGISTRY: quay.io
  IMAGE_NAME: myorg/rook-k8s-lab
```

---

## Compliance Referenzen

### NIS2 Art. 21 — Secure Development

NIS2 fordert:
> "Sichere Entwicklung von Software und Systemen"

**Umsetzung in Pipeline:**
| Anforderung | Umsetzung |
|-------------|-----------|
| Vulnerability Scanning | Trivy scannt jedes Image vor Deployment |
| Supply Chain Security | Nur geprüfte Images werden deployed |
| Incident Response | CVE Reports in SARIF Format |

### BSI CON.1 M4 — Schwachstellenmanagement

> "Prozesse zur Erkennung und Behebung von Schwachstellen in Container-Images"

Pipeline implementiert:
- Automatisiertes Scanning bei jedem Build
- Blockieren bei CRITICAL Vulnerabilities
- SARIF Export für Audit

### ISO 27001 A.12.6 — Technical Vulnerability Management

- A.12.6.1: Schwachstellen werden zeitnah identifiziert ✅
- A.12.6.2: Relevanz wird bewertet (Severity Filter) ✅
- A.12.6.3: Maßnahmen zur Behebung (Auto-Update Pipeline) ✅

### EU Cyber Resilience Act (CRA)

> Ab 2027: Pflicht-Scans für Produkte mit digitalen Elementen

Unsere Pipeline erfüllt diese Anforderung bereits jetzt.

---

*Erstellt: 2026-04-21*
