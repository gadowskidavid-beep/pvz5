extends RefCounted
class_name BAL
# ================================================================
# ZENTRALE BALANCING-CONFIG  —  HIER alles nachjustieren.
# (Skill-/Upgrade-Kosten selbst liegen als Daten-Dicts in Game.gd:
#  CHASSIS, RESEARCH, EQUIP, MUT, SHOP_*, PRESTIGE, ZTYPES.
#  Die Skalierungs-Kurven, der Wellen-/Boss-Zeitplan und die
#  Akt/Rasen-Definitionen stehen hier.)
# ================================================================

# ---- Wellen & Akte ----
const ACT_SIZE := 25          # Wellen pro Rasen
const FINAL_WAVE := 100
const BOSS_WAVES := [25, 50, 75, 100]
const MINIBOSS_WAVE := 9      # kleiner Extra-Boss zum Kennenlernen

# ---- Wellen-Menge (Anzahl Zombies) ----
const WAVE_BASE := 3
const WAVE_PER := 1.6

# ---- Zombie-Skalierung pro Welle ----
const Z_HP_PER_WAVE := 0.09
const Z_HP_POW := 1.5
const Z_HP_POW_MUL := 0.011
const Z_SPD_PER_WAVE := 0.012

# ---- Gehirn-Traeger (nicht jeder Zombie droppt Gehirne!) ----
const BRAIN_MIN_WAVE := 6     # ab hier koennen Traeger auftauchen
const BRAIN_CHANCE := 0.10    # Chance, dass ein normaler Spawn ein Traeger wird

# ---- Idle-Zombies zwischen den Wellen ----
const IDLE_MIN := 5.0
const IDLE_MAX := 9.0

# ---- Dynamische Zerstoerung ----
const HAZARD_DMG := 65.0      # Umwelt-Schaden an einer zufaelligen Pflanze
const HAZARD_MIN := 6.0
const HAZARD_MAX := 12.0

# ---- Boss-Keys je Boss-Welle (Index passend zu BOSS_WAVES) ----
const BOSS_KEYS := ["boss_a", "boss_b", "boss_c", "megaboss"]

# ================================================================
# AKTE / RASEN  —  3 Hauptrasen + Finale.
# WICHTIG: gleich schwer, nur anderer STIL (Optik + Zombie-Mix + Mechanik).
# Felder: name, night, pond, roof, hazard, g1/g2 (Rasenfarben),
#         spawn = gewichtete Tabelle [[zombie_key, gewicht], ...]
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


# ================================================================
# PFLANZEN-SKILL-TREES  —  Herzstueck (Waehrung: FP)
# Jede Pflanze hat einen eigenen BAUM: Knoten mit Position (pos),
# Voraussetzung (req = Eltern-Knoten) und EINMALIGEM Effekt (eff).
# Jeder Skill wird nur EINMAL freigeschaltet (kein Level-Grind).
# "root" = die Pflanze selbst (automatisch besessen, Anker + Startpunkt).
# eff-Keys: dmg/rate/hp/amount/splash/radius (=% als Bruch),
#           pierce/range/regen (=additiv), thorns/faster (=Bruch),
#           burn/slow/poison/chain/twin (=true).
# pos: Vector2(spalte, reihe) — reihe 0 = unten (Wurzel), nach oben groesser.
# ================================================================
const START_FP := 10          # Tutorial: genau genug fuer 1 Schuetzen

const PLANT_TREES := {
	"sonne": {"nodes": {
		"root":    {"n":"Sonnenblume","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"amount1": {"n":"Ertrag I","d":"+25% Sonne je Ernte","cost":6,"req":"root","pos":Vector2(0,1),"eff":{"amount":0.25}},
		"photo":   {"n":"Photosynthese","d":"-20% Produktionszeit","cost":10,"req":"amount1","pos":Vector2(-1,2),"eff":{"faster":0.20}},
		"robust":  {"n":"Robuste Wurzel","d":"+40% HP","cost":9,"req":"amount1","pos":Vector2(1,2),"eff":{"hp":0.40}},
		"amount2": {"n":"Ertrag II","d":"+35% Sonne","cost":16,"req":"amount1","pos":Vector2(0,2),"eff":{"amount":0.35}},
		"twin":    {"n":"Zwillingsblüte","d":"Legendär · Produziert doppelte Sonne","cost":45,"req":"amount2","pos":Vector2(0,3),"eff":{"twin":true},"rare":true},
	}},
	"pea": {"branches":[[-1.0,"Tempo"],[0.0,"Schaden"],[1.0,"Spezial"]], "nodes": {
		"root":  {"n":"Erbsenschütze","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":  {"n":"Schaden I","d":"+30% Schaden","cost":6,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.30}},
		"rate1": {"n":"Feuerrate I","d":"+25% Feuerrate","cost":8,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"dmg2":  {"n":"Schaden II","d":"+40% Schaden","cost":16,"req":"dmg1","pos":Vector2(0,2),"eff":{"dmg":0.40}},
		"pierce":{"n":"Durchschuss","d":"Erbse durchdringt +1 Zombie","cost":22,"req":"dmg1","pos":Vector2(1,2),"eff":{"pierce":1}},
		"fire":  {"n":"Feuer","d":"Setzt Zombies in Brand","cost":30,"req":"rate1","pos":Vector2(-1,2),"eff":{"burn":true}},
		"ice":   {"n":"Eis","d":"Verlangsamt Zombies","cost":30,"req":"rate1","pos":Vector2(-2,2),"eff":{"slow":true}},
		"elec":  {"n":"Nuklear-Erbse","d":"Legendär · Blitz springt auf mehrere Zombies","cost":48,"req":"dmg2","pos":Vector2(0,3),"eff":{"chain":true},"rare":true},
	}},
	"wall": {"nodes": {
		"root":  {"n":"Wal-Nuss","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"hp1":   {"n":"Panzer I","d":"+50% HP","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"hp":0.50}},
		"thorns":{"n":"Dornenpanzer","d":"Reflektiert 30% Schaden","cost":18,"req":"hp1","pos":Vector2(-1,2),"eff":{"thorns":0.30}},
		"regen": {"n":"Regeneration","d":"+5 HP/s Selbstheilung","cost":20,"req":"hp1","pos":Vector2(1,2),"eff":{"regen":5.0}},
		"hp2":   {"n":"Panzer II","d":"+60% HP","cost":22,"req":"hp1","pos":Vector2(0,2),"eff":{"hp":0.60}},
	}},
	"werfer": {"nodes": {
		"root":  {"n":"Kohl-Werfer","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":  {"n":"Schaden I","d":"+35% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.35}},
		"rate1": {"n":"Wurftempo","d":"+25% Feuerrate","cost":12,"req":"dmg1","pos":Vector2(-1,2),"eff":{"rate":0.25}},
		"splash":{"n":"Wurfradius","d":"+35% Splash-Radius","cost":16,"req":"dmg1","pos":Vector2(1,2),"eff":{"splash":0.35}},
		"fire":  {"n":"Feuer","d":"Brand-Fläche","cost":30,"req":"dmg1","pos":Vector2(0,2),"eff":{"burn":true}},
		"poison":{"n":"Gift","d":"Gift-Fläche","cost":34,"req":"splash","pos":Vector2(1,3),"eff":{"poison":true}},
	}},
	"stachel": {"nodes": {
		"root":  {"n":"Stachel","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":  {"n":"Schärfe I","d":"+40% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.40}},
		"hp":    {"n":"Verankert","d":"+40% HP","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"hp":0.40}},
		"dmg2":  {"n":"Schärfe II","d":"+50% Schaden","cost":18,"req":"dmg1","pos":Vector2(1,2),"eff":{"dmg":0.50}},
		"poison":{"n":"Gift","d":"Vergiftet Zombies","cost":28,"req":"dmg1","pos":Vector2(0,2),"eff":{"poison":true}},
	}},
	"nebler": {"nodes": {
		"root":  {"n":"Nebler","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":  {"n":"Schaden I","d":"+30% Schaden","cost":10,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.30}},
		"rate1": {"n":"Feuerrate","d":"+25% Feuerrate","cost":14,"req":"dmg1","pos":Vector2(-1,2),"eff":{"rate":0.25}},
		"range": {"n":"Reichweite","d":"+0,6 Nebel-Reichweite","cost":16,"req":"dmg1","pos":Vector2(1,2),"eff":{"range":0.6}},
		"poison":{"n":"Gift","d":"Vergiftet Zombies","cost":32,"req":"dmg1","pos":Vector2(0,2),"eff":{"poison":true}},
		"ice":   {"n":"Eis","d":"Verlangsamt Zombies","cost":32,"req":"rate1","pos":Vector2(-1,3),"eff":{"slow":true}},
	}},
	"bombe": {"nodes": {
		"root": {"n":"Bombe","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1": {"n":"Sprengkraft I","d":"+40% Schaden","cost":12,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.40}},
		"radius":{"n":"Radius","d":"+35% Explosionsradius","cost":20,"req":"dmg1","pos":Vector2(0,2),"eff":{"radius":0.35}},
		"dmg2": {"n":"Sprengkraft II","d":"+60% Schaden","cost":26,"req":"radius","pos":Vector2(0,3),"eff":{"dmg":0.60}},
	}},
	"beam": {"nodes": {
		"root": {"n":"Mais-Beam","d":"Basis","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1": {"n":"Schaden I","d":"+35% Schaden","cost":14,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.35}},
		"rate1":{"n":"Frequenz","d":"+25% Feuerrate","cost":18,"req":"dmg1","pos":Vector2(-1,2),"eff":{"rate":0.25}},
		"dmg2": {"n":"Schaden II","d":"+45% Schaden","cost":28,"req":"dmg1","pos":Vector2(0,2),"eff":{"dmg":0.45}},
		"elec": {"n":"Überladung","d":"Legendär · Blitz springt auf mehrere Zombies","cost":50,"req":"dmg1","pos":Vector2(1,2),"eff":{"chain":true},"rare":true},
	}},
}
