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
var CHASSIS := {
	"sonne":   {"n":"Sonnenblume","arch":"sun","fp":0,"req":"","col":Color(1,0.83,0.2),"cost":50,"hp":60,"cd":5,"amount":25,"interval":8.0,"d":"Produziert Sonne."},
	"pea":     {"n":"Erbsenschütze","arch":"shooter","fp":10,"req":"","col":Color(0.35,0.85,0.4),"cost":100,"hp":60,"cd":5,"dmg":22,"rate":1.4,"speed":340.0,"d":"Schießt Erbsen."},
	"wall":    {"n":"Wal-Nuss","arch":"wall","fp":18,"req":"pea","col":Color(0.62,0.44,0.26),"cost":50,"hp":340,"cd":14,"d":"Zäher Blocker."},
	"werfer":  {"n":"Kohl-Werfer","arch":"lobber","fp":40,"req":"pea","col":Color(0.5,0.75,0.3),"cost":150,"hp":60,"cd":6,"dmg":42,"rate":0.7,"splash":0.9,"d":"Bogenwurf, Fläche."},
	"stachel": {"n":"Stachel","arch":"spike","fp":35,"req":"wall","col":Color(0.55,0.7,0.35),"cost":100,"hp":120,"cd":6,"dmg":16,"d":"Bodendornen."},
	"nebler":  {"n":"Nebler","arch":"fume","fp":60,"req":"werfer","col":Color(0.75,0.6,0.85),"cost":125,"hp":60,"cd":5,"dmg":15,"rate":1.6,"range":2.6,"d":"Nebel, trifft mehrere."},
	"bombe":   {"n":"Bombe","arch":"bomb","fp":80,"req":"stachel","col":Color(0.5,0.28,0.16),"cost":150,"hp":1,"cd":30,"dmg":200,"radius":1.4,"d":"Einmal-Explosion."},
	"beam":    {"n":"Mais-Beam","arch":"beam","fp":120,"req":"nebler","col":Color(0.95,0.82,0.3),"cost":225,"hp":60,"cd":8,"dmg":38,"rate":0.9,"d":"Strahl durch die Reihe."},
}
var CH_ORDER := ["sonne","pea","wall","werfer","stachel","nebler","bombe","beam"]

# ---- RESEARCH (geleverte Upgrades, FP) ----
var RESEARCH := {
	"r_dmg":   {"n":"Schaden","base":4,"g":1.30,"per":0.10,"kind":"pct","d":"+10% Pflanzen-Schaden"},
	"r_rate":  {"n":"Feuerrate","base":6,"g":1.30,"per":0.07,"kind":"pct","d":"+7% Feuerrate"},
	"r_click": {"n":"Klick-Kraft","base":5,"g":1.26,"per":6,"kind":"add","d":"+6 Klick-Schaden"},
	"r_hp":    {"n":"Pflanzen-HP","base":7,"g":1.30,"per":0.10,"kind":"pct","d":"+10% HP"},
	"r_sun":   {"n":"Sonnenausbeute","base":8,"g":1.30,"per":0.10,"kind":"pct","d":"+10% Sonne"},
	"r_coin":  {"n":"Münzausbeute","base":9,"g":1.34,"per":0.12,"kind":"pct","d":"+12% Münzen"},
	"r_fp":    {"n":"Forschungsdrang","base":14,"g":1.45,"per":0.10,"kind":"pct","d":"+10% FP von Zombies"},
}
var RES_ORDER := ["r_dmg","r_rate","r_click","r_hp","r_sun","r_coin","r_fp"]

# ---- EQUIP (einmalig, FP) ----
var EQUIP := {
	"u_almanac":    {"n":"Almanach","fp":5,"req":"","d":"Pflanzen-Almanach"},
	"u_shovel":     {"n":"Schaufel","fp":6,"req":"","d":"Pflanzen entfernen"},
	"u_zombiebook": {"n":"Zombie-Buch","fp":9,"req":"u_almanac","d":"Zombie-Enzyklopädie"},
	"f_lane2":      {"n":"2. Reihe","fp":16,"req":"","d":"+1 Rasenreihe"},
	"f_lane3":      {"n":"3. Reihe","fp":34,"req":"f_lane2","d":"+1 Rasenreihe"},
	"f_mowerfix":   {"n":"Mäher-Werkstatt","fp":26,"req":"","d":"Mäher werden zwischen Wellen repariert"},
	"e_clickcoin":  {"n":"Klick-Gold","fp":10,"req":"u_almanac","d":"Zombies anklicken gibt Münzen"},
}
var EQ_ORDER := ["u_almanac","u_shovel","u_zombiebook","f_lane2","f_lane3","f_mowerfix","e_clickcoin"]

# ---- MUTATIONEN (einmalig, FP) — wirken auf alle Angriffs-Pflanzen ----
var MUT := {
	"m_fire":   {"n":"Feuer","fp":16,"eff":"burn","col":Color(1,0.5,0.2),"d":"Schüsse setzen Zombies in Brand"},
	"m_ice":    {"n":"Eis","fp":16,"eff":"slow","col":Color(0.5,0.8,1),"d":"Schüsse verlangsamen"},
	"m_poison": {"n":"Gift","fp":22,"eff":"poison","col":Color(0.6,0.9,0.3),"d":"Schüsse vergiften"},
	"m_elec":   {"n":"Elektro","fp":30,"eff":"chain","col":Color(1,0.95,0.4),"d":"Blitz springt auf Nachbarn"},
}
var MUT_ORDER := ["m_fire","m_ice","m_poison","m_elec"]

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
var PRES_ORDER := ["startpea","sunbloom","lane","sun","srate","dmg","hp","brain"]

# ---- ZOMBIES ----
var ZTYPES := {
	"basic":    {"n":"Zombie","hp":130,"speed":15,"dmg":38,"fp":1,"col":Color(0.5,0.55,0.5)},
	"flag":     {"n":"Fahnen-Zombie","hp":150,"speed":22,"dmg":38,"fp":2,"col":Color(0.55,0.5,0.6)},
	"cone":     {"n":"Hütchen-Zombie","hp":300,"speed":14,"dmg":40,"fp":2,"col":Color(0.6,0.5,0.4)},
	"vaulter":  {"n":"Stangenspringer","hp":210,"speed":21,"dmg":40,"fp":3,"vault":true,"col":Color(0.5,0.6,0.55)},
	"bucket":   {"n":"Eimer-Zombie","hp":560,"speed":12,"dmg":45,"fp":3,"col":Color(0.6,0.62,0.66)},
	"brainz":   {"n":"Hirn-Träger","hp":240,"speed":18,"dmg":38,"fp":2,"brain":1,"carrier":true,"col":Color(0.62,0.42,0.72)},
	"brute":    {"n":"Grobian","hp":460,"speed":12,"dmg":55,"fp":3,"smash":true,"col":Color(0.52,0.42,0.5)},
	"miniboss": {"n":"Mini-Boss","hp":1500,"speed":11,"dmg":80,"fp":6,"boss":true,"brain":3,"col":Color(0.7,0.4,0.5)},
	"boss_a":   {"n":"Garten-Gargantuar","hp":1200,"speed":9,"dmg":120,"fp":14,"boss":true,"brain":6,"smash":true,"col":Color(0.5,0.7,0.35)},
	"boss_b":   {"n":"Sumpf-Koloss","hp":1400,"speed":11,"dmg":130,"fp":18,"boss":true,"brain":10,"summon":4,"col":Color(0.3,0.55,0.6)},
	"boss_c":   {"n":"Dach-Zerstörer","hp":1700,"speed":10,"dmg":150,"fp":24,"boss":true,"brain":16,"smash":true,"col":Color(0.72,0.45,0.3)},
	"megaboss": {"n":"Ober-Gargantuar","hp":2600,"speed":8,"dmg":220,"fp":60,"boss":true,"brain":35,"final":true,"smash":true,"summon":6,"col":Color(0.85,0.2,0.6)},
}

# ================================================================
# ZUSTAND
# ================================================================
# --- persistente Meta (gespeichert) ---
var brains := 0
var prestige := {}
var seen := {}          # Set: zombie-key -> true
var carry_coins := 0
var zlab := {"str":0,"arm":0,"spd":0}
# --- Skills (NICHT gespeichert, bleiben aber während der Sitzung) ---
var fp := 0
var research := {}
var unlocked := {"sonne": true}   # chassis + equip + mutation ids
var run_shop := {}
var lure := 0                     # Lockstoff-Stufe: Idle-Zombies zwischen Wellen
var god := false                  # Dev: Rasen kann nicht verloren gehen
# --- Kampf-Laufzeit ---
var sun := 75
var coins := 0
var wave := 0
var phase := "prep"     # "prep" | "fight"
var selected := "sonne"
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
func lanes_count() -> int:
	return min(5, 1 + pres_lvl("lane") + field_lanes())
func start_sun() -> int: return 50 + 25 * pres_lvl("sun")
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
func has_click_coin() -> bool: return has("e_clickcoin")
func mower_fix() -> bool: return has("f_mowerfix")
func risk_level() -> int: return int(zlab.str) + int(zlab.arm) + int(zlab.spd)
func reward_mul() -> float: return 1.0 + 0.10 * risk_level()
func idle_cap() -> int: return 1 + lure          # max. Zombies zwischen den Wellen
func lure_max() -> bool: return lure >= 5
func lure_cost() -> int: return int(ceil(18 * pow(1.7, lure)))
func buy_lure() -> bool:
	if lure_max(): return false
	var c := lure_cost()
	if fp < c: return false
	fp -= c; lure += 1
	return true
func active_effects() -> Array:
	var a := []
	for k in MUT_ORDER:
		if has(k): a.append(MUT[k].eff)
	return a
func chassis_req_ok(ck: String) -> bool:
	var r: String = CHASSIS[ck].req
	return r == "" or has(r)
func equip_req_ok(k: String) -> bool:
	var r: String = EQUIP[k].req
	return r == "" or has(r)
func pass_cost(k: String) -> int:
	return int(SHOP_PASS[k].base) * (int(run_shop.get(k, 0)) + 1)

func compute_chassis_stats(ck: String) -> Dictionary:
	var c = CHASSIS[ck]
	var arch: String = c.arch
	var s := {
		"arch": arch, "key": ck,
		"cost": int(c.get("cost", 0)), "hp": float(c.get("hp", 60)), "cd": float(c.get("cd", 6)),
		"dmg": float(c.get("dmg", 0)), "rate": float(c.get("rate", 0.0)), "speed": float(c.get("speed", 0.0)),
		"splash": float(c.get("splash", 0.0)), "range": float(c.get("range", 0.0)),
		"amount": int(c.get("amount", 0)), "interval": float(c.get("interval", 0.0)), "radius": float(c.get("radius", 0.0)),
		"effects": (active_effects() if ["shooter","beam","fume","lobber"].has(arch) else []),
	}
	s.dmg = round(s.dmg * res_mul("r_dmg") * pres_dmg_mul() * run_dmg_mul())
	s.hp = round(s.hp * res_mul("r_hp") * pres_hp_mul())
	s.amount = int(round(s.amount * res_mul("r_sun") * run_sun_mul()))
	if arch == "sun": s.amount += 5 * pres_lvl("sunbloom")
	s.rate = s.rate * res_mul("r_rate") * run_rate_mul()
	s.shot_int = (1.0 / s.rate) if s.rate > 0 else 0.0
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
func buy_chassis(ck: String) -> bool:
	if has(ck) or not chassis_req_ok(ck): return false
	var c := int(CHASSIS[ck].fp)
	if fp < c: return false
	fp -= c; unlocked[ck] = true; selected = ck
	return true
func buy_equip(k: String) -> bool:
	if has(k) or not equip_req_ok(k): return false
	var c := int(EQUIP[k].fp)
	if fp < c: return false
	fp -= c; unlocked[k] = true
	return true
func buy_mut(k: String) -> bool:
	if has(k): return false
	var c := int(MUT[k].fp)
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
func zlab_change(key: String, delta: int) -> void:
	zlab[key] = clamp(int(zlab.get(key, 0)) + delta, 0, 10)
	save_game()

# ================================================================
# RUN
# ================================================================
func new_run() -> void:
	sun = start_sun()
	coins = 0
	wave = 0
	phase = "prep"
	run_shop.clear()
	if not has(selected): selected = "sonne"

# Wiedergeburt: ALLE Skills weg, Prestige (Gehirne) bleibt und schaltet Boni frei
func rebirth() -> void:
	fp = 0
	research = {}
	run_shop = {}
	lure = 0
	unlocked = {"sonne": true}
	selected = "sonne"
	shovel = false
	_apply_prestige_unlocks()
	new_run()

func _apply_prestige_unlocks() -> void:
	if pres_lvl("startpea") > 0: unlocked["pea"] = true

# ================================================================
# SPEICHERN / LADEN (nur Meta!)
# ================================================================
func save_game() -> void:
	var data := {"brains": brains, "prestige": prestige, "carry_coins": carry_coins, "zlab": zlab, "seen": seen.keys()}
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
	if data.has("prestige") and typeof(data.prestige) == TYPE_DICTIONARY: prestige = data.prestige
	carry_coins = int(data.get("carry_coins", 0))
	if data.has("zlab") and typeof(data.zlab) == TYPE_DICTIONARY:
		zlab = {"str": int(data.zlab.get("str", 0)), "arm": int(data.zlab.get("arm", 0)), "spd": int(data.zlab.get("spd", 0))}
	seen = {}
	if data.has("seen"):
		for k in data.seen: seen[k] = true
