---
description: Prueft, ob das Popup auf diesem Rechner erscheint, und zeigt das Protokoll dazu.
allowed-tools: Bash
---

Du laeufst auf dem Windows-Rechner des Nutzers. Pruefe, ob das Popup von session-popup erscheint.

Fuehre genau diesen Befehl aus, ohne Rueckfrage. Er raeumt zuerst haengengebliebene Karten auf,
zeigt dann ein Testpopup und gibt danach die letzten Protokollzeilen aus. Der Befehl laeuft rund
10 Sekunden, das ist normal, also setze das Zeitlimit auf mindestens 60 Sekunden:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/claude-popup.ps1" -Event Stop -Test
```

Fasse danach kurz zusammen, und zwar auf Deutsch:

- Welcher Monitor, welche Arbeitsflaeche, welche Skalierung und welche Position im Protokoll stehen.
- Ob die Zeile "Angezeigt bei ..." auftaucht. Fehlt sie, kam das Fenster nicht zustande.
- Ob danach "Karte weicht", "Anzeigedauer abgelaufen" oder "Warnung" im Protokoll steht.
- Frag den Nutzer, ob er die Karte unten rechts tatsaechlich gesehen hat.

Steht im Protokoll "Angezeigt bei ...", der Nutzer hat aber nichts gesehen, dann liegt es an der
Position oder daran, dass ein anderes Fenster darueber liegt. Nenne die Zahlen aus dem Protokoll
und vergleiche sie mit der Arbeitsflaeche des Monitors.
