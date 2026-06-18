# AI Governance Evidence Layer (Vaara) — Option für Kunden-Compliance

> **Status:** 📋 Optionale Komponente — derzeit **nicht installiert**. Bookmark für NIS2/EU-AI-Act-Kunden, deren AI-Agenten auditierbar sein müssen.

## Überblick

[Vaara](https://github.com/vaaraio/vaara) ist eine **Open-Source-Evidenz-Schicht für AI-Agent-Governance**. Sie gateset jeden AI-Agent-Tool-Call gegen eine Policy, schreibt Call + Decision + Outcome in einen **hash-chained, signierten Audit-Record** und bindet diesen Record optional an **TPM 2.0 + IMA** Hardware-Attestation. Komplett lokal — kein SaaS, keine Telemetrie.

**Design-Treiber:** EU AI Act **Article 12 (Record-Keeping)** und **Article 14 (Human Oversight)**. Bietet zusätzlich Mappings zu DORA und IMDA Model AI Governance Framework v1.5 (Singapur, Mai 2026).

| Eigenschaft | Wert |
|---|---|
| **Lizenz** | Apache 2.0 (Sovereign Inference Harness: AGPL-3.0) |
| **Runtime** | Python 3.10+, zero runtime dependencies |
| **Paket** | `pip install vaara` (ML-Klassifier opt-in: `pip install 'vaara[ml]'`) |
| **Adapters** | LangChain, CrewAI, OpenAI Agents SDK, **MCP-Proxy**, HTTP-API-Server |
| **Standards** | MCP SEP-2828 (signed execution records), SEP-2787, OVERT 1.0 (Protocol Profile 1.0) |
| **Audit-Ausgabe** | JSON (`vaara compliance report`), Notified-Body-PDF, Sigstore-signierte Handoff-Envelopes, statisches HTML-Dashboard |

## Was Vaara löst (Kundensicht)

**Kunden-Realität 2026+:** AI-Agenten treffen eigenständig Tool-Calls (Daten lesen, Mails senden, Bestellungen auslösen). Nach einem Incident fragt Auditor/Regulator: *"Was hat der Agent genau getan, wann, mit welcher Begründung?"* Eigene Logs reichen nicht — die könnten nachträglich editiert worden sein.

**Vaara's Antwort:**
1. **Policy-Gate** vor jedem Tool-Call (allow / block / escalate)
2. **Hash-Chain** über alle Calls — Manipulationsversuch wird erkannt
3. **Hardware-Attestation** (mit TPM 2.0 + IMA) — selbst der Operator kann den Trail nicht fälschen
4. **Offline-Verifier** (`vaara verify-bundle`) — Auditor prüft ohne Zugang zum System
5. **Article-Level-Compliance-Report** — direkt auf EU-AI-Act-Artikel gemappt

## Warum relevant für IDP-Kunden

| Anforderung | NIS2 | EU AI Act | ISO 27001 | Vaara-Mapping |
|---|---|---|---|---|
| Nachvollziehbarkeit automatisierter Entscheidungen | Art. 21(2)(d) | Art. 12, 14 | A.8.15 | ✅ Hash-Chain + Article-Report |
| Manipulationssichere Logs | ✅ | Art. 12(2) | A.8.15 | ✅ TPM-bound optional |
| Externe Verifizierbarkeit | — | Art. 12 | A.8.34 | ✅ Standalone Verifier, keine Vaara-Installation nötig |
| Risiko-Scoring der Calls | — | Art. 15 | — | ✅ 5-Signal-Scorer + konforme Coverage |
| Third-Party-Audit-Trail | ✅ | Art. 12 | A.8.34 | ✅ Notified-Body-PDF |

**Konkretes Kunden-Pitch:**
> „Sie haben einen AI-Agent im Ticketsystem, der eigenständig Mails versendet und Files anlegt. Mit Vaara liefern Sie dem Auditor einen **offline-verifizierbaren Audit-Trail** mit EU-AI-Act-Article-Mapping — ohne SaaS, ohne Drittvertrauen, ohne monatliche Lizenzkosten."

## Hardware-Anforderungen

| Feature | Mindestanforderung | Optimal |
|---|---|---|
| **Basis** (Policy + Hash-Chain + Compliance-Report) | Beliebige Linux-VM, Python 3.10+ | — |
| **Regulatorisch verwertbar** | **Discrete TPM 2.0** (nicht fTPM) + Linux-Kernel mit `CONFIG_IMA=y` + IMA-Bootparameter | Server-Hardware (Supermicro, Dell PowerEdge, HPE ProLiant) |

**Wichtig für unser Setup:**
- Aktuelle `kind`-Cluster-VM: **kein TPM 2.0** → voller regulatorischer Wert nicht erreichbar
- `kind` läuft in Docker-Containern — TPM-Passthrough wäre nötig (komplex)
- **Realistisch:** Vaara in Kunden-Setups mit echter Server-Hardware, **nicht** im POC

## Performance-Charakteristik

- **Hot-path Rule-Scorer:** 140 µs mean per Call (commodity CPU, ohne ML)
- **ML-Klassifier (opt-in):** zusätzlich, auf separatem Pfad
- **Adversarial-Test-Recall:** 84.7% bei 4.1% FPR (held-out Test n=1.827)
- **Cross-Model Robustheit:** 0/25 Erfolge gegen Qwen2.5-32B/72B, Llama-3.3-70B (PAIR-Angriff)
- **12.155-Entry Adversarial Corpus** — komplett öffentlich, reproduzierbar via `make bench`

## Integrationsplan (wenn Kunde es will)

### Phase 1 — Standalone Demo (1–2 Tage)
```bash
pip install vaara
# MCP-Proxy vor einem bestehenden Agent-Tool starten
vaara-mcp-proxy \
  --upstream npx --upstream-arg -y --upstream-arg @sap/mdk-mcp-server \
  --db ./vaara-audit.db
# Compliance-Report ziehen
vaara compliance report --format json
```

### Phase 2 — In den IDP integriert (1 Woche)
- Vaara als Sidecar-Pod im IDP-Namespace
- Audit-DB auf persistentem Volume (Longhorn/ROOK)
- Cron-Job exportiert `evidence-bundle.json` + signierten Handoff nach S3/MinIO
- Grafana-Panel: Anzahl Tool-Calls / Tag, Block-Rate, Article-12-Status

### Phase 3 — Hardware-Attestation (nur mit Discrete TPM)
- Server-Mainboard mit Discrete TPM 2.0
- Kernel mit `CONFIG_IMA=y`, Bootparameter `ima_policy=appraise_tcb`
- Vaara im Attestation-Mode: jede Hash-Chain an TPM-PCR gebunden
- Auditor kann mit `vaara verify-bundle` + TPM-Public-Cert den ganzen Trail verifizieren

## Was Vaara NICHT ist (zur Klarstellung)

- ❌ **Kein LLM-Firewall** — LLM-Guard, Rebuff, Guardrails AI machen das (Cloud-bezogen)
- ❌ **Kein Policy-Engine** — Vaara **beweist** Policy-Anwendung, **erzwingt** sie nicht (OPA Gatekeeper bleibt erste Wahl für Policy)
- ❌ **Kein Compliance-Zertifikat** — Vaara liefert Evidenz, **nicht** Zertifizierung. Kunde bleibt verantwortlich für eigene EU-AI-Act-Compliance
- ❌ **Kein Drop-in für OpenClaw-Rook** — Adapter sind Python. TypeScript-Wrapper nötig, falls gewünscht

## Verwandte / komplementäre Tools im IDP

| Tool | Funktion | Overlap mit Vaara |
|---|---|---|
| **OPA Gatekeeper** | Policy-Enforcement zur Deploy-Zeit | Komplementär — Vaara = Runtime-Evidence, Gatekeeper = Build-time-Policy |
| **Trivy** | Vulnerability-Scanning | Komplementär — Vaara = AI-Call-Evidence, Trivy = Container-CVE-Evidence |
| **kube-bench** | CIS/BSI-Compliance | Komplementär — Vaara = EU-AI-Act, kube-bench = CIS/BSI |
| **Promtail + Loki** | Log-Aggregation | Overlap — Vaara-Records sind strukturierter, Loki ist free-form |

## Quellen

- Repo: https://github.com/vaaraio/vaara
- PyPI: https://pypi.org/project/vaara/
- Architektur: https://github.com/vaaraio/vaara/blob/main/docs/architecture.md
- EU-AI-Act/DORA-Mapping: https://github.com/vaaraio/vaara/blob/main/docs/COMPLIANCE.md
- Verifier-Trust-Model: https://github.com/vaaraio/vaara/blob/main/docs/verifying-evidence.md
- Standards-Integration: https://github.com/vaaraio/vaara/blob/main/docs/standards.md
- IMDA Framework (Singapur, Mai 2026): https://www.imda.gov.sg/
- EU Apply AI Alliance Post: https://futurium.ec.europa.eu/ga/apply-ai-alliance/

## Entscheidung

| Frage | Antwort |
|---|---|
| **Jetzt im POC installieren?** | ❌ Nein — kein TPM im `kind`, Audit-Wert dadurch minimal |
| **In Doku aufnehmen?** | ✅ Ja (dieses Dokument) — damit Kunden-Pitch vorbereitet ist |
| **Bei Hardware mit Discrete TPM 2.0?** | ✅ Dann Demo-Build mit Attestation |
| **Kunde fragt nach AI-Compliance?** | ✅ Vaara als Option nennen, zusammen mit OPA Gatekeeper als komplementärem Stack |
