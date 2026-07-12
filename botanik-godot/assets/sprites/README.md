# Sprites — Anleitung (Freelancer-Brief)

Lege PNG-Dateien (transparenter Hintergrund) mit **exakt diesen Namen** in die passenden Ordner.
Sobald eine Datei da ist, nutzt das Spiel automatisch das Sprite statt der gezeichneten Grafik.
Fehlt eine Datei, wird weiter die eingebaute Grafik gezeichnet (nichts bricht).

## Format
- **PNG**, transparenter Hintergrund
- Empfohlene Groesse: **96x96 px** (min. 64x64). Quadratisch.
- Pixel-Art wird scharf skaliert (Nearest-Filter ist im Spiel aktiv).
- Blickrichtung: Pflanzen schauen/schiessen nach **rechts**, Zombies laufen nach **links**.

## Pflanzen  ->  `assets/sprites/plants/<name>.png`
| Datei | Pflanze |
|-------|---------|
| `sonne.png` | Sonnenblume |
| `pea.png` | Erbsen-Schuetze |
| `wall.png` | Panzer-Nuss |
| `pilz.png` | Angriffs-Pilz (Nacht) |
| `sonnenpilz.png` | Sonnen-Pilz (Nacht) |
| `lilypad.png` | Seerosenblatt (Wasser) |
| `wasserpilz.png` | Wasserpilz |
| `frostbluete.png` | Frostbluete |

## Zombies  ->  `assets/sprites/zombies/<name>.png`
| Datei | Zombie |
|-------|--------|
| `basic.png` | Standard-Zombie |
| `flag.png` | Fahnen-Zombie |
| `cone.png` | Huetchen-Zombie |
| `vaulter.png` | Stangenspringer |
| `bucket.png` | Eimer-Zombie |
| `brainz.png` | Hirn-Traeger |
| `brute.png` | Grobian |
| `balloon.png` | Ballon-Zombie (fliegt) |
| `sprinter.png` | Renn-Zombie |
| `shield.png` | Schild-Zombie |
| `miniboss.png` | Mini-Boss |
| `boss_a.png` | Feuer-Boss (W25) |
| `boss_b.png` | Eis-Boss (W50) |
| `boss_c.png` | Blitz-Boss (W75) |
| `megaboss.png` | Untoter Ueberlord (W100) |

## Sonne (Sammel-Objekt)  ->  `assets/sprites/sun.png`
Die kleine einsammelbare Sonne.

## Hochladen
- Auf github.com: in den jeweiligen Ordner -> "Add file" -> "Upload files" -> committen.
- Danach Bescheid geben — der Rest laeuft automatisch.

## Animationen (spaeter)
Falls du animierte Sprites willst (mehrere Frames), sag Bescheid — dann erweitere ich das
System auf `pea_0.png`, `pea_1.png`, ... (oder ein Spritesheet) mit Frame-Timer.
