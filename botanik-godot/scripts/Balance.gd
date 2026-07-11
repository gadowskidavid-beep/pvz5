extends RefCounted
class_name BAL
# ================================================================
# ZENTRALE BALANCING-CONFIG  —  HIER alles nachjustieren.
# ================================================================

# ---- Wellen & Akte ----
const ACT_SIZE := 25          # Wellen pro Rasen
const FINAL_WAVE := 100
const BOSS_WAVES := [25, 50, 75, 100]
const MINIBOSS_WAVE := 9      # kleiner Extra-Boss zum Kennenlernen
const MAX_CHAINS := 3         # (nicht mehr genutzt)

# ---- Wellen-Menge (Anzahl Zombies) ----
const WAVE_BASE := 3
const WAVE_PER := 1.6

# ---- Zombie-Skalierung pro Welle ----
const Z_HP_PER_WAVE := 0.09
const Z_HP_POW := 1.5
const Z_HP_POW_MUL := 0.011
const Z_SPD_PER_WAVE := 0.012

# ---- Gehirn-Traeger (nicht jeder Zombie droppt Gehirne!) ----
const BRAIN_MIN_WAVE := 6
const BRAIN_CHANCE := 0.10

# ---- Idle-Zombies zwischen den Wellen ----
const IDLE_MIN := 5.0
const IDLE_MAX := 9.0

# ---- Dynamische Zerstoerung ----
const HAZARD_DMG := 65.0
const HAZARD_MIN := 6.0
const HAZARD_MAX := 12.0

# ---- Boss-Keys je Boss-Welle (Index passend zu BOSS_WAVES) ----
const BOSS_KEYS := ["boss_a", "boss_b", "boss_c", "megaboss"]

# ================================================================
# AKTE / RASEN
# ================================================================
const ACTS := [
	{
		"name": "Vorgarten",
		"night": false, "pond": false, "roof": false, "hazard": false,
		"g1": Color(0.23, 0.42, 0.25), "g2": Color(0.27, 0.49, 0.29),
		"spawn": [["basic", 5], ["flag", 1], ["cone", 3], ["vaulter", 1]],
	},
	{
		"name": "Nacht-Teich",
		"night": true, "pond": true, "roof": false, "hazard": false,
		"g1": Color(0.10, 0.14, 0.22), "g2": Color(0.12, 0.18, 0.26),
		"spawn": [["basic", 3], ["vaulter", 4], ["cone", 2], ["brainz", 1]],
	},
	{
		"name": "Dachterrasse",
		"night": false, "pond": false, "roof": true, "hazard": true,
		"g1": Color(0.34, 0.28, 0.24), "g2": Color(0.39, 0.32, 0.27),
		"spawn": [["cone", 3], ["bucket", 4], ["brute", 2], ["basic", 2]],
	},
	{
		"name": "Finstere Zone",
		"night": true, "pond": false, "roof": false, "hazard": true,
		"g1": Color(0.16, 0.08, 0.20), "g2": Color(0.21, 0.10, 0.26),
		"spawn": [["bucket", 3], ["brute", 3], ["vaulter", 3], ["brainz", 2], ["cone", 2]],
	},
]

# ================================================================
# STATISCHE HELFER
# ================================================================
static func act_index(w: int) -> int:
	return clampi(int((max(w, 1) - 1) / ACT_SIZE), 0, 3)
static func act_of(w: int) -> Dictionary:
	return ACTS[act_index(w)]
static func is_boss_wave(w: int) -> bool:
	return BOSS_WAVES.has(w)
static func boss_key(w: int) -> String:
	var idx := BOSS_WAVES.find(w)
	return BOSS_KEYS[idx] if idx >= 0 else ""

const START_FP := 10          # Tutorial: genau genug fuer 1 Schuetzen

# ================================================================
# EIN FOKUS-BAUM PRO PFLANZE — Mitte + 4 Element-Richtungen.
# FEUER (rechts +x) · EIS (links -x) · BLITZ (oben +y) · UNTOD (unten -y)
# Jedes Element wirkt PFLANZEN-SPEZIFISCH (siehe eff/Beschreibung).
# eff-Keys: dmg/rate/hp/amount/splash/radius (=% Bruch, rate darf negativ sein),
#           pierce/range/regen/extra_lanes (=additiv), thorns/faster (=Bruch),
#           burn/slow/poison/chain/twin (=true).
# pos: Vector2(spalte, reihe) — Mitte (0,0), 4 Arme in die Himmelsrichtungen.
# ================================================================
const PLANT_TREES := {
	"pea": {"nodes": {
		"root": {"n":"Schütze","d":"Feuert Erbsen geradeaus. Skille in die 4 Element-Richtungen.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Wucht","d":"+35% Schaden","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"c2": {"n":"Schnellfeuer","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"c3": {"n":"Zaeher Stiel","d":"+35% HP","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"hp":0.35}},
		"c4": {"n":"Durchschuss","d":"+1 Durchschuss","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"pierce":1}},
		"f1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"dmg":0.2}},
		"f2": {"n":"Feuer-Erbse","d":"+20% Feuerrate · Brand","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"burn":true,"rate":0.2}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f4": {"n":"Flammenrad","d":"+20% Schaden · +30% Feuerrate","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"rate":0.3,"dmg":0.2},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Frost-Erbse","d":"-20% Feuerrate (langsamer) · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"rate":-0.2}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e4": {"n":"Tiefkuehlung","d":"+25% Schaden · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"dmg":0.25},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Blitz-Erbse","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b4": {"n":"Gewitter-Erbse","d":"+30% Schaden · Kettenblitz","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"chain":true,"dmg":0.3},"rare":true},
		"u1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"dmg":0.2}},
		"u2": {"n":"Zweikopf-Erbse","d":"+1 Nachbarreihen","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"extra_lanes":1}},
		"u3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"dmg":0.25}},
		"u4": {"n":"Nekro-Dreikopf","d":"+1 Nachbarreihen · Gift","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"extra_lanes":1,"poison":true},"rare":true},
	}},
	"frostbluete": {"nodes": {
		"root": {"n":"Frostblüte","d":"Verlangsamt von Beginn an.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Wucht","d":"+35% Schaden","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"c2": {"n":"Schnellfeuer","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"c3": {"n":"Zaeher Stiel","d":"+35% HP","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"hp":0.35}},
		"c4": {"n":"Durchschuss","d":"+1 Durchschuss","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"pierce":1}},
		"f1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"dmg":0.2}},
		"f2": {"n":"Frostbrand","d":"+20% Feuerrate · Brand","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"burn":true,"rate":0.2}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f4": {"n":"Dampfschuss","d":"+25% Schaden · Brand","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"burn":true,"dmg":0.25},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Tiefkuehlung","d":"+20% Schaden · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"dmg":0.2}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e4": {"n":"Permafrost","d":"+20% Feuerrate · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"rate":0.2},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Eisblitz","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b4": {"n":"Frostschock","d":"+30% Schaden · Kettenblitz","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"chain":true,"dmg":0.3},"rare":true},
		"u1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"dmg":0.2}},
		"u2": {"n":"Zwei-Kristall","d":"+1 Nachbarreihen","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"extra_lanes":1}},
		"u3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"dmg":0.25}},
		"u4": {"n":"Nekro-Frost","d":"Gift","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"poison":true},"rare":true},
	}},
	"sonne": {"nodes": {
		"root": {"n":"Sonnenblume","d":"Produziert Sonne.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Ertrag","d":"+35% Sonne","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"amount":0.35}},
		"c2": {"n":"Wachstum","d":"-15% Produktionszeit","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"faster":0.15}},
		"c3": {"n":"Robuste Wurzel","d":"+40% HP","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"hp":0.4}},
		"c4": {"n":"Reiche Bluete","d":"+30% Sonne","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"amount":0.3}},
		"f1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"amount":0.2}},
		"f2": {"n":"Heisse Sonne","d":"+40% Sonne","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"amount":0.4}},
		"f3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"amount":0.25}},
		"f4": {"n":"Sonnenbrand","d":"+40% Sonne · -15% Produktionszeit","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"amount":0.4,"faster":0.15},"rare":true},
		"e1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"amount":0.2}},
		"e2": {"n":"Eisblüte","d":"+40% HP · -10% Produktionszeit","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.4,"faster":0.1}},
		"e3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"amount":0.25}},
		"e4": {"n":"Zwillingsblüte","d":"Doppelte Sonne","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"twin":true},"rare":true},
		"b1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"amount":0.2}},
		"b2": {"n":"Blitz-Sonne","d":"-20% Produktionszeit","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"faster":0.2}},
		"b3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"amount":0.25}},
		"b4": {"n":"Energiestoss","d":"+40% Sonne · -15% Produktionszeit","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"amount":0.4,"faster":0.15},"rare":true},
		"u1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"amount":0.2}},
		"u2": {"n":"Nachtsonne","d":"+30% Sonne · +2 HP/s","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"amount":0.3,"regen":2.0}},
		"u3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"amount":0.25}},
		"u4": {"n":"Nekro-Sonne","d":"+50% Sonne · +3 HP/s","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"amount":0.5,"regen":3.0},"rare":true},
	}},
	"sonnenpilz": {"nodes": {
		"root": {"n":"Sonnenpilz","d":"Billige Sonne, auch nachts.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Ertrag","d":"+35% Sonne","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"amount":0.35}},
		"c2": {"n":"Wachstum","d":"-15% Produktionszeit","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"faster":0.15}},
		"c3": {"n":"Robuste Wurzel","d":"+40% HP","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"hp":0.4}},
		"c4": {"n":"Reiche Bluete","d":"+30% Sonne","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"amount":0.3}},
		"f1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"amount":0.2}},
		"f2": {"n":"Glut-Kappe","d":"+40% Sonne","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"amount":0.4}},
		"f3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"amount":0.25}},
		"f4": {"n":"Feuer-Sporen","d":"+40% Sonne · -15% Produktionszeit","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"amount":0.4,"faster":0.15},"rare":true},
		"e1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"amount":0.2}},
		"e2": {"n":"Frost-Kappe","d":"+40% HP · -10% Produktionszeit","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.4,"faster":0.1}},
		"e3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"amount":0.25}},
		"e4": {"n":"Doppelsporen","d":"Doppelte Sonne","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"twin":true},"rare":true},
		"b1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"amount":0.2}},
		"b2": {"n":"Blitz-Kappe","d":"-20% Produktionszeit","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"faster":0.2}},
		"b3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"amount":0.25}},
		"b4": {"n":"Energiepilz","d":"+50% Sonne","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"amount":0.5},"rare":true},
		"u1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"amount":0.2}},
		"u2": {"n":"Grab-Kappe","d":"+30% Sonne · +2 HP/s","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"amount":0.3,"regen":2.0}},
		"u3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"amount":0.25}},
		"u4": {"n":"Nekro-Kappe","d":"+50% Sonne","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"amount":0.5},"rare":true},
	}},
	"wall": {"nodes": {
		"root": {"n":"Panzer-Nuss","d":"Zaeher Blocker.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Panzer","d":"+50% HP","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"hp":0.5}},
		"c2": {"n":"Heilung","d":"+3 HP/s","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"regen":3.0}},
		"c3": {"n":"Dornen","d":"Dornen 20%","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"thorns":0.2}},
		"c4": {"n":"Bunker","d":"+40% HP","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"hp":0.4}},
		"f1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"hp":0.3}},
		"f2": {"n":"Feuernuss","d":"Dornen 30%","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"thorns":0.3}},
		"f3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"hp":0.35}},
		"f4": {"n":"Lava-Nuss","d":"+30% HP · Dornen 40%","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"thorns":0.4,"hp":0.3},"rare":true},
		"e1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.3}},
		"e2": {"n":"Eisnuss","d":"+60% HP","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.6}},
		"e3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"hp":0.35}},
		"e4": {"n":"Gletscher-Nuss","d":"+80% HP · +3 HP/s","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"hp":0.8,"regen":3.0},"rare":true},
		"b1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"hp":0.3}},
		"b2": {"n":"Stahlnuss","d":"+40% HP · Dornen 35%","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"thorns":0.35,"hp":0.4}},
		"b3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"hp":0.35}},
		"b4": {"n":"Blitz-Bunker","d":"+50% HP · Dornen 50%","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"thorns":0.5,"hp":0.5},"rare":true},
		"u1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"hp":0.3}},
		"u2": {"n":"Untote Nuss","d":"Ekelhaft: Zombies wechseln beim Fressen die Lane · +5 HP/s","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"regen":5.0,"lane_switch":1.0}},
		"u3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"hp":0.35}},
		"u4": {"n":"Grab-Nuss","d":"+50% HP · +8 HP/s","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"regen":8.0,"hp":0.5},"rare":true},
	}},
	"lilypad": {"nodes": {
		"root": {"n":"Lilypad","d":"Wasser-Plattform, zaehes Blatt.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Panzer","d":"+50% HP","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"hp":0.5}},
		"c2": {"n":"Heilung","d":"+3 HP/s","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"regen":3.0}},
		"c3": {"n":"Dornen","d":"Dornen 20%","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"thorns":0.2}},
		"c4": {"n":"Bunker","d":"+40% HP","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"hp":0.4}},
		"f1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"hp":0.3}},
		"f2": {"n":"Lavapad","d":"Dornen 30%","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"thorns":0.3}},
		"f3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"hp":0.35}},
		"f4": {"n":"Magma-Pad","d":"Dornen 40%","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"thorns":0.4},"rare":true},
		"e1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.3}},
		"e2": {"n":"Eispad","d":"+60% HP","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.6}},
		"e3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"hp":0.35}},
		"e4": {"n":"Frostpad","d":"+80% HP","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"hp":0.8},"rare":true},
		"b1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"hp":0.3}},
		"b2": {"n":"Blitzpad","d":"Dornen 35%","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"thorns":0.35}},
		"b3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"hp":0.35}},
		"b4": {"n":"Gewitterpad","d":"Dornen 50%","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"thorns":0.5},"rare":true},
		"u1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"hp":0.3}},
		"u2": {"n":"Grab-Pad","d":"+5 HP/s","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"regen":5.0}},
		"u3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"hp":0.35}},
		"u4": {"n":"Seerosenblüte","d":"+9 HP/s","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"regen":9.0},"rare":true},
	}},
	"pilz": {"nodes": {
		"root": {"n":"Pilz","d":"Nacht-Sporenwolke, trifft mehrere.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Wucht","d":"+35% Schaden","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"c2": {"n":"Tempo","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"c3": {"n":"Wellenradius","d":"+30% Splash","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"splash":0.3}},
		"c4": {"n":"Zaeh","d":"+30% HP","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"hp":0.3}},
		"f1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"dmg":0.2}},
		"f2": {"n":"Brand-Sporen","d":"+20% Feuerrate · Brand","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"burn":true,"rate":0.2}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f4": {"n":"Glutwolke","d":"+20% Schaden · +30% Feuerrate","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"rate":0.3,"dmg":0.2},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Klebsporen","d":"-15% Feuerrate (langsamer) · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"rate":-0.15}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e4": {"n":"Frostnebel","d":"+20% Schaden · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"dmg":0.2},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Blitz-Sporen","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b4": {"n":"Sturmwolke","d":"+30% Schaden · Kettenblitz","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"chain":true,"dmg":0.3},"rare":true},
		"u1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"dmg":0.2}},
		"u2": {"n":"Gift-Sporen","d":"Gift","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"poison":true}},
		"u3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"dmg":0.25}},
		"u4": {"n":"Seuche","d":"+40% Schaden · Gift · Kettenblitz","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"poison":true,"chain":true,"dmg":0.4},"rare":true},
	}},
	"wasserpilz": {"nodes": {
		"root": {"n":"Wasserpilz","d":"Wirft Druckwellen (Flaeche).","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Wucht","d":"+35% Schaden","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"c2": {"n":"Tempo","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"c3": {"n":"Wellenradius","d":"+30% Splash","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"splash":0.3}},
		"c4": {"n":"Zaeh","d":"+30% HP","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"hp":0.3}},
		"f1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"dmg":0.2}},
		"f2": {"n":"Dampfwelle","d":"+20% Schaden · Brand","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"burn":true,"dmg":0.2}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f4": {"n":"Siedeflut","d":"+30% Splash · Brand","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"burn":true,"splash":0.3},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Frostwelle","d":"+20% Splash · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"splash":0.2}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e4": {"n":"Eisflut","d":"+25% Schaden · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"dmg":0.25},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Blitzwelle","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b4": {"n":"Sturmflut","d":"+30% Schaden · Kettenblitz","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"chain":true,"dmg":0.3},"rare":true},
		"u1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"dmg":0.2}},
		"u2": {"n":"Faulwasser","d":"Gift","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"poison":true}},
		"u3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"dmg":0.25}},
		"u4": {"n":"Sumpffieber","d":"+30% Splash · Gift","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"poison":true,"splash":0.3},"rare":true},
	}},
}
