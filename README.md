# 🌻 Garten der Verteidigung 🧟

Ein **Incremental-/Idle-Spiel**, das im **Plants-vs-Zombies-Gameplay** gipfelt — komplett in einer einzigen `index.html` (kein Build, keine Abhängigkeiten).

## ▶️ Spielen

Öffne einfach die Datei [`index.html`](index.html) in einem Browser.

Alternativ über **GitHub Pages**: In den Repo-Einstellungen unter *Settings → Pages* den `main`-Branch als Quelle wählen — danach ist das Spiel unter `https://gadowskidavid-beep.github.io/pvz5/` spielbar.

## 🎮 So funktioniert es

### Phase 1 — Der Garten (Idle)
- Klicke die große ☀️ **Sonne**, um Sonne zu sammeln.
- Kaufe im **Laden**: Klick-Upgrades, Sonnenblumen (Auto-Produktion) und Wachstums-Boosts.
- Erreiche **Meilensteine**, die nacheinander Pflanzen und schließlich den Verteidigungs-Modus freischalten:

| Gesamt-Sonne | Freischaltung |
|---|---|
| 50 | 🌱 Erbsenschütze |
| 150 | 🛡️ **Verteidigungs-Modus** |
| 200 | 🌰 Walnuss |
| 600 | ❄️ Eis-Erbse (verlangsamt) |
| 1200 | 🌿 Doppel-Schütze |
| 2000 | 🍒 Kirschbombe (Flächenschaden) |

### Phase 2 — Die Verteidigung (Plants vs Zombies)
- 5×9-Rasen: oben eine Pflanze wählen, dann aufs Feld klicken zum Pflanzen.
- Fallende ☀️ anklicken und Sonnenblumen erzeugen Kampf-Sonne.
- Zombie-Wellen (🧟 normal / Kegelhut / Eimer) laufen von rechts an.
- Überlebe alle Wellen → **Sonnen-Belohnung** im Garten. Jeder Sieg macht den nächsten Kampf schwerer.
- Erreicht ein Zombie dein Haus → verloren.

Der Fortschritt wird automatisch im Browser (`localStorage`) gespeichert.

---

*Gebaut mit Kiro.*
