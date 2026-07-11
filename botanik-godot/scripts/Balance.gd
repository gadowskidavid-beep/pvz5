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
const MAX_CHAINS := 3         # nur 3 Chains gleichzeitig im Deck aktiv

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
	"sonne": {"branches":[[-1.0,"Tempo"],[0.0,"Ertrag"],[1.0,"Schutz"]], "nodes": {
		"root":    {"n":"Sonnenblume","d":"Tag-Chassis. Produziert Sonne.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"amount1": {"n":"Ertrag I","d":"+25% Sonne je Ernte","cost":6,"req":"root","pos":Vector2(0,1),"eff":{"amount":0.25}},
		"photo1":  {"n":"Photosynthese I","d":"-14% Produktionszeit","cost":8,"req":"root","pos":Vector2(-1,1),"eff":{"faster":0.14}},
		"hp1":     {"n":"Robuste Wurzel","d":"+40% HP","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"hp":0.40}},
		"amount2": {"n":"Ertrag II","d":"+30% Sonne","cost":16,"req":"amount1","pos":Vector2(0,2),"eff":{"amount":0.30}},
		"photo2":  {"n":"Photosynthese II","d":"-14% Produktionszeit","cost":18,"req":"photo1","pos":Vector2(-1,2),"eff":{"faster":0.14}},
		"hp2":     {"n":"Panzerknolle","d":"+50% HP","cost":18,"req":"hp1","pos":Vector2(1,2),"eff":{"hp":0.50}},
		"amount3": {"n":"Ertrag III","d":"+40% Sonne","cost":30,"req":"amount2","pos":Vector2(0,3),"eff":{"amount":0.40}},
		"blitz":   {"n":"Blitzableiter","d":"Legendär · Fängt Blitze ab und wandelt sie in Sonne (Wetter-Synergie). +30% Sonne.","cost":60,"req":"photo2","pos":Vector2(-1,3),"eff":{"amount":0.30},"rare":true},
		"twin":    {"n":"Zwillingsblüte","d":"Legendär · Produziert doppelte Sonne","cost":70,"req":"amount3","pos":Vector2(0,4),"eff":{"twin":true},"rare":true},
	}},
	"pea": {"branches":[[-1.5,"Tempo"],[0.0,"Schaden"],[1.5,"Spezial"]], "nodes": {
		"root":    {"n":"Erbsenschütze","d":"Basis-Chassis. Feuert Erbsen geradeaus auf Zombies.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":    {"n":"Schwere Erbsen","d":"+30% Schaden pro Treffer.","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.30}},
		"rate1":   {"n":"Schnellschuss","d":"+25% Feuerrate.","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"pierce1": {"n":"Durchschuss","d":"Erbsen durchdringen +1 Zombie.","cost":18,"req":"root","pos":Vector2(1,1),"eff":{"pierce":1}},
		"dmg2":    {"n":"Stahlkern","d":"+40% Schaden. Bricht Panzerung leichter.","cost":22,"req":"dmg1","pos":Vector2(0,2),"eff":{"dmg":0.40}},
		"rate2":   {"n":"Dauerfeuer","d":"+30% Feuerrate.","cost":26,"req":"rate1","pos":Vector2(-1,2),"eff":{"rate":0.30}},
		"ice":     {"n":"Frost-Erbse","d":"Treffer verlangsamen Zombies deutlich.","cost":30,"req":"rate1","pos":Vector2(-2,2),"eff":{"slow":true}},
		"fire":    {"n":"Brand-Erbse","d":"Treffer setzen Zombies in Brand (Schaden über Zeit).","cost":32,"req":"pierce1","pos":Vector2(1,2),"eff":{"burn":true}},
		"pierce2": {"n":"Doppel-Durchschuss","d":"Erbsen durchdringen +1 weiteren Zombie.","cost":40,"req":"pierce1","pos":Vector2(2,2),"eff":{"pierce":1}},
		"dmg3":    {"n":"Panzerbrecher","d":"+50% Schaden. Zerlegt Eimer-Zombies.","cost":48,"req":"dmg2","pos":Vector2(0,3),"eff":{"dmg":0.50}},
		"orkan":   {"n":"Saatenorkan","d":"Legendär · Erzeugt einen Kettenschlag, der auf mehrere Zombies überspringt und durchdringt. Cooldown: 45 Sek.","cost":95,"req":"dmg3","pos":Vector2(0,4),"eff":{"chain":true,"pierce":1},"rare":true,"cd":45},
	}},
	"wall": {"branches":[[-1.0,"Regen"],[0.0,"Panzer"],[1.0,"Dornen"]], "nodes": {
		"root":   {"n":"Panzer-Nuss","d":"Ueberall · Zaeher Blocker.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"hp1":    {"n":"Panzer I","d":"+50% HP","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"hp":0.50}},
		"regen1": {"n":"Heilung I","d":"+3 HP/s Selbstheilung","cost":12,"req":"root","pos":Vector2(-1,1),"eff":{"regen":3.0}},
		"thorn1": {"n":"Dornen I","d":"Reflektiert 20% Schaden","cost":14,"req":"root","pos":Vector2(1,1),"eff":{"thorns":0.20}},
		"hp2":    {"n":"Panzer II","d":"+60% HP","cost":20,"req":"hp1","pos":Vector2(0,2),"eff":{"hp":0.60}},
		"regen2": {"n":"Heilung II","d":"+4 HP/s Selbstheilung","cost":22,"req":"regen1","pos":Vector2(-1,2),"eff":{"regen":4.0}},
		"thorn2": {"n":"Dornen II","d":"Reflektiert 25% Schaden","cost":24,"req":"thorn1","pos":Vector2(1,2),"eff":{"thorns":0.25}},
		"hp3":    {"n":"Bunker","d":"+70% HP","cost":34,"req":"hp2","pos":Vector2(0,3),"eff":{"hp":0.70}},
		"reflect":{"n":"Stachelpanzer","d":"Legendär · Reflektiert 40% Schaden","cost":60,"req":"thorn2","pos":Vector2(1,3),"eff":{"thorns":0.40},"rare":true},
		"fort":   {"n":"Festung","d":"Legendär · +100% HP","cost":75,"req":"hp3","pos":Vector2(0,4),"eff":{"hp":1.0},"rare":true},
	}},
	"pilz": {"branches":[[-1.0,"Tempo"],[0.0,"Gift"],[1.0,"Reichweite"]], "nodes": {
		"root":   {"n":"Pilz","d":"Nacht-Chassis. Sporenwolke trifft mehrere Zombies.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":   {"n":"Sporenkraft I","d":"+30% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.30}},
		"rate1":  {"n":"Schnelle Sporen","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"range1": {"n":"Weite Wolke","d":"+0,5 Reichweite","cost":14,"req":"root","pos":Vector2(1,1),"eff":{"range":0.5}},
		"poison": {"n":"Gift-Sporen","d":"Vergiftet Zombies (Schaden ueber Zeit)","cost":22,"req":"dmg1","pos":Vector2(0,2),"eff":{"poison":true}},
		"slow":   {"n":"Klebsporen","d":"Verlangsamt Zombies","cost":22,"req":"rate1","pos":Vector2(-1,2),"eff":{"slow":true}},
		"range2": {"n":"Nebelmeer","d":"+0,6 Reichweite","cost":24,"req":"range1","pos":Vector2(1,2),"eff":{"range":0.6}},
		"dmg2":   {"n":"Toxin II","d":"+40% Schaden","cost":30,"req":"poison","pos":Vector2(0,3),"eff":{"dmg":0.40}},
		"rate2":  {"n":"Sporenschwall","d":"+30% Feuerrate","cost":32,"req":"slow","pos":Vector2(-1,3),"eff":{"rate":0.30}},
		"nova":   {"n":"Sporen-Nova","d":"Legendär · Kettengift springt auf mehrere Zombies. Cooldown: 40 Sek.","cost":85,"req":"dmg2","pos":Vector2(0,4),"eff":{"chain":true,"poison":true},"rare":true,"cd":40},
	}},
	"sonnenpilz": {"branches":[[-1.0,"Tempo"],[0.0,"Ertrag"],[1.0,"Schutz"]], "nodes": {
		"root":    {"n":"Sonnenpilz","d":"Nacht-Chassis. Billige Sonne, auch nachts.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"amount1": {"n":"Nacht-Ertrag I","d":"+30% Sonne","cost":6,"req":"root","pos":Vector2(0,1),"eff":{"amount":0.30}},
		"faster1": {"n":"Wachstum I","d":"-15% Produktionszeit","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"faster":0.15}},
		"hp1":     {"n":"Zaehe Kappe","d":"+40% HP","cost":8,"req":"root","pos":Vector2(1,1),"eff":{"hp":0.40}},
		"amount2": {"n":"Nacht-Ertrag II","d":"+40% Sonne","cost":18,"req":"amount1","pos":Vector2(0,2),"eff":{"amount":0.40}},
		"faster2": {"n":"Wachstum II","d":"-15% Produktionszeit","cost":20,"req":"faster1","pos":Vector2(-1,2),"eff":{"faster":0.15}},
		"hp2":     {"n":"Sporenpanzer","d":"+50% HP","cost":18,"req":"hp1","pos":Vector2(1,2),"eff":{"hp":0.50}},
		"amount3": {"n":"Mondlicht","d":"+45% Sonne","cost":30,"req":"amount2","pos":Vector2(0,3),"eff":{"amount":0.45}},
		"twin":    {"n":"Doppelsporen","d":"Legendär · Produziert doppelte Sonne","cost":60,"req":"amount3","pos":Vector2(0,4),"eff":{"twin":true},"rare":true},
	}},
	"lilypad": {"branches":[[-1.0,"Regen"],[0.0,"Panzer"],[1.0,"Dornen"]], "nodes": {
		"root":   {"n":"Lilypad","d":"Wasser-Chassis. Zaehes Blatt / Plattform.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"hp1":    {"n":"Dicke Blaetter","d":"+50% HP","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"hp":0.50}},
		"regen1": {"n":"Wasserheilung I","d":"+4 HP/s Selbstheilung","cost":14,"req":"root","pos":Vector2(-1,1),"eff":{"regen":4.0}},
		"thorn1": {"n":"Scharfkantig","d":"Reflektiert 20% Schaden","cost":14,"req":"root","pos":Vector2(1,1),"eff":{"thorns":0.20}},
		"hp2":    {"n":"Panzerblatt","d":"+60% HP","cost":20,"req":"hp1","pos":Vector2(0,2),"eff":{"hp":0.60}},
		"regen2": {"n":"Wasserheilung II","d":"+5 HP/s Selbstheilung","cost":24,"req":"regen1","pos":Vector2(-1,2),"eff":{"regen":5.0}},
		"thorn2": {"n":"Schneidblatt","d":"Reflektiert 30% Schaden","cost":26,"req":"thorn1","pos":Vector2(1,2),"eff":{"thorns":0.30}},
		"hp3":    {"n":"Seerosen-Bollwerk","d":"+70% HP","cost":34,"req":"hp2","pos":Vector2(0,3),"eff":{"hp":0.70}},
		"bloom":  {"n":"Seerosenblüte","d":"Legendär · +9 HP/s Selbstheilung","cost":65,"req":"regen2","pos":Vector2(-1,3),"eff":{"regen":9.0},"rare":true},
	}},
	"wasserpilz": {"branches":[[-1.0,"Tempo"],[0.0,"Schaden"],[1.0,"Welle"]], "nodes": {
		"root":   {"n":"Wasserpilz","d":"Wasser-Chassis. Wirft Druckwellen (Flaeche).","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":   {"n":"Druckwelle I","d":"+35% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.35}},
		"rate1":  {"n":"Schnellwurf","d":"+25% Feuerrate","cost":12,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"splash1":{"n":"Wellenradius I","d":"+30% Splash-Radius","cost":14,"req":"root","pos":Vector2(1,1),"eff":{"splash":0.30}},
		"dmg2":   {"n":"Druckwelle II","d":"+45% Schaden","cost":24,"req":"dmg1","pos":Vector2(0,2),"eff":{"dmg":0.45}},
		"rate2":  {"n":"Sturmwurf","d":"+30% Feuerrate","cost":26,"req":"rate1","pos":Vector2(-1,2),"eff":{"rate":0.30}},
		"splash2":{"n":"Wellenradius II","d":"+35% Splash-Radius","cost":28,"req":"splash1","pos":Vector2(1,2),"eff":{"splash":0.35}},
		"poison": {"n":"Faulwasser","d":"Vergiftet Zombies","cost":30,"req":"splash2","pos":Vector2(1,3),"eff":{"poison":true}},
		"dmg3":   {"n":"Tsunami","d":"+55% Schaden","cost":38,"req":"dmg2","pos":Vector2(0,3),"eff":{"dmg":0.55}},
		"flut":   {"n":"Sturzflut","d":"Legendär · Kettenwelle springt auf mehrere Zombies. Cooldown: 40 Sek.","cost":90,"req":"dmg3","pos":Vector2(0,4),"eff":{"chain":true},"rare":true,"cd":40},
	}},
	"frostbluete": {"branches":[[-1.0,"Tempo"],[0.0,"Frost"],[1.0,"Kontrolle"]], "nodes": {
		"root":    {"n":"Frostblüte","d":"Kontroll-Chassis. Schuesse verlangsamen von Beginn an.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
		"dmg1":    {"n":"Eisschuss I","d":"+30% Schaden","cost":8,"req":"root","pos":Vector2(0,1),"eff":{"dmg":0.30}},
		"rate1":   {"n":"Schnellfrost","d":"+25% Feuerrate","cost":10,"req":"root","pos":Vector2(-1,1),"eff":{"rate":0.25}},
		"pierce1": {"n":"Frost-Durchschuss","d":"Durchdringt +1 Zombie","cost":18,"req":"root","pos":Vector2(1,1),"eff":{"pierce":1}},
		"dmg2":    {"n":"Eisschuss II","d":"+40% Schaden","cost":22,"req":"dmg1","pos":Vector2(0,2),"eff":{"dmg":0.40}},
		"rate2":   {"n":"Blizzard","d":"+30% Feuerrate","cost":26,"req":"rate1","pos":Vector2(-1,2),"eff":{"rate":0.30}},
		"pierce2": {"n":"Doppelfrost","d":"Durchdringt +1 weiteren Zombie","cost":34,"req":"pierce1","pos":Vector2(1,2),"eff":{"pierce":1}},
		"burn":    {"n":"Frostbrand","d":"Zusaetzlicher Schaden ueber Zeit","cost":28,"req":"rate2","pos":Vector2(-1,3),"eff":{"burn":true}},
		"dmg3":    {"n":"Permafrost","d":"+50% Schaden","cost":40,"req":"dmg2","pos":Vector2(0,3),"eff":{"dmg":0.50}},
		"schock":  {"n":"Frostschock","d":"Legendär · Eisblitz springt auf mehrere Zombies. Cooldown: 35 Sek.","cost":85,"req":"dmg3","pos":Vector2(0,4),"eff":{"chain":true},"rare":true,"cd":35},
	}},
}


# ================================================================
# ELEMENT-TREE (gemeinsam fuer ALLE Chains, Waehrung: FP)
# Waechst von der Mitte in 4 Richtungen. Schaltet die Element-Mutationen
# der Pflanzen frei (Gate) und verstaerkt die Element-Effekte.
# "bis zur Mutation dauert es" -> erste Element-Knoten sind teuer.
# Richtungen: FEUER (rechts +x), EIS (links -x), BLITZ (oben +y), UNTOD (unten -y)
# id-Praefix = Richtung (feuer/eis/blitz/untod) -> steuert Boost-Zaehlung.
# ================================================================
const ELEMENT_TREE := {
	"root":   {"n":"Mutations-Kern","d":"Zentrum. Waehle eine Element-Richtung, in die du investierst.","cost":0,"req":"","pos":Vector2(0,0),"eff":{}},
	# --- FEUER (rechts) — Zerstoerung/Brand ---
	"feuer1": {"n":"Feuer: Zündung","d":"Schaltet FEUER-Mutationen aller Pflanzen frei (Brand-Knoten).","cost":40,"req":"root","pos":Vector2(1,0),"eff":{}},
	"feuer2": {"n":"Feuer: Lodern","d":"+35% Feuer-Schaden ueber Zeit.","cost":70,"req":"feuer1","pos":Vector2(2,0),"eff":{}},
	"feuer3": {"n":"Feuer: Feuersturm","d":"+35% Feuer-Schaden.","cost":115,"req":"feuer2","pos":Vector2(3,0),"eff":{}},
	"feuer4": {"n":"Feuer: Inferno","d":"Legendär · massiver Feuer-Boost. Synergie mit dem Feuerboss.","cost":180,"req":"feuer3","pos":Vector2(4,0),"eff":{},"rare":true},
	# --- EIS (links) — Kontrolle/Kaelte ---
	"eis1":   {"n":"Eis: Frost","d":"Schaltet EIS-Mutationen aller Pflanzen frei (Verlangsamung).","cost":40,"req":"root","pos":Vector2(-1,0),"eff":{}},
	"eis2":   {"n":"Eis: Raureif","d":"+35% laengere Verlangsamung.","cost":70,"req":"eis1","pos":Vector2(-2,0),"eff":{}},
	"eis3":   {"n":"Eis: Blizzard","d":"+35% laengere Verlangsamung.","cost":115,"req":"eis2","pos":Vector2(-3,0),"eff":{}},
	"eis4":   {"n":"Eis: Absoluter Nullpunkt","d":"Legendär · massive Kaelte. Synergie mit dem Eisboss.","cost":180,"req":"eis3","pos":Vector2(-4,0),"eff":{},"rare":true},
	# --- BLITZ (oben) — Sturm/Elektrizitaet ---
	"blitz1": {"n":"Blitz: Funke","d":"Schaltet BLITZ-Mutationen aller Pflanzen frei (Kettenblitz).","cost":45,"req":"root","pos":Vector2(0,1),"eff":{}},
	"blitz2": {"n":"Blitz: Ladung","d":"+35% Kettenblitz-Schaden.","cost":75,"req":"blitz1","pos":Vector2(0,2),"eff":{}},
	"blitz3": {"n":"Blitz: Gewitter","d":"+35% Kettenblitz-Schaden.","cost":120,"req":"blitz2","pos":Vector2(0,3),"eff":{}},
	"blitz4": {"n":"Blitz: Sturmherr","d":"Legendär · Gewitter wird zur Chance. Synergie mit dem Blitzboss.","cost":185,"req":"blitz3","pos":Vector2(0,4),"eff":{},"rare":true},
	# --- UNTOD (unten) — Verfall/Gift ---
	"untod1": {"n":"Untod: Verwesung","d":"Schaltet UNTOD-Mutationen aller Pflanzen frei (Gift).","cost":45,"req":"root","pos":Vector2(0,-1),"eff":{}},
	"untod2": {"n":"Untod: Faeulnis","d":"+35% Gift-Schaden.","cost":75,"req":"untod1","pos":Vector2(0,-2),"eff":{}},
	"untod3": {"n":"Untod: Seuche","d":"+35% Gift-Schaden.","cost":120,"req":"untod2","pos":Vector2(0,-3),"eff":{}},
	"untod4": {"n":"Untod: Nekromantie","d":"Legendär · dunkle Macht. Synergie mit dem finalen Untoten.","cost":185,"req":"untod3","pos":Vector2(0,-4),"eff":{},"rare":true},
}
