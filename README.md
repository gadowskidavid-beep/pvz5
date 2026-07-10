# 🧬🧟 Botanik-Labor — Incremental Tower-Defense

Ein aufgeräumtes, **einfaches** Incremental im Plants-vs-Zombies-Stil auf **einem Bildschirm**. Farme dich Stufe für Stufe hoch, **starte die Wellen selbst**, und schaffe das Ziel: **überlebe Welle 100**. Verlierst du, startest du neu — **Gehirne bleiben** für dauerhafte + einzigartige Upgrades. Alles in einer einzigen `index.html`.

## ▶️ Spielen
[`index.html`](index.html) im Browser öffnen, oder per **GitHub Pages**
(*Settings → Pages → Branch `main`*): `https://gadowskidavid-beep.github.io/pvz5/`

## 🎮 So läuft's
1. Du startest **nur mit der Sonnenblume**. Setze sie für Sonne.
2. **Klicke Zombies direkt an** (ohne gewählte Pflanze) = Klick-Schaden — so farmst du am Anfang 🧬 FP.
3. **Wellen startest du selbst** über den großen Button „🌊 Welle X starten". Dazwischen ist Vorbereitungszeit: platzieren, sammeln, forschen.
4. Zombies droppen **🧬 FP**. Im **Forschungslabor** kaufst du:
   - **⚛ Wissenschaft** — geleverte, **immer farmbare** Upgrades (Schaden, Feuerrate, Klick-Kraft, HP, Sonne, Münzen, FP). Erste Stufen billig (4–8 FP), Kosten steigen pro Stufe.
   - **🌱 Pflanzen** freischalten (Erbsenschütze → Wand → Werfer → Stachel → Nebler → Bombe → Beam).
   - **🛠 Ausrüstung** (Almanach, Schaufel, Zeitkontrolle, extra Reihen, Rasenmäher-Zündung/Reparatur, Klick-Gold …).
5. **🪙 Münzen** (von Zombies) gibst du im **Laden** für Run-Items & Passive aus.
6. **🧠 Gehirne** (von Bossen) → **Wiedergeburt**: dauerhafte Boni + einzigartige Chain-Upgrades.

> **Wichtig:** Skills (FP, Forschung, freigeschaltete Pflanzen) werden **nicht** gespeichert — jeder Neustart ist frisch. Dauerhaft bleiben nur **Gehirne, Prestige, Chains und die Enzyklopädie**.

## 🌍 Dynamische Welt
Tag (1–9) → 🌙 **Nacht** (10–19, weniger Himmels-Sonne) → Tag (20) → 🌊 **Teich** (25+). **Mini-Boss** bei Welle 9, **Bosse** alle 15 Wellen, **Ober-Gargantuar** bei Welle 100.

## 🎨 Godot-Konzept
[`godot-concept.svg`](godot-concept.svg) zeigt, wie eine spätere **Godot/C#-Version** mit gemalten Assets/PNGs aussehen könnte (die Formen/Emojis sind Platzhalter für deine eigenen Sprites).

## ⚛️ Forschung & 🧬 Mutations-Labor
- **Forschungslabor** im **Atom-Layout**: die geleverten Upgrades kreisen als Knoten um einen leuchtenden Atomkern.
- **Mutations-Labor** — zweigeteilt:
  - **Links „Pflanzen verbessern"** (aktiv!): Kaufe Element-Mutationen 🔥 Feuer (Brand), ❄️ Eis (verlangsamt), ☠️ Gift (DoT), ⚡ Elektro (Kettenblitz). Sie wirken auf **alle deine Angriffs-Pflanzen** und lassen sich kombinieren.
  - **Rechts „Zombies stärker machen"** (Risk-Reward): Regler für Stärke/Rüstung/Geschwindigkeit → höhere **Risiko-Stufe** → **mehr 🪙/🧬/🧠** auf alle Drops.

## 🔜 Später geplant
Aquatische Teich-Mechaniken, mehr Zombie-Arten, weitere Pflanzen-Chassis.

## 🛠️ Technik
Reines HTML/CSS/JS, Canvas, `localStorage` (nur Meta). Datengetrieben (`CHASSIS`, `RESEARCH`, `EQUIP`, `SHOP_*`, `PRESTIGE`, `UNIQUE`). Prototyp für die spätere **Godot/C#-Version**.

---
*Gebaut mit Kiro.*
