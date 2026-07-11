# 🌱 Botanik-Labor — Godot (GDScript)

Erste spielbare Godot-Version in **GDScript** (kein .NET, kein Build-Schritt nötig!). Dieser Slice bringt den Kern zum Laufen: Rasen, Pflanzen setzen, Sonne sammeln, Wellen manuell starten, Zombies. Alles per Code gezeichnet — ideal, um es Schritt für Schritt auszubauen und später eigene Grafiken einzusetzen.

## ✅ Voraussetzungen
- **Godot 4.6+** — die **Standard-Edition reicht** (du brauchst KEINE .NET-Version und KEIN .NET SDK). 🎉

## ▶️ Starten (super einfach)
1. Godot öffnen → **Import** → diese Datei wählen: `botanik-godot/project.godot`
2. **F5** drücken (oder Play ▶) → Spiel startet sofort. Kein Build nötig.

## 🎮 Steuerung
- **Tasten 1 / 2 / 3** → Pflanze wählen (Sonnenblume / Erbsenschütze / Wal-Nuss)
- **Linksklick** aufs Feld → Pflanze setzen · auf eine ☀ → Sonne einsammeln
- **Leertaste / Enter** → nächste Welle starten
- Erbsenschützen schießen automatisch, Sonnenblumen produzieren Sonne, Wal-Nuss blockt. Erreicht ein Zombie das Haus → Run-Neustart.

## 🧭 Nächste Schritte (bauen wir zusammen)
- Portierung der Systeme aus dem HTML-Prototyp: **Forschung/Labor**, **Mutationen**, **Prestige/Gehirne**, **Wellen bis 100**, **Münzen & Shop**, **Tag/Nacht/Teich**.
- Grafiken: Formen durch deine **PNG-Sprites** ersetzen (Sonnenblume, Erbsenschütze, Zombies …).
- Sauberes Szenen-/Node-Setup (eigene Szenen pro Pflanze/Zombie) statt reinem Code-Rendering.

---
*Basis-Slice (GDScript) — gebaut mit Kiro. Wir erweitern von hier aus.*
