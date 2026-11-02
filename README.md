# session-popup

Ein dezentes Windows-Popup für Claude Code. Es erscheint, wenn Claude fertig ist oder auf dich wartet, und bringt dich mit einem Klick zurück zur Session.

```
┌────────────────────────────────────────────┐
│ ●  Claude Code  ·  mein-projekt        ✓   │
│                                            │
│ Claude braucht deine Freigabe              │
│ Claude needs your permission to use Bash   │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │          ⧉  Zur Session                │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

## Was es kann

- **Meldet sich, wenn Claude fertig ist oder dich braucht**, also bei Berechtigungsanfragen, bei Rückfragen von Claude und wenn ein Plan auf deine Freigabe wartet.
- **Erscheint auch bei „Nicht stören“**, weil es ein eigenes Fenster ist und kein Windows-Toast.
- **Taucht auf dem Monitor auf, auf dem gerade deine Maus ist**, unten rechts.
- **Zeigt den echten Inhalt:** den Text der Anfrage bzw. die erste Zeile der Antwort, dazu den Projektordner.
- **✓** schließt es sofort, **„Zur Session“** holt das Terminal nach vorne, in Claude Desktop heißt der Button **„Claude öffnen“** und holt das Desktop-Fenster nach vorne.
- **Blendet sich nach 10 Sekunden aus**, außer die Maus ist darauf.
- **Bleibt still, wenn das Terminal der Session schon im Vordergrund ist.** In Claude Desktop kommt es immer, weil dort mehrere Sessions im selben Fenster laufen und nicht erkennbar ist, welche gerade offen ist.
- **Stapelt sich bei mehreren Sessions.** Jede Session bekommt eine eigene Karte, die neueste unten, ältere darüber. Es sind höchstens 4 Karten gleichzeitig sichtbar. Meldet sich dieselbe Session erneut, ersetzt die neue Karte ihre alte.
- **Läuft asynchron**, Claude wartet nicht darauf.

## Installation

In Claude Code:

```
/plugin marketplace add oasis4/claude-popup
/plugin install session-popup@session-popup
```

Danach Claude Code bzw. Claude Desktop neu starten.

## Voraussetzungen

- Windows 10/11 mit Windows PowerShell 5.1 (vorinstalliert)
- Claude Code im Terminal oder in Claude Desktop

## Hinweise

- „Zur Session“ holt das Terminal-*Fenster* nach vorne. Bei mehreren Tabs im selben Fenster wechselt es nicht zwingend auf den richtigen Tab.
- Läuft Claude Code im Terminal von VS Code oder einer anderen App, holt „Zur Session“ das Fenster dieser App nach vorne.
- In Claude Desktop kann das Popup nicht auf einen bestimmten Chat umschalten. Claude Desktop bietet dafür bisher keinen offiziellen Weg (die `claude://` Links können nur neue Code-Sessions öffnen). Ist Claude Desktop beim Erscheinen des Popups schon vorne, zeigt es deshalb keinen Button, sondern den Hinweis, zu welchem Projekt du in der Seitenleiste wechseln sollst.
- Bei Berechtigungsanfragen kommt das Popup erst, wenn die Anfrage etwa 6 Sekunden unbeantwortet ist. Antwortest du vorher, bleibt es still.

## Wenn „Zur Session“ nicht funktioniert

Das Popup schreibt bei jedem Erscheinen und jedem Klick ein kurzes Protokoll nach `%TEMP%\claude-popup.log`. Es behält die letzten paar hundert Zeilen, also auch frühere Popups. Drücke Windows+R, gib `%TEMP%\claude-popup.log` ein und schicke den Inhalt mit, wenn du einen Fehler meldest. Es enthält keine Nachrichten, nur Prozessnamen und Fenstertitel. Ein Fenstertitel kann je nach Terminal den Namen der Session enthalten.

## Deinstallieren

```
/plugin uninstall session-popup@session-popup
```
