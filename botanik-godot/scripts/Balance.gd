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
# PFLANZEN-SKILL-TREES  —  Herzstueck der Progression (Waehrung: FP)
# PT_NODES: Knoten-Vorlagen.  ARCH_TREE: welche Knoten je Archetyp.
# kind: "pct" (multiplikativ 1+per*lvl) | "add" (per*lvl) | "unlock" (max 1)
# ================================================================
const START_FP := 10          # Tutorial: genau genug fuer 1 Schuetzen

const PT_NODES := {
	"dmg":      {"n":"Schaden","base":4,"g":1.27,"per":0.12,"kind":"pct","max":40,"d":"+12% Schaden"},
	"rate":     {"n":"Feuerrate","base":6,"g":1.28,"per":0.08,"kind":"pct","max":30,"d":"+8% Feuerrate"},
	"hp":       {"n":"Zellwand","base":5,"g":1.26,"per":0.10,"kind":"pct","max":30,"d":"+10% HP"},
	"pierce":   {"n":"Durchschuss","base":35,"g":2.0,"per":1,"kind":"add","max":4,"d":"Erbse durchdringt +1 Zombie"},
	"splash":   {"n":"Wurfradius","base":24,"g":1.55,"per":0.18,"kind":"pct","max":8,"d":"+18% Splash-Radius"},
	"range":    {"n":"Reichweite","base":22,"g":1.5,"per":0.30,"kind":"add","max":5,"d":"+0,3 Nebel-Reichweite"},
	"amount":   {"n":"Sonnen-Ertrag","base":5,"g":1.30,"per":0.15,"kind":"pct","max":40,"d":"+15% Sonne je Ernte"},
	"faster":   {"n":"Photosynthese","base":8,"g":1.32,"per":0.05,"kind":"pct","max":12,"d":"-5% Produktionszeit"},
	"radius":   {"n":"Sprengkraft","base":26,"g":1.55,"per":0.15,"kind":"pct","max":8,"d":"+15% Explosionsradius"},
	"recharge": {"n":"Nachladen","base":22,"g":1.5,"per":0.06,"kind":"pct","max":8,"d":"-6% Abklingzeit"},
	"thorns":   {"n":"Dornenpanzer","base":30,"g":1.7,"per":0.15,"kind":"pct","max":5,"d":"Reflektiert 15% Schaden je Stufe"},
	"regen":    {"n":"Regeneration","base":28,"g":1.6,"per":3.0,"kind":"add","max":6,"d":"+3 HP/s Selbstheilung"},
	"e_fire":   {"n":"Feuer","base":40,"g":1.0,"per":0,"kind":"unlock","max":1,"d":"Treffer setzen Zombies in Brand"},
	"e_ice":    {"n":"Eis","base":40,"g":1.0,"per":0,"kind":"unlock","max":1,"d":"Treffer verlangsamen Zombies"},
	"e_poison": {"n":"Gift","base":55,"g":1.0,"per":0,"kind":"unlock","max":1,"d":"Treffer vergiften Zombies"},
	"e_elec":   {"n":"Elektro","base":75,"g":1.0,"per":0,"kind":"unlock","max":1,"d":"Blitz springt auf Nachbar-Zombies"},
	"twin":     {"n":"Zwillingsblüte","base":80,"g":1.0,"per":0,"kind":"unlock","max":1,"d":"Produziert doppelte Sonne"},
}

const ARCH_TREE := {
	"sun":     ["amount", "faster", "hp", "twin"],
	"shooter": ["dmg", "rate", "hp", "pierce", "e_fire", "e_ice", "e_poison", "e_elec"],
	"lobber":  ["dmg", "rate", "splash", "hp", "e_fire", "e_poison"],
	"fume":    ["dmg", "rate", "range", "hp", "e_poison", "e_ice"],
	"beam":    ["dmg", "rate", "hp", "e_elec"],
	"spike":   ["dmg", "hp", "e_poison"],
	"wall":    ["hp", "thorns", "regen"],
	"bomb":    ["dmg", "radius"],
}
