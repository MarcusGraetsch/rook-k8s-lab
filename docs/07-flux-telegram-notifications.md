# Flux Telegram Notifications

## Überblick

Der Flux Notification Controller kann Events an Telegram senden wenn:
- Ein GitRepository aktualisiert wird
- Eine Kustomization erfolgreich deployed wurde
- Health Checks fehlschlagen
- Fehler auftreten

## Was brauchen wir?

| Was | Woher |
|-----|-------|
| Telegram Bot Token | @BotFather auf Telegram |
| Chat ID | Direkt-Chat mit Bot oder Group ID |

## Schritt 1: Telegram Bot erstellen

1. Öffne Telegram und suche nach **@BotFather**
2. Sende `/newbot`
3. Gib dem Bot einen Namen, z.B. `Rook K8s Notifier`
4. BotFather gibt dir einen **Token** im Format: `123456789:ABCdefGHIjklMNOpqrSTUvwxyz`
5. **WICHTIG:** Diesen Token sicher speichern (like a password)

## Schritt 2: Chat ID herausfinden

### Variante A: Direkt-Chat mit dem Bot
1. Starte einen Chat mit deinem neuen Bot
2. Sende eine beliebige Nachricht (z.B. "test")
3. Besuche `https://api.telegram.org/bot<DEIN_TOKEN>/getUpdates`
4. Im JSON: `"chat":{"id":123456789,...}` — das ist deine **Chat ID**

### Variante B: Telegram Group
1. Füge den Bot zu einer Gruppe hinzu
2. Sende eine Nachricht in der Gruppe
3. Besuche `https://api.telegram.org/bot<DEIN_TOKEN>/getUpdates`
4. Die Chat ID ist negativ, z.B. `-123456789`

## Schritt 3: Flux Alert Provider konfigurieren

```bash
# Telegram Provider erstellen
flux create alert-provider telegram \
  --type telegram \
  --channel 123456789 \
  --secret-ref telegram-secret \
  --token-ref telegram-token
```

## Schritt 4: Secret für Token erstellen

```bash
# Token als Kubernetes Secret
kubectl create secret generic telegram-token \
  --from-literal=token=DEIN_BOT_TOKEN

# Alternativ: Flux Secret
flux create secret telegram-secret \
  --from-literal=token=DEIN_BOT_TOKEN
```

## Schritt 5: Alert erstellen

```bash
flux create alert telegram \
  --provider-ref telegram \
  --event-severity info \
  --event-severity error
```

## Schritt 6: Provider und Alert YAML (direkt)

```yaml
# alert-provider.yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: telegram
  namespace: flux-system
spec:
  type: telegram
  channel: "123456789"
  secretRef:
    name: telegram-token

---
# alert.yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: telegram
  namespace: flux-system
spec:
  providerRef:
    name: telegram
  eventSources:
    - kind: Kustomization
      name: rook-lab
    - kind: GitRepository
      name: rook-lab
```

## Test-Nachricht senden

```bash
# Manuell eine Test-Nachricht senden (curl direkt)
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=123456789&text=Flux Test: Kubernetes Lab ist alive"
```

## Flux Notification Events

| Event | Wann |
|-------|------|
| `info` | Deployment erfolgreich, Git pull war okay |
| `error` | Health Check failed, Reconciliation fehlgeschlagen |
| `debug` | Jedes Detail (nur bei Problemen) |

## Troubleshooting

### Bot antwortet nicht
- BotFather Token prüfen
- Chat ID prüfen (ist sie positiv für Direkt-Chat?)
- Bot muss mindestens eine Nachricht empfangen haben (getUpdates)

### Notification kommt nicht an
```bash
# Logs vom Notification Controller
kubectl logs -n flux-system deployment/notification-controller

# Event Sources prüfen
flux get event-sources

# Provider Status
flux get alert-providers
```

## Nächste Schritte

1. [ ] Bot Token besorgen (Marcus: @BotFather)
2. [ ] Chat ID ermitteln
3. [ ] Provider + Alert YAML erstellen
4. [ ] Test-Nachricht senden
5. [ ] Flux committen + pushen

---

## Compliance Referenzen

### NIS2 Art. 23 — Vorfallmeldung

NIS2 Art. 23 fordert:
> "Meldepflichtige Sicherheitsvorfälle sind den zuständigen Behörden unverzüglich, spätestens aber 24 Stunden nach Kenntnisnahme zu melden"

Telegram Alerts ermöglichen:
- **Sofortige Benachrichtigung** des Platform Teams
- **Dokumentation** der Vorfallzeitpunkte (Message History)
- **Schnelle Reaktion** um 24h-Frist einzuhalten

### BSI IT-Grundschutz OPS.1.1.3

**M3: Eskalationskonzept**
> "Bei sicherheitsrelevanten Ereignissen muss ein definiertes Eskalationsverfahren greifen"

Flux Telegram Notifications = Eskalationsstufe 1:
1. Flux erkennt Problem (K8s Event)
2. Telegram Alert an Platform Team
3. Team beginnt Incident Response

### ISO 27001 A.16.1.2

**Reporting Information Security Events:**
> "Informationssicherheitsvorfälle sind so schnell wie möglich zu melden"

Telegram als Kanal erfüllt:
- Near-real-time Benachrichtigung
- Gruppensupport für Incident Teams
- Message-Timestamps als Audit Trail

---

*Quelle: fluxcd.io/docs/flux/notifications*
*Erstellt: 2026-04-21*
