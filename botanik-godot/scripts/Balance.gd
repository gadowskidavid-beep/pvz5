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
		"root":   {"n":"Schütze","d":"Feuert Erbsen geradeaus. Waehle unten eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Schwere Erbsen","d":"+35% Schaden","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"core2":  {"n":"Zaeher Stiel","d":"+35% HP","cost":8,"req":"root","pos":Vector2(-1,1),"eff":{"hp":0.35}},
		"feuer1": {"n":"Feuer-Erbse","d":"FEUER: setzt in Brand UND schiesst schneller (+20% Rate).","cost":20,"req":"root","pos":Vector2(1,0),"eff":{"burn":true,"rate":0.20}},
		"feuer2": {"n":"Flammenrad","d":"FEUER+ : +30% Rate, +20% Schaden.","cost":50,"req":"feuer1","pos":Vector2(2,0),"eff":{"rate":0.30,"dmg":0.20},"rare":true},
		"eis1":   {"n":"Frost-Erbse","d":"EIS: verlangsamt Gegner, schiesst aber langsamer (-20% Rate).","cost":20,"req":"root","pos":Vector2(-1,0),"eff":{"slow":true,"rate":-0.20}},
		"eis2":   {"n":"Tiefkuehlung","d":"EIS+ : staerkerer Frost, +25% Schaden.","cost":50,"req":"eis1","pos":Vector2(-2,0),"eff":{"slow":true,"dmg":0.25},"rare":true},
		"blitz1": {"n":"Blitz-Erbse","d":"BLITZ: Treffer loest Kettenblitz auf Nachbar-Zombies aus.","cost":24,"req":"root","pos":Vector2(0,1),"eff":{"chain":true}},
		"blitz2": {"n":"Gewitter-Erbse","d":"BLITZ+ : staerkere Kette, +30% Schaden.","cost":55,"req":"blitz1","pos":Vector2(0,2),"eff":{"chain":true,"dmg":0.30},"rare":true},
		"untod1": {"n":"Zweikopf-Erbse","d":"UNTOD: extra Kopf — beschiesst auch die Nachbarreihen (3 Reihen).","cost":26,"req":"root","pos":Vector2(0,-1),"eff":{"extra_lanes":1}},
		"untod2": {"n":"Nekro-Dreikopf","d":"UNTOD+ : noch mehr Koepfe (5 Reihen) + Gift.","cost":60,"req":"untod1","pos":Vector2(0,-2),"eff":{"extra_lanes":1,"poison":true},"rare":true},
	}},
	"sonne": {"nodes": {
		"root":   {"n":"Sonnenblume","d":"Produziert Sonne. Waehle eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Ertrag","d":"+30% Sonne","cost":6,"req":"root","pos":Vector2(1,1),"eff":{"amount":0.30}},
		"core2":  {"n":"Robuste Wurzel","d":"+40% HP","cost":8,"req":"root","pos":Vector2(-1,1),"eff":{"hp":0.40}},
		"feuer1": {"n":"Heisse Sonne","d":"FEUER: +40% Sonne.","cost":16,"req":"root","pos":Vector2(1,0),"eff":{"amount":0.40}},
		"feuer2": {"n":"Sonnenbrand","d":"FEUER+ : +40% Sonne, -15% Produktionszeit.","cost":45,"req":"feuer1","pos":Vector2(2,0),"eff":{"amount":0.40,"faster":0.15},"rare":true},
		"eis1":   {"n":"Eisblüte","d":"EIS: +40% HP, -10% Produktionszeit (zaeh aus Eis).","cost":16,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.40,"faster":0.10}},
		"eis2":   {"n":"Zwillingsblüte","d":"EIS+ : Legendär · produziert doppelte Sonne.","cost":55,"req":"eis1","pos":Vector2(-2,0),"eff":{"twin":true},"rare":true},
		"blitz1": {"n":"Blitz-Sonne","d":"BLITZ: -20% Produktionszeit (Energie).","cost":18,"req":"root","pos":Vector2(0,1),"eff":{"faster":0.20}},
		"blitz2": {"n":"Energiestoss","d":"BLITZ+ : +40% Sonne, -15% Produktionszeit.","cost":45,"req":"blitz1","pos":Vector2(0,2),"eff":{"amount":0.40,"faster":0.15},"rare":true},
		"untod1": {"n":"Nachtsonne","d":"UNTOD: +30% Sonne, +2 HP/s.","cost":18,"req":"root","pos":Vector2(0,-1),"eff":{"amount":0.30,"regen":2.0}},
		"untod2": {"n":"Nekro-Sonne","d":"UNTOD+ : +50% Sonne, +3 HP/s.","cost":50,"req":"untod1","pos":Vector2(0,-2),"eff":{"amount":0.50,"regen":3.0},"rare":true},
	}},
	"wall": {"nodes": {
		"root":   {"n":"Panzer-Nuss","d":"Zaeher Blocker. Waehle eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Panzer","d":"+50% HP","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"hp":0.50}},
		"core2":  {"n":"Heilung","d":"+3 HP/s Selbstheilung","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"regen":3.0}},
		"feuer1": {"n":"Feuernuss","d":"FEUER: Kontaktschaden — Fresser nehmen Schaden (Dornen 30%).","cost":18,"req":"root","pos":Vector2(1,0),"eff":{"thorns":0.30}},
		"feuer2": {"n":"Lava-Nuss","d":"FEUER+ : Dornen 40%, +30% HP.","cost":46,"req":"feuer1","pos":Vector2(2,0),"eff":{"thorns":0.40,"hp":0.30},"rare":true},
		"eis1":   {"n":"Eisnuss","d":"EIS: +60% HP (massiv, blockt Springer).","cost":18,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.60}},
		"eis2":   {"n":"Gletscher-Nuss","d":"EIS+ : +80% HP, +3 HP/s.","cost":48,"req":"eis1","pos":Vector2(-2,0),"eff":{"hp":0.80,"regen":3.0},"rare":true},
		"blitz1": {"n":"Stahlnuss","d":"BLITZ: Blitzableiter — zappt knabbernde Zombies (Dornen 35%, +40% HP).","cost":22,"req":"root","pos":Vector2(0,1),"eff":{"thorns":0.35,"hp":0.40}},
		"blitz2": {"n":"Blitz-Bunker","d":"BLITZ+ : Dornen 50%, +50% HP.","cost":52,"req":"blitz1","pos":Vector2(0,2),"eff":{"thorns":0.50,"hp":0.50},"rare":true},
		"untod1": {"n":"Untote Nuss","d":"UNTOD: widerlich — heilt sich stark (+5 HP/s).","cost":20,"req":"root","pos":Vector2(0,-1),"eff":{"regen":5.0}},
		"untod2": {"n":"Grab-Nuss","d":"UNTOD+ : +8 HP/s, +50% HP.","cost":50,"req":"untod1","pos":Vector2(0,-2),"eff":{"regen":8.0,"hp":0.50},"rare":true},
	}},
	"pilz": {"nodes": {
		"root":   {"n":"Pilz","d":"Nacht-Sporenwolke, trifft mehrere. Waehle eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Sporenkraft","d":"+30% Schaden","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.30}},
		"core2":  {"n":"Weite Wolke","d":"+0,5 Reichweite","cost":12,"req":"root","pos":Vector2(-1,1),"eff":{"range":0.50}},
		"feuer1": {"n":"Brand-Sporen","d":"FEUER: Brand + schneller (+20% Rate).","cost":20,"req":"root","pos":Vector2(1,0),"eff":{"burn":true,"rate":0.20}},
		"feuer2": {"n":"Glutwolke","d":"FEUER+ : +30% Rate, +20% Schaden.","cost":48,"req":"feuer1","pos":Vector2(2,0),"eff":{"rate":0.30,"dmg":0.20},"rare":true},
		"eis1":   {"n":"Klebsporen","d":"EIS: verlangsamt, schiesst etwas langsamer (-15% Rate).","cost":20,"req":"root","pos":Vector2(-1,0),"eff":{"slow":true,"rate":-0.15}},
		"eis2":   {"n":"Frostnebel","d":"EIS+ : staerkerer Frost, +20% Schaden.","cost":48,"req":"eis1","pos":Vector2(-2,0),"eff":{"slow":true,"dmg":0.20},"rare":true},
		"blitz1": {"n":"Blitz-Sporen","d":"BLITZ: Kettenblitz auf Nachbar-Zombies.","cost":24,"req":"root","pos":Vector2(0,1),"eff":{"chain":true}},
		"blitz2": {"n":"Sturmwolke","d":"BLITZ+ : staerkere Kette, +30% Schaden.","cost":52,"req":"blitz1","pos":Vector2(0,2),"eff":{"chain":true,"dmg":0.30},"rare":true},
		"untod1": {"n":"Gift-Sporen","d":"UNTOD: vergiftet Zombies (Spezialitaet des Pilzes).","cost":22,"req":"root","pos":Vector2(0,-1),"eff":{"poison":true}},
		"untod2": {"n":"Seuche","d":"UNTOD+ : Gift + Kettengift, +40% Schaden.","cost":55,"req":"untod1","pos":Vector2(0,-2),"eff":{"poison":true,"chain":true,"dmg":0.40},"rare":true},
	}},
	"sonnenpilz": {"nodes": {
		"root":   {"n":"Sonnenpilz","d":"Billige Sonne, auch nachts. Waehle eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Nacht-Ertrag","d":"+30% Sonne","cost":6,"req":"root","pos":Vector2(1,1),"eff":{"amount":0.30}},
		"core2":  {"n":"Wachstum","d":"-15% Produktionszeit","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"faster":0.15}},
		"feuer1": {"n":"Glut-Kappe","d":"FEUER: +40% Sonne.","cost":16,"req":"root","pos":Vector2(1,0),"eff":{"amount":0.40}},
		"feuer2": {"n":"Feuer-Sporen","d":"FEUER+ : +40% Sonne, -15% Produktionszeit.","cost":45,"req":"feuer1","pos":Vector2(2,0),"eff":{"amount":0.40,"faster":0.15},"rare":true},
		"eis1":   {"n":"Frost-Kappe","d":"EIS: +40% HP, -10% Produktionszeit.","cost":16,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.40,"faster":0.10}},
		"eis2":   {"n":"Doppelsporen","d":"EIS+ : Legendär · produziert doppelte Sonne.","cost":55,"req":"eis1","pos":Vector2(-2,0),"eff":{"twin":true},"rare":true},
		"blitz1": {"n":"Blitz-Kappe","d":"BLITZ: -20% Produktionszeit.","cost":18,"req":"root","pos":Vector2(0,1),"eff":{"faster":0.20}},
		"blitz2": {"n":"Energiepilz","d":"BLITZ+ : +50% Sonne.","cost":45,"req":"blitz1","pos":Vector2(0,2),"eff":{"amount":0.50},"rare":true},
		"untod1": {"n":"Grab-Kappe","d":"UNTOD: +30% Sonne, +2 HP/s.","cost":18,"req":"root","pos":Vector2(0,-1),"eff":{"amount":0.30,"regen":2.0}},
		"untod2": {"n":"Nekro-Kappe","d":"UNTOD+ : +50% Sonne.","cost":48,"req":"untod1","pos":Vector2(0,-2),"eff":{"amount":0.50},"rare":true},
	}},
	"lilypad": {"nodes": {
		"root":   {"n":"Lilypad","d":"Wasser-Plattform, zaehes Blatt. Waehle eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Dicke Blaetter","d":"+50% HP","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"hp":0.50}},
		"core2":  {"n":"Wasserheilung","d":"+4 HP/s","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"regen":4.0}},
		"feuer1": {"n":"Lavapad","d":"FEUER: Kontaktschaden an Fresser (Dornen 30%).","cost":18,"req":"root","pos":Vector2(1,0),"eff":{"thorns":0.30}},
		"feuer2": {"n":"Magma-Pad","d":"FEUER+ : Dornen 40%.","cost":44,"req":"feuer1","pos":Vector2(2,0),"eff":{"thorns":0.40},"rare":true},
		"eis1":   {"n":"Eispad","d":"EIS: +60% HP (kaltes Wasser, sehr zaeh).","cost":18,"req":"root","pos":Vector2(-1,0),"eff":{"hp":0.60}},
		"eis2":   {"n":"Frostpad","d":"EIS+ : +80% HP.","cost":46,"req":"eis1","pos":Vector2(-2,0),"eff":{"hp":0.80},"rare":true},
		"blitz1": {"n":"Blitzpad","d":"BLITZ: zappt Fresser (Dornen 35%).","cost":22,"req":"root","pos":Vector2(0,1),"eff":{"thorns":0.35}},
		"blitz2": {"n":"Gewitterpad","d":"BLITZ+ : Dornen 50%.","cost":50,"req":"blitz1","pos":Vector2(0,2),"eff":{"thorns":0.50},"rare":true},
		"untod1": {"n":"Grab-Pad","d":"UNTOD: +5 HP/s Selbstheilung.","cost":20,"req":"root","pos":Vector2(0,-1),"eff":{"regen":5.0}},
		"untod2": {"n":"Seerosenblüte","d":"UNTOD+ : +9 HP/s.","cost":48,"req":"untod1","pos":Vector2(0,-2),"eff":{"regen":9.0},"rare":true},
	}},
	"wasserpilz": {"nodes": {
		"root":   {"n":"Wasserpilz","d":"Wirft Druckwellen (Flaeche). Waehle eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Druckwelle","d":"+35% Schaden","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.35}},
		"core2":  {"n":"Wellenradius","d":"+30% Splash","cost":12,"req":"root","pos":Vector2(-1,1),"eff":{"splash":0.30}},
		"feuer1": {"n":"Dampfwelle","d":"FEUER: Brand-Flaeche, +20% Schaden.","cost":20,"req":"root","pos":Vector2(1,0),"eff":{"burn":true,"dmg":0.20}},
		"feuer2": {"n":"Siedeflut","d":"FEUER+ : Brand, +30% Splash.","cost":48,"req":"feuer1","pos":Vector2(2,0),"eff":{"burn":true,"splash":0.30},"rare":true},
		"eis1":   {"n":"Frostwelle","d":"EIS: verlangsamt, +20% Splash.","cost":20,"req":"root","pos":Vector2(-1,0),"eff":{"slow":true,"splash":0.20}},
		"eis2":   {"n":"Eisflut","d":"EIS+ : Frost, +25% Schaden.","cost":48,"req":"eis1","pos":Vector2(-2,0),"eff":{"slow":true,"dmg":0.25},"rare":true},
		"blitz1": {"n":"Blitzwelle","d":"BLITZ: Kettenblitz auf Nachbarn.","cost":24,"req":"root","pos":Vector2(0,1),"eff":{"chain":true}},
		"blitz2": {"n":"Sturmflut","d":"BLITZ+ : staerkere Kette, +30% Schaden.","cost":52,"req":"blitz1","pos":Vector2(0,2),"eff":{"chain":true,"dmg":0.30},"rare":true},
		"untod1": {"n":"Faulwasser","d":"UNTOD: vergiftet Zombies.","cost":22,"req":"root","pos":Vector2(0,-1),"eff":{"poison":true}},
		"untod2": {"n":"Sumpffieber","d":"UNTOD+ : Gift, +30% Splash.","cost":55,"req":"untod1","pos":Vector2(0,-2),"eff":{"poison":true,"splash":0.30},"rare":true},
	}},
	"frostbluete": {"nodes": {
		"root":   {"n":"Frostblüte","d":"Verlangsamt von Beginn an. Waehle eine Element-Richtung.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"core1":  {"n":"Eisschuss","d":"+30% Schaden","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"dmg":0.30}},
		"core2":  {"n":"Frost-Durchschuss","d":"Durchdringt +1 Zombie","cost":16,"req":"root","pos":Vector2(-1,1),"eff":{"pierce":1}},
		"feuer1": {"n":"Frostbrand","d":"FEUER: Brand + schneller (+20% Rate).","cost":20,"req":"root","pos":Vector2(1,0),"eff":{"burn":true,"rate":0.20}},
		"feuer2": {"n":"Dampfschuss","d":"FEUER+ : Brand, +25% Schaden.","cost":48,"req":"feuer1","pos":Vector2(2,0),"eff":{"burn":true,"dmg":0.25},"rare":true},
		"eis1":   {"n":"Tiefkuehlung","d":"EIS: staerkerer Frost, +20% Schaden.","cost":18,"req":"root","pos":Vector2(-1,0),"eff":{"slow":true,"dmg":0.20}},
		"eis2":   {"n":"Permafrost","d":"EIS+ : Frost, +20% Rate.","cost":46,"req":"eis1","pos":Vector2(-2,0),"eff":{"slow":true,"rate":0.20},"rare":true},
		"blitz1": {"n":"Eisblitz","d":"BLITZ: Kettenblitz auf Nachbarn.","cost":24,"req":"root","pos":Vector2(0,1),"eff":{"chain":true}},
		"blitz2": {"n":"Frostschock","d":"BLITZ+ : staerkere Kette, +30% Schaden.","cost":52,"req":"blitz1","pos":Vector2(0,2),"eff":{"chain":true,"dmg":0.30},"rare":true},
		"untod1": {"n":"Zwei-Kristall","d":"UNTOD: extra Kopf — beschiesst Nachbarreihen (3 Reihen).","cost":26,"req":"root","pos":Vector2(0,-1),"eff":{"extra_lanes":1}},
		"untod2": {"n":"Nekro-Frost","d":"UNTOD+ : + Gift.","cost":50,"req":"untod1","pos":Vector2(0,-2),"eff":{"poison":true},"rare":true},
	}},
}
