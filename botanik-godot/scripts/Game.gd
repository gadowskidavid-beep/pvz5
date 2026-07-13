extends Node
# ================================================================
# Botanik-Labor — zentrales Spielmodell (Autoload "Game")
# Enthält Daten, Zustand, Helfer und Speichern/Laden.
# ================================================================

# ---- Raster ----
const COLS := 9
const CELL := 90
const LAWN_X := 150
const LAWN_Y := 96

# ---- CHASSIS (Pflanzen) ----
# ---- CHASSIS = die 8 CHAINS (env: day/night/water/any) ----
var CHASSIS := {
	"sonne":       {"n":"Sonnenblume","arch":"sun","env":"day","fp":0,"req":"","col":Color(1,0.83,0.2),"cost":50,"hp":60,"cd":5,"amount":25,"interval":8.0,"d":"Tag · Oekonomie: produziert Sonne."},
	"pea":         {"n":"Schütze","arch":"shooter","env":"day","fp":10,"req":"","col":Color(0.35,0.85,0.4),"cost":100,"hp":60,"cd":5,"dmg":22,"rate":1.1,"speed":340.0,"d":"Tag · Schaden/DPS: schießt Erbsen — skille die Feuerrate!"},
	"wall":        {"n":"Panzer-Nuss","arch":"wall","env":"any","fp":18,"req":"pea","col":Color(0.62,0.44,0.26),"cost":50,"hp":340,"cd":14,"d":"Ueberall · Verteidigung: zaeher Blocker."},
	"pilz":        {"n":"Pilz","arch":"fume","env":"night","fp":36,"req":"","col":Color(0.72,0.55,0.85),"cost":100,"hp":60,"cd":5,"dmg":16,"rate":1.6,"range":2.6,"d":"Nacht · Gift & Sporen-Flaeche. Stark bei Nacht, schwach am Tag."},
	"sonnenpilz":  {"n":"Sonnenpilz","arch":"sun","env":"night","fp":20,"req":"sonne","col":Color(0.8,0.72,0.5),"cost":25,"hp":60,"cd":5,"amount":15,"interval":7.0,"d":"Nacht · Billige Sonne, produziert auch nachts."},
	"lilypad":     {"n":"Lilypad","arch":"wall","env":"water","fp":16,"req":"","col":Color(0.4,0.72,0.5),"cost":25,"hp":180,"cd":8,"d":"Wasser · Plattform/Utility: zaehes Blatt."},
	"wasserpilz":  {"n":"Wasserpilz","arch":"lobber","env":"water","fp":44,"req":"lilypad","col":Color(0.4,0.72,0.85),"cost":150,"hp":60,"cd":6,"dmg":40,"rate":0.8,"splash":0.9,"d":"Wasser · Wellen-Flaechenschaden."},
	"frostbluete": {"n":"Frostblüte","arch":"shooter","env":"any","fp":34,"req":"pea","col":Color(0.6,0.85,1),"cost":150,"hp":60,"cd":6,"dmg":18,"rate":1.2,"speed":320.0,"d":"Ueberall · Kontrolle: verlangsamt & friert ein."},
}
var CH_ORDER := ["sonne","pea","wall","pilz","sonnenpilz","lilypad","wasserpilz","frostbluete"]

# ---- ALLGEMEINE UPGRADES (FP) — Oekonomie/Klick (vorlaeufig; wird spaeter der Sonnen-Tree) ----
var RESEARCH := {
	"r_click": {"n":"Klick-Kraft","base":5,"g":1.26,"per":6,"kind":"add","d":"+6 Klick-Schaden (Faust)"},
	"r_coin":  {"n":"Münzausbeute","base":9,"g":1.34,"per":0.12,"kind":"pct","d":"+12% Münzen"},
	"r_fp":    {"n":"Forschungsdrang","base":14,"g":1.45,"per":0.10,"kind":"pct","d":"+10% FP von Zombies"},
	"r_loot":  {"n":"Glücksbringer","base":18,"g":1.5,"per":0.08,"kind":"pct","d":"+8% Chance auf doppelte FP-Beute (Dropchance)"},
}
var RES_ORDER := ["r_click","r_coin","r_fp","r_loot"]

# ---- EQUIP (einmalig, FP) ----
var EQUIP := {
	"u_hammer":     {"n":"Hammer","fp":4,"req":"","d":"Zombies per Klick zerschlagen (Faust)"},
	"u_almanac":    {"n":"Almanach","fp":5,"req":"","d":"Pflanzen-Almanach"},
	"u_shovel":     {"n":"Schaufel","fp":6,"req":"","d":"Pflanzen entfernen"},
	"u_zombiebook": {"n":"Zombie-Buch","fp":9,"req":"u_almanac","d":"Zombie-Enzyklopädie"},
	"f_lane2":      {"n":"2. Reihe","fp":16,"req":"","d":"+1 Rasenreihe"},
	"f_lane3":      {"n":"3. Reihe","fp":34,"req":"f_lane2","d":"+1 Rasenreihe"},
	"f_mowerfix":   {"n":"Mäher-Werkstatt","fp":26,"req":"","d":"Mäher werden zwischen Wellen repariert"},
	"e_clickcoin":  {"n":"Klick-Gold","fp":10,"req":"u_almanac","d":"Zombies anklicken gibt Münzen"},
}
var EQ_ORDER := ["u_hammer","u_shovel","u_almanac","u_zombiebook","f_mowerfix","e_clickcoin"]

# ---- IN-RUN LADEN (Münzen) ----
var SHOP_ITEMS := {
	"isun":    {"n":"Sofort-Sonne","cost":8,"d":"+250 Sonne"},
	"ifreeze": {"n":"Schockfrost","cost":16,"d":"Alle Zombies einfrieren"},
	"imower":  {"n":"Mäher-Service","cost":22,"d":"Alle Rasenmäher reparieren"},
}
var SHOP_ITEM_ORDER := ["isun","ifreeze","imower"]
var SHOP_PASS := {
	"s_dmg":  {"n":"Kampfrausch","base":12,"d":"+12% Schaden (Run)"},
	"s_rate": {"n":"Adrenalin","base":12,"d":"+12% Feuerrate (Run)"},
	"s_sun":  {"n":"Sonnenkraft","base":10,"d":"+15% Sonne (Run)"},
	"s_click":{"n":"Eisenfaust","base":8,"d":"+25 Klick-Schaden (Run)"},
	"s_coin": {"n":"Münz-Magnet","base":14,"d":"+50% Münzen (Run)"},
}
var SHOP_PASS_ORDER := ["s_dmg","s_rate","s_sun","s_click","s_coin"]

# ---- PRESTIGE (Gehirne) ----
var PRESTIGE := {
	"startpea": {"n":"Erbsen-Gen","base":5,"g":1.0,"max":1,"d":"Erbsenschütze ist von Beginn an freigeschaltet"},
	"sunbloom": {"n":"Sonnen-Gen","base":4,"g":1.6,"max":10,"d":"+5 Sonne je Sonnenblume"},
	"lane":  {"n":"Neue Reihe","base":3,"g":2.3,"max":4,"d":"+1 Rasenreihe (max 5)"},
	"sun":   {"n":"Start-Sonne","base":2,"g":1.5,"max":20,"d":"+25 Start-Sonne"},
	"srate": {"n":"Sonnenfluss","base":2,"g":1.5,"max":25,"d":"+0,15 Sonne/s"},
	"dmg":   {"n":"Mutationskraft","base":3,"g":1.45,"max":60,"d":"+8% Schaden"},
	"hp":    {"n":"Zäh-Zellen","base":3,"g":1.45,"max":60,"d":"+8% Pflanzen-HP"},
	"brain": {"n":"Gehirn-Gier","base":4,"g":1.55,"max":40,"d":"+15% Gehirne von Bossen"},
}
var PRES_ORDER := ["startpea","sunbloom","sun","srate","dmg","hp","brain"]   # "lane" entfernt: Rasen ist fest 5 Reihen

# ---- ZOMBIES ----
var ZTYPES := {
	"basic":    {"n":"Zombie","hp":130,"speed":15,"dmg":38,"fp":1,"col":Color(0.5,0.55,0.5)},
	"flag":     {"n":"Fahnen-Zombie","hp":150,"speed":22,"dmg":38,"fp":2,"col":Color(0.55,0.5,0.6)},
	"cone":     {"n":"Hütchen-Zombie","hp":300,"speed":14,"dmg":40,"fp":2,"col":Color(0.6,0.5,0.4)},
	"vaulter":  {"n":"Stangenspringer","hp":210,"speed":21,"dmg":40,"fp":3,"vault":true,"col":Color(0.5,0.6,0.55)},
	"bucket":   {"n":"Eimer-Zombie","hp":560,"speed":12,"dmg":45,"fp":3,"col":Color(0.6,0.62,0.66)},
	"brainz":   {"n":"Hirn-Träger","hp":240,"speed":18,"dmg":38,"fp":2,"brain":1,"carrier":true,"col":Color(0.62,0.42,0.72)},
	"brute":    {"n":"Grobian","hp":460,"speed":12,"dmg":55,"fp":3,"smash":true,"col":Color(0.52,0.42,0.5)},
	"balloon":  {"n":"Ballon-Zombie","hp":170,"speed":19,"dmg":40,"fp":3,"fly":true,"col":Color(0.72,0.5,0.58)},
	"sprinter": {"n":"Renn-Zombie","hp":200,"speed":22,"dmg":40,"fp":3,"rage":true,"col":Color(0.72,0.38,0.36)},
	"shield":   {"n":"Schild-Zombie","hp":260,"speed":13,"dmg":42,"fp":3,"shield":260.0,"col":Color(0.5,0.58,0.72)},
	"miniboss": {"n":"Mini-Boss","hp":1500,"speed":11,"dmg":80,"fp":6,"boss":true,"brain":3,"col":Color(0.7,0.4,0.5)},
	"boss_a":   {"n":"Flammen-Gargantuar","hp":2400,"speed":9,"dmg":120,"fp":14,"boss":true,"brain":6,"smash":true,"element":"feuer","col":Color(0.95,0.4,0.2)},
	"boss_b":   {"n":"Frost-Koloss","hp":3000,"speed":10,"dmg":130,"fp":18,"boss":true,"brain":10,"element":"eis","col":Color(0.4,0.68,1.0)},
	"boss_c":   {"n":"Gewitter-Zerstörer","hp":3600,"speed":10,"dmg":150,"fp":24,"boss":true,"brain":16,"element":"blitz","col":Color(1.0,0.85,0.3)},
	"megaboss": {"n":"Untoter Überlord","hp":7000,"speed":8,"dmg":220,"fp":60,"boss":true,"brain":35,"final":true,"smash":true,"summon":6,"element":"untot","col":Color(0.72,0.35,0.9)},
}

# ================================================================
# ZUSTAND
# ================================================================
# --- persistente Meta (gespeichert) ---
var brains := 0
var prestige := {}
var seen := {}          # Set: zombie-key -> true
var carry_coins := 0
var unlocked_slots := 3           # Anzahl Samen-Slots (dauerhaft, via Gehirne erweiterbar)
# --- Boss-Reihenfolge: pro Run neu gemischt (Finale bleibt fix) ---
var boss_order: Array = ["boss_a", "boss_b", "boss_c"]
# --- Skills (NICHT gespeichert, bleiben aber während der Sitzung) ---
var fp := 0
var research := {}
var unlocked := {}                # nur EQUIP-ids (Schaufel/Reihen/Almanach ...)
var seeds := []                   # Samen-Slots: [{chain, nodes}] — je Slot ein eigener Bau
var edit_slot := 0                # welcher Slot wird im Drawer bearbeitet
var place_slot := 0               # welcher Slot ist zum Setzen gewaehlt (-1 = Hammer/Faust)
var run_shop := {}
var lure := 0                     # Lockstoff-Stufe: Idle-Zombies zwischen Wellen
var god := false                  # Dev: Rasen kann nicht verloren gehen
var lanes_bought := 0             # zusaetzliche Rasen-Reihen (mit FP gekauft, Start = 1 Reihe)
var plants_unlocked := {}         # Set: Chain-Key -> true (mit FP im Labor freigeschaltet)
var garage := false               # Garage/Labor frei (mit Sonne) -> Fokus-Baeume nutzbar
var tutorial_done := false        # Rasenmaeher-Intro (Welle 1) erledigt
# --- Kampf-Laufzeit ---
var sun := 75
var coins := 0
var wave := 0
var phase := "prep"     # "prep" | "fight"
var shovel := false
var paused := false      # true wenn ein Overlay offen ist

const SAVE_PATH := "user://botanik_save.json"

func _ready() -> void:
	load_game()
	rebirth()

# ================================================================
# HELFER
# ================================================================
func has(id: String) -> bool: return unlocked.has(id)
func res_lvl(k: String) -> int: return int(research.get(k, 0))
func res_cost(k: String) -> int:
	var r = RESEARCH[k]
	return int(ceil(r.base * pow(r.g, res_lvl(k))))
func res_mul(k: String) -> float:
	return 1.0 + float(RESEARCH[k].per) * res_lvl(k)
func pres_lvl(k: String) -> int: return int(prestige.get(k, 0))
func pres_max(k: String) -> bool: return pres_lvl(k) >= int(PRESTIGE[k].max)
func pres_cost(k: String) -> int:
	var p = PRESTIGE[k]
	return int(ceil(p.base * pow(p.g, pres_lvl(k))))
func field_lanes() -> int:
	return (1 if has("f_lane2") else 0) + (1 if has("f_lane3") else 0)
const LANE_MAX := 5
func lanes_count() -> int:
	return clampi(1 + lanes_bought, 1, LANE_MAX)   # Start = 1 Reihe, bis 5 mit FP freischaltbar
func lane_count_max() -> bool: return lanes_count() >= LANE_MAX
func lane_cost() -> int: return int(30 * pow(2.0, lanes_bought))   # 30, 60, 120, 240
func buy_lane() -> bool:
	if lane_count_max(): return false
	var c := lane_cost()
	if fp < c: return false
	fp -= c; lanes_bought += 1
	return true
func start_sun() -> int: return 50 + 25 * pres_lvl("sun")   # genug fuer die erste Sonnenblume

# ---- Fortschritt: Pflanzen mit FP freischalten, Garage mit Sonne ----
const PLANT_UNLOCK := {"pea":8,"sonne":12,"wall":22,"lilypad":26,"frostbluete":40,"sonnenpilz":32,"pilz":48,"wasserpilz":58}
const GARAGE_COST := 500          # Sonne fuer die Garage -> schaltet die Fokus-Baeume frei
func plant_unlocked(ck: String) -> bool: return plants_unlocked.has(ck)
func plant_unlock_cost(ck: String) -> int: return int(PLANT_UNLOCK.get(ck, 30))
func unlock_plant(ck: String) -> bool:
	if plant_unlocked(ck): return true
	var c := plant_unlock_cost(ck)
	if fp < c: return false
	fp -= c; plants_unlocked[ck] = true
	return true
func buy_garage() -> bool:
	if garage: return true
	if sun < GARAGE_COST: return false
	sun -= GARAGE_COST; garage = true
	return true
func sun_passive() -> float: return 0.15 * pres_lvl("srate")
func brain_mul() -> float: return 1.0 + 0.15 * pres_lvl("brain")
func pres_dmg_mul() -> float: return 1.0 + 0.08 * pres_lvl("dmg")
func pres_hp_mul() -> float: return 1.0 + 0.08 * pres_lvl("hp")
func run_dmg_mul() -> float: return 1.0 + 0.12 * int(run_shop.get("s_dmg", 0))
func run_rate_mul() -> float: return 1.0 + 0.12 * int(run_shop.get("s_rate", 0))
func run_sun_mul() -> float: return 1.0 + 0.15 * int(run_shop.get("s_sun", 0))
func click_dmg() -> int:
	return int(round((10 + 6 * res_lvl("r_click") + 25 * int(run_shop.get("s_click", 0))) * pres_dmg_mul()))
func coin_mul() -> float:
	return res_mul("r_coin") * (1.0 + 0.5 * int(run_shop.get("s_coin", 0)))
func fp_mul() -> float: return res_mul("r_fp")
func loot_chance() -> float: return min(0.9, 0.08 * res_lvl("r_loot"))   # Chance auf doppelte FP-Beute
func has_click_coin() -> bool: return has("e_clickcoin")
func mower_fix() -> bool: return has("f_mowerfix")
func risk_level() -> int: return 0
func reward_mul() -> float: return 1.0   # Zombie-Risiko-Regler gestrichen
func idle_cap() -> int: return 1 + lure          # max. Zombies zwischen den Wellen
func lure_max() -> bool: return lure >= 5
func lure_cost() -> int: return int(ceil(18 * pow(1.7, lure)))
func buy_lure() -> bool:
	if lure_max(): return false
	var c := lure_cost()
	if fp < c: return false
	fp -= c; lure += 1
	return true
# ---- Samen-Slots (jeder Slot ein eigener Bau: chain + eigene Skill-Knoten) ----
func seed_chain(slot: int) -> String:
	if slot < 0 or slot >= seeds.size(): return ""
	return str(seeds[slot].chain)
func seed_nodes(slot: int) -> Dictionary:
	if slot < 0 or slot >= seeds.size(): return {}
	return seeds[slot].nodes
func seed_set_chain(slot: int, ck: String) -> void:
	if slot < 0 or slot >= seeds.size(): return
	# Fairness: 50% FP-Erstattung fuer bereits gekaufte Skill-Knoten des alten Baus
	var old := str(seeds[slot].chain)
	if old != "" and old != ck:
		var onodes := tree_nodes(old)
		var back := 0.0
		for id in seeds[slot].nodes:
			back += float(onodes.get(id, {}).get("cost", 0)) * 0.5
		fp += int(back)
	seeds[slot].chain = ck
	seeds[slot].nodes = {}       # neue Pflanze -> neue Skills (50% FP kamen zurueck)
func seed_reset(slot: int) -> void:
	if slot < 0 or slot >= seeds.size(): return
	seeds[slot].chain = ""
	seeds[slot].nodes = {}
	if place_slot == slot: place_slot = -1
func slot_count() -> int: return seeds.size()
# Welches Element hat dieser Samen schon gewaehlt? ("" = noch keins) — Knoten-Praefix f/e/b/u
func seed_element(slot: int) -> String:
	for id in seed_nodes(slot):
		var p: String = str(id).substr(0, 1)
		if p == "f" or p == "e" or p == "b" or p == "u": return p
	return ""

# ---- Pflanzen-Skill-Baum PRO SLOT ----
func tree_nodes(ck: String) -> Dictionary:
	return BAL.PLANT_TREES.get(ck, {}).get("nodes", {})
func pt_owned(slot: int, node: String) -> bool:
	if node == "root": return seed_chain(slot) != ""
	return seed_nodes(slot).has(node)
func pt_node_cost(slot: int, node: String) -> int:
	return int(tree_nodes(seed_chain(slot)).get(node, {}).get("cost", 0))
func pt_req(slot: int, node: String) -> String:
	return str(tree_nodes(seed_chain(slot)).get(node, {}).get("req", ""))
func pt_can(slot: int, node: String) -> bool:
	if seed_chain(slot) == "": return false
	if pt_owned(slot, node): return false
	var nodes := tree_nodes(seed_chain(slot))
	if not nodes.has(node): return false
	var r := pt_req(slot, node)
	if not (r == "" or pt_owned(slot, r)): return false
	# Exklusivitaet: pro Samen nur EIN Element-Zweig (f/e/b/u)
	var p: String = node.substr(0, 1)
	if p == "f" or p == "e" or p == "b" or p == "u":
		var comm := seed_element(slot)
		if comm != "" and comm != p: return false
	return true
func buy_pt(slot: int, node: String) -> bool:
	if not pt_can(slot, node): return false
	var c := pt_node_cost(slot, node)
	if fp < c: return false
	fp -= c
	seed_nodes(slot)[node] = true
	return true
func plant_bonus(slot: int) -> Dictionary:
	var b := _zero_bonus()
	var ck := seed_chain(slot)
	if ck == "": return b
	var nodes := tree_nodes(ck)
	var owned := seed_nodes(slot)
	for id in nodes:
		if id == "root" or not owned.has(id): continue
		var eff = nodes[id].get("eff", {})
		for key in eff:
			if not b.has(key): continue
			if typeof(eff[key]) == TYPE_BOOL: b[key] = b[key] or eff[key]
			else: b[key] = float(b[key]) + float(eff[key])
	return b
func _zero_bonus() -> Dictionary:
	return {"dmg":0.0,"rate":0.0,"hp":0.0,"amount":0.0,"pierce":0.0,"splash":0.0,"range":0.0,"radius":0.0,"regen":0.0,"thorns":0.0,"faster":0.0,"extra_lanes":0.0,"lane_switch":0.0,"contact_dmg":0.0,"tall":0.0,"chill":0.0,"lightning_rod":0.0,"necro":0.0,"fire_death":0.0,"zap":0.0,"aimbot":0.0,"burn":false,"slow":false,"poison":false,"chain":false,"twin":false}

func equip_req_ok(k: String) -> bool:
	var r: String = EQUIP[k].req
	return r == "" or has(r)
func pass_cost(k: String) -> int:
	return int(SHOP_PASS[k].base) * (int(run_shop.get(k, 0)) + 1)

# ---- Samen-Slots freischalten (Gehirne, dauerhaft) ----
func seed_slot_max() -> bool: return unlocked_slots >= 6
func seed_slot_cost() -> int: return int(15 * pow(2.2, max(0, unlocked_slots - 3)))
func buy_seed_slot() -> bool:
	if seed_slot_max(): return false
	var c := seed_slot_cost()
	if brains < c: return false
	brains -= c; unlocked_slots += 1
	seeds.append({"chain": "", "nodes": {}})
	save_game()
	return true

# Umgebungs-Multiplikator: Nacht-Pflanzen stark bei Nacht, Tag-Pflanzen schwaecher nachts
func env_mul(ck: String) -> float:
	var env: String = str(CHASSIS[ck].get("env", "any"))
	var night: bool = bool(BAL.act_of(wave).get("night", false))
	if env == "night": return 1.35 if night else 0.70
	if env == "day": return 0.85 if night else 1.0
	return 1.0

func seed_stats(slot: int) -> Dictionary:
	return _compute(seed_chain(slot), plant_bonus(slot))
func compute_chassis_stats(ck: String) -> Dictionary:   # Basis (Almanach/Anzeige)
	return _compute(ck, _zero_bonus())
func _compute(ck: String, b: Dictionary) -> Dictionary:
	if ck == "" or not CHASSIS.has(ck): return {"arch": "", "key": "", "cost": 0, "hp": 0.0, "effects": []}
	var c = CHASSIS[ck]
	var arch: String = c.arch
	var attacker := ["shooter","beam","fume","lobber","spike","bomb"].has(arch)
	var em := env_mul(ck)
	var eff_list := []
	if attacker:
		if b.burn: eff_list.append("burn")
		if b.slow: eff_list.append("slow")
		if b.poison: eff_list.append("poison")
		if b.chain: eff_list.append("chain")
		if ck == "frostbluete" and not eff_list.has("slow"): eff_list.append("slow")
	var s := {
		"arch": arch, "key": ck,
		"cost": int(c.get("cost", 0)), "hp": float(c.get("hp", 60)), "cd": float(c.get("cd", 6)),
		"dmg": float(c.get("dmg", 0)), "rate": float(c.get("rate", 0.0)), "speed": float(c.get("speed", 0.0)),
		"splash": float(c.get("splash", 0.0)), "range": float(c.get("range", 0.0)),
		"amount": int(c.get("amount", 0)), "interval": float(c.get("interval", 0.0)), "radius": float(c.get("radius", 0.0)),
		"effects": eff_list,
		"pierce": int(b.pierce),
		"thorns": float(b.thorns),
		"regen": float(b.regen),
		"extra_lanes": int(b.extra_lanes),
		"lane_switch": float(b.lane_switch),
		"contact_dmg": float(b.contact_dmg),
		"tall": float(b.tall),
		"chill": float(b.chill),
		"lightning_rod": float(b.lightning_rod),
		"necro": float(b.necro),
		"fire_death": float(b.fire_death),
		"zap": float(b.zap),
		"aimbot": float(b.aimbot),
	}
	# Pflanzen-eigener Skill-Baum (einmalige Knoten) + Prestige + Run-Shop
	s.dmg = round(s.dmg * (1.0 + b.dmg) * pres_dmg_mul() * run_dmg_mul() * em)
	s.hp = round(s.hp * (1.0 + b.hp) * pres_hp_mul())
	s.amount = int(round(s.amount * (1.0 + b.amount) * run_sun_mul() * em))
	if arch == "sun":
		s.amount += 5 * pres_lvl("sunbloom")
		if b.twin: s.amount *= 2
	s.rate = s.rate * max(0.25, 1.0 + b.rate) * run_rate_mul()
	s.shot_int = (1.0 / s.rate) if s.rate > 0 else 0.0
	s.interval = s.interval * clamp(1.0 - float(b.faster), 0.3, 1.0)
	s.splash = s.splash * (1.0 + b.splash)
	s.range = s.range + float(b.range)
	s.radius = s.radius * (1.0 + b.radius)
	s.cost = max(0, int(round(s.cost)))
	return s

# ================================================================
# KAUF-AKTIONEN
# ================================================================
func buy_research(k: String) -> bool:
	var c := res_cost(k)
	if fp < c: return false
	fp -= c
	research[k] = res_lvl(k) + 1
	return true
func buy_equip(k: String) -> bool:
	if has(k) or not equip_req_ok(k): return false
	var c := int(EQUIP[k].fp)
	if fp < c: return false
	fp -= c; unlocked[k] = true
	return true

func buy_prestige(k: String) -> bool:
	if pres_max(k): return false
	var c := pres_cost(k)
	if brains < c: return false
	brains -= c; prestige[k] = pres_lvl(k) + 1; save_game()
	return true
func buy_pass(k: String) -> bool:
	var c := pass_cost(k)
	if coins < c: return false
	coins -= c; run_shop[k] = int(run_shop.get(k, 0)) + 1
	return true
# ================================================================
# RUN
# ================================================================
func new_run() -> void:
	sun = start_sun()
	coins = 0
	wave = 0
	phase = "prep"
	run_shop.clear()

# Boss fuer eine Boss-Welle: Reihenfolge der 3 Hauptbosse ist pro Run gemischt, Finale fix.
func boss_key_for_wave(w: int) -> String:
	var idx := BAL.BOSS_WAVES.find(w)
	if idx < 0: return ""
	if idx >= 3: return "megaboss"
	return str(boss_order[idx])

# Wiedergeburt: ALLE Skills/Samen weg, Prestige (Gehirne) + Slot-Anzahl bleiben
func rebirth() -> void:
	boss_order.shuffle()                           # jeder Run: andere Boss-Reihenfolge
	fp = 0                                         # Frischstart: alles auf 0
	research = {}
	run_shop = {}
	lure = 0
	unlocked = {}
	plants_unlocked = {}
	garage = false
	tutorial_done = false
	lanes_bought = 0
	shovel = false
	edit_slot = 0
	seeds = []
	for i in range(max(3, unlocked_slots)):
		seeds.append({"chain": "", "nodes": {}})
	plants_unlocked["sonne"] = true                # Sonnenblume = freier Starter
	seeds[0].chain = "sonne"                       # in Slot 1 vorbelegt
	place_slot = 0                                 # direkt zum Setzen gewaehlt
	if pres_lvl("startpea") > 0:
		plants_unlocked["pea"] = true              # Prestige: Erbse gratis freigeschaltet
	new_run()

# ================================================================
# SPEICHERN / LADEN (nur Meta!)
# ================================================================
func save_game() -> void:
	var data := {"brains": brains, "prestige": prestige, "carry_coins": carry_coins, "seen": seen.keys(), "slots": unlocked_slots}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return
	var txt := f.get_as_text(); f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY: return
	brains = int(data.get("brains", 0))
	unlocked_slots = int(data.get("slots", 3))
	if data.has("prestige") and typeof(data.prestige) == TYPE_DICTIONARY: prestige = data.prestige
	carry_coins = int(data.get("carry_coins", 0))
	seen = {}
	if data.has("seen"):
		for k in data.seen: seen[k] = true
