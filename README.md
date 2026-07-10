# 🧬🧟 Botanik-Labor — Single-Screen Idle-Roguelike

Alles auf **einem Bildschirm**: Der **Rasen ist immer präsent** und läuft durchgehend. Du erforschst einen **riesigen Fokusbaum**, schaltest Pflanzen (Chassis) frei, verbesserst jede Pflanze mit **eigenen Mutationen**, und überlebst endlose, immer stärkere Zombie-Wellen. Zombies droppen **Forschungspunkte (🧬 FP)**, **Bosse droppen Gehirne (🧠)** für die **Wiedergeburt (Prestige)**. Alles in einer einzigen `index.html`.

## ▶️ Spielen
[`index.html`](index.html) im Browser öffnen, oder per **GitHub Pages**
(*Settings → Pages → Branch `main`*): `https://gadowskidavid-beep.github.io/pvz5/`

## 🎬 So beginnt es
Du startest **nur mit der Sonnenblume**. Zombies greifen an und überrennen dich — zum Glück mäht dein **Rasenmäher** 🚜 die erste Welle komplett nieder. Die besiegten Zombies droppen genug 🧬 FP, um im **Fokusbaum** den **Erbsenschützen** zu erforschen. Ab da öffnet sich der ganze Baum.

## 🗺️ Der Bildschirm
- **Links:** dein Pflanzen-HUD (freigeschaltete Chassis) + Werkzeuge (Schaufel).
- **Mitte:** der Rasen (läuft immer). Pflanze wählen → aufs Feld tippen. ☀ einsammeln.
- **Oben:** Ressourcen (☀ 🧬 🧠), Zeitkontrolle (⏸ 🐢 ⏩) und die Bücher/Overlays.

## 🔬 Der Fokusbaum (pan/zoom)
- **Chassis freischalten:** Sonnenblume, Erbsenschütze, Wand-Nuss, Kohl-Werfer, Stachel, Nebler, Bombe, Mais-Beam.
- **Mutationen pro Chassis**, z. B.
  - 🫛 Erbsenschütze: Feuerrate, Doppelschuss, Feuer, Eis, Durchschuss, Gift, +Schaden
  - 🌻 Sonnenblume: Twin-Flower (doppelte Sonne), Schnellblüher, **Solar-Laser** (schwacher Laser auf Cooldown)
  - 🥥 Wand: mehr HP, Dornen, Regeneration · und für jedes weitere Chassis eigene Zweige
- **Meta-Upgrades:** +FP von Zombies, +Schaden, +Sonne, Start-Sonne, „Lockstoff" (mehr Zombies & mehr FP).
- **Freischaltungen:** 📖 Almanach, 🔧 Schaufel, ⏩ Zeitkontrolle, 🧟 Zombie-Buch, 🧪 Mutations-Labor (Endgame).

## 🧠 Wiedergeburt (Prestige)
Gehirne von **Bossen** (alle 5 Wellen) bleiben dauerhaft. Kaufe: neue Reihen (1 → 5), Start-Sonne, Sonnenfluss, +Schaden, +HP, Gehirn-Multiplikator, Auto-Gärtner. Danach neuer, stärkerer Run.

## 🧟 Zombies
Zombie, Hütchen, Fahne (Anführer), Eimer, **Ballon** (fliegt — braucht Flak!), **Stangenspringer**, **Gargantuar (Boss)**. Alle werden im Zombie-Buch erfasst, sobald du ihnen begegnest.

## 🛠️ Technik
Reines HTML/CSS/JS, Canvas (Baum + Rasen), `localStorage`. Datengetrieben (`CHASSIS`, `MUT`, `META`, `UTIL`, `PRESTIGE`, `computeChassisStats`). Prototyp für die spätere **Godot/C#-Version**.

---
*Gebaut mit Kiro.*
