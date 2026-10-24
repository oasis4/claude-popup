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

- **Erscheint auch bei „Nicht stören“**, weil es ein eigenes Fenster ist und kein Windows-Toast.
- **Taucht auf dem Monitor auf, auf dem gerade deine Maus ist**, unten rechts.
- **Zeigt den echten Inhalt:** den Text der Anfrage bzw. die erste Zeile der Antwort, dazu den Projektordner.
- **✓** schließt es sofort, **„Zur Session“** holt das Terminal bzw. Claude Desktop nach vorne.
- **Blendet sich nach 8 Sekunden aus**, außer die Maus ist darauf.
- **Bleibt still, wenn die Session schon im Vordergrund ist.**
- **Immer nur ein Popup:** Ein neues ersetzt das alte.
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
- In Claude Desktop löst der `Notification`-Hook je nach Version bei Berechtigungsanfragen eventuell nicht aus. Der `Stop`-Hook funktioniert.

## Deinstallieren

```
/plugin uninstall session-popup@session-popup
```
