# 🌱 Botanik-Labor — Godot (C#)

Erste spielbare Godot-Version im **C# / .NET**-Stack. Dieser Slice bringt den Kern zum Laufen: Rasen, Pflanzen setzen, Sonne sammeln, Wellen manuell starten, Zombies. Alles per Code gezeichnet — ideal, um es Schritt für Schritt auszubauen und später eigene Grafiken einzusetzen.

## ✅ Voraussetzungen
- **Godot 4.6+ — die „.NET"-Edition** (auf der Download-Seite die Variante mit **C#/.NET**, nicht die Standard-Version!)
- **.NET SDK 8** installiert (`dotnet --version` sollte 8.x zeigen)

## ▶️ Starten (wichtig, in dieser Reihenfolge)
1. Godot (.NET) öffnen → **Import** → diese Datei wählen: `botanik-godot/project.godot`
2. Godot erkennt C#. Erzeuge die C#-Solution:
   **Menü oben: Project → Tools → C# → „Create C# solution"** (falls nicht automatisch angeboten).
3. Oben rechts auf den **Build-Button (Hammer 🔨)** klicken und warten, bis „Build succeeded" erscheint.
4. **F5** drücken (oder Play ▶) → Spiel startet.

## 🎮 Steuerung
- **Tasten 1 / 2 / 3** → Pflanze wählen (Sonnenblume / Erbsenschütze / Wal-Nuss)
- **Linksklick** aufs Feld → Pflanze setzen · auf eine ☀ → Sonne einsammeln
- **Leertaste / Enter** → nächste Welle starten
- Erbsenschützen schießen automatisch, Sonnenblumen produzieren Sonne, Wal-Nuss blockt. Erreicht ein Zombie das Haus → Run-Neustart.

## 🛠️ Troubleshooting
- **„NuGetSdkResolver" / SDK-Version-Fehler:** Das passiert, wenn eine `.csproj` mit falscher `Godot.NET.Sdk`-Version existiert. Lösung: Lass Godot die Solution neu erzeugen (Schritt 2) — dann stimmt die Version automatisch zu deinem Godot.
- **C# baut nicht:** Prüfe, dass du die **.NET-Edition** von Godot nutzt und das **.NET SDK 8** installiert ist.
- **Kein Text sichtbar:** Alles gut — der HUD-Text nutzt Godots Standardschrift.

## 🧭 Nächste Schritte (bauen wir zusammen)
- Portierung der Systeme aus dem HTML-Prototyp: **Forschung/Labor**, **Mutationen**, **Prestige/Gehirne**, **Wellen bis 100**, **Münzen & Shop**, **Tag/Nacht/Teich**.
- Grafiken: Shapes durch deine **PNG-Sprites** ersetzen (Sonnenblume, Erbsenschütze, Zombies …).
- Sauberes Szenen-/Node-Setup (eigene Szenen pro Pflanze/Zombie) statt reinem Code-Rendering.

---
*Basis-Slice — gebaut mit Kiro. Wir erweitern von hier aus.*
