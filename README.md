# 🧬🧠 Botanik-Labor — Idle-Roguelike

Ein **Idle-Roguelike** im Plants-vs-Zombies-Stil, bei dem du dir deine Pflanzen **selbst zusammenbaust**. Du erforschst Gene in einem interaktiven **Fokusbaum**, kombinierst sie im **Labor** zu eigenen Pflanzen und verteidigst damit einen **endlosen Rasen**. Zombies droppen **Gehirne 🧠**, die du bei der **Wiedergeburt** in permanente Boni investierst. Alles in einer einzigen `index.html`.

## ▶️ Spielen
Öffne [`index.html`](index.html) im Browser, oder per **GitHub Pages**:
*Settings → Pages → Branch `main`* → `https://gadowskidavid-beep.github.io/pvz5/`

## 🔁 Der Loop
1. **🔬 Forschung** — Zieh-/Zoom-barer Fokusbaum. Gib **Forschungspunkte (FP)** aus (aus Kämpfen), um **Chassis** (Pflanzentypen) und **Attribute** (Gene) freizuschalten.
2. **📋 Attribute** — Tabelle deines gesamten Wissens: erforscht vs. verschlossen, nach Typ (Offensiv / Defensiv / Global).
3. **🧪 Labor** — Kombiniere **1 Chassis + bis zu 3 Attribute** zu einer eigenen Pflanze. Kosten & Werte werden automatisch berechnet. Globale Attribute wirken automatisch auf alles.
4. **📦 Sammlung** — deine erschaffenen Pflanzen.
5. **🌱 Rasen** — Idle-Roguelike-Kampf: **Start mit nur 1 Reihe** und wenig Sonne. Endlose, stärker werdende Wellen. Setze Pflanzen, sammle ☀, überlebe so lange wie möglich. **Zombies droppen 🧠 Gehirne.** Rasenmäher retten jede Reihe einmal.
6. **🧠 Wiedergeburt (Prestige)** — Investiere Gehirne dauerhaft:
   - 🌱 **Neue Reihe** (1 → 5)
   - ☀ **Start-Sonne**, 🌞 **Sonnenfluss** (passive Sonne)
   - 💥 **Schaden**, 💚 **Pflanzen-HP**, 🧠 **Gehirn-Multiplikator**
   - 🤖 **Auto-Gärtner** (platziert Pflanzen automatisch → mehr idle)

   Danach startest du einen neuen, stärkeren Run. Der Sucht-Loop. 🔁

## ⚙️ Systeme
- **Chassis (Kampfverhalten):** Schütze, Wand, Werfer, Stachel, Sonne, Nebler, Bombe, Beam.
- **Attribute:** Eis, Feuer, Gift, Elektro (Kettenblitz), Durchschlag, Doppelschuss, Dreispur, Tempo, Flugabwehr, Reichweite+, Panzerung+, Sonnenbonus + globale (Schaden/Sonne/Kosten/Tempo/Start-Sonne).
- **Zombies:** normal, Hütchen, Eimer, Fahne, **Ballon** (fliegt — braucht Flugabwehr!), **Stangenspringer**.
- Fortschritt (FP, Gehirne, Prestige, Forschung, Sammlung) wird automatisch im Browser gespeichert.

## 🛠️ Technik
- Reines HTML/CSS/JS, Canvas-Rendering (Fokusbaum + Rasen), `localStorage`.
- Datengetrieben (`CHASSIS`, `ATTR`, `PRESTIGE`, `computeBattleStats`).
- Basiert auf dem UI-Prototyp des Spielers; Prototyp für die spätere **Godot/C#-Version**.

---
*Gebaut mit Kiro.*
