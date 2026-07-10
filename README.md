# 🧬🧟 Botanik-Labor — Single-Screen Idle-Roguelike

Alles auf **einem Bildschirm**: Der **Rasen läuft immer**. Erforsche einen **riesigen Fokusbaum**, schalte Pflanzen (Chassis) + Mutationen frei, **klicke Zombies für Schaden & Münzen**, gib Münzen im **In-Run-Laden** für Items & Passive aus — und schaffe das große Ziel: **überlebe Welle 100!** Verlierst du, fängst du neu an, behältst aber **Gehirne** für **einzigartige Upgrade-Chains**. Alles in einer einzigen `index.html`.

## ▶️ Spielen
[`index.html`](index.html) im Browser öffnen, oder per **GitHub Pages**
(*Settings → Pages → Branch `main`*): `https://gadowskidavid-beep.github.io/pvz5/`

## 🎯 Ziel & Loop
- **Ziel:** Überlebe bis **Welle 100** → Sieg mit großer Gehirn-Belohnung.
- **Niederlage:** Run startet neu — **Gehirne bleiben** und fließen in permanente + einzigartige Upgrades.
- **Loop:** Zombies klicken/besiegen → 🧬 FP + 🪙 Münzen → forschen & im Laden kaufen → tiefer kommen → Bosse geben 🧠 → Prestige → stärker neu starten.

## 💰 Ressourcen
- **☀ Sonne** — im Run, platziert Pflanzen.
- **🧬 FP** — von Zombies, für den Fokusbaum (permanent).
- **🪙 Münzen** — im Run, für den **Laden** (Items + Passive). Anklicken & Kills geben Münzen.
- **🧠 Gehirne** — nur von **Bossen**, für Wiedergeburt + einzigartige Chains (permanent).

## 🖱️ Klick-Kampf
Ohne gewählte Pflanze **Zombies direkt anklicken** = Klick-Schaden (+ Münzen mit „Klick-Gold"). Im Baum aufrüstbar: *Starker Finger*, *Presslufthammer*, *Blitzfinger* (trifft 3 Zombies). Zusätzlich im Laden: *Eisenfaust*.

## 🔬 Fokusbaum (pan/zoom, 67 Knoten)
- **Chassis:** Sonne, Erbsenschütze, Wand, Werfer, Stachel, Nebler, Bombe, Beam — je eigener Mutations-Ast (Feuer, Eis, Gift, Krit, Durchschuss, Dreispur, Twin-Flower, Solar-Laser, Dornen …).
- **🌊 Feld/Rasen:** 2./3. Reihe, Sonne schneller & mehr wert, **Rasenmäher per Klick** & **Respawn (5 Min)** + Turbo.
- **🪙 Klick & Münzen:** Münz-Boni + Klick-Schaden.
- **Meta:** +FP, +Schaden, +Sonne, Lockstoff. **Utility:** Almanach, Schaufel, Zeitkontrolle, Zombie-Buch, Labor.

## 🪙 In-Run-Laden
- **Items:** Sofort-Sonne, Schockfrost (alle einfrieren), Bomben-Regen (Flächenschaden), Mäher-Service.
- **Passive (ganzer Run, steigende Kosten):** Kampfrausch, Adrenalin, Sonnenkraft, Eisenfaust, Münz-Magnet.

## 🌍 Dynamische Welt
- **Welle 1–9:** Tag · **Welle 9:** Mini-Boss 👺
- **Welle 10–19:** 🌙 Nacht (weniger Himmels-Sonne!)
- **Welle 20+:** Tag · **Welle 25+:** 🌊 Teich
- **Bosse** alle 15 Wellen 👹 · **Welle 100:** Ober-Gargantuar 👿 (Finale). Wellen werden stetig härter.

## 🧠 Wiedergeburt
Permanente Stufen (Reihen, Sonne, Schaden, HP, Gehirn-Multi, Auto-Gärtner) **und einzigartige Chains**: Erststart → Ersatz-Mäher → Sparschwein (Münz-Übertrag) → Overkill (+Krit) → Zweites Leben (überlebe 1 Niederlage/Run).

## 🛠️ Technik
Reines HTML/CSS/JS, Canvas (Baum + Rasen), `localStorage`. Datengetrieben (`CHASSIS`, `MUT`, `ECON`, `SHOP_*`, `UNIQUE`, `PRESTIGE`, `computeChassisStats`). Prototyp für die spätere **Godot/C#-Version**.

---
*Gebaut mit Kiro.*
