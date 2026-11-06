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
- **Blendet sich nach 10 Sekunden aus**, außer die Maus ist darauf. Wartet Claude auf eine Antwort, bleibt die Karte 30 Sekunden stehen, weil du dann wirklich etwas tun musst. Beides ist einstellbar.
- **Bleibt still, wenn Claude nur fertig ist und das Terminal der Session schon im Vordergrund ist.** Wartet Claude dagegen auf dich, kommt das Popup trotzdem: das Fenster kann vorne sein, während darin ein anderer Tab sichtbar ist. In Claude Desktop kommt es immer, weil dort mehrere Sessions im selben Fenster laufen und nicht erkennbar ist, welche gerade offen ist.
- **Stapelt sich bei mehreren Sessions.** Jede Session bekommt eine eigene Karte, die neueste unten, ältere darüber. Es sind höchstens 4 Karten gleichzeitig sichtbar, einstellbar. Meldet sich dieselbe Session erneut, ersetzt die neue Karte ihre alte.
- **Läuft asynchron**, Claude wartet nicht darauf.

## Installation

In Claude Code:

```
/plugin marketplace add oasis4/claude-popup
/plugin install session-popup@session-popup
```

Danach Claude Code bzw. Claude Desktop neu starten.

## Einstellungen

Alles Weitere läuft über Umgebungsvariablen, zum Beispiel in `.claude/settings.json` unter `env`:

```json
{
  "env": {
    "CLAUDE_POPUP_SECONDS": "10",
    "CLAUDE_POPUP_WAIT_SECONDS": "30",
    "CLAUDE_POPUP_ALWAYS": "0",
    "CLAUDE_POPUP_MAX": "4"
  }
}
```

| Variable | Bedeutung | Standard |
| --- | --- | --- |
| `CLAUDE_POPUP_SECONDS` | Anzeigedauer in Sekunden, wenn Claude fertig ist. Bei `0` bleibt die Karte stehen, bis du klickst, höchstens 5 Minuten | `10` |
| `CLAUDE_POPUP_WAIT_SECONDS` | Anzeigedauer, wenn Claude auf eine Freigabe oder Antwort wartet | `30` |
| `CLAUDE_POPUP_ALWAYS` | `1` zeigt das Popup auch dann, wenn das Terminal der Session schon im Vordergrund ist | `0` |
| `CLAUDE_POPUP_MAX` | Wie viele Karten höchstens gleichzeitig zu sehen sind | `4` |

## Voraussetzungen

- Windows 10/11 mit Windows PowerShell 5.1 (vorinstalliert)
- Claude Code im Terminal oder in Claude Desktop

## Hinweise

- „Zur Session“ holt das Terminal-*Fenster* nach vorne. Bei mehreren Tabs im selben Fenster wechselt es nicht zwingend auf den richtigen Tab.
- Läuft Claude Code im Terminal von VS Code oder einer anderen App, holt „Zur Session“ das Fenster dieser App nach vorne.
- In Claude Desktop kann das Popup nicht auf einen bestimmten Chat umschalten. Claude Desktop bietet dafür bisher keinen offiziellen Weg (die `claude://` Links können nur neue Code-Sessions öffnen). Ist Claude Desktop beim Erscheinen des Popups schon vorne, zeigt es deshalb keinen Button, sondern den Hinweis, zu welchem Projekt du in der Seitenleiste wechseln sollst.
- Bei Berechtigungsanfragen kommt das Popup erst, wenn die Anfrage etwa 6 Sekunden unbeantwortet ist. Antwortest du vorher, bleibt es still.

## Wenn kein Popup kommt

Erster Schritt, in Claude Code:

```
/popup-test
```

Das räumt hängengebliebene Karten auf, zeigt ein Testpopup und gibt danach das Protokoll aus. Kommt dabei eine Karte, funktioniert das Popup grundsätzlich, und es liegt an einer der Regeln oben, also daran, dass Claude nur fertig war und das Terminal vorne, oder dass die Karte nach 10 Sekunden schon weg war.

Von Hand geht dasselbe in Windows PowerShell so, ohne den Installationspfad zu kennen:

```powershell
$s = Get-ChildItem "$env:USERPROFILE\.claude\plugins" -Recurse -Filter claude-popup.ps1 | Select-Object -First 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $s.FullName -Event Stop -Test
```

Kommt auch im Test keine Karte, hilft das Protokoll weiter.

## Protokoll

Das Popup schreibt bei jedem Erscheinen und jedem Klick nach `%TEMP%\claude-popup.log`, rund 300 KB, danach wandert das Alte nach `claude-popup.log.alt`. Drücke Windows+R und gib `%TEMP%\claude-popup.log` ein. Es enthält keine Nachrichten, nur Prozessnamen und Fenstertitel. Ein Fenstertitel kann je nach Terminal den Namen der Session enthalten.

Diese Zeilen sagen das Meiste:

| Zeile | Bedeutung |
| --- | --- |
| `----- Event Stop` | Der Hook hat gefeuert. Fehlt diese Zeile ganz, kommt das Problem nicht vom Skript, sondern Claude Code ruft den Hook nicht auf |
| `Terminal ist vorne und Claude ist nur fertig` | Absicht, kein Fehler. `CLAUDE_POPUP_ALWAYS=1` schaltet das ab |
| `Monitor ..., Arbeitsflaeche ...` | Auf welchem Monitor und mit welcher Skalierung gerechnet wurde |
| `Angezeigt bei links ... oben ...` | Das Fenster ist entstanden. Steht hier eine Position weit außerhalb deiner Bildschirme, liegt es an der Positionsrechnung |
| `Karte weicht` | Eine neuere Karte derselben Session hat sie ersetzt, oder es waren zu viele Karten offen |
| `Warnung: eigene Karte konnte nicht angemeldet werden` | Der Ordner `%TEMP%\claude-popup` ist nicht beschreibbar |

Wenn gar nichts mehr hilft, lösche `%TEMP%\claude-popup`. Dort melden sich die Karten an, damit sie sich stapeln. Bleiben dort Dateien von abgestürzten oder hart beendeten Popups liegen, können sie neue Popups blockieren. Seit Version 1.3.0 erkennt das Skript solche Reste selbst, aber löschen schadet nie.

## Deinstallieren

```
/plugin uninstall session-popup@session-popup
```
