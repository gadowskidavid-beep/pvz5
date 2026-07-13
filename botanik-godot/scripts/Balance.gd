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

# ---- Musik / Rhythmus ----
const MUSIC_BPM := 128.0      # Takt fuer Beat-synchrones Schiessen + Pflanzen-Bounce (auf den Song stellen)
const RHYTHM_SHOOT := true    # true = Schuetzen feuern auf den Beat; false = normale Feuerrate
const MAX_CHAINS := 3         # (nicht mehr genutzt)

# ---- Wellen-Menge (Anzahl Zombies) ----
const WAVE_BASE := 4
const WAVE_PER := 2.0

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

# ---- Rasen-Umbruch (alle 25 Wellen: Map bricht um + Boss erscheint) ----
const UMBRUCH_REFUND := 0.5   # 50% Sonnen-Erstattung fuer zerstoerte Pflanzen
const UMBRUCH_GRACE := 8.0    # Sekunden Schonfrist, bevor die Horde nachrueckt

# ---- Dynamische Zerstoerung ----
const HAZARD_DMG := 65.0
const HAZARD_MIN := 6.0
const HAZARD_MAX := 12.0

# ---- Nacht-Pilze: wachsen bis zum Ablauf (Zeitdruck-Mechanik) ----
const SHROOM_LIFESPAN := 55.0     # Sekunden, dann verschwindet der Pilz
const SHROOM_GROWTH_MAX := 2.6    # Endstaerke = 2.6x (Schaden bzw. Sonne)

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
		"spawn": [["basic", 5], ["flag", 1], ["cone", 3], ["vaulter", 1], ["sprinter", 1]],
	},
	{
		"name": "Nacht-Teich",
		"night": true, "pond": true, "roof": false, "hazard": false,
		"g1": Color(0.10, 0.14, 0.22), "g2": Color(0.12, 0.18, 0.26),
		"spawn": [["basic", 3], ["vaulter", 4], ["cone", 2], ["brainz", 1], ["balloon", 2]],
	},
	{
		"name": "Dachterrasse",
		"night": false, "pond": false, "roof": true, "hazard": true,
		"g1": Color(0.34, 0.28, 0.24), "g2": Color(0.39, 0.32, 0.27),
		"spawn": [["cone", 3], ["bucket", 4], ["brute", 2], ["basic", 2], ["shield", 3], ["balloon", 1]],
	},
	{
		"name": "Finstere Zone",
		"night": true, "pond": false, "roof": false, "hazard": true,
		"g1": Color(0.16, 0.08, 0.20), "g2": Color(0.21, 0.10, 0.26),
		"spawn": [["bucket", 3], ["brute", 3], ["vaulter", 3], ["brainz", 2], ["cone", 2], ["shield", 2], ["balloon", 2], ["sprinter", 2]],
	},
]

# ================================================================
# STATISCHE HELFER
# ================================================================
static func act_index(w: int) -> int:
	# Neuer Akt beginnt AUF der Boss-Welle (25/50/75): Umbruch + Boss im selben Moment.
	return clampi(int(max(w, 1) / ACT_SIZE), 0, 3)
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
		"f2x1": {"n":"Zornknospe","d":"+15% Schaden","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"dmg":0.15}},
		"f2x2": {"n":"Flinke Ranke","d":"+15% Feuerrate","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"rate":0.15}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f3x1": {"n":"Dickes Blatt","d":"+20% HP","cost":36,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.2}},
		"f3x2": {"n":"Splitterschuss","d":"+1 Durchschuss","cost":36,"req":"f3","pos":Vector2(3,-1),"eff":{"pierce":1}},
		"f4": {"n":"Flammenrad","d":"+20% Schaden · +30% Feuerrate","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"rate":0.3,"dmg":0.2},"rare":true},
		"f4s": {"n":"Urkern","d":"Uraltes Wissen schlummert hier. +30% Schaden","cost":80,"req":"f4","pos":Vector2(5,1),"eff":{"dmg":0.3},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Frost-Erbse","d":"-20% Feuerrate (langsamer) · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"rate":-0.2}},
		"e2y1": {"n":"Bittersaft","d":"+15% Schaden","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"dmg":0.15}},
		"e2y2": {"n":"Zappelwurzel","d":"+12% Feuerrate","cost":28,"req":"e2","pos":Vector2(-2,-1),"eff":{"rate":0.12}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"e3","pos":Vector2(-3,1),"eff":{"hp":0.25}},
		"e3y2": {"n":"Nadelsturm","d":"+1 Durchschuss","cost":34,"req":"e3","pos":Vector2(-3,-1),"eff":{"pierce":1}},
		"e4": {"n":"Tiefkuehlung","d":"+25% Schaden · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"dmg":0.25},"rare":true},
		"e4s": {"n":"Herz des Waldes","d":"Das verborgene Herz. +30% Feuerrate","cost":80,"req":"e4","pos":Vector2(-5,1),"eff":{"rate":0.3},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Blitz-Erbse","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b2y1": {"n":"Dornenherz","d":"+20% Schaden","cost":28,"req":"b2","pos":Vector2(1,2),"eff":{"dmg":0.2}},
		"b2y2": {"n":"Hastknolle","d":"+15% Feuerrate","cost":28,"req":"b2","pos":Vector2(-1,2),"eff":{"rate":0.15}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b3y1": {"n":"Zaehes Mark","d":"+20% HP","cost":34,"req":"b3","pos":Vector2(1,3),"eff":{"hp":0.2}},
		"b4": {"n":"Gewitter-Erbse","d":"+30% Schaden · Kettenblitz","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"chain":true,"dmg":0.3},"rare":true},
		"b4s": {"n":"Sternsame","d":"Ein Same aus einer anderen Zeit. +30% HP","cost":80,"req":"b4","pos":Vector2(1,5),"eff":{"hp":0.3},"rare":true},
		"u1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"dmg":0.2}},
		"u2": {"n":"Zweikopf-Erbse","d":"+1 Nachbarreihen","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"extra_lanes":1}},
		"u2y1": {"n":"Zornfaser","d":"+15% Schaden","cost":28,"req":"u2","pos":Vector2(1,-2),"eff":{"dmg":0.15}},
		"u3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"dmg":0.25}},
		"u4": {"n":"Nekro-Dreikopf","d":"+1 Nachbarreihen · Gift","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"extra_lanes":1,"poison":true},"rare":true},
		"u4s": {"n":"Uralte Spore","d":"Aelter als das Labor selbst. +1 Durchschuss","cost":80,"req":"u4","pos":Vector2(1,-5),"eff":{"pierce":1},"rare":true},
	}},
	"frostbluete": {"nodes": {
		"root": {"n":"Frostblüte","d":"Verlangsamt von Beginn an.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Wucht","d":"+35% Schaden","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"c2": {"n":"Schnellfeuer","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"c3": {"n":"Zaeher Stiel","d":"+35% HP","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"hp":0.35}},
		"c4": {"n":"Durchschuss","d":"+1 Durchschuss","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"pierce":1}},
		"f1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"dmg":0.2}},
		"f2": {"n":"Frostbrand","d":"+20% Feuerrate · Brand","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"burn":true,"rate":0.2}},
		"f2x1": {"n":"Zornknospe","d":"+15% Schaden","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"dmg":0.15}},
		"f2x2": {"n":"Flinke Ranke","d":"+15% Feuerrate","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"rate":0.15}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f3x1": {"n":"Dickes Blatt","d":"+20% HP","cost":36,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.2}},
		"f3x2": {"n":"Splitterschuss","d":"+1 Durchschuss","cost":36,"req":"f3","pos":Vector2(3,-1),"eff":{"pierce":1}},
		"f4": {"n":"Dampfschuss","d":"+25% Schaden · +20% Feuerrate · Brand","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"burn":true,"dmg":0.25,"rate":0.2},"rare":true},
		"f4s": {"n":"Mondtraene","d":"Nur der Nebel kannte sie. +30% Schaden","cost":80,"req":"f4","pos":Vector2(5,1),"eff":{"dmg":0.3},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Tiefkuehlung","d":"+20% Schaden · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"dmg":0.2}},
		"e2y1": {"n":"Bittersaft","d":"+15% Schaden","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"dmg":0.15}},
		"e2y2": {"n":"Zappelwurzel","d":"+12% Feuerrate","cost":28,"req":"e2","pos":Vector2(-2,-1),"eff":{"rate":0.12}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"e3","pos":Vector2(-3,1),"eff":{"hp":0.25}},
		"e3y2": {"n":"Nadelsturm","d":"+1 Durchschuss","cost":34,"req":"e3","pos":Vector2(-3,-1),"eff":{"pierce":1}},
		"e4": {"n":"Permafrost","d":"+25% Schaden · +20% Feuerrate · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"rate":0.2,"dmg":0.25},"rare":true},
		"e4s": {"n":"Wurzelthron","d":"Hier endet der tiefste Ast. +30% Feuerrate","cost":80,"req":"e4","pos":Vector2(-5,1),"eff":{"rate":0.3},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Eisblitz","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b2y1": {"n":"Dornenherz","d":"+20% Schaden","cost":28,"req":"b2","pos":Vector2(1,2),"eff":{"dmg":0.2}},
		"b2y2": {"n":"Hastknolle","d":"+15% Feuerrate","cost":28,"req":"b2","pos":Vector2(-1,2),"eff":{"rate":0.15}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b3y1": {"n":"Zaehes Mark","d":"+20% HP","cost":34,"req":"b3","pos":Vector2(1,3),"eff":{"hp":0.2}},
		"b4": {"n":"Frostschock","d":"+30% Schaden · Kettenblitz","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"chain":true,"dmg":0.3},"rare":true},
		"b4s": {"n":"Seelenharz","d":"Es fluestert nachts. +30% HP","cost":80,"req":"b4","pos":Vector2(1,5),"eff":{"hp":0.3},"rare":true},
		"u1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"dmg":0.2}},
		"u2": {"n":"Zwei-Kristall","d":"+1 Nachbarreihen","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"extra_lanes":1}},
		"u2y1": {"n":"Zornfaser","d":"+15% Schaden","cost":28,"req":"u2","pos":Vector2(1,-2),"eff":{"dmg":0.15}},
		"u3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"dmg":0.25}},
		"u4": {"n":"Nekro-Frost","d":"+30% Schaden · +1 Nachbarreihe · Gift","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"poison":true,"extra_lanes":1,"dmg":0.3},"rare":true},
		"u4s": {"n":"Blutbluete","d":"Sie waechst nur im Verborgenen. +1 Durchschuss","cost":80,"req":"u4","pos":Vector2(1,-5),"eff":{"pierce":1},"rare":true},
	}},
	"sonne": {"nodes": {
		"root": {"n":"Sonnenblume","d":"Produziert Sonne.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Ertrag","d":"+35% Sonne","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"amount":0.35}},
		"c2": {"n":"Wachstum","d":"-15% Produktionszeit","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"faster":0.15}},
		"c3": {"n":"Robuste Wurzel","d":"+40% HP","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"hp":0.4}},
		"c4": {"n":"Reiche Bluete","d":"+30% Sonne","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"amount":0.3}},
		"f1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"amount":0.2}},
		"f2": {"n":"Feuerblume","d":"Explodiert beim Tod: entzuendet Zombies in der Naehe · +40% Sonne","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"amount":0.4,"fire_death":1.0}},
		"f2x1": {"n":"Dickes Blatt","d":"+20% HP","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"hp":0.2}},
		"f2x2": {"n":"Rindenpanzer","d":"+25% HP","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"hp":0.25}},
		"f3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"amount":0.25}},
		"f3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.25}},
		"f3y2": {"n":"Zaehes Mark","d":"+20% HP","cost":34,"req":"f3","pos":Vector2(3,-1),"eff":{"hp":0.2}},
		"f4": {"n":"Zuenderholz","d":"Groessere Todes-Explosion · +40% Sonne","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"amount":0.4,"fire_death":2.0},"rare":true},
		"e1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"amount":0.2}},
		"e2": {"n":"Eisblüte","d":"+50% HP (aus Eis, haelt mehr aus)","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.5}},
		"e2y1": {"n":"Steinhaut","d":"+25% HP","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"hp":0.25}},
		"e3": {"n":"Panzer-Eis","d":"+40% HP","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"hp":0.4}},
		"e4": {"n":"Twinflower","d":"Doppelte Sonne · +40% HP","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"twin":true,"hp":0.4},"rare":true},
		"b1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"amount":0.2}},
		"b2": {"n":"Blitzstrahl","d":"Zappt regelmaessig einen Zombie · -20% Produktionszeit","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"faster":0.2,"zap":1.0}},
		"b3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"amount":0.25}},
		"b4": {"n":"Gewitter-Blume","d":"Staerkerer & haeufigerer Zap · +30% Sonne","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"amount":0.3,"zap":2.0},"rare":true},
		"u1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"amount":0.2}},
		"u2": {"n":"Necromancer","d":"Belebt regelmaessig eine tote Pflanze wieder · +2 HP/s","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"regen":2.0,"necro":1.0}},
		"u3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"amount":0.25}},
		"u4": {"n":"Nekro-Meister","d":"Schnellere Wiederbelebung · +50% Sonne · +3 HP/s","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"amount":0.5,"regen":3.0,"necro":1.0},"rare":true},
	}},
	"sonnenpilz": {"nodes": {
		"root": {"n":"Sonnenpilz","d":"Billige Nacht-Sonne. Produziert mit der Zeit immer mehr Sonne (bis 2.6x), laeuft dann aber ab.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Ertrag","d":"+35% Sonne","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"amount":0.35}},
		"c2": {"n":"Wachstum","d":"-15% Produktionszeit","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"faster":0.15}},
		"c3": {"n":"Robuste Wurzel","d":"+40% HP","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"hp":0.4}},
		"c4": {"n":"Reiche Bluete","d":"+30% Sonne","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"amount":0.3}},
		"f1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"amount":0.2}},
		"f2": {"n":"Glut-Kappe","d":"+40% Sonne","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"amount":0.4}},
		"f2x1": {"n":"Dickes Blatt","d":"+20% HP","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"hp":0.2}},
		"f2x2": {"n":"Rindenpanzer","d":"+25% HP","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"hp":0.25}},
		"f3": {"n":"Ertrag II","d":"+25% Sonne","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"amount":0.25}},
		"f3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.25}},
		"f3y2": {"n":"Zaehes Mark","d":"+20% HP","cost":34,"req":"f3","pos":Vector2(3,-1),"eff":{"hp":0.2}},
		"f4": {"n":"Feuer-Sporen","d":"+40% Sonne · -15% Produktionszeit","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"amount":0.4,"faster":0.15},"rare":true},
		"e1": {"n":"Ertrag I","d":"+20% Sonne","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"amount":0.2}},
		"e2": {"n":"Frost-Kappe","d":"+40% HP · -10% Produktionszeit","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.4,"faster":0.1}},
		"e2y1": {"n":"Steinhaut","d":"+25% HP","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"hp":0.25}},
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
		"f2": {"n":"Feuernuss","d":"Brennt Angreifer bei Beruehrung (Feuerschaden) · Dornen 30%","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"thorns":0.3,"contact_dmg":16.0}},
		"f2x1": {"n":"Dickes Blatt","d":"+20% HP","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"hp":0.2}},
		"f2x2": {"n":"Rindenpanzer","d":"+25% HP","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"hp":0.25}},
		"f3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"hp":0.35}},
		"f3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.25}},
		"f3y2": {"n":"Zaehes Mark","d":"+20% HP","cost":34,"req":"f3","pos":Vector2(3,-1),"eff":{"hp":0.2}},
		"f4": {"n":"Lava-Nuss","d":"+30% HP · Dornen 40%","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"thorns":0.4,"hp":0.3},"rare":true},
		"e1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.3}},
		"e2": {"n":"Eisnuss","d":"2 Kacheln hoch: blockt Springer & Ueberflieger · verlangsamt Angreifer · +60% HP","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.6,"tall":1.0,"chill":1.0}},
		"e2y1": {"n":"Steinhaut","d":"+25% HP","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"hp":0.25}},
		"e3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"hp":0.35}},
		"e4": {"n":"Gletscher-Nuss","d":"+80% HP · +3 HP/s","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"hp":0.8,"regen":3.0},"rare":true},
		"b1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"hp":0.3}},
		"b2": {"n":"Stahlnuss","d":"Blitzableiter: immun gegen Umwelt-Blitz, zappt Angreifer · +40% HP · Dornen 35%","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"thorns":0.35,"hp":0.4,"lightning_rod":1.0}},
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
		"f2": {"n":"Lavapad","d":"Brennt Angreifer bei Beruehrung (Kontaktschaden) · Dornen 30%","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"thorns":0.3,"contact_dmg":14.0}},
		"f2x1": {"n":"Dickes Blatt","d":"+20% HP","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"hp":0.2}},
		"f2x2": {"n":"Rindenpanzer","d":"+25% HP","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"hp":0.25}},
		"f3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"hp":0.35}},
		"f3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.25}},
		"f3y2": {"n":"Zaehes Mark","d":"+20% HP","cost":34,"req":"f3","pos":Vector2(3,-1),"eff":{"hp":0.2}},
		"f4": {"n":"Magma-Pad","d":"Starker Kontakt-Feuerschaden · Dornen 40%","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"thorns":0.4,"contact_dmg":22.0},"rare":true},
		"e1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.3}},
		"e2": {"n":"Eispad","d":"Kuehlt das Wasser: verlangsamt Angreifer · +60% HP","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"hp":0.6,"chill":1.0}},
		"e2y1": {"n":"Steinhaut","d":"+25% HP","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"hp":0.25}},
		"e3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"hp":0.35}},
		"e4": {"n":"Frostpad","d":"Verlangsamt Angreifer · +80% HP","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"hp":0.8,"chill":1.0},"rare":true},
		"b1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"hp":0.3}},
		"b2": {"n":"Blitzpad → Katze","d":"Verwandelt sich in die Katze (Cattail): zielt automatisch auf Zombies auf ALLEN Lanes","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"aimbot":1.0}},
		"b3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"hp":0.35}},
		"b4": {"n":"Gewitter-Katze","d":"Staerkere Katze: zielt schneller & haerter auf alle Lanes","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"aimbot":2.0},"rare":true},
		"u1": {"n":"Panzerung I","d":"+30% HP","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"hp":0.3}},
		"u2": {"n":"Grab-Pad","d":"Untod-Plattform: +5 HP/s Regeneration","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"regen":5.0}},
		"u3": {"n":"Panzerung II","d":"+35% HP","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"hp":0.35}},
		"u4": {"n":"Seerosenblüte","d":"+9 HP/s Regeneration","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"regen":9.0},"rare":true},
	}},
	"pilz": {"nodes": {
		"root": {"n":"Pilz","d":"Nacht-Sporenwolke. Waechst mit der Zeit immer staerker (bis 2.6x), laeuft dann aber ab. Timing entscheidet!","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"c1": {"n":"Wucht","d":"+35% Schaden","cost":10,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"c2": {"n":"Tempo","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"c3": {"n":"Wellenradius","d":"+30% Splash","cost":10,"req":"root","pos":Vector2(1,-1),"eff":{"splash":0.3}},
		"c4": {"n":"Zaeh","d":"+30% HP","cost":10,"req":"root","pos":Vector2(-1,-1),"eff":{"hp":0.3}},
		"f1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(1,0),"eff":{"dmg":0.2}},
		"f2": {"n":"Brand-Sporen","d":"+20% Feuerrate · Brand","cost":18,"req":"f1","pos":Vector2(2,0),"eff":{"burn":true,"rate":0.2}},
		"f2x1": {"n":"Zornknospe","d":"+15% Schaden","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"dmg":0.15}},
		"f2x2": {"n":"Flinke Ranke","d":"+15% Feuerrate","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"rate":0.15}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f3x1": {"n":"Dickes Blatt","d":"+20% HP","cost":36,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.2}},
		"f3x2": {"n":"Wilder Trieb","d":"+18% Schaden","cost":36,"req":"f3","pos":Vector2(3,-1),"eff":{"dmg":0.18}},
		"f4": {"n":"Glutwolke","d":"+20% Schaden · +30% Feuerrate","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"rate":0.3,"dmg":0.2},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Klebsporen","d":"-15% Feuerrate (langsamer) · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"rate":-0.15}},
		"e2y1": {"n":"Bittersaft","d":"+15% Schaden","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"dmg":0.15}},
		"e2y2": {"n":"Zappelwurzel","d":"+12% Feuerrate","cost":28,"req":"e2","pos":Vector2(-2,-1),"eff":{"rate":0.12}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"e3","pos":Vector2(-3,1),"eff":{"hp":0.25}},
		"e3y2": {"n":"Dornenherz","d":"+20% Schaden","cost":34,"req":"e3","pos":Vector2(-3,-1),"eff":{"dmg":0.2}},
		"e4": {"n":"Frostnebel","d":"+20% Schaden · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"dmg":0.2},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Blitz-Sporen","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b2y1": {"n":"Hastknolle","d":"+15% Feuerrate","cost":28,"req":"b2","pos":Vector2(1,2),"eff":{"rate":0.15}},
		"b2y2": {"n":"Zaehes Mark","d":"+20% HP","cost":28,"req":"b2","pos":Vector2(-1,2),"eff":{"hp":0.2}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b3y1": {"n":"Zornfaser","d":"+15% Schaden","cost":34,"req":"b3","pos":Vector2(1,3),"eff":{"dmg":0.15}},
		"b3y2": {"n":"Windgeist","d":"+12% Feuerrate","cost":34,"req":"b3","pos":Vector2(-1,3),"eff":{"rate":0.12}},
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
		"f2x1": {"n":"Zornknospe","d":"+15% Schaden","cost":30,"req":"f2","pos":Vector2(2,1),"eff":{"dmg":0.15}},
		"f2x2": {"n":"Flinke Ranke","d":"+15% Feuerrate","cost":30,"req":"f2","pos":Vector2(2,-1),"eff":{"rate":0.15}},
		"f3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"f2","pos":Vector2(3,0),"eff":{"dmg":0.25}},
		"f3x1": {"n":"Dickes Blatt","d":"+20% HP","cost":36,"req":"f3","pos":Vector2(3,1),"eff":{"hp":0.2}},
		"f3x2": {"n":"Wilder Trieb","d":"+18% Schaden","cost":36,"req":"f3","pos":Vector2(3,-1),"eff":{"dmg":0.18}},
		"f4": {"n":"Siedeflut","d":"+20% Schaden · +30% Splash · Brand","cost":48,"req":"f3","pos":Vector2(4,0),"eff":{"burn":true,"splash":0.3,"dmg":0.2},"rare":true},
		"e1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(-1,0),"eff":{"dmg":0.2}},
		"e2": {"n":"Frostwelle","d":"+20% Splash · Verlangsamt","cost":18,"req":"e1","pos":Vector2(-2,0),"eff":{"slow":true,"splash":0.2}},
		"e2y1": {"n":"Bittersaft","d":"+15% Schaden","cost":28,"req":"e2","pos":Vector2(-2,1),"eff":{"dmg":0.15}},
		"e2y2": {"n":"Zappelwurzel","d":"+12% Feuerrate","cost":28,"req":"e2","pos":Vector2(-2,-1),"eff":{"rate":0.12}},
		"e3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"e2","pos":Vector2(-3,0),"eff":{"dmg":0.25}},
		"e3y1": {"n":"Eisenrinde","d":"+25% HP","cost":34,"req":"e3","pos":Vector2(-3,1),"eff":{"hp":0.25}},
		"e3y2": {"n":"Dornenherz","d":"+20% Schaden","cost":34,"req":"e3","pos":Vector2(-3,-1),"eff":{"dmg":0.2}},
		"e4": {"n":"Eisflut","d":"+25% Schaden · Verlangsamt","cost":48,"req":"e3","pos":Vector2(-4,0),"eff":{"slow":true,"dmg":0.25},"rare":true},
		"b1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.2}},
		"b2": {"n":"Blitzwelle","d":"Kettenblitz","cost":18,"req":"b1","pos":Vector2(0,2),"eff":{"chain":true}},
		"b2y1": {"n":"Hastknolle","d":"+15% Feuerrate","cost":28,"req":"b2","pos":Vector2(1,2),"eff":{"rate":0.15}},
		"b2y2": {"n":"Zaehes Mark","d":"+20% HP","cost":28,"req":"b2","pos":Vector2(-1,2),"eff":{"hp":0.2}},
		"b3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"b2","pos":Vector2(0,3),"eff":{"dmg":0.25}},
		"b3y1": {"n":"Zornfaser","d":"+15% Schaden","cost":34,"req":"b3","pos":Vector2(1,3),"eff":{"dmg":0.15}},
		"b3y2": {"n":"Windgeist","d":"+12% Feuerrate","cost":34,"req":"b3","pos":Vector2(-1,3),"eff":{"rate":0.12}},
		"b4": {"n":"Sturmflut","d":"+30% Schaden · Kettenblitz","cost":48,"req":"b3","pos":Vector2(0,4),"eff":{"chain":true,"dmg":0.3},"rare":true},
		"u1": {"n":"Schaden I","d":"+20% Schaden","cost":8,"req":"root","pos":Vector2(0,-1),"eff":{"dmg":0.2}},
		"u2": {"n":"Faulwasser","d":"Gift","cost":18,"req":"u1","pos":Vector2(0,-2),"eff":{"poison":true}},
		"u3": {"n":"Schaden II","d":"+25% Schaden","cost":24,"req":"u2","pos":Vector2(0,-3),"eff":{"dmg":0.25}},
		"u4": {"n":"Sumpffieber","d":"+25% Schaden · +30% Splash · Gift","cost":48,"req":"u3","pos":Vector2(0,-4),"eff":{"poison":true,"splash":0.3,"dmg":0.25},"rare":true},
	}},
}
