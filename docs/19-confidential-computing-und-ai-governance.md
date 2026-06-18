# Confidential Computing & AI Governance — Stack-Übersicht für Kunden

> **Status:** 📋 Konzept-Doc. Stack-Empfehlung für Kunden, die AI-Workloads **nachweisbar** compliant betreiben wollen. Reine Architektur-Diskussion, **noch nicht implementiert**.

## Überblick

Dieses Dokument ergänzt `18-vaara-ai-governance-evidence.md` um die **Schutz-Schicht** (Confidential Computing) und ordnet beides in den **vollständigen AI-Compliance-Stack** ein, den wir Kunden anbieten können.

**Drei orthogonale Sicherheits-Dimensionen für AI-Workloads:**

| Dimension | Schutz vor | Werkzeuge in unserem Stack |
|---|---|---|
| **At Rest** (gespeichert) | Gestohlene Festplatte, Backup-Leaks | LUKS auf Nodes, Hetzner Storage Box, Cryptomator |
| **In Transit** (übertragen) | Netzwerk-Abhörung | TLS, WireGuard, mTLS im Service-Mesh |
| **In Use** (verarbeitet) | Cloud-Admin, Hypervisor, fremde Tenants | **Confidential Computing (TEEs)** ← dieses Doc |
| **Audit / Governance** | Nachträgliche Log-Manipulation | **Vaara** (TPM+IMA) — siehe Doc 18 |

## Was Confidential Computing (CC) löst

**Kunden-Realität 2026+:** "Wir wollen KI im Ticketsystem einsetzen, aber die Daten sind personenbezogen. Wir vertrauen dem Cloud-Provider nicht (DSGVO-Auslegung, US CLOUD Act-Risiko bei US-Hyperscalern). Gleichzeitig wollen wir **beweisen** können, dass kein Mensch außerhalb unserer Organisation die Daten sah."

**CC-Antwort:**
- Daten liegen **während der Verarbeitung verschlüsselt im RAM**
- Weder Cloud-Admin, Hypervisor noch andere Tenants können sie im Klartext lesen
- **Attestation** beweist, dass die Software in einer echten Hardware-Enklave lief (nicht z.B. in einer manipulierten VM)
- Schlüssel bleiben beim Kunden ("Hold Your Own Key")

## TEE-Technologien (Übersicht)

| TEE | Was | Wo verfügbar (Juni 2026) |
|---|---|---|
| **Intel SGX** | Application-Level-Enklaven (klein, sehr isoliert) | Server-Xeon, aus Consumer-Intel seit 12th Gen entfernt |
| **Intel TDX** | Ganze VMs in Enklaven | Xeon Scalable ab 4th Gen |
| **AMD SEV** | VM-Speicher verschlüsselt | EPYC + ausgewählte Consumer-Ryzen |
| **AMD SEV-SNP** | SEV + Memory-Integrity + Attestation | Primär EPYC |
| **ARM CCA** | VM-Enklaven für ARM | Neoverse-Plattform |
| **Nvidia H100/H200 CC** | GPU-Confidential-Computing für AI | H100/H200-Rechenzentrums-Hardware |
| **AWS Nitro Enclaves** | AWS-spezifische Enklaven | AWS EC2 |

## Anbieter im DACH-Markt

### [enclaive.io](https://www.enclaive.io/de) — Multi-Cloud-Wrapper

enclaive ist **kein TEE-Hersteller** (nutzt Intel/AMD-Hardware), sondern ein **Multi-Cloud-Orchestrierungs-Layer** der CC für verschiedene Cloud-Provider einheitlich verfügbar macht.

| Produkt | Funktion | Use-Case |
|---|---|---|
| **Buckypaper CVMs** | Confidential VMs auf AWS/Azure/GCP/STACKIT | Standard-Workloads in Enklaven |
| **Dyneemes K8s** | Kubernetes mit TEE-Nodes | Containerisierte AI-Workloads in Enklaven |
| **vHSM** | Virtual Hardware Security Module | Eigenes Schlüsselmanagement |
| **Vault** | Secret-Management in CC | Schlüssel-Rotation ohne Klartext-Exposition |
| **Nitride** | Key-Brokerage | Schlüssel-Übergabe an Workloads, attestiert |
| **Garnet Firewall** | Confidential AI Gateway | KI-Prompts/Responses in Enklaven, schützt vor LLM-Daten-Leaks |
| **AI Enclave** | KI-Modelle in Enklaven | Modell-Training/Inferenz mit verschlüsselten Daten |
| **eMCP** | Enklaven-MCP-Proxy | Kombination CC + MCP (passt zu Vaara-MCP-Proxy!) |
| **Verschlüsselte DBs** | MongoDB, PostgreSQL, MariaDB, Redis | Transparent verschlüsselt, kein Performance-Verlust |
| **Nextcloud / GitLab** | Managed confidential apps | Schnellstart für Kunden ohne Eigenentwicklung |
| **Compliance-Automatisierung** | Belege DSGVO/NIS2/DORA/TISAX/ISO 27001 | Audit-Berichte auf Knopfdruck |

**Referenzkunden:** Arbeiterwohlfahrt RTK, Lufthansa Industry Solutions, Lilie Ihwas Attorneys.

### [STACKIT](https://www.stackit.de/) — Deutsche Cloud

- Schwarz-Gruppe (Lidl, Kaufland), **DE-Rechenzentren**, **BSI C5 testiert**
- CC via enclaive
- **Sovereignty-Pitch:** DE-Cloud + DSGVO + BSI + CC — vollständig ohne US-Hyperscaler

**Kombination STACKIT + Hetzner** (Du nutzt Hetzner schon für Storage):
- **STACKIT** = Compute + CC
- **Hetzner Storage Box** = verschlüsselter Storage (E2EE)
- Beide DE, beide DSGVO-konform, beide günstig im Vergleich zu Hyperscalern

### Open-Source-Konzepte (ohne Anbieter-Lock-in)

| Projekt | Was | Status (Juni 2026) |
|---|---|---|
| **Confidential Containers** (CNCF) | K8s-Pods in Hardware-Enklaven | CNCF Sandbox, produktionsreif |
| **Enarx** | TEE-Workload-Framework, hardware-agnostisch | Aktiv |
| **Gramine** | Lib-OS für SGX/SEV | Aktiv, Intel-maintained |
| **Occlum** | Lib-OS für SGX, gut für Legacy-Apps | Aktiv |
| **Asylo** (Google) | Enklaven-Framework | Status prüfen |

## Vollständiger AI-Compliance-Stack für Kunden

```
┌─────────────────────────────────────────────────────────────────┐
│                     KUNDEN-WORKLOADS                              │
│  (KI-Agenten, RAG-Pipelines, LLM-Inferenz, Datenanalyse)         │
├─────────────────────────────────────────────────────────────────┤
│  GOVERNANCE / AUDIT                                             │
│  ┌─────────────────────────┐  ┌─────────────────────────────┐   │
│  │ Vaara (TPM+IMA)         │  │ OPA Gatekeeper              │   │
│  │ = tamper-evident        │  │ = Policy zur Build-Zeit     │   │
│  │   Audit-Trail           │  │   (siehe Doc 02)            │   │
│  │ (siehe Doc 18)          │  │                             │   │
│  └─────────────────────────┘  └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  CONFIDENTIAL COMPUTING (Schutz "in use")                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ enclaive.io Multi-Cloud CC (Buckypaper CVMs / Dyneemes) │   │
│  │ = Daten in Hardware-Enklaven, kein Cloud-Admin sieht    │   │
│  │   Klartext                                              │   │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│  PLATTFORM-FOUNDATION                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ rook-k8s-lab IDP (Flux, ArgoCD, Keycloak, Trivy, ...)   │   │
│  │ = GitOps, RBAC, SSO, Vulnerability-Mgmt, Backup         │   │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│  CLOUD- / STORAGE-INFRASTRUKTUR                                 │
│  ┌────────────────────┐  ┌─────────────────────────────────┐   │
│  │ STACKIT (DE)        │  │ Hetzner Storage Box (DE)         │  │
│  │ = Compute + CC      │  │ = verschlüsselter Storage (E2EE) │  │
│  └────────────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Jede Schicht löst eine andere Klasse von Bedrohungen:**
- **OPA Gatekeeper** = "Diese Policy ist erzwungen, bevor der Code deployed wird"
- **enclaive CC** = "Während der Verarbeitung hatte niemand Klartext-Zugriff"
- **Vaara** = "Dieser Agent-Call ist nachträglich nicht mehr manipulierbar"
- **rook-k8s-lab Foundation** = "Die Plattform selbst ist compliant betrieben (CIS, BSI)"
- **STACKIT + Hetzner** = "Auch der Provider ist DE, BSI-C5, DSGVO"

## Kunden-Pitch (3 Stufen)

### 🟢 Stufe 1 — Standard (was wir heute liefern)
- IDP-Plattform (rook-k8s-lab) mit OPA, Trivy, ArgoCD, Keycloak
- Compliance-Belege: CIS Kubernetes, BSI IT-Grundschutz, DSGVO
- **Spricht:** Kunden mit "normalen" Compliance-Anforderungen

### 🟡 Stufe 2 — AI-erweitert
- Stufe 1 + **Vaara** (Audit-Trail für AI-Agents)
- EU AI Act Article 12/14/15 Mappings
- Optional: Mock-MCP-Proxy mit Vaara im POC
- **Spricht:** Kunden mit AI-Workloads + EU-AI-Act-Pflichten

### 🔴 Stufe 3 — Confidential AI
- Stufe 2 + **enclaive Confidential Computing** (auf STACKIT oder hyperscaler)
- Garnet Firewall + AI Enclave (LLM-Prompts in Enklaven)
- Vaara-MCP-Proxy in eMCP (CC + Audit kombiniert)
- **Spricht:** Kunden mit hochsensiblen Daten (Personenbezogen, IP, Defense, Life Sciences)

## Konkrete Use-Cases

| Branche | Warum Stufe 3? |
|---|---|
| **Behörden / VS-NfD** | Nur DE-Cloud + BSI-C5 + CC akzeptabel |
| **Life Sciences / Medizin** | Patientendaten, BSI C5 + gematik-Betreiberausschluss |
| **Finance / DORA** | DORA-Compliance, KI-gestützte Risikoanalyse, vertrauliche KI-Modelle |
| **Defense** | Sichere Informationsaustausch-Plattformen, resiliente 5G-Netze |
| **Industrie 4.0** | IP-Schutz für Trainingsdaten, Industrial-Cloud-Konnektivität |
| **Legal (Kanzleien)** | Mandantendaten in KI-Tools, Schweigepflicht |

## Lokales Confidential Computing (für unseren eigenen Stack)

Für unser Privat-/Resilience-Setup (siehe `private/marcus-resilience-todo.md` §11e):

| Hardware | CC-Fähigkeit (Juni 2026) |
|---|---|
| **Minisforum AI X1 Pro** (Ryzen AI 9 HX 370) | SEV in Hardware, **SEV-SNP vermutlich gesperrt**, BIOS-Freischaltung nötig (Garantie-Risiko) |
| **Minisforum UM890 Pro** | Selbe Situation wie X1 Pro |
| **Gebrauchte Dell OptiPlex Micro / HP ProDesk Mini** | Oft SGX-fähig (ältere Modelle), Discrete TPM 2.0 möglich |
| **Mini-ITX Server-Boards** (ASRock Rack, Supermicro) | Voll CC-fähig, TPM-Header Standard |
| **Dedizierter Audit-Server** (z.B. Dell PowerEdge, HPE ProLiant) | Voll CC + TPM + IMA, klassische Server-Hardware |

**Realistisch für Eigenbedarf:**
- **Nicht-CC-privat** = Ollama lokal, sensible Daten durch Verschlüsselung "at rest" + hoffen, dass kein Cloud-Leak
- **CC-privat** = separater kleiner Server mit SEV/SGX, sensible Sessions dort, Output verschlüsselt zurück
- Tradeoff: Aufwand vs. Threat-Model — für die meisten Use-Cases reicht "nicht-CC-privat"

## Beziehung zu Vaara-MCP-Proxy

Vaara hat einen **MCP-Proxy** (`vaara-mcp-proxy`), der AI-Tool-Calls auditiert. enclaive hat **eMCP** (Enklaven-MCP-Proxy), der MCP-Calls in Enklaven ausführt.

**Kombiniert:**
- **eMCP** = "MCP-Call läuft in CC-Enklave, Daten sind während Verarbeitung geschützt"
- **Vaara-MCP-Proxy** = "MCP-Call wird mit hash-chain aufgezeichnet, Audit-Trail da"
- **Zusammen** = "MCP-Call lief in CC-Enklave, ist attestiert, **und** nachträglich nicht manipulierbar"

Diese Kombination ist **architektonisch einzigartig** und ein echter Differentiator für Kunden mit höchsten Anforderungen.

## Entscheidungs-Matrix: Wann welche Stufe?

| Kunden-Anforderung | Stufe 1 (IDP) | Stufe 2 (+Vaara) | Stufe 3 (+enclaive CC) |
|---|---|---|---|
| DSGVO-Baseline | ✅ reicht | — | — |
| NIS2-Baseline | ✅ reicht | — | — |
| AI-Workloads dokumentieren | ❌ | ✅ nötig | ✅ |
| EU AI Act Article 12 | ❌ | ✅ nötig | ✅ |
| EU AI Act Article 14 (Human Oversight) | 🟡 mit Custom | ✅ | ✅ |
| Datenraum (mehrere Parteien, niemand vertraut) | ❌ | ❌ | ✅ nötig |
| BSI C5 / VS-NfD | ❌ | ❌ | ✅ nötig |
| IP-Schutz in Industrial Cloud | ❌ | 🟡 | ✅ nötig |
| Patientendaten / Mandantendaten | 🟡 Verschlüsselung reicht meist | 🟡 | ✅ bei höchsten Schutzanforderungen |

## Quellen

- [enclaive.io Multi-Cloud Confidential Computing Platform](https://www.enclaive.io/de)
- [STACKIT — Schwarz-Gruppe Cloud](https://www.stackit.de/)
- [AMD SEV-SNP Documentation](https://www.amd.com/system/files/TechDocs/56860.pdf)
- [Intel TDX Documentation](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-trust-domain-extensions.html)
- [CNCF Confidential Containers](https://github.com/confidential-containers)
- [Enarx Project](https://enarx.dev/)
- [Gramine Project](https://gramineproject.io/)
- IMDA Model AI Governance Framework v1.5 (Singapur, Mai 2026)
- EU AI Act Article 12 (Record-Keeping), Article 14 (Human Oversight)
- DORA (Digital Operational Resilience Act, Finance)
- BSI C5 (Cloud Computing Compliance Criteria Catalogue)
- Bezug zu Vaara: siehe `18-vaara-ai-governance-evidence.md`

## Nächste Schritte

- [ ] **POC-Bau:** kind-Cluster um Confidential-Container-Stub erweitern (Demo)
- [ ] **enclaive-Account anlegen** für STACKIT + Buckypaper Test-Instance
- [ ] **Vaara-MCP-Proxy + eMCP** Architektur-Skizze für Kunden-Whitepaper
- [ ] **Pre-Sales-Material:** Kunden-Pitch-Doc (1-Pager) zu Stufe 3 ableiten
- [ ] **Schulung:** Eigene Lern-Kurve zu SEV-SNP + TDX-Konfiguration
