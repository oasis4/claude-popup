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
- **✓** schließt es sofort, **„Zur Session“** holt das Terminal nach vorne, in Claude Desktop heißt der Button **„Claude öffnen“** und holt das Desktop-Fenster nach vorne.
- **Blendet sich nach 8 Sekunden aus**, außer die Maus ist darauf.
- **Bleibt still, wenn das Terminal der Session schon im Vordergrund ist.** In Claude Desktop kommt es immer, weil dort mehrere Sessions im selben Fenster laufen und nicht erkennbar ist, welche gerade offen ist.
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
- In Claude Desktop kann das Popup nicht auf einen bestimmten Chat umschalten. Claude Desktop bietet dafür bisher keinen offiziellen Weg (die `claude://` Links können nur neue Code-Sessions öffnen). Wenn mehrere Chats offen sind, erkennst du am Projektnamen im Popup, welcher fertig ist, und wählst ihn in der Seitenleiste aus.
- In Claude Desktop löst der `Notification`-Hook je nach Version bei Berechtigungsanfragen eventuell nicht aus. Der `Stop`-Hook funktioniert.

## Deinstallieren

```
/plugin uninstall session-popup@session-popup
```
