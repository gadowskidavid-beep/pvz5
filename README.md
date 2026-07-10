# 🌻🧬 Botanik-Labor 🧟

Ein **Incremental-Spiel**, in dem du dir deine Pflanzen **selbst baust** — statt fertige Pflanzen freizuschalten, erforschst du Gene im **Skilltree** und kombinierst sie im **Labor** zu eigenen Samenpacks. Danach verteidigst du damit den Rasen im **Plants-vs-Zombies-Stil**. Alles in einer einzigen `index.html`, ohne Build und ohne Abhängigkeiten.

## ▶️ Spielen

Öffne [`index.html`](index.html) in einem Browser.

Oder per **GitHub Pages**: *Settings → Pages → Branch `main`* wählen → spielbar unter
`https://gadowskidavid-beep.github.io/pvz5/`

## 🔁 Der Spielablauf

1. **🌱 Garten** — Klicke Sonne, kaufe Idle-Sonnenblumen & Upgrades. Sonne finanziert Forschung und platziert Pflanzen im Kampf.
2. **🔬 Forschung (Skilltree)** — Gib Forschungspunkte aus (aus Siegen + mit Sonne finanziert). Schalte frei:
   - **Chassis** (Basis): Schütze, Werfer, Nebler, Wand, Stachel, Sonne, Bombe, Beam
   - **Gene**: Eis ❄️, Feuer 🔥, Gift ☠️, Elektro ⚡, Doppelschuss, Dreispur, Durchschlag, Reichweite+, Panzerung+, Sonnenbonus, Flugabwehr 🎈, Schnellfeuer
   - **Passive**: +Schaden, +HP, +Sonne, günstigere Packs
3. **🧪 Labor** — Kombiniere **1 Chassis + bis zu 3 Gene** zu deinem eigenen Samenpack. Beispiele:
   - `Werfer + Feuer + Dreispur` = Flammen-Katapult über 3 Reihen 🔥
   - `Beam + Durchschlag + Eis` = durchdringender Frost-Laser 🔺
   - `Wand + Panzerung` = Panzermauer 🧱
   Kosten & Werte werden automatisch aus den Bausteinen berechnet. Benenne es, wähle ein Emoji, speichere.
4. **🛡️ Loadout & Kampf** — Wähle bis zu 8 deiner Packs, dann verteidige den 5×9-Rasen gegen Zombie-Wellen.

## 🧟 Gegner & Hilfen
- Zombie-Typen: normal, Hütchen, **Eimer**, **Fahne** (Anführer), **Ballon** (fliegt — nur mit Flugabwehr-Gen treffbar!), **Stangenspringer** (überspringt die erste Pflanze).
- **Rasenmäher** 🚜 retten dich **einmal pro Reihe**.
- Jeder Sieg gibt Sonne **und** Forschungspunkte und erhöht die Wellenzahl im nächsten Kampf.

## 🛠️ Technik
- Reines HTML/CSS/JavaScript, Canvas-Rendering, `localStorage`-Speicherung.
- Datengetriebenes System (`CHASSIS`, `GENES`, `PASSIVES`, `computeStats`) → beliebig viele eigene Pflanzen.
- Prototyp für die spätere **Godot/C#-Version**.

---

*Gebaut mit Kiro.*
