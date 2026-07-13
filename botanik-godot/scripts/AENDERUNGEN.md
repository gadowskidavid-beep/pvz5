# Änderungen von Claude — 13.07.2026

Alle 4 Script-Dateien ersetzen: `botanik-godot/scripts/` (Balance.gd, Game.gd, Lawn.gd, Main.gd).
Vorher am besten einen Git-Commit machen, damit du zurück kannst!

## 1. 💥 RASEN-UMBRUCH (neu!) — Lawn.gd + Balance.gd
- Bei Welle **25 / 50 / 75** beginnt jetzt der neue Rasen GENAU auf der Boss-Welle (vorher wechselte er still eine Welle später).
- Beim Umbruch: **alle Pflanzen werden zerstört**, du bekommst **50% ihrer Sonne zurück** (`UMBRUCH_REFUND`), und die Zombie-Horde wartet **8 Sekunden Schonfrist** (`UMBRUCH_GRACE`) — aber der **Boss kommt sofort** und läuft langsam an, während du hektisch neu baust. Genau der Moment aus deiner Vision.
- Beide Werte stehen in Balance.gd und sind frei justierbar.

## 2. 🎲 ZUFÄLLIGE BOSS-REIHENFOLGE — Game.gd
- Die 3 Hauptbosse (Flammen-Gargantuar, Frost-Koloss, Gewitter-Zerstörer) werden **pro Run neu gemischt** (`boss_order.shuffle()` in `rebirth()`).
- Der finale **Untote Überlord bei Welle 100 bleibt fix**.
- Neue Funktion: `Game.boss_key_for_wave(w)` — Lawn.gd nutzt sie statt der festen Zuordnung.

## 3. 💰 FP-ERSTATTUNG BEIM SLOT-WECHSEL — Game.gd
- Wechselst du in einem Samen-Slot die Pflanze, bekommst du jetzt **50% der ausgegebenen FP der alten Skill-Knoten zurück** (vorher: Totalverlust ohne Warnung).

## 4. ⚖ BALANCING — Game.gd
- Schütze: Feuerrate **0.9 → 1.1** (Early Game weniger zäh).
- Boss-HP kräftig erhöht: boss_a 1300→**2400**, boss_b 1600→**3000**, boss_c 1800→**3600**, Megaboss 2800→**7000** (Bosse fühlten sich rechnerisch zu weich an).
- ⚠ Bitte einmal Welle 1–30 selbst testspielen und ggf. in Balance.gd/Game.gd nachjustieren.

## 5. 🧹 AUFGERÄUMT — Game.gd + Main.gd
- Alle Reste des gestrichenen Zombie-Risiko-Reglers (`zlab`) entfernt: Variable, Funktion `zlab_change`, Save/Load-Einträge, Reset-Referenz in Main.gd. Alte Savegames laden weiterhin problemlos (unbekannte Felder werden ignoriert).
- Zeilenenden aller Scripts auf LF normalisiert.

## Getestet?
Ich kann Godot hier nicht ausführen — alle Ersetzungen wurden aber automatisch auf Eindeutigkeit geprüft und die Logik gegengelesen. Bitte einmal in Godot öffnen (Fehlerkonsole checken) und Welle 24→25 anspielen: Umbruch-Meldung, Sonnen-Erstattung, 8s Ruhe, Boss läuft an.
