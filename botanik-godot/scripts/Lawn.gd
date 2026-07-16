extends Node2D
# Kampf-Engine: zeichnet den Rasen und simuliert Pflanzen/Zombies.
# Liest/schreibt den Zustand in der Autoload-Instanz "Game".

var rows := 1
var plants: Array = []
var zombies: Array = []
var peas: Array = []
var suns: Array = []
var mowers: Array = []
var fx: Array = []
var graveyard: Array = []   # tote Pflanzen fuer Necromancer-Wiederbelebung
var popups: Array = []      # schwebende Zahlen (+Sonne, Belohnungen)
var _font: Font             # Fallback-Font fuer die schwebenden Zahlen
var _tex_cache := {}        # geladene Sprite-Texturen (null = kein Sprite -> gezeichneter Fallback)
var _frames_cache := {}     # animierte Frame-Listen je Ordner
var _anim_cache := {}       # benannte Zustands-Animationen: "kind|state" -> [Texture2D]
var _anim_clock := 0.0      # globale Animations-Uhr
var _bg_cache := {}         # "day"/"night" -> Texture2D (Tag/Nacht-Hintergrund)
var rng := RandomNumberGenerator.new()

var to_spawn := 0
var spawn_timer := 0.0
var sky_timer := 5.0
var idle_timer := 6.0
var hazard_timer := 8.0
var msg := ""
var msg_t := 0.0
# ---- Wetter ----
var weather := "klar"      # klar / gewitter / nebel / frost
var strike_t := 0.0        # Timer fuer Gewitter-Blitze
# ---- Rhythmus (Beat-synchrones Schiessen + Pflanzen-Bounce) ----
var beat_interval := 0.469  # Sekunden pro Beat (aus BPM, in _ready gesetzt)
var beat_t := 0.0           # Zeit seit letztem Beat
var beat_pulse := 0.0       # 1.0 auf dem Beat, klingt schnell ab (fuer Bounce)
var _boss_seen := false     # Boss-Auftritt: einmaliger Screen-Flash
# Kill-Combo: schnelle Kills hintereinander erhoehen die Belohnung
var combo := 0
var combo_t := 0.0
const COMBO_WINDOW := 2.6   # Sekunden bis der Combo verfaellt
var auto_wave_t := 0.0      # Countdown bis zur automatischen naechsten Welle
# Screen-Shake (nur die Spielwelt, nicht das HUD)
var _shake := 0.0
var _shake_mag := 0.0
var _mouse := Vector2(-999, -999)   # Mausposition fuer die Platzier-Vorschau
# Lauf-Statistik (fuer den Todes-/Sieg-Bildschirm)
var run_kills := 0
var best_combo := 0

func _ready() -> void:
	rng.randomize()
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # scharfe Pixel-Art (kein Blur)
	beat_interval = 60.0 / max(1.0, BAL.MUSIC_BPM)
	reset_run()

# Setzt den Takt-Zaehler zurueck (spaeter vom Musikplayer beim Song-Start aufgerufen -> Beat 1 = Downbeat)
func reset_beat() -> void:
	beat_t = 0.0
	beat_pulse = 1.0

# Laedt ein Sprite, falls vorhanden (sonst null -> gezeichneter Fallback). Ergebnis wird gecacht.
func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path): return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path): t = load(path)
	_tex_cache[path] = t
	return t

# Laedt Animations-Frames aus einem Ordner: <dir>/0.png, 1.png, 2.png ... (gecacht)
func _frames(dir: String) -> Array:
	if _frames_cache.has(dir): return _frames_cache[dir]
	var arr := []
	for i in range(24):
		var p := "%s/%d.png" % [dir, i]
		if ResourceLoader.exists(p): arr.append(load(p))
		else: break
	_frames_cache[dir] = arr
	return arr

# Zombie-Textur: erst nummerierter Ordner zombies/<kind>/0.png, sonst einzelne Datei
func _zombie_tex(kind: String) -> Texture2D:
	var frames := _frames("res://assets/sprites/zombies/%s" % kind)
	if frames.size() > 0:
		var idx := int(_anim_clock / 0.16) % frames.size()
		return frames[idx]
	return _tex("res://assets/sprites/zombies/%s.png" % kind)

# Benannte Zustands-Animation: sucht im Ordner alle PNGs, die "walking"/"idle"/"dying" enthalten
func _zombie_anim(kind: String, state: String) -> Array:
	var key := kind + "|" + state
	if _anim_cache.has(key): return _anim_cache[key]
	var dir := "res://assets/sprites/zombies/%s" % kind
	var frames := []
	var da := DirAccess.open(dir)
	if da != null:
		var names := []
		for f in da.get_files():
			var low := f.to_lower()
			if low.ends_with(".png") and low.find(state) != -1:
				names.append(f)
		names.sort()   # 000,001,... -> richtige Reihenfolge
		for n in names:
			var t = load(dir + "/" + n)
			if t != null: frames.append(t)
	_anim_cache[key] = frames
	return frames

# Tag/Nacht-Hintergrund: bg/day.png bzw. bg/night.png, mit Heuristik + Fallback
func _scene_bg(night: bool) -> Texture2D:
	var key := "night" if night else "day"
	if _bg_cache.has(key): return _bg_cache[key]
	var tex: Texture2D = null
	# Direkte Kandidaten — deckt day.png.jpg, night.png, .jpeg, .webp ab
	for ext in [".png", ".png.jpg", ".jpg", ".jpeg", ".webp"]:
		var cand := "res://assets/sprites/bg/%s%s" % [key, ext]
		if ResourceLoader.exists(cand):
			tex = load(cand); break
	# Fallback: Ordner scannen (auch jpg/jpeg/webp, nicht nur png)
	if tex == null:
		var da := DirAccess.open("res://assets/sprites/bg")
		var any_tex: Texture2D = null
		var match_tex: Texture2D = null
		if da != null:
			for f in da.get_files():
				var low := f.to_lower()
				if not (low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp")): continue
				var p := "res://assets/sprites/bg/" + f
				if any_tex == null: any_tex = load(p)
				var is_night := low.find("graveyard") != -1 or low.find("night") != -1 or low.find("nacht") != -1 or low.find("dark") != -1
				var is_day := low.find("day") != -1 or low.find("tag") != -1 or low.find("forest") != -1 or low.find("wald") != -1 or low.find("garden") != -1 or low.find("garten") != -1
				if night and is_night: match_tex = load(p); break
				if (not night) and is_day: match_tex = load(p); break
		tex = match_tex if match_tex != null else any_tex
	_bg_cache[key] = tex
	return tex

func _start_dying(z) -> void:
	if not z.get("dropped", false): _kill(z)
	z["dying"] = true
	z["die_t"] = 0.0
	# Truemmer-Partikel beim Sterben (fliegen auseinander, fallen)
	var gcol: Color = z.get("col", Color(0.6, 0.7, 0.5))
	var gn := 8 if z.get("boss", false) else 5
	for _gi in range(gn):
		var ang := rng.randf() * TAU
		var spd := 60.0 + rng.randf() * 130.0
		fx.append({"t": "gib", "x": float(z.x), "y": float(z.y) - 18.0, "vx": cos(ang) * spd, "vy": sin(ang) * spd - 90.0, "life": 0.5 + rng.randf() * 0.35, "col": gcol, "sz": 2.5 + rng.randf() * 2.8})
	# Liebespaar: stirbt einer, wird der Partner sauer und rennt los
	var partner = z.get("partner", null)
	if partner != null and not partner.get("dying", false) and float(partner.get("hp", 0.0)) > 0.0:
		partner["enraged"] = true
		partner["partner"] = null      # Link loesen (kein Zirkelbezug)
		fx.append({"t": "boom", "x": partner.x, "y": partner.y - 20, "life": 0.3})
		Music.play_sfx("rage", 0.3)
		msg = "Ein Renn-Zombie hat seinen Partner verloren — jetzt rennt er wuetend!"; msg_t = 1.8
	z["partner"] = null

func _die_dur(z) -> float:
	var df := _zombie_anim(str(z.kind), "dying")
	return max(0.4, df.size() * 0.06)

func world_of(w: int) -> Dictionary:
	return BAL.act_of(w)

func reset_run() -> void:
	Game.rebirth()
	plants.clear(); zombies.clear(); peas.clear(); suns.clear(); fx.clear(); graveyard.clear(); popups.clear()
	rows = Game.lanes_count()
	Game.update_lawn_y(rows)   # Rasen mittig auf dem Bildschirm
	mowers.clear()
	for r in range(rows):
		mowers.append({"row": r, "x": float(Game.LAWN_X - 30), "active": false, "used": false})
	sky_timer = 5.0; to_spawn = 0; idle_timer = 6.0; hazard_timer = 9.0
	combo = 0; combo_t = 0.0; run_kills = 0; best_combo = 0
	_shake = 0.0; _shake_mag = 0.0; position = Vector2.ZERO
	weather = "klar"; strike_t = 0.0
	Music.set_rain(false)
	msg = "Pflanze eine Sonnenblume, um die erste Welle zu starten!"; msg_t = 6.0

# Reihen nachziehen, wenn neue freigeschaltet wurden (mid-run kaufbar)
func _sync_rows() -> void:
	var want := Game.lanes_count()
	if want <= rows: return
	# Rasen bleibt zentriert: LAWN_Y neu berechnen und alle vorhandenen Objekte mitschieben
	var old_y := Game.LAWN_Y
	Game.update_lawn_y(want)
	var dy := float(Game.LAWN_Y - old_y)
	if dy != 0.0:
		for p in plants: p.y += dy
		for z in zombies: z.y += dy
		for pe in peas: pe.y += dy
		for su in suns: su.y += dy; su.ty += dy
		for g in graveyard: g.y += dy
	for r in range(rows, want):
		mowers.append({"row": r, "x": float(Game.LAWN_X - 30), "active": false, "used": false})
	rows = want

func start_wave() -> void:
	if Game.phase != "prep": return
	Game.wave += 1
	Game.phase = "fight"
	_roll_weather()
	_sync_rows()
	# --- RASEN-UMBRUCH: neuer Akt (Welle 25/50/75) — die Map bricht um! ---
	var umbruch := Game.wave > 1 and BAL.act_index(Game.wave) != BAL.act_index(Game.wave - 1)
	if umbruch: _do_umbruch()
	to_spawn = BAL.WAVE_BASE + int(Game.wave * BAL.WAVE_PER) + int(Game.wave / 6.0) * Game.lanes_count()
	spawn_timer = (BAL.UMBRUCH_GRACE if umbruch else 0.5)
	if umbruch:
		pass   # Flag-Zombie kommt erst nach der Schonfrist mit der Horde
	else:
		_spawn("flag")
		to_spawn = max(0, to_spawn - 1)
	if BAL.is_boss_wave(Game.wave):
		var bk := Game.boss_key_for_wave(Game.wave)
		_spawn(bk)   # Boss kommt SOFORT — waehrend du im Umbruch neu baust
		fx.append({"t": "flash", "life": 0.35, "col": Color(1.0, 0.92, 0.8)})
		Music.play_sfx("boss_spawn", 1.0)
		to_spawn += int(Game.ZTYPES[bk].get("summon", 0))
		var wo := world_of(Game.wave)
		if umbruch:
			msg = "RASEN-UMBRUCH: %s!  BOSS: %s  ·  Schonfrist: baue neu auf!" % [str(wo.name), str(Game.ZTYPES[bk].n)]
			msg_t = float(BAL.UMBRUCH_GRACE)
		else:
			msg = "%s  —  BOSS: %s!" % [wo.name, Game.ZTYPES[bk].n]; msg_t = 3.0
		return
	elif Game.wave == BAL.MINIBOSS_WAVE:
		_spawn("miniboss")
	msg = "Welle %d startet!" % Game.wave; msg_t = 1.6

# Der grosse Moment: Rasen bricht um. Pflanzen zerstoert (50% Sonne zurueck), kurze Schonfrist.
func _do_umbruch() -> void:
	var back := 0.0
	for p in plants:
		back += float(p.s.get("cost", 0)) * BAL.UMBRUCH_REFUND
	plants.clear()
	graveyard.clear()
	peas.clear()
	Game.sun += int(back)
	fx.append({"t": "flash", "life": 0.45, "col": Color(0.7, 0.4, 1.0)})
	var wo := world_of(Game.wave)
	msg = "DER RASEN BRICHT UM — %s!  +%d Sonne erstattet · %d s Schonfrist" % [str(wo.name), int(back), int(BAL.UMBRUCH_GRACE)]
	msg_t = float(BAL.UMBRUCH_GRACE)

func _roll_weather() -> void:
	# Erste Welle & Boss-Wellen bleiben klar
	if Game.wave <= 1 or BAL.is_boss_wave(Game.wave):
		weather = "klar"; strike_t = 2.0; Music.set_rain(false); return
	var r := rng.randf()
	if r < 0.45: weather = "klar"
	elif r < 0.63: weather = "gewitter"
	elif r < 0.81: weather = "nebel"
	else: weather = "frost"
	strike_t = rng.randf_range(12.0, 22.0)   # erster Blitz kommt nicht sofort
	Music.set_rain(weather == "gewitter")    # Regen-Sound nur bei Gewitter
	if weather != "klar":
		msg = "Wetter: %s!" % weather_name(); msg_t = 2.2

func weather_name() -> String:
	match weather:
		"gewitter": return "Gewitter"
		"nebel": return "Nebel"
		"frost": return "Frost"
		_: return "Klar"

func weather_hud() -> String:
	return "" if weather == "klar" else "  ·  " + weather_name()

# Eine Pflanze hat "BlitzEvolution" (Blitz-Ast geskillt) oder ist die Stahlnuss -> Blitzableiter
func _is_lightning_rod(p) -> bool:
	var s = p.s
	if float(s.get("lightning_rod", 0.0)) > 0.0: return true
	if str(p.get("element", "")) == "b": return true          # Blitz-Evolution
	if s.get("effects", []).has("chain"): return true          # Kettenblitz
	if float(s.get("zap", 0.0)) > 0.0: return true             # Blitzstrahl (Sonne)
	if float(s.get("aimbot", 0.0)) > 0.0: return true          # Katze (Blitzpad)
	return false

func _storm_strike() -> void:
	if plants.is_empty(): return
	# Blitzableiter (Blitz-Evolution/Stahlnuss) ziehen den Blitz an sich
	var rods := []
	for p in plants:
		if _is_lightning_rod(p): rods.append(p)
	var harmless := not rods.is_empty()
	var tgt = rods[rng.randi() % rods.size()] if harmless else plants[rng.randi() % plants.size()]
	# Optik + Sound
	fx.append({"t": "bolt", "x": tgt.x, "y": float(Game.LAWN_Y - 70), "x2": tgt.x, "y2": tgt.y, "life": 0.3})
	fx.append({"t": "flash", "life": 0.22, "col": Color(0.8, 0.9, 1.0)})
	Music.play_sfx("thunder")
	if harmless:
		# Ableiter faengt den Blitz harmlos + entlaedt ihn in nahe Zombies
		fx.append({"t": "boom", "x": tgt.x, "y": tgt.y, "life": 0.25})
		for z in zombies:
			if z.hp > 0 and Vector2(z.x, z.y).distance_to(Vector2(tgt.x, tgt.y)) < Game.CELL * 2.2:
				z.hp -= 70.0
				fx.append({"t": "bolt", "x": tgt.x, "y": tgt.y, "x2": z.x, "y2": z.y, "life": 0.2})
		msg = "Blitzableiter faengt den Blitz!"; msg_t = 1.3
	else:
		tgt.hp -= 120.0
		fx.append({"t": "boom", "x": tgt.x, "y": tgt.y, "life": 0.3})
		msg = "Blitz schlaegt in eine Pflanze ein!"; msg_t = 1.3
		if tgt.hp <= 0: _plant_dies(tgt)

func _end_wave() -> void:
	if Game.wave >= 100:
		var rew := 150 + int(Game.brains * 0.25)
		Game.brains += rew; Game.save_game()
		Game.phase = "won"
		msg = "SIEG! Welle 100 geschafft! +%d Skulls" % rew; msg_t = 6.0
		return
	Game.phase = "prep"
	Game.fp += Game.wave
	auto_wave_t = 3.5   # bei aktiviertem Auto-Modus startet die naechste Welle nach kurzer Pause
	# Wellen-Abschluss-Bonus (skaliert mit der Welle) — belohnt Durchhalten
	var bonus_sun := 25 + Game.wave * 5
	Game.sun += bonus_sun
	_add_shake(4.0)
	_popup(Game.LAWN_X + Game.COLS * Game.CELL * 0.5, Game.LAWN_Y + 20.0, "Welle geschafft! +%d Sonne" % bonus_sun, Color(0.6, 1.0, 0.65))
	# Maeher werden NUR mit der Werkstatt-Skill repariert (sonst bleiben verbrauchte Maeher weg)
	if Game.mower_fix():
		for m in mowers: m.used = false; m.active = false; m.x = float(Game.LAWN_X - 30)
	msg = "Welle %d geschafft! +%d FP · +%d Sonne" % [Game.wave, Game.wave, bonus_sun]; msg_t = 2.2

func _make_zombie(kind: String) -> Dictionary:
	var b = Game.ZTYPES[kind]
	var row := rng.randi() % rows
	var hp_mul := 1.0 + Game.wave * BAL.Z_HP_PER_WAVE + pow(Game.wave, BAL.Z_HP_POW) * BAL.Z_HP_POW_MUL
	var hp := float(b.hp) * hp_mul
	return {
		"kind": kind, "row": row, "x": float(Game.LAWN_X + Game.COLS * Game.CELL + 20),
		"y": Game.LAWN_Y + row * Game.CELL + Game.CELL / 2.0,
		"hp": hp, "maxhp": hp, "speed": float(b.speed) * (1.0 + Game.wave * BAL.Z_SPD_PER_WAVE),
		"dmg": float(b.dmg), "col": b.col,
		"boss": b.get("boss", false), "final": b.get("final", false), "vault": b.get("vault", false),
		"smash": b.get("smash", false), "carrier": b.get("carrier", false),
		"jumped": false, "fp": int(b.fp), "brain": int(b.get("brain", 0)),
		"slow": 0.0, "burn": 0.0, "poison": 0.0, "dropped": false, "switched": false,
		"element": str(b.get("element", "")), "ability_t": 0.0,
		"fly": b.get("fly", false), "rage": b.get("rage", false),
		"shield": float(b.get("shield", 0.0)), "maxshield": float(b.get("shield", 0.0)),
		"enraged": false, "shirt": "", "partner": null
	}

func _spawn_poof(x: float, y: float) -> void:
	for _k in range(5):
		var a := rng.randf() * TAU
		fx.append({"t": "gib", "x": x, "y": y - 10.0, "vx": cos(a) * 45.0, "vy": sin(a) * 30.0 - 20.0, "life": 0.4, "col": Color(0.55, 0.35, 0.7), "sz": 2.4 + rng.randf() * 1.5})

func _spawn(kind: String) -> void:
	Game.seen[kind] = true
	var z1 = _make_zombie(kind)
	zombies.append(z1)
	_spawn_poof(float(z1.x), float(z1.y))
	# Renn-Zombie kommt als LIEBESPAAR: zwei Partner (Shirt "him"/"her"),
	# stirbt einer, wird der andere sauer und rennt los.
	if kind == "sprinter":
		z1["shirt"] = "him"
		var z2 = _make_zombie(kind)
		z2["shirt"] = "her"
		z2["row"] = z1.row
		z2["y"] = z1.y
		z2["x"] = float(z1.x) + Game.CELL * 0.85   # laeuft direkt hinter dem Partner
		z1["partner"] = z2
		z2["partner"] = z1
		zombies.append(z2)

func _spawn_one() -> void:
	var act := world_of(Game.wave)
	var k := _weighted(act.spawn)
	# Gehirn-Traeger tauchen selten zusaetzlich auf (nur sie + Bosse droppen Gehirne)
	if Game.wave >= BAL.BRAIN_MIN_WAVE and k != "brainz" and rng.randf() < BAL.BRAIN_CHANCE:
		k = "brainz"
	# Progressive Ruestung: je hoeher die Welle, desto oefter werden schwache Zombies aufgepanzert
	var armor_chance: float = min(0.55, Game.wave * 0.012)
	if (k == "basic" or k == "flag") and rng.randf() < armor_chance:
		var armored := ["cone", "bucket", "shield", "brute"]
		k = armored[rng.randi() % armored.size()]
	_spawn(k)

func _weighted(table) -> String:
	var total := 0
	for e in table: total += int(e[1])
	if total <= 0: return "basic"
	var r := rng.randi() % total
	for e in table:
		r -= int(e[1])
		if r < 0: return str(e[0])
	return str(table[0][0])

func item(name: String) -> void:
	if name == "isun": Game.sun += 250
	elif name == "ifreeze":
		for z in zombies: z.slow = 6.0
	elif name == "imower":
		for m in mowers: m.used = false; m.active = false; m.x = float(Game.LAWN_X - 30)

func _process(delta: float) -> void:
	if not Game.paused and Game.phase != "won" and Game.phase != "dead":
		# Fast-Forward: die Simulation mehrfach pro Frame laufen lassen (stabile Schritte)
		var steps: int = clampi(int(Game.game_speed), 1, 3)
		for _i in range(steps):
			_update(delta)
	if msg_t > 0: msg_t -= delta
	# Screen-Shake abklingen lassen und auf die Spielwelt anwenden (HUD bleibt ruhig)
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta / 0.35)
		var amp := _shake_mag * _shake
		position = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	queue_redraw()

# Screen-Shake ausloesen (Groesse = Pixel-Ausschlag)
func _add_shake(mag: float) -> void:
	_shake_mag = max(_shake_mag, mag)
	_shake = 1.0

func _update(dt: float) -> void:
	_anim_clock += dt
	# Kill-Combo verfaellt, wenn zu lange kein Zombie stirbt
	if combo > 0:
		combo_t -= dt
		if combo_t <= 0.0: combo = 0
	# Rhythmus-Takt: beat_now ist genau in dem Frame true, in dem ein Beat faellt
	beat_t += dt
	var beat_now := false
	if beat_t >= beat_interval:
		beat_t -= beat_interval
		beat_now = true
		beat_pulse = 1.0
	if beat_pulse > 0.0: beat_pulse = max(0.0, beat_pulse - dt / 0.16)
	# Boss-Auftritt: einmaliger roter Screen-Flash, wenn ein Boss auf dem Feld erscheint
	var boss_now := false
	for z in zombies:
		if z.get("boss", false) and float(z.get("hp", 0.0)) > 0.0:
			boss_now = true; break
	if boss_now and not _boss_seen:
		fx.append({"t": "flash", "col": Color(1.0, 0.2, 0.15), "life": 0.6})
		_add_shake(12.0)
		_boss_seen = true
	elif not boss_now:
		_boss_seen = false
	var wo := world_of(Game.wave)
	var night := BAL.is_night_wave(Game.wave)
	# Himmels-Sonne (nachts seltener & weniger)
	sky_timer -= dt
	if sky_timer <= 0:
		sky_timer = (8.0 + rng.randf() * 4.0) * (1.7 if night else 1.0)
		var x := Game.LAWN_X + 40 + rng.randf() * (Game.COLS * Game.CELL - 80)
		var val := int(round(25 * (0.5 if night else 1.0)))
		suns.append({"x": x, "y": float(Game.LAWN_Y - 10), "ty": Game.LAWN_Y + 50 + rng.randf() * (rows * Game.CELL - 120), "vy": 70.0, "value": val, "falling": true, "life": 12.0})
	# Wetter: Gewitter schlaegt Blitze auf Zombies (Blitz-Synergie)
	if weather == "gewitter" and not plants.is_empty():
		strike_t -= dt
		if strike_t <= 0:
			strike_t = rng.randf_range(16.0, 30.0)   # seltenes, cooles Ereignis
			_storm_strike()
	# Wellensteuerung
	if Game.phase == "fight":
		spawn_timer -= dt
		if to_spawn > 0 and spawn_timer <= 0:
			spawn_timer = 1.6 + rng.randf() * 1.9   # groessere Abstaende -> Wellen laufen laenger, nicht alles auf einmal
			_spawn_one(); to_spawn -= 1
		if to_spawn <= 0 and zombies.is_empty():
			_end_wave()
	elif Game.phase == "prep":
		# Zwischen den Wellen kommen vereinzelt Zombies (Cap = idle_cap, im Labor upgradebar)
		idle_timer -= dt
		if idle_timer <= 0 and zombies.size() < Game.idle_cap():
			idle_timer = rng.randf_range(5.0, 9.0)
			_spawn("basic")
		# Auto-Modus: naechste Welle nach kurzer Pause selbst starten (erst ab Welle 1)
		if Game.auto_wave and Game.wave >= 1:
			auto_wave_t -= dt
			if auto_wave_t <= 0.0:
				start_wave()
	# Umwelt-Zerstoerung (Dachterrasse/Finstere Zone): beschaedigt zufaellige Pflanzen
	if wo.get("hazard", false) and not plants.is_empty():
		hazard_timer -= dt
		if hazard_timer <= 0:
			hazard_timer = rng.randf_range(BAL.HAZARD_MIN, BAL.HAZARD_MAX)
			var ph = plants[rng.randi() % plants.size()]
			if _is_lightning_rod(ph):
				# Blitzableiter (Blitz-Evolution/Stahlnuss): leitet den Umwelt-Blitz harmlos ab
				fx.append({"t": "boom", "x": ph.x, "y": ph.y, "life": 0.2})
				msg = "Blitz abgeleitet!"; msg_t = 1.0
			else:
				ph.hp -= BAL.HAZARD_DMG
				fx.append({"t": "boom", "x": ph.x, "y": ph.y, "life": 0.3})
				if ph.hp <= 0: _plant_dies(ph)
				msg = "Umwelt-Schaden!"; msg_t = 1.0
	# Pflanzen
	var revived: Array = []   # Necromancer-Wiederbelebungen (erst nach der Schleife einfuegen)
	var expired: Array = []   # abgelaufene Nacht-Pilze (erst nach der Schleife entfernen)
	for p in plants:
		var s = p.s
		if float(p.get("recoil", 0.0)) > 0.0: p["recoil"] = max(0.0, float(p.recoil) - dt / 0.14)
		if float(s.get("regen", 0.0)) > 0.0 and p.hp < p.maxhp:
			p.hp = min(p.maxhp, p.hp + float(s.regen) * dt)
		# Vom Eisboss eingefroren: Pflanze macht nichts, bis sie auftaut
		if float(p.get("frozen", 0.0)) > 0.0:
			p["frozen"] = float(p.get("frozen", 0.0)) - dt
			continue
		# Nacht-Pilze wachsen bis zum Ablauf: staerker mit der Zeit, dann verschwinden sie
		if str(Game.CHASSIS[p.ck].get("env", "any")) == "night":
			p["age"] = float(p.get("age", 0.0)) + dt
			var frac: float = clamp(p.age / BAL.SHROOM_LIFESPAN, 0.0, 1.0)
			p["gm"] = 1.0 + frac * (BAL.SHROOM_GROWTH_MAX - 1.0)
			if p.age >= BAL.SHROOM_LIFESPAN:
				expired.append(p)
				continue
		# Blitzstrahl-Sonnenblume: zappt regelmaessig einen Zombie
		if float(s.get("zap", 0.0)) > 0.0:
			p["zap_t"] = float(p.get("zap_t", 0.0)) + dt
			var zap_iv := 2.0 if float(s.get("zap", 0.0)) >= 2.0 else 3.0
			if weather == "gewitter": zap_iv *= 0.5   # Gewitter-Synergie: doppelt so oft zappen
			if p.zap_t >= zap_iv:
				p.zap_t = 0.0
				_zap_random(p)
		# Necromancer-Sonnenblume: belebt regelmaessig eine tote Pflanze wieder
		if float(s.get("necro", 0.0)) > 0.0 and not graveyard.is_empty():
			p["necro_t"] = float(p.get("necro_t", 0.0)) + dt
			if p.necro_t >= 8.0:
				p.necro_t = 0.0
				var rev = _necro_revive()
				if rev != null: revived.append(rev)
		# Cattail/Katze (Blitzpad): zielt automatisch auf Zombies auf ALLEN Lanes
		if float(s.get("aimbot", 0.0)) > 0.0:
			p["aim_t"] = float(p.get("aim_t", 0.0)) + dt
			var aim_iv := 1.0 if float(s.get("aimbot", 0.0)) >= 2.0 else 1.5
			if weather == "gewitter": aim_iv *= 0.6   # Gewitter-Synergie: Katze zielt schneller
			if p.aim_t >= aim_iv:
				p.aim_t = 0.0
				_cattail_fire(p)
		if p.arch == "bomb":
			p.fuse -= dt
			if p.fuse <= 0 and not p.done: _bomb(p); p.done = true
			continue
		p.t += dt
		if p.arch == "sun":
			if p.t >= s.interval:
				p.t = 0.0
				suns.append({"x": p.x + rng.randf_range(-8,8), "y": p.y, "ty": p.y, "vy": 0.0, "value": int(s.amount * float(p.get("gm", 1.0))), "falling": false, "life": 12.0})
				# kleiner Funken-Ausbruch bei der Sonnen-Produktion
				for _sk in range(4):
					var sa := rng.randf() * TAU
					fx.append({"t": "gib", "x": float(p.x), "y": float(p.y) - 6.0, "vx": cos(sa) * 42.0, "vy": -40.0 - rng.randf() * 45.0, "life": 0.42, "col": Color(1.0, 0.9, 0.4), "sz": 2.0 + rng.randf() * 1.2})
		elif p.arch == "shooter":
			if p.t >= s.shot_int and (beat_now or not BAL.RHYTHM_SHOOT) and _lane_has(p): p.t = 0.0; _shoot(p); p["recoil"] = 1.0
		elif p.arch == "beam":
			if p.t >= s.shot_int and (beat_now or not BAL.RHYTHM_SHOOT) and _lane_has(p): p.t = 0.0; _beam(p); p["recoil"] = 1.0
		elif p.arch == "fume":
			if p.t >= s.shot_int and (beat_now or not BAL.RHYTHM_SHOOT) and _lane_has(p): p.t = 0.0; _fume(p); p["recoil"] = 1.0
		elif p.arch == "lobber":
			if p.t >= s.shot_int and (beat_now or not BAL.RHYTHM_SHOOT) and _lane_has(p): p.t = 0.0; _lob(p); p["recoil"] = 1.0
	for rp in revived:
		plants.append(rp)
		fx.append({"t": "boom", "x": rp.x, "y": rp.y, "life": 0.3})
	for ep in expired:
		fx.append({"t": "boom", "x": ep.x, "y": ep.y, "life": 0.35})
		plants.erase(ep)
	# Erbsen
	for i in range(peas.size() - 1, -1, -1):
		var pe = peas[i]
		if pe.get("lob", false):
			pe.pt += dt / pe.dur
			pe.x = pe.sx + (pe.tx - pe.sx) * pe.pt
			if pe.pt >= 1.0: _lob_hit(pe); peas.remove_at(i)
			continue
		pe.x += pe.vx * dt
		if pe.x > Game.LAWN_X + Game.COLS * Game.CELL + 20: peas.remove_at(i); continue
		var gone := false
		for z in zombies:
			if z.row == pe.row and z.hp > 0 and abs(z.x - pe.x) < 26 and not pe.hit.has(z):
				if float(z.get("shield", 0.0)) > 0.0:
					z["shield"] = float(z.shield) - pe.dmg   # Schild absorbiert frontale Erbsen
				else:
					z.hp -= pe.dmg; _apply_fx(z, pe.effects, pe.dmg)
					z["hitflash"] = 0.16   # kurzes weisses Aufblitzen beim Treffer
					# Aufschlag-Spritzer am Treffpunkt
					for _ik in range(2):
						var ia := rng.randf() * TAU
						fx.append({"t": "gib", "x": float(pe.x), "y": float(z.y), "vx": cos(ia) * 45.0 - 25.0, "vy": sin(ia) * 45.0, "life": 0.26, "col": Color(0.92, 1.0, 0.72), "sz": 2.0})
				Music.play_sfx("pea_hit", 0.09)
				pe.hit.append(z)
				if int(pe.pierce) > 0:
					pe.pierce = int(pe.pierce) - 1
				else:
					peas.remove_at(i); gone = true
				break
		if gone: continue
	# Zombies
	for i in range(zombies.size() - 1, -1, -1):
		var z = zombies[i]
		# Sterbe-Animation abspielen, dann erst entfernen
		if z.get("dying", false):
			z.die_t += dt
			if z.die_t >= _die_dur(z): zombies.remove_at(i)
			continue
		if z.burn > 0: z.hp -= 8.0 * dt; z.burn -= dt
		if z.poison > 0: z.hp -= 9.0 * dt; z.poison -= dt
		if z.slow > 0: z.slow -= dt
		if float(z.get("hitflash", 0.0)) > 0.0: z["hitflash"] = float(z.hitflash) - dt
		if z.hp <= 0: _start_dying(z); continue
		# Element-Boss-Faehigkeit (feuer/eis/blitz/untot)
		if str(z.get("element", "")) != "":
			z["ability_t"] = float(z.get("ability_t", 0.0)) + dt
			if z.ability_t >= 6.0:
				z.ability_t = 0.0
				_boss_ability(z)
		var sl := 1.0
		if z.slow > 0: sl = 0.4 if weather == "frost" else 0.5   # Frost verstaerkt Slows
		elif weather == "frost": sl = 0.85                        # Frost bremst generell
		var tgt = null
		for p in plants:
			if p.arch == "spike" or p.arch == "bomb": continue
			# Ballon-Zombie fliegt ueber alles ausser hohen Pflanzen (Eisnuss)
			if z.get("fly", false) and float(p.s.get("tall", 0.0)) <= 0.0: continue
			if p.row == z.row and abs(z.x - p.x) < Game.CELL * 0.42 and z.x >= p.x - Game.CELL * 0.2:
				tgt = p; break
		# Von einer hohen Pflanze heruntergeholt -> landet und frisst normal weiter
		if z.get("fly", false) and tgt != null:
			z.fly = false
			fx.append({"t": "boom", "x": z.x, "y": z.y, "life": 0.2})
		z["eating"] = tgt != null   # steht/frisst -> Idle-Animation, sonst Walking
		# Stachel-Schaden
		for p in plants:
			if p.arch == "spike" and p.row == z.row and abs(z.x - p.x) < Game.CELL * 0.5:
				z.hp -= float(p.s.dmg) * dt * 2.0
				_apply_fx(z, p.s.effects, float(p.s.dmg))
		if tgt != null and z.vault and not z.jumped and float(tgt.s.get("tall", 0.0)) <= 0.0:
			z.x = tgt.x - Game.CELL * 0.55; z.jumped = true
			Music.play_sfx("jump", 0.2)
		elif tgt != null and z.smash:
			# Smasher/Boss zerschmettert die Pflanze sofort -> Meta muss sich anpassen
			var px = tgt.x; var py = tgt.y
			_plant_dies(tgt)
			fx.append({"t": "boom", "x": px, "y": py, "life": 0.28})
		elif tgt != null and float(tgt.s.get("lane_switch", 0.0)) > 0.0 and not z.switched and not z.boss and not z.final:
			# Untote Nuss: schmeckt so ekelhaft, dass der Zombie angewidert die Lane wechselt
			var opts := []
			if z.row - 1 >= 0: opts.append(z.row - 1)
			if z.row + 1 < rows: opts.append(z.row + 1)
			if opts.size() > 0:
				var nr: int = opts[rng.randi() % opts.size()]
				z.row = nr
				z.y = Game.LAWN_Y + nr * Game.CELL + Game.CELL / 2.0
				z.x += Game.CELL * 0.35            # etwas zurueckgeschreckt
				z.switched = true
				fx.append({"t": "boom", "x": z.x, "y": z.y, "life": 0.22})
			else:
				# keine Nachbar-Lane frei -> normal fressen
				tgt.hp -= z.dmg * dt
				if tgt.hp <= 0: _plant_dies(tgt, true)   # vom Zombie gefressen
		elif tgt != null:
			Music.play_sfx("eating", 0.5)   # gedrosselt -> ruhiges Kau-Geraeusch
			tgt.hp -= z.dmg * dt
			if float(tgt.s.get("thorns", 0.0)) > 0.0:
				z.hp -= z.dmg * float(tgt.s.thorns) * dt
			# Feuernuss: Kontakt-Feuerschaden + entzuenden
			var cdmg := float(tgt.s.get("contact_dmg", 0.0))
			if cdmg > 0.0:
				z.hp -= cdmg * dt
				z.burn = max(z.burn, 1.4)
			# Stahlnuss: zappt knabbernde Zombies
			if float(tgt.s.get("lightning_rod", 0.0)) > 0.0:
				z.hp -= 22.0 * dt
			# Eisnuss: verlangsamt Angreifer
			if float(tgt.s.get("chill", 0.0)) > 0.0:
				z.slow = max(z.slow, 1.5)
			if tgt.hp <= 0: _plant_dies(tgt, true)   # vom Zombie gefressen
		else:
			var spd: float = z.speed
			if str(z.kind) == "sprinter":
				# Liebespaar bummelt gemuetlich (0.6x) - bis der Partner stirbt, dann Vollgas (2.0x)
				spd = float(z.speed) * (2.0 if z.get("enraged", false) else 0.6)
			elif z.get("rage", false):
				spd = float(z.speed) * (1.0 + (1.0 - z.hp / z.maxhp) * 1.3)
			z.x -= spd * sl * dt
		if z.x < Game.LAWN_X + 10:
			if not _mow(z.row):
				if Game.god: z.hp = 0
				else: _lose(); return
	# Rasenmäher
	for m in mowers:
		if m.used or not m.active: continue
		m.x += 560.0 * dt
		for z in zombies:
			if z.row == m.row and z.x < m.x + Game.CELL * 0.4 and z.x > m.x - Game.CELL: _kill(z); z.hp = 0
		if m.x > Game.LAWN_X + Game.COLS * Game.CELL + 30: m.active = false; m.used = true
	for i in range(zombies.size() - 1, -1, -1):
		if zombies[i].hp <= 0 and not zombies[i].get("dying", false):
			_start_dying(zombies[i])   # z.B. vom Maeher getoetet -> Sterbe-Animation statt sofort weg
	# Sonne
	for i in range(suns.size() - 1, -1, -1):
		var su = suns[i]
		if su.falling and su.y < su.ty: su.y += su.vy * dt
		else: su.falling = false
		su.life -= dt
		if su.life <= 0:
			# Idle-freundlich: nicht eingesammelte Sonne wird automatisch gutgeschrieben
			var av: int = int(su.value)
			Game.sun += av
			_popup(su.x, su.y, "+%d" % av, Color(1, 0.88, 0.4))
			suns.remove_at(i)
	# Effekte
	for i in range(fx.size() - 1, -1, -1):
		fx[i].life -= dt
		# Truemmer-Partikel (Zombie-Tod): fliegen mit Schwerkraft auseinander
		if fx[i].t == "gib":
			fx[i].x += float(fx[i].vx) * dt
			fx[i].y += float(fx[i].vy) * dt
			fx[i].vy = float(fx[i].vy) + 520.0 * dt
		if fx[i].life <= 0: fx.remove_at(i)
	# Schwebende Zahlen steigen auf und verblassen
	for i in range(popups.size() - 1, -1, -1):
		popups[i].y -= 26.0 * dt
		popups[i].life -= dt
		if popups[i].life <= 0: popups.remove_at(i)

func _lane_has(p) -> bool:
	var maxx := 1.0e9
	if weather == "nebel": maxx = p.x + 4.0 * Game.CELL   # Nebel verkuerzt die Sicht der Schuetzen
	for z in zombies:
		if z.row == p.row and z.x > p.x - 10 and z.x < maxx and z.hp > 0: return true
	return false

func _shoot(p) -> void:
	Music.play_sfx("shoot_pea")
	var s = p.s
	var ex := int(s.get("extra_lanes", 0))
	_spawn_pea(p, p.row, s)
	for d in range(1, ex + 1):
		if p.row - d >= 0: _spawn_pea(p, p.row - d, s)
		if p.row + d < rows: _spawn_pea(p, p.row + d, s)

func _spawn_pea(p, lane: int, s) -> void:
	var y := Game.LAWN_Y + lane * Game.CELL + Game.CELL / 2.0 - 6.0
	peas.append({"row": lane, "x": p.x + 20, "y": y, "vx": s.speed if s.speed > 0 else 340.0, "dmg": s.dmg, "effects": s.effects, "lob": false, "pierce": int(s.get("pierce", 0)), "hit": []})

func _beam(p) -> void:
	var s = p.s
	for z in zombies:
		if z.row == p.row and z.x > p.x and z.hp > 0: z.hp -= s.dmg; _apply_fx(z, s.effects, s.dmg)
	fx.append({"t": "beam", "x": p.x, "y": p.y, "life": 0.12})

func _fume(p) -> void:
	Music.play_sfx("shoot_shroom")
	var s = p.s
	var gm := float(p.get("gm", 1.0))
	var reach = p.x + (s.range if s.range > 0 else 2.6) * Game.CELL
	for z in zombies:
		if z.row == p.row and z.x > p.x - 6 and z.x < reach and z.hp > 0: z.hp -= s.dmg * gm; _apply_fx(z, s.effects, s.dmg * gm)
	fx.append({"t": "fume", "x": p.x, "y": p.y, "w": (s.range if s.range > 0 else 2.6) * Game.CELL, "life": 0.2})

func _lob(p) -> void:
	Music.play_sfx("shoot_shroom")
	var s = p.s
	var tx = p.x + 4 * Game.CELL
	var best := 1.0e9
	for z in zombies:
		if z.row == p.row and z.hp > 0 and z.x < best: best = z.x; tx = z.x
	peas.append({"row": p.row, "x": p.x, "y": p.y, "sx": p.x, "tx": tx, "pt": 0.0, "dur": 0.85, "dmg": s.dmg, "splash": (s.splash if s.splash > 0 else 0.9) * Game.CELL, "effects": s.effects, "lob": true})

func _lob_hit(sh) -> void:
	for z in zombies:
		if z.row == sh.row and z.hp > 0 and abs(z.x - sh.tx) < sh.splash: z.hp -= sh.dmg; _apply_fx(z, sh.effects, sh.dmg)
	fx.append({"t": "splat", "x": sh.tx, "y": Game.LAWN_Y + sh.row * Game.CELL + Game.CELL / 2.0, "life": 0.2})

func _bomb(p) -> void:
	var rr = (p.s.radius if p.s.radius > 0 else 1.4) * Game.CELL
	for z in zombies:
		if Vector2(z.x, z.y).distance_to(Vector2(p.x, p.y)) < rr:
			z.hp -= p.s.dmg
			if p.s.effects.has("burn"): z.burn = 3.0
	fx.append({"t": "boom", "x": p.x, "y": p.y, "life": 0.4})
	plants.erase(p)

func _apply_fx(z, effects, dmg) -> void:
	for e in effects:
		if e == "slow": z.slow = 3.0
		elif e == "burn": z.burn = 4.0
		elif e == "poison": z.poison = 5.0
		elif e == "chain": _chain(z, dmg)

func _chain(z, dmg) -> void:
	# Kettenblitz springt nur auf die Nachbar-Tiles des getroffenen Zombies
	# (angrenzende Lanes = row +/-1 ODER dieselbe Lane dahinter), in Reichweite.
	var reach := 1.6 * Game.CELL
	var others := []
	for o in zombies:
		if o == z or o.hp <= 0: continue
		if abs(o.row - z.row) > 1: continue                 # nur direkt angrenzende Lanes
		if Vector2(o.x, o.y).distance_to(Vector2(z.x, z.y)) > reach: continue
		others.append(o)
	others.sort_custom(func(a, b): return Vector2(a.x,a.y).distance_to(Vector2(z.x,z.y)) < Vector2(b.x,b.y).distance_to(Vector2(z.x,z.y)))
	for i in range(min(2, others.size())):
		others[i].hp -= dmg * 0.5
		fx.append({"t": "bolt", "x": z.x, "y": z.y, "x2": others[i].x, "y2": others[i].y, "life": 0.2})

# ---- Element-Effekte der Sonnenblume ----

func _plant_dies(p, eaten := false) -> void:
	if eaten: Music.play_sfx("plant_died")   # nur wenn ein Zombie sie gefressen hat
	# Feuerblume: entzuendet beim Tod Zombies in der Naehe (Zuenderholz = groesser)
	var fd := float(p.s.get("fire_death", 0.0))
	if fd > 0.0:
		var rr := (1.1 + 0.4 * fd) * Game.CELL
		for z in zombies:
			if z.hp > 0 and Vector2(z.x, z.y).distance_to(Vector2(p.x, p.y)) < rr:
				z.hp -= 35.0 * fd
				z.burn = max(z.burn, 3.0)
		fx.append({"t": "boom", "x": p.x, "y": p.y, "life": 0.35})
	# Nicht-Bomben landen im Friedhof (Necromancer kann sie wiederbeleben)
	if p.arch != "bomb":
		graveyard.append({"ck": p.ck, "arch": p.arch, "row": p.row, "col": p.col, "x": p.x, "y": p.y, "s": p.s, "maxhp": p.maxhp})
		if graveyard.size() > 12: graveyard.pop_front()
	plants.erase(p)

func _tile_free(row: int, col: int) -> bool:
	for p in plants:
		if p.row == row and p.col == col: return false
	return true

func _necro_revive():
	# neueste tote Pflanze zuerst, deren Kachel wieder frei ist
	while not graveyard.is_empty():
		var g = graveyard.pop_back()
		if _tile_free(int(g.row), int(g.col)):
			return {"ck": g.ck, "arch": g.arch, "row": int(g.row), "col": int(g.col), "x": g.x, "y": g.y, "hp": float(g.maxhp) * 0.5, "maxhp": float(g.maxhp), "s": g.s, "t": 0.0, "fuse": (0.7 if g.arch == "bomb" else 0.0), "done": false}
	return null

func _zap_random(p) -> void:
	var alive := []
	for z in zombies:
		if z.hp > 0: alive.append(z)
	if alive.is_empty(): return
	var zapv := float(p.s.get("zap", 1.0))
	var t = alive[rng.randi() % alive.size()]
	t.hp -= 40.0 * zapv
	t.slow = max(t.slow, 0.6)
	fx.append({"t": "bolt", "x": p.x, "y": p.y, "x2": t.x, "y2": t.y, "life": 0.2})

# ---- Cattail / Katze (Blitzpad): trifft Zombies auf ALLEN Lanes ----
func _cattail_fire(p) -> void:
	var best = null
	var bd := 1.0e9
	for z in zombies:
		if z.hp <= 0: continue
		var d: float = Vector2(z.x, z.y).distance_to(Vector2(p.x, p.y))
		if d < bd: bd = d; best = z
	if best == null: return
	var dmg := 40.0 * float(p.s.get("aimbot", 1.0))
	best.hp -= dmg
	_apply_fx(best, p.s.effects, dmg)
	fx.append({"t": "bolt", "x": p.x, "y": p.y, "x2": best.x, "y2": best.y, "life": 0.22})

# ---- Element-Boss-Faehigkeiten ----
func _boss_ability(z) -> void:
	var el := str(z.get("element", ""))
	if el == "feuer":
		# Flammensturm: verbrennt eine zufaellige Pflanze
		if not plants.is_empty():
			var pf = plants[rng.randi() % plants.size()]
			pf.hp -= 140.0
			fx.append({"t": "boom", "x": pf.x, "y": pf.y, "life": 0.4})
			if pf.hp <= 0: _plant_dies(pf)
		msg = "FEUERBOSS: Flammensturm!"; msg_t = 1.4
	elif el == "eis":
		# Vereisung: friert alle Pflanzen einer Reihe kurz ein
		var lane := rng.randi() % rows
		for pe in plants:
			if pe.row == lane: pe["frozen"] = 4.0
		msg = "EISBOSS: Reihe %d vereist!" % (lane + 1); msg_t = 1.4
	elif el == "blitz":
		# Einschlag: Blitz zerstoert/schaedigt eine zufaellige Pflanze
		if not plants.is_empty():
			var pb = plants[rng.randi() % plants.size()]
			fx.append({"t": "bolt", "x": z.x, "y": z.y, "x2": pb.x, "y2": pb.y, "life": 0.28})
			pb.hp -= 200.0
			if pb.hp <= 0: _plant_dies(pb)
		msg = "BLITZBOSS: Einschlag!"; msg_t = 1.4
	elif el == "untot":
		# Auferstehung: beschwoert zusaetzliche Zombies
		to_spawn += 2
		msg = "UNTOTER UEBERLORD: Auferstehung!"; msg_t = 1.4

func _mow(row: int) -> bool:
	for m in mowers:
		if m.row == row and not m.used:
			if not m.active: m.active = true
			return true
	return false

func _kill(z) -> void:
	if z.dropped: return
	z.dropped = true
	# Kill-Combo hochzaehlen — schnelle Kills hintereinander geben mehr Belohnung
	combo += 1
	combo_t = COMBO_WINDOW
	run_kills += 1
	best_combo = max(best_combo, combo)
	# Combo-Meilenstein: Bonus-FP + kleiner Shake bei 10/20/30 ...
	if combo >= 10 and combo % 10 == 0:
		var cb := combo * 3
		Game.fp += cb
		_popup(z.x, z.y - 46, "COMBO x%d  +%d FP" % [combo, cb], Color(1.0, 0.85, 0.3))
		_add_shake(5.0)
	var cmult := 1.0 + 0.04 * float(min(combo, 25))   # bis zu +100% bei Combo 25
	if combo >= 3:
		_popup(z.x, z.y - 30, "Combo x%d" % combo, Color(1.0, 0.62, 0.2))
	var rew := Game.reward_mul() * cmult
	if z.boss:
		var b := int(max(1, round((z.brain + int(Game.wave / 5.0)) * Game.brain_mul() * rew)))
		Game.brains += b; Game.save_game()
		fx.append({"t": "boom", "x": z.x, "y": z.y, "life": 0.4})
		_add_shake(9.0)
		msg = "Boss besiegt! +%d Skulls" % b; msg_t = 2.5
	elif z.get("carrier", false) and int(z.get("brain", 0)) > 0:
		var bc := int(max(1, round(z.brain * Game.brain_mul() * rew)))
		Game.brains += bc; Game.save_game()
		msg = "Skull erbeutet! +%d" % bc; msg_t = 1.5
	var fpg := int(max(1, round(z.fp * Game.fp_mul() * rew)))
	if rng.randf() < Game.loot_chance():
		fpg *= 2
		fx.append({"t": "boom", "x": z.x, "y": z.y - 20, "life": 0.25})   # Gluecks-Beute!
	Game.fp += fpg
	Game.coins += int(max(1, round((1 + Game.wave * 0.08 + (8 if z.boss else 0)) * Game.coin_mul() * rew)))

func _lose() -> void:
	Game.phase = "dead"
	Music.set_rain(false)
	Music.play_sfx("dead", 1.0)
	msg = "Überrannt!  Kills: %d · Bester Combo: x%d" % [run_kills, best_combo]; msg_t = 5.0

# ---- Eingabe ----
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		return
	if Game.paused: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		lawn_click(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if Game.phase == "won": reset_run()
			else: start_wave()
		elif event.keycode == KEY_X:
			if Game.has("u_shovel"):
				if Game.shovel:
					Game.shovel = false
					Game.place_slot = Game.SELECT_NONE
				else:
					Game.shovel = true
					Game.place_slot = Game.SELECT_NONE
		elif event.keycode == KEY_H:
			if Game.has("u_hammer"):
				if Game.place_slot == Game.SELECT_HAMMER and not Game.shovel:
					Game.place_slot = Game.SELECT_NONE
				else:
					Game.place_slot = Game.SELECT_HAMMER
					Game.shovel = false
		elif event.keycode == KEY_A:
			Game.auto_wave = not Game.auto_wave
		elif event.keycode == KEY_F:
			Game.game_speed = Game.game_speed % 3 + 1
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx := int(event.keycode) - int(KEY_1)
			if idx < Game.slot_count() and Game.seed_chain(idx) != "":
				if Game.place_slot == idx and not Game.shovel:
					Game.place_slot = Game.SELECT_NONE
				else:
					Game.place_slot = idx
					Game.shovel = false

# ---- Klick-Steuerung ----
func lawn_click(pos: Vector2) -> void:
	if Game.phase == "won" or Game.phase == "dead": return
	# Sonne einsammeln
	for i in range(suns.size() - 1, -1, -1):
		if pos.distance_to(Vector2(suns[i].x, suns[i].y)) < 30:
			var sv: int = int(suns[i].value)
			var sxp := float(suns[i].x)
			var syp := float(suns[i].y)
			_popup(sxp, syp, "+%d" % sv, Color(1, 0.9, 0.35))
			for _k in range(6):
				var a := rng.randf() * TAU
				fx.append({"t": "gib", "x": sxp, "y": syp, "vx": cos(a) * 70.0, "vy": sin(a) * 70.0 - 30.0, "life": 0.45, "col": Color(1.0, 0.92, 0.45), "sz": 2.4 + rng.randf() * 1.4})
			Music.play_sfx("collect_sun")
			Game.sun += sv; suns.remove_at(i); return
	var col := int((pos.x - Game.LAWN_X) / Game.CELL)
	var row := int((pos.y - Game.LAWN_Y) / Game.CELL)
	if col < 0 or col >= Game.COLS or row < 0 or row >= rows: return
	# Schaufel: Pflanze entfernen + 50% Sonne zurueck
	if Game.shovel:
		for p in plants:
			if p.col == col and p.row == row:
				var refund := int(round(float(p.s.get("cost", 0)) * 0.5))
				if refund > 0:
					Game.sun += refund
					_popup(p.x, p.y - 10, "+%d" % refund, Color(1, 0.9, 0.4))
				plants.erase(p); return
		return
	# Hammer/Faust aktiv
	if Game.place_slot == Game.SELECT_HAMMER:
		if not Game.has("u_hammer"): return
		var best = null; var bd := 1.0e9
		for z in zombies:
			if z.hp > 0:
				var d = pos.distance_to(Vector2(z.x, z.y))
				if d < Game.CELL * 0.55 and d < bd: bd = d; best = z
		if best != null:
			best.hp -= Game.click_dmg()
			if Game.has_click_coin(): Game.coins += int(max(1, round(Game.coin_mul())))
		return
	# Normale Hand: nichts auswaehlen und keine Aktion auf dem Rasen
	if Game.place_slot == Game.SELECT_NONE: return
	# Pflanze aus dem gewaehlten Samen-Slot setzen
	_place(col, row)

func _place(col: int, row: int) -> void:
	var slot: int = Game.place_slot
	var ck: String = Game.seed_chain(slot)
	if slot < 0 or ck == "": return
	var s = Game.seed_stats(slot)
	if s.arch != "bomb":
		for p in plants:
			if p.col == col and p.row == row: return
	if Game.sun < s.cost: msg = "Zu wenig Sonne!"; msg_t = 1.2; return
	Game.sun -= s.cost
	var x = Game.LAWN_X + col * Game.CELL + Game.CELL / 2.0
	var y = Game.LAWN_Y + row * Game.CELL + Game.CELL / 2.0
	plants.append({"ck": ck, "arch": s.arch, "row": row, "col": col, "x": x, "y": y, "hp": float(s.hp), "maxhp": float(s.hp), "s": s, "t": 0.0, "fuse": (0.7 if s.arch == "bomb" else 0.0), "done": false, "element": Game.seed_element(slot)})
	# Staub-Woelkchen beim Pflanzen
	for _dk in range(5):
		var da := rng.randf() * TAU
		fx.append({"t": "gib", "x": float(x), "y": float(y) + 16.0, "vx": cos(da) * 55.0, "vy": -20.0 - rng.randf() * 28.0, "life": 0.36, "col": Color(0.62, 0.46, 0.3), "sz": 2.4 + rng.randf() * 1.6})
	Music.play_sfx("plant")
	# Intuitiver Start: die allererste gesetzte Pflanze startet Welle 1
	if Game.wave == 0 and Game.phase == "prep":
		start_wave()

# ---- Zeichnen ----
func _draw() -> void:
	var wo := world_of(Game.wave)
	var night := BAL.is_night_wave(Game.wave)
	var lawn_rect := Rect2(Game.LAWN_X, Game.LAWN_Y, Game.COLS * Game.CELL, rows * Game.CELL)
	# --- Hintergrund-Kulisse (Tag/Nacht folgt dem Zyklus, Full-Screen-Backdrop) ---
	var bg := _scene_bg(night)
	if bg != null:
		var vp := get_viewport_rect().size
		draw_texture_rect(bg, Rect2(0, 0, vp.x, vp.y), false)
	else:
		_draw_sky(night)
	# --- Solider Rasen auf einem Erd-Sockel (Perspektive/Plattform) ---
	var lx := float(Game.LAWN_X)
	var ly := float(Game.LAWN_Y)
	var lw := float(Game.COLS * Game.CELL)
	var lh := float(rows * Game.CELL)
	draw_rect(Rect2(lx - 12, ly - 8, lw + 24, lh + 42), Color(0.16, 0.10, 0.05))   # dunkler Erd-Rahmen (Tiefe)
	draw_rect(Rect2(lx - 7, ly - 3, lw + 14, lh + 28), Color(0.32, 0.21, 0.12))    # Erde/Sockel
	for r in range(rows):
		for c in range(Game.COLS):
			var g: Color
			if bg == null and wo.pond and r == rows - 1: g = (Color(0.11,0.33,0.4) if (r+c)%2==0 else Color(0.13,0.39,0.45))
			elif bg == null: g = (wo.g1 if (r + c) % 2 == 0 else wo.g2)
			else: g = Color(0.32, 0.56, 0.25) if (r + c) % 2 == 0 else Color(0.26, 0.49, 0.20)
			draw_rect(Rect2(lx + c * Game.CELL, ly + r * Game.CELL, Game.CELL, Game.CELL), g)
	draw_rect(Rect2(lx, ly, lw, 5), Color(0.52, 0.82, 0.42, 0.8))        # heller Grasrand oben
	for c in range(Game.COLS + 1):
		draw_line(Vector2(lx + c * Game.CELL, ly), Vector2(lx + c * Game.CELL, ly + lh), Color(0, 0, 0, 0.13), 1.0)
	for r in range(rows + 1):
		draw_line(Vector2(lx, ly + r * Game.CELL), Vector2(lx + lw, ly + r * Game.CELL), Color(0, 0, 0, 0.13), 1.0)
	draw_rect(Rect2(lx - 7, ly + lh, lw + 14, 10), Color(0, 0, 0, 0.30))  # Schatten an der Vorderkante
	if bg == null: _draw_grass_deco(lx, ly, lw, lh, night)                # Grasbueschel + Blueten (nur ohne BG-Bild)
	if bg == null and night: draw_rect(lawn_rect, Color(0.08,0.12,0.25,0.30))
	if wo.get("roof", false): draw_rect(lawn_rect, Color(0.5,0.35,0.18,0.14))
	# Wetter-Overlay
	if weather == "nebel": draw_rect(lawn_rect, Color(0.82, 0.84, 0.88, 0.24))
	elif weather == "frost": draw_rect(lawn_rect, Color(0.55, 0.72, 1.0, 0.15))
	elif weather == "gewitter":
		draw_rect(lawn_rect, Color(0.12, 0.12, 0.28, 0.22))
		_draw_rain(lawn_rect)
	draw_rect(Rect2(Game.LAWN_X - 14, Game.LAWN_Y, 9, rows * Game.CELL), Color(0.42,0.32,0.62))
	# Tiefe: sanfter Verlauf (oben heller, unten dunkler)
	var _lh := rows * Game.CELL
	draw_rect(Rect2(Game.LAWN_X, Game.LAWN_Y, Game.COLS * Game.CELL, _lh * 0.45), Color(1, 1, 1, 0.03))
	draw_rect(Rect2(Game.LAWN_X, Game.LAWN_Y + _lh * 0.62, Game.COLS * Game.CELL, _lh * 0.38), Color(0, 0, 0, 0.10))
	# Rasenmäher
	for m in mowers:
		if m.used: continue
		_draw_mower(m.x, Game.LAWN_Y + m.row * Game.CELL + Game.CELL * 0.55, m.get("active", false))
	# Pflanzen
	for p in plants:
		var col: Color = Game.CHASSIS[p.ck].col
		if float(p.get("frozen", 0.0)) > 0.0: col = col.lerp(Color(0.55, 0.8, 1.0), 0.55)
		# Nacht-Pilze pulsieren/wachsen sichtbar mit ihrer Staerke
		var pr := 28.0
		if p.has("gm"): pr = 24.0 + 6.0 * (float(p.gm) - 1.0) / max(0.01, BAL.SHROOM_GROWTH_MAX - 1.0)
		pr *= 1.0 + beat_pulse * 0.10                                 # Beat-Bounce: Pflanze "atmet" im Takt
		var rk := float(p.get("recoil", 0.0)) * 6.0                   # Rueckstoss beim Schuss (kurz nach links)
		var pby: float = p.y + sin(float(p.t) * 2.2) * 1.5            # sanftes Wippen
		_shadow(p.x, p.y, pr)
		_draw_plant(p, col, pr, p.x - rk, pby)
		_draw_evo(p, p.x - rk, pby, pr)
		if float(p.get("frozen", 0.0)) > 0.0:
			# Eis-Kristalle auf eingefrorener Pflanze
			draw_circle(Vector2(p.x, pby), pr * 0.95, Color(0.7, 0.9, 1.0, 0.25))
			for ci in range(4):
				var ca := float(ci) * TAU / 4.0 + 0.4
				draw_line(Vector2(p.x, pby), Vector2(p.x + cos(ca) * pr * 0.6, pby + sin(ca) * pr * 0.5), Color(0.85, 0.95, 1.0, 0.6), 2.0)
		# Muendungsblitz beim Schuss (nutzt den vorhandenen Rueckstoss-Wert, Element-gefaerbt)
		var _rc: float = clamp(float(p.get("recoil", 0.0)), 0.0, 1.0)
		if _rc > 0.35 and (str(p.arch) == "shooter" or str(p.arch) == "beam"):
			var ms: Dictionary = p.s
			var mcol := Color(1.0, 0.95, 0.6, _rc)
			if bool(ms.get("burn", false)): mcol = Color(1.0, 0.55, 0.2, _rc)
			elif bool(ms.get("slow", false)): mcol = Color(0.6, 0.85, 1.0, _rc)
			elif bool(ms.get("chain", false)) or float(ms.get("zap", 0.0)) > 0.0: mcol = Color(0.7, 1.0, 0.6, _rc)
			draw_circle(Vector2(p.x + pr * 0.9, pby), 5.0 + 5.0 * _rc, mcol)
		# Element-Aura: der gewaehlte Skill-Ast ist auf dem Rasen sichtbar
		var es: Dictionary = p.s
		var ar := pr + 5.0 + sin(float(p.t) * 4.0) * 1.5
		if bool(es.get("burn", false)):
			draw_arc(Vector2(p.x, pby), ar, 0.0, TAU, 26, Color(1.0, 0.45, 0.10, 0.45), 2.5)
		elif bool(es.get("slow", false)):
			draw_arc(Vector2(p.x, pby), ar, 0.0, TAU, 26, Color(0.45, 0.80, 1.0, 0.45), 2.5)
		elif bool(es.get("chain", false)) or float(es.get("zap", 0.0)) > 0.0:
			draw_arc(Vector2(p.x, pby), ar, 0.0, TAU, 26, Color(1.0, 0.88, 0.30, 0.45), 2.5)
		elif bool(es.get("poison", false)) or float(es.get("necro", 0.0)) > 0.0:
			draw_arc(Vector2(p.x, pby), ar, 0.0, TAU, 26, Color(0.72, 0.40, 0.95, 0.45), 2.5)
		_hp_bar(p.x, p.y + 30, p.hp / p.maxhp, Color(0.35,0.85,0.4))
		# Warnung: pulsierender roter Ring, wenn die Pflanze fast zerstoert ist
		if p.hp / p.maxhp < 0.3:
			var wp := 0.5 + 0.5 * sin(_anim_clock * 8.0)
			draw_arc(Vector2(p.x, pby), pr + 8.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, 0.35 + 0.4 * wp), 2.5)
		# Nacht-Pilz: verbleibende Lebensdauer (lila Balken oben)
		if p.has("age"):
			var lifeleft: float = clamp(1.0 - float(p.age) / BAL.SHROOM_LIFESPAN, 0.0, 1.0)
			_hp_bar(p.x, p.y - 34, lifeleft, Color(0.72, 0.5, 0.95))
	# Erbsen / Projektile — je Element eingefaerbt & geformt
	for pe in peas:
		var py2: float = pe.y
		if pe.get("lob", false):
			var arc = sin(PI * pe.pt) * Game.CELL * 0.7
			py2 = Game.LAWN_Y + pe.row * Game.CELL + Game.CELL/2.0 - arc
		_draw_projectile(pe.x, py2, pe.get("effects", []))
	# Zombies
	for z in zombies:
		var zc: Color = z.col
		if z.slow > 0: zc = zc.lerp(Color(0.6,0.8,1), 0.4)
		if z.get("enraged", false): zc = zc.lerp(Color(1.0, 0.25, 0.15), 0.5)   # wuetend -> rot
		var sz = 60 if z.boss else 40
		var zy: float = z.y
		if z.get("fly", false): zy = z.y - Game.CELL * 0.32   # Ballon schwebt hoeher
		_shadow(z.x, zy + sz * 0.5, sz * 0.5)
		var _hf := float(z.get("hitflash", 0.0))
		if _hf > 0.0: zc = zc.lerp(Color(1, 1, 1), clamp(_hf / 0.16, 0.0, 1.0) * 0.8)   # Treffer-Aufblitzen
		_draw_zombie(z, zc, float(sz), z.x, zy)
		if z.boss:
			draw_circle(Vector2(z.x, zy), sz * 0.92, Color(zc.r, zc.g, zc.b, 0.12))   # weicher Aura-Schein
			draw_arc(Vector2(z.x, zy), sz * 0.78 + sin(_anim_clock * 3.0) * 2.5, 0.0, TAU, 30, Color(zc.r, zc.g, zc.b, 0.5), 3.0)
			draw_arc(Vector2(z.x, zy), sz * 0.96 + sin(_anim_clock * 2.0) * 3.0, 0.0, TAU, 34, Color(1, 1, 1, 0.22), 2.0)
		if str(z.kind) == "brainz":
			draw_circle(Vector2(z.x, zy - sz * 0.62), 9.0 + sin(_anim_clock * 5.0) * 2.0, Color(1.0, 0.5, 0.75, 0.35))
		if z.get("fly", false):
			draw_line(Vector2(z.x, zy - sz*0.55), Vector2(z.x, zy - sz*0.95), Color(0.25,0.25,0.25), 1.5)
			draw_circle(Vector2(z.x, zy - sz*1.05), 13, Color(0.92,0.5,0.55))
		if float(z.get("shield", 0.0)) > 0.0:
			# Schild vorne (links, Richtung Pflanzen)
			draw_rect(Rect2(z.x - sz*0.62, zy - sz*0.5, 7, sz*1.0), Color(0.62,0.78,0.96,0.9))
		_hp_bar(z.x, zy - sz*0.62, z.hp / z.maxhp, Color(0.9,0.3,0.3))
		if z.burn > 0:
			# aufsteigende Flammen
			for fi in range(3):
				var fph := fmod(_anim_clock * 3.0 + float(fi) * 0.4, 1.0)
				var fxp: float = float(z.x) + (float(fi) - 1.0) * float(sz) * 0.26 + sin(_anim_clock * 8.0 + float(fi)) * 2.0
				var fyp: float = zy - float(sz) * 0.2 - fph * float(sz) * 0.75
				draw_circle(Vector2(fxp, fyp), (1.0 - fph) * 6.0, Color(1.0, 0.45 + 0.35 * fph, 0.1, 0.7 * (1.0 - fph)))
		if z.poison > 0:
			# aufsteigende Gift-Blasen
			for bi in range(3):
				var bph := fmod(_anim_clock * 2.0 + float(bi) * 0.45, 1.0)
				var bxp: float = float(z.x) + float(sz) * 0.28 + sin(_anim_clock * 4.0 + float(bi)) * 3.0
				var byp: float = zy - float(sz) * 0.2 - bph * float(sz) * 0.65
				draw_circle(Vector2(bxp, byp), (1.0 - bph) * 3.5 + 1.0, Color(0.55, 0.9, 0.35, 0.6 * (1.0 - bph)))
		if z.get("eating", false) and not z.get("dying", false):
			# kauendes Maul auf der Pflanzen-Seite (links)
			var ch := 0.5 + 0.5 * sin(_anim_clock * 14.0)
			var mxp: float = float(z.x) - float(sz) * 0.4
			draw_colored_polygon(PackedVector2Array([Vector2(mxp, zy - 4.0 - ch * 3.0), Vector2(mxp - 7.0, zy), Vector2(mxp, zy + 4.0 + ch * 3.0)]), Color(0.95, 0.95, 0.95, 0.8))
		if z.slow > 0:
			# Eis-Splitter um verlangsamte Zombies
			for si in range(3):
				var sa := _anim_clock * 1.4 + float(si) * TAU / 3.0
				var ip := Vector2(z.x + cos(sa) * sz * 0.42, zy + sin(sa) * sz * 0.36)
				draw_circle(ip, 2.6, Color(0.72, 0.9, 1.0, 0.85))
				draw_circle(ip, 4.2, Color(0.6, 0.85, 1.0, 0.25))
		if str(z.get("shirt", "")) != "" and not z.get("dying", false):
			_draw_shirt(z.x, zy + sz * 0.08, str(z.shirt), z.get("enraged", false))
	# Boss-Lebensbalken oben am Bildschirm
	for bz in zombies:
		if bz.boss and bz.hp > 0:
			var bfrac: float = clamp(bz.hp / bz.maxhp, 0.0, 1.0)
			var bw := 520.0
			var bx := Game.LAWN_X + (Game.COLS * Game.CELL - bw) / 2.0
			var by := 70.0
			draw_rect(Rect2(bx - 3, by - 3, bw + 6, 22), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(bx, by, bw, 16), Color(0.18, 0.05, 0.08))
			draw_rect(Rect2(bx, by, bw * bfrac, 16), bz.col)
			# Boss-Name ueber dem Balken
			if _font != null:
				var bn := str(Game.ZTYPES.get(str(bz.kind), {}).get("n", "BOSS")).to_upper()
				draw_string_outline(_font, Vector2(bx, by - 6), bn, HORIZONTAL_ALIGNMENT_CENTER, bw, 15, 4, Color(0, 0, 0, 0.7))
				draw_string(_font, Vector2(bx, by - 6), bn, HORIZONTAL_ALIGNMENT_CENTER, bw, 15, Color(1, 0.85, 0.7))
			break
	# Sonne
	for s in suns:
		if s.get("falling", false):
			draw_line(Vector2(s.x, s.y - 16), Vector2(s.x, s.y - 32), Color(1, 0.9, 0.4, 0.22), 3.0)   # Fall-Schweif
		_draw_sun_icon(s.x, s.y, 16.0)
	# Effekte
	for e in fx:
		if e.t == "boom": draw_circle(Vector2(e.x, e.y), 60 * (e.life/0.4), Color(1,0.6,0.1, e.life/0.4))
		elif e.t == "beam": draw_line(Vector2(e.x, e.y), Vector2(Game.LAWN_X + Game.COLS*Game.CELL, e.y), Color(1,0.3,0.3, e.life/0.12), 5)
		elif e.t == "fume": draw_rect(Rect2(e.x, e.y - Game.CELL*0.4, e.w, Game.CELL*0.8), Color(0.6,0.6,0.6, e.life/0.2*0.5))
		elif e.t == "splat": draw_circle(Vector2(e.x, e.y), 11, Color(0.7,0.95,0.5, e.life/0.2))
		elif e.t == "bolt": draw_line(Vector2(e.x, e.y), Vector2(e.x2, e.y2), Color(1,0.95,0.4, e.life/0.2), 3)
		elif e.t == "gib":
			var ga: float = clamp(float(e.life) / 0.6, 0.0, 1.0)
			var gc: Color = e.get("col", Color(0.6, 0.7, 0.5)); gc.a = ga
			draw_circle(Vector2(e.x, e.y), float(e.get("sz", 3.0)), gc)
		elif e.t == "flash":
			var fc: Color = e.get("col", Color(1, 1, 1))
			fc.a = clamp(float(e.life), 0.0, 1.0) * 0.55
			draw_rect(Rect2(Game.LAWN_X - 14, Game.LAWN_Y - 10, Game.COLS * Game.CELL + 28, rows * Game.CELL + 40), fc)
	# Schwebende Zahlen (+Sonne etc.) — mit dunklem Umriss fuer bessere Lesbarkeit
	if _font != null:
		for pu in popups:
			var a: float = clamp(float(pu.life), 0.0, 1.0)
			var pc: Color = pu.col; pc.a = a
			var pos := Vector2(float(pu.x) - 12.0, float(pu.y))
			draw_string_outline(_font, pos, str(pu.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, a * 0.8))
			draw_string(_font, pos, str(pu.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, pc)
	# Platzier-Vorschau (Geist der gewaehlten Pflanze / Schaufel-Markierung)
	_draw_ghost()
	# Kill-Combo-Anzeige (mittig ueber dem Feld, mit Ablauf-Balken)
	var _fcx := Game.LAWN_X + Game.COLS * Game.CELL * 0.5
	if combo >= 3 and _font != null:
		var ctxt := "COMBO x%d" % combo
		var cc := Color(1.0, 0.72, 0.28).lerp(Color(1.0, 0.4, 0.2), clamp(float(combo) / 25.0, 0.0, 1.0))
		var frac: float = clamp(combo_t / COMBO_WINDOW, 0.0, 1.0)
		var fsz := int(20 + 6.0 * frac)
		var cpos := Vector2(_fcx - float(ctxt.length()) * 6.0, 106.0)
		draw_string_outline(_font, cpos, ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 5, Color(0, 0, 0, 0.7))
		draw_string(_font, cpos, ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, cc)
		# Ablauf-Balken (zeigt, wie lange der Combo noch haelt)
		var barw := 120.0
		draw_rect(Rect2(_fcx - barw * 0.5, 114.0, barw, 5.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(_fcx - barw * 0.5, 114.0, barw * frac, 5.0), cc)
	# Auto-Modus: Countdown bis zur naechsten Welle
	if Game.auto_wave and Game.phase == "prep" and Game.wave >= 1 and _font != null:
		var atxt := "Auto: naechste Welle in %ds" % int(ceil(max(0.0, auto_wave_t)))
		var apos := Vector2(_fcx - 108.0, 132.0)
		draw_string_outline(_font, apos, atxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
		draw_string(_font, apos, atxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 1.0, 0.7))
	# Anmarsch-Warnung: pulsierende Pfeile am rechten Rand, solange Zombies nachkommen
	_draw_incoming()
	# Gefahr-Rand am Haus, wenn Zombies nah sind
	_draw_house_danger()
	# Atmosphaere-Overlay (Gluehwuermchen/Sonnenstrahlen + Vignette) — nur ohne BG-Bild
	if _scene_bg(night) == null: _draw_atmosphere(night)

func _popup(x: float, y: float, text: String, col: Color) -> void:
	popups.append({"x": x, "y": y, "text": text, "life": 1.1, "col": col})

func _shadow(cx: float, cy: float, r: float) -> void:
	draw_circle(Vector2(cx, cy + r * 0.7), r * 0.85, Color(0, 0, 0, 0.20))

# ---- Rasenmaeher: Koerper, Griff, Raeder, rotierende Klinge (+ Staub wenn aktiv) ----
func _draw_mower(x: float, y: float, active: bool) -> void:
	var wob := (sin(_anim_clock * 20.0) * 1.0) if active else 0.0
	draw_rect(Rect2(x, y, 32, 16), Color(0.85, 0.29, 0.22))
	draw_rect(Rect2(x, y, 32, 5), Color(1.0, 0.55, 0.42, 0.7))          # Glanzstreifen
	draw_line(Vector2(x + 30, y + 2), Vector2(x + 41, y - 9), Color(0.62, 0.62, 0.64), 2.5)   # Griff
	draw_circle(Vector2(x + 7, y + 17 + wob), 5.0, Color(0.14, 0.14, 0.15))
	draw_circle(Vector2(x + 25, y + 17 - wob), 5.0, Color(0.14, 0.14, 0.15))
	draw_circle(Vector2(x + 7, y + 17 + wob), 2.0, Color(0.42, 0.42, 0.45))
	draw_circle(Vector2(x + 25, y + 17 - wob), 2.0, Color(0.42, 0.42, 0.45))
	if active:
		var bl := 0.5 + 0.5 * sin(_anim_clock * 40.0)
		draw_circle(Vector2(x + 34, y + 8), 6.0 + bl * 2.0, Color(0.85, 0.9, 0.95, 0.55))   # Klingen-Wirbel
		for k in range(3):
			draw_circle(Vector2(x - float(k) * 6.0, y + 14), 3.0 - float(k), Color(0.6, 0.55, 0.4, 0.4))  # Staub

# ---- Leichter Regen (bei Gewitter): schraege Tropfen + kleine Aufschlag-Kringel am Boden ----
func _draw_rain(rect: Rect2) -> void:
	var t := _anim_clock
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 424242                       # fester Seed -> ruhiger, gleichmaessiger Regen
	var groundy := rect.position.y + rect.size.y - 3.0
	# fallende Tropfen (leicht schraeg)
	for i in range(40):
		var bx := rect.position.x + rng2.randf() * rect.size.x
		var spd := 260.0 + rng2.randf() * 130.0
		var ph := rng2.randf()
		var yy := rect.position.y + fmod(ph * rect.size.y + t * spd, rect.size.y)
		draw_line(Vector2(bx, yy), Vector2(bx - 2.5, yy + 13.0), Color(0.70, 0.80, 1.0, 0.22), 1.0)
	# kleine Aufschlag-Kringel (sanft aufploppend, an festen Stellen)
	for j in range(7):
		var sx := rect.position.x + rng2.randf() * rect.size.x
		var life := fmod(t * 1.5 + rng2.randf(), 1.0)   # 0..1 Zyklus je Stelle
		var a := (1.0 - life) * 0.30
		var rr := 2.0 + life * 6.0
		draw_arc(Vector2(sx, groundy), rr, PI, TAU, 8, Color(0.75, 0.85, 1.0, a), 1.0)

# ============================================================
# PROZEDURALE KULISSE (wenn kein eigenes BG-Bild hinterlegt ist)
# Sanfter Farbverlauf-Himmel, Sonne/Mond, Wolken/Sterne, Huegel.
# ============================================================
func _draw_sky(night: bool) -> void:
	var vp := get_viewport_rect().size
	var top: Color
	var bot: Color
	if night:
		top = Color(0.04, 0.06, 0.15); bot = Color(0.17, 0.14, 0.30)
	else:
		top = Color(0.40, 0.71, 0.98); bot = Color(0.80, 0.91, 0.99)
	var bands := 26
	var bh := vp.y / float(bands)
	for i in range(bands):
		var f := float(i) / float(bands - 1)
		draw_rect(Rect2(0, i * bh, vp.x, bh + 1.0), top.lerp(bot, f))
	if night:
		# Mond oben rechts + weicher Halo
		var mp := Vector2(vp.x * 0.83, vp.y * 0.19)
		draw_circle(mp, 50, Color(0.95, 0.96, 0.85, 0.10))
		draw_circle(mp, 38, Color(0.95, 0.96, 0.85, 0.16))
		draw_circle(mp, 30, Color(0.94, 0.95, 0.88))
		draw_circle(mp + Vector2(11, -5), 26, top.lerp(bot, 0.15))   # Sichel-Schatten
		# Sterne (fester Seed -> kein Flackern, nur sanftes Funkeln)
		var rng2 := RandomNumberGenerator.new(); rng2.seed = 909091
		for i in range(72):
			var sx := rng2.randf() * vp.x
			var sy := rng2.randf() * vp.y * 0.52
			var tw := 0.5 + 0.5 * sin(_anim_clock * 2.0 + float(i) * 1.7)
			draw_circle(Vector2(sx, sy), 0.8 + tw * 0.9, Color(1, 1, 1, 0.30 + 0.45 * tw))
	else:
		# Sonne oben rechts mit weichem Glanz
		var sp := Vector2(vp.x * 0.84, vp.y * 0.17)
		draw_circle(sp, 64, Color(1, 0.95, 0.6, 0.10))
		draw_circle(sp, 46, Color(1, 0.93, 0.5, 0.18))
		draw_circle(sp, 32, Color(1, 0.95, 0.66))
		# langsam driftende Wolken
		for cd in [[0.18, 0.16, 1.0], [0.48, 0.10, 0.8], [0.66, 0.24, 1.15], [0.34, 0.30, 0.7]]:
			var cx := fmod(cd[0] * vp.x + _anim_clock * 7.0 * cd[2], vp.x + 160.0) - 80.0
			_cloud(cx, cd[1] * vp.y, cd[2])
	# Boden/Feld am Horizont fuer Tiefe (unter dem Rasen-Sockel)
	var horizon: float = min(vp.y * 0.5, float(Game.LAWN_Y) - 22.0)
	var field := Color(0.11, 0.16, 0.12) if night else Color(0.33, 0.54, 0.27)
	draw_rect(Rect2(0, horizon, vp.x, vp.y - horizon), field)
	var hillcol := field.lightened(0.07)
	for hx in [vp.x * 0.14, vp.x * 0.52, vp.x * 0.86]:
		draw_circle(Vector2(hx, horizon + 34), 130, hillcol)
	# ferne Silhouetten fuer Tiefe: Baeume am Tag, Grabsteine in der Nacht
	var silc := field.darkened(0.4)
	var rngS := RandomNumberGenerator.new(); rngS.seed = 8123
	var baseY := horizon + 16.0
	for i in range(9):
		var sxp := 40.0 + float(i) * (vp.x / 9.0) + rngS.randf() * 30.0
		if night:
			var gw := 14.0 + rngS.randf() * 8.0
			var gh := 20.0 + rngS.randf() * 14.0
			draw_rect(Rect2(sxp - gw * 0.5, baseY - gh, gw, gh), silc)
			draw_circle(Vector2(sxp, baseY - gh), gw * 0.5, silc)
		else:
			var th := 24.0 + rngS.randf() * 18.0
			draw_rect(Rect2(sxp - 3, baseY - th, 6, th), silc)
			draw_circle(Vector2(sxp, baseY - th), 13.0 + rngS.randf() * 6.0, silc)
	# sanfter Dunst am Horizont
	draw_rect(Rect2(0, horizon - 6, vp.x, 16), Color(0.9, 0.93, 0.96, 0.06 if night else 0.11))

# ---- Fallende Umgebungspartikel: Blaetter (Tag), Schnee (bei Frost) ----
func _draw_ambient_fall(night: bool, vp: Vector2) -> void:
	if weather == "gewitter": return          # bei Regen kein Extra-Gewusel
	var snow := (weather == "frost")
	if not snow and night: return             # nachts uebernehmen die Gluehwuermchen
	var rngA := RandomNumberGenerator.new(); rngA.seed = 20260713
	var n := 22 if snow else 13
	for i in range(n):
		var bx := rngA.randf() * vp.x
		var spd := (30.0 + rngA.randf() * 42.0) if snow else (20.0 + rngA.randf() * 28.0)
		var ph := rngA.randf()
		var yy := fmod(ph * vp.y + _anim_clock * spd, vp.y)
		var sway := sin(_anim_clock * (1.0 + ph) + float(i)) * (6.0 if snow else 11.0)
		var px := bx + sway
		if snow:
			draw_circle(Vector2(px, yy), 2.0 + ph * 1.4, Color(0.9, 0.95, 1.0, 0.6))
		else:
			var lc := Color(0.85, 0.6, 0.25, 0.5) if (i % 2 == 0) else Color(0.62, 0.8, 0.35, 0.45)
			var rot := _anim_clock * 2.0 + float(i)
			var arm := Vector2(cos(rot), sin(rot)) * 4.0
			draw_line(Vector2(px, yy) - arm, Vector2(px, yy) + arm, lc, 2.5)

func _cloud(x: float, y: float, s: float) -> void:
	var col := Color(1, 1, 1, 0.72)
	draw_circle(Vector2(x, y), 22 * s, col)
	draw_circle(Vector2(x + 26 * s, y + 6 * s), 18 * s, col)
	draw_circle(Vector2(x - 24 * s, y + 6 * s), 16 * s, col)
	draw_circle(Vector2(x, y + 11 * s), 20 * s, col)

# ---- Atmosphaere-Overlay: Gluehwuermchen (Nacht), Sonnenstrahlen (Tag), Vignette ----
func _draw_atmosphere(night: bool) -> void:
	var vp := get_viewport_rect().size
	_draw_ambient_fall(night, vp)
	if night:
		var rng3 := RandomNumberGenerator.new(); rng3.seed = 5150
		for i in range(16):
			var bx := rng3.randf() * vp.x
			var by := vp.y * (0.30 + rng3.randf() * 0.55)
			var dx := sin(_anim_clock * 0.7 + float(i) * 1.3) * 22.0
			var dy := cos(_anim_clock * 0.5 + float(i) * 2.1) * 14.0
			var glow := 0.4 + 0.6 * (0.5 + 0.5 * sin(_anim_clock * 3.0 + float(i)))
			var fp := Vector2(bx + dx, by + dy)
			draw_circle(fp, 4.5, Color(0.9, 1.0, 0.55, 0.10 * glow))
			draw_circle(fp, 1.8, Color(0.95, 1.0, 0.6, 0.85 * glow))
	else:
		# weiche Sonnenstrahlen von oben rechts
		var sp := Vector2(vp.x * 0.84, vp.y * 0.17)
		for k in range(7):
			var a := -2.4 + float(k) * 0.16 + sin(_anim_clock * 0.3) * 0.02
			var d := Vector2(cos(a), sin(a))
			var per := Vector2(-d.y, d.x) * (26.0 + k * 2.0)
			var far := sp + d * 900.0
			draw_colored_polygon(PackedVector2Array([sp - per * 0.15, far - per, far + per]), Color(1.0, 0.96, 0.7, 0.035))
	# Vignette: sanftes Abdunkeln der Raender (nachts staerker)
	var va := 0.34 if night else 0.20
	var edge := 46.0
	draw_rect(Rect2(0, 0, vp.x, edge), Color(0, 0, 0, va * 0.7))
	draw_rect(Rect2(0, vp.y - edge - 72, vp.x, edge + 72), Color(0, 0, 0, va))
	draw_rect(Rect2(0, 0, edge, vp.y), Color(0, 0, 0, va * 0.6))
	draw_rect(Rect2(vp.x - edge, 0, edge, vp.y), Color(0, 0, 0, va * 0.6))

# ---- Grasbueschel + kleine Blueten an der Vorderkante des Rasens ----
func _draw_grass_deco(lx: float, ly: float, lw: float, lh: float, night: bool) -> void:
	var basey := ly + lh + 4.0
	var gcol := Color(0.20, 0.42, 0.18) if night else Color(0.34, 0.62, 0.26)
	var rng4 := RandomNumberGenerator.new(); rng4.seed = 3737
	var n := int(lw / 26.0)
	for i in range(n):
		var gx := lx + 8.0 + float(i) * 26.0 + rng4.randf() * 6.0
		var sway := sin(_anim_clock * 1.4 + float(i)) * 2.2
		for b in range(3):
			var off := (float(b) - 1.0) * 3.2
			draw_line(Vector2(gx + off, basey), Vector2(gx + off + sway * (0.5 + 0.3 * b), basey - 10.0 - b), gcol, 2.0)
		if i % 4 == 0:
			var fcol := Color(1.0, 0.8, 0.35) if (i % 8 == 0) else Color(1.0, 0.5, 0.7)
			draw_circle(Vector2(gx + sway, basey - 12.0), 2.6, fcol)

# ---- Platzier-Vorschau: zeigt, wo die Pflanze landet (gruen = ok, rot = belegt/zu teuer) ----
func _draw_ghost() -> void:
	if Game.paused or Game.phase == "won" or Game.phase == "dead": return
	if _mouse.x < 0.0: return
	var col := int((_mouse.x - Game.LAWN_X) / Game.CELL)
	var row := int((_mouse.y - Game.LAWN_Y) / Game.CELL)
	if col < 0 or col >= Game.COLS or row < 0 or row >= rows: return
	var cellrect := Rect2(Game.LAWN_X + col * Game.CELL, Game.LAWN_Y + row * Game.CELL, Game.CELL, Game.CELL)
	var cxp := Game.LAWN_X + col * Game.CELL + Game.CELL / 2.0
	var cyp := Game.LAWN_Y + row * Game.CELL + Game.CELL / 2.0
	# Schaufel-Modus: Pflanze unter dem Cursor rot markieren
	if Game.shovel:
		for p in plants:
			if p.col == col and p.row == row:
				draw_rect(cellrect, Color(1.0, 0.3, 0.2, 0.20))
				draw_rect(cellrect, Color(1.0, 0.45, 0.35, 0.85), false, 2.0)
				return
		return
	if Game.place_slot < 0: return
	var ck := Game.seed_chain(Game.place_slot)
	if ck == "": return
	var occupied := false
	for p in plants:
		if p.col == col and p.row == row: occupied = true; break
	var s = Game.seed_stats(Game.place_slot)
	var affordable: bool = Game.sun >= int(s.cost)
	var okp := (not occupied) and affordable
	var gc: Color = Game.CHASSIS[ck].col
	var edge := Color(0.5, 1.0, 0.55) if okp else Color(1.0, 0.35, 0.28)
	draw_rect(cellrect, Color(edge.r, edge.g, edge.b, 0.12))
	draw_rect(cellrect, Color(edge.r, edge.g, edge.b, 0.85), false, 2.0)
	if okp:
		draw_circle(Vector2(cxp, cyp), 22.0, Color(gc.r, gc.g, gc.b, 0.38))   # Pflanzen-Geist
	if _font != null:
		var ct := "%d" % int(s.cost)
		var tc := Color(1, 0.95, 0.6) if affordable else Color(1, 0.5, 0.45)
		draw_string_outline(_font, Vector2(cxp - 10, cyp + 6), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.7))
		draw_string(_font, Vector2(cxp - 10, cyp + 6), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tc)

# ---- Anmarsch-Warnung: pulsierende Pfeile am rechten Feldrand, wenn noch Zombies kommen ----
func _draw_incoming() -> void:
	if Game.phase != "fight" or to_spawn <= 0: return
	var rx := Game.LAWN_X + Game.COLS * Game.CELL + 6.0
	var pulse := 0.5 + 0.5 * sin(_anim_clock * 6.0)
	var a := 0.25 + 0.4 * pulse
	for r in range(rows):
		var ry := Game.LAWN_Y + r * Game.CELL + Game.CELL * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(rx + 15, ry - 9), Vector2(rx + 15, ry + 9), Vector2(rx, ry)]), Color(1.0, 0.28, 0.2, a))

# ---- Gefahr: leuchtender roter Rand am Haus (links), wenn ein Zombie nah ist ----
func _draw_house_danger() -> void:
	var nearest := 9999.0
	for z in zombies:
		if z.get("dying", false): continue
		nearest = min(nearest, float(z.x) - float(Game.LAWN_X))
	if nearest > Game.CELL * 2.2: return
	var t: float = 1.0 - clamp(nearest / (Game.CELL * 2.2), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_anim_clock * 8.0)
	var a := (0.15 + 0.30 * t) * (0.6 + 0.4 * pulse)
	draw_rect(Rect2(Game.LAWN_X - 20, Game.LAWN_Y - 10, 26, rows * Game.CELL + 40), Color(1.0, 0.15, 0.1, a))

# ---- T-Shirt der Liebespaar-Zombies: kleines Herz + "him"/"her" (+ Wut-Dampf wenn sauer) ----
func _draw_shirt(cx: float, cy: float, shirt: String, angry: bool) -> void:
	var hc := Color(1.0, 0.2, 0.2) if angry else Color(1.0, 0.30, 0.45)
	draw_circle(Vector2(cx - 3.0, cy - 2.0), 2.4, hc)
	draw_circle(Vector2(cx + 3.0, cy - 2.0), 2.4, hc)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5.2, cy - 1.0), Vector2(cx + 5.2, cy - 1.0), Vector2(cx, cy + 5.0)]), hc)
	if _font != null:
		draw_string(_font, Vector2(cx - 14.0, cy + 20.0), ("him" if shirt == "him" else "her"), HORIZONTAL_ALIGNMENT_CENTER, 28, 10, Color(1, 1, 1))
	if angry:
		draw_line(Vector2(cx - 11, cy - 16), Vector2(cx - 14, cy - 22), Color(1, 0.4, 0.3, 0.85), 2.0)
		draw_line(Vector2(cx + 11, cy - 16), Vector2(cx + 14, cy - 22), Color(1, 0.4, 0.3, 0.85), 2.0)

# ---- Evolutions-Extras auf der Pflanze (Blitz-Plasma-Glimmen / Untod: 2 kleine Koepfe) ----
func _draw_evo(p, cx: float, cy: float, pr: float) -> void:
	var s = p.s
	# Blitz-Plasma-Glimmen: nur wenn die Blitz-Faehigkeit wirklich da ist
	if s.get("effects", []).has("chain") or float(s.get("zap", 0.0)) > 0.0 or float(s.get("aimbot", 0.0)) > 0.0 or float(s.get("lightning_rod", 0.0)) > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(_anim_clock * 6.0 + cx * 0.05)
		draw_circle(Vector2(cx, cy), pr * (1.12 + 0.12 * pulse), Color(0.4, 1.0, 0.55, 0.10 + 0.10 * pulse))
		for k in range(3):
			var a := _anim_clock * 5.0 + float(k) * TAU / 3.0
			draw_circle(Vector2(cx + cos(a) * pr * 1.05, cy + sin(a) * pr * 1.05), 2.0, Color(0.75, 1.0, 0.8, 0.9))
	# Extra-Koepfe: nur wenn der Schuetze wirklich mehrere Reihen beschiesst (extra_lanes)
	var ex := int(s.get("extra_lanes", 0))
	if ex >= 1 and (str(p.arch) == "shooter" or str(p.arch) == "beam"):
		var hc: Color = Game.CHASSIS[p.ck].col
		var hy := cy - pr * 0.66
		var n := clampi(ex, 1, 2)
		for k in range(n):
			var off := pr * (0.42 + 0.34 * float(k))
			for hx in [cx - off, cx + off]:
				draw_circle(Vector2(hx, hy), pr * 0.24, hc.darkened(0.15))
				draw_circle(Vector2(hx, hy), pr * 0.24, hc.darkened(0.45), false, 1.5)
				draw_circle(Vector2(hx - pr * 0.08, hy - pr * 0.02), pr * 0.045, Color(0.9, 0.2, 0.2))
				draw_circle(Vector2(hx + pr * 0.08, hy - pr * 0.02), pr * 0.045, Color(0.9, 0.2, 0.2))

# ---- Projektil je Element: Feuer=Flammen-Welle, Blitz=Plasma, Eis=blau, Gift=gruen ----
func _draw_projectile(x: float, y: float, effects) -> void:
	# Bewegungs-Schweif hinter dem Projektil (element-gefaerbt, verblassend)
	var trc := Color(0.62, 0.95, 0.4, 0.5)
	if effects.has("burn"): trc = Color(1.0, 0.55, 0.15, 0.5)
	elif effects.has("chain"): trc = Color(0.5, 1.0, 0.6, 0.5)
	elif effects.has("slow"): trc = Color(0.5, 0.8, 1.0, 0.5)
	elif effects.has("poison"): trc = Color(0.6, 0.9, 0.35, 0.5)
	for k in range(3):
		var ta := trc; ta.a = trc.a * (1.0 - float(k) / 3.0)
		draw_circle(Vector2(x - float(k + 1) * 6.0, y), 5.0 - float(k) * 1.2, ta)
	if effects.has("burn"):
		draw_circle(Vector2(x, y), 8.0, Color(1.0, 0.5, 0.12, 0.30))
		var t := _anim_clock * 22.0 + x * 0.2
		var pts := PackedVector2Array()
		for i in range(5):
			pts.append(Vector2(x - 8.0 + float(i) * 4.0, y + sin(t + float(i) * 1.1) * 3.0))
		draw_polyline(pts, Color(1.0, 0.78, 0.25), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y + 3), Vector2(x + 5, y + 3), Vector2(x + 2, y - 6)]), Color(1.0, 0.45, 0.1))
	elif effects.has("chain"):
		draw_circle(Vector2(x, y), 8.0, Color(0.4, 1.0, 0.5, 0.30))
		draw_circle(Vector2(x, y), 4.0, Color(0.78, 1.0, 0.82))
		draw_line(Vector2(x - 6, y - 3), Vector2(x + 5, y + 2), Color(0.6, 1.0, 0.6), 1.5)
	elif effects.has("slow"):
		draw_circle(Vector2(x, y), 6.0, Color(0.5, 0.8, 1.0))
		draw_circle(Vector2(x - 2, y - 2), 1.6, Color(1, 1, 1, 0.9))
	elif effects.has("poison"):
		draw_circle(Vector2(x, y), 6.0, Color(0.6, 0.9, 0.35))
	else:
		draw_circle(Vector2(x, y), 6.0, Color(0.62, 0.95, 0.4))

# ---- Gesicht: zwei Augen + Mund (mood: happy/neutral/angry) ----
func _face(cx: float, cy: float, s: float, mood: String, eyecol := Color(0.1, 0.1, 0.12)) -> void:
	var ex := s * 0.42
	var ey := cy - s * 0.08
	draw_circle(Vector2(cx - ex, ey), s * 0.27, Color(1, 1, 1))          # Augenweiss
	draw_circle(Vector2(cx + ex, ey), s * 0.27, Color(1, 1, 1))
	draw_circle(Vector2(cx - ex, ey), s * 0.13, eyecol)                  # Pupille
	draw_circle(Vector2(cx + ex, ey), s * 0.13, eyecol)
	draw_circle(Vector2(cx - ex + s * 0.05, ey - s * 0.05), s * 0.05, Color(1, 1, 1, 0.9))  # Glanz im Auge
	draw_circle(Vector2(cx + ex + s * 0.05, ey - s * 0.05), s * 0.05, Color(1, 1, 1, 0.9))
	var my := cy + s * 0.42
	if mood == "happy":
		draw_arc(Vector2(cx, my - s * 0.18), s * 0.32, deg_to_rad(20), deg_to_rad(160), 14, eyecol, 2.5)
	elif mood == "angry":
		draw_arc(Vector2(cx, my + s * 0.18), s * 0.32, deg_to_rad(200), deg_to_rad(340), 14, eyecol, 2.5)
	else:
		draw_line(Vector2(cx - s * 0.2, my), Vector2(cx + s * 0.2, my), eyecol, 2.5)

# ---- Detaillierte Pflanze je nach Typ + Gesicht ----
func _draw_plant(p, col: Color, pr: float, cx: float, cy: float) -> void:
	var ck := str(p.ck)
	var arch := str(p.arch)
	# Skin faerbt sich erst, wenn die Element-FAEHIGKEIT wirklich freigeschaltet ist
	# (nicht schon beim ersten Schaden-Knoten in der Richtung)
	var _es = p.s
	if _es.get("effects", []).has("burn") or float(_es.get("contact_dmg", 0.0)) > 0.0 or float(_es.get("fire_death", 0.0)) > 0.0:
		col = col.lerp(Color(1.0, 0.30, 0.15), 0.60)     # Feuer
	elif _es.get("effects", []).has("slow") or float(_es.get("chill", 0.0)) > 0.0:
		col = col.lerp(Color(0.35, 0.65, 1.0), 0.60)     # Eis
	elif _es.get("effects", []).has("chain") or float(_es.get("zap", 0.0)) > 0.0 or float(_es.get("aimbot", 0.0)) > 0.0 or float(_es.get("lightning_rod", 0.0)) > 0.0:
		col = col.lerp(Color(0.35, 1.0, 0.55), 0.55)     # Blitz
	elif _es.get("effects", []).has("poison") or float(_es.get("necro", 0.0)) > 0.0 or float(_es.get("lane_switch", 0.0)) > 0.0:
		col = col.lerp(Color(0.62, 0.35, 0.95), 0.50)    # Untod
	# Eigenes Sprite? -> zeichnen und fertig
	var tex := _tex("res://assets/sprites/plants/%s.png" % ck)
	if tex != null:
		var d := pr * 2.5
		draw_texture_rect(tex, Rect2(cx - d * 0.5, cy - d * 0.5, d, d), false)
		return
	if ck == "sonne":
		# Sonnenblume: goldene Bluetenblaetter + brauner Kern + froehliches Gesicht
		for i in range(10):
			var a := deg_to_rad(i * 36.0)
			draw_circle(Vector2(cx + cos(a) * pr * 0.98, cy + sin(a) * pr * 0.98), pr * 0.34, Color(1, 0.8, 0.18))
		draw_circle(Vector2(cx, cy), pr * 0.72, Color(0.5, 0.32, 0.12))
		draw_circle(Vector2(cx, cy), pr * 0.72, Color(0.32, 0.19, 0.06), false, 2.0)
		_face(cx, cy, pr * 0.72, "happy", Color(0.22, 0.12, 0.03))
		return
	if ck == "lilypad":
		draw_circle(Vector2(cx, cy), pr, Color(0.16, 0.45, 0.28))
		draw_circle(Vector2(cx, cy), pr - 3.0, col)
		_face(cx, cy, pr * 0.5, "happy")
		return
	if ck == "wall":
		# Panzer-Nuss: ovale Nuss mit Panzer-Rillen
		draw_circle(Vector2(cx, cy - pr * 0.22), pr * 0.80, col.darkened(0.45))
		draw_circle(Vector2(cx, cy + pr * 0.20), pr * 0.88, col.darkened(0.45))
		draw_circle(Vector2(cx, cy - pr * 0.22), pr * 0.72, col)
		draw_circle(Vector2(cx, cy + pr * 0.20), pr * 0.80, col)
		draw_arc(Vector2(cx, cy), pr * 0.58, -1.1, 1.1, 12, col.darkened(0.3), 2.0)
		draw_arc(Vector2(cx, cy), pr * 0.40, -1.0, 1.0, 10, col.darkened(0.25), 2.0)
		_face(cx, cy - pr * 0.12, pr * 0.58, "neutral")
		return
	if ck == "pilz" or ck == "wasserpilz" or ck == "sonnenpilz":
		# Pilz: heller Stiel + Halbkuppel-Hut mit Punkten
		var capc := col
		if ck == "sonnenpilz": capc = Color(1.0, 0.80, 0.25)
		var stemc := Color(0.92, 0.88, 0.80)
		draw_rect(Rect2(cx - pr * 0.28, cy - pr * 0.05, pr * 0.56, pr * 0.92), stemc)
		draw_rect(Rect2(cx - pr * 0.28, cy - pr * 0.05, pr * 0.56, pr * 0.92), stemc.darkened(0.3), false, 2.0)
		var cap := PackedVector2Array()
		for i in range(13):
			var a := PI + PI * float(i) / 12.0
			cap.append(Vector2(cx + cos(a) * pr * 1.05, cy - pr * 0.05 + sin(a) * pr * 0.95))
		draw_colored_polygon(cap, capc)
		draw_rect(Rect2(cx - pr * 1.05, cy - pr * 0.14, pr * 2.10, pr * 0.14), capc.darkened(0.3))
		draw_circle(Vector2(cx - pr * 0.42, cy - pr * 0.52), pr * 0.13, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(cx + pr * 0.30, cy - pr * 0.64), pr * 0.11, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(cx + 0.02 * pr, cy - pr * 0.34), pr * 0.09, Color(1, 1, 1, 0.9))
		if ck == "sonnenpilz":
			draw_circle(Vector2(cx, cy - pr * 0.5), pr * 0.9, Color(1.0, 0.85, 0.3, 0.14))
		_face(cx, cy + pr * 0.30, pr * 0.40, "happy")
		return
	if ck == "frostbluete":
		# Frostbluete: 6 Eiskristall-Blaetter + frostiger Kern + kleines Rohr
		for i in range(6):
			var a := deg_to_rad(i * 60.0 + 30.0)
			var tipp := Vector2(cx + cos(a) * pr * 1.12, cy + sin(a) * pr * 1.12)
			var lft := Vector2(cx + cos(a + 0.45) * pr * 0.42, cy + sin(a + 0.45) * pr * 0.42)
			var rgt := Vector2(cx + cos(a - 0.45) * pr * 0.42, cy + sin(a - 0.45) * pr * 0.42)
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy), lft, tipp, rgt]), Color(0.62, 0.85, 1.0, 0.95))
		draw_rect(Rect2(cx + pr * 0.42, cy - pr * 0.16, pr * 0.62, pr * 0.32), Color(0.50, 0.75, 0.95))
		draw_circle(Vector2(cx, cy), pr * 0.52, Color(0.85, 0.95, 1.0))
		_face(cx, cy, pr * 0.44, "neutral", Color(0.15, 0.3, 0.5))
		return
	# Basis-Koerper
	draw_circle(Vector2(cx, cy), pr, col.darkened(0.5))
	draw_circle(Vector2(cx, cy), pr - 3.0, col)
	draw_circle(Vector2(cx - pr * 0.32, cy - pr * 0.32), pr * 0.30, col.lightened(0.4))
	if arch == "shooter" or arch == "beam":
		draw_rect(Rect2(cx + pr * 0.45, cy - pr * 0.2, pr * 0.78, pr * 0.4), col.darkened(0.28))
		draw_circle(Vector2(cx + pr * 1.22, cy), pr * 0.24, col.darkened(0.4))
		_face(cx - pr * 0.12, cy - pr * 0.05, pr * 0.55, "angry")
	elif arch == "wall":
		_face(cx, cy, pr * 0.72, "neutral")
	elif arch == "fume" or arch == "lobber":
		draw_circle(Vector2(cx - pr * 0.35, cy - pr * 0.32), pr * 0.16, col.lightened(0.55))
		draw_circle(Vector2(cx + pr * 0.32, cy - pr * 0.36), pr * 0.13, col.lightened(0.55))
		_face(cx, cy + pr * 0.12, pr * 0.55, "neutral")
	else:
		_face(cx, cy, pr * 0.62, "happy")

# ---- Detaillierter Zombie: Torso + Arme + Gesicht (hohle rote Augen, zackiger Mund) ----
func _draw_zombie(z, zc: Color, sz: float, zx: float, zy: float) -> void:
	var kind := str(z.kind)
	# 1) Benannte Zustands-Animation (walking / idle / dying)
	var state := "walking"
	if z.get("dying", false): state = "dying"
	elif z.get("eating", false): state = "idle"
	var frames := _zombie_anim(kind, state)
	if frames.is_empty() and state != "walking": frames = _zombie_anim(kind, "walking")
	if frames.size() > 0:
		var idx := 0
		if state == "dying":
			idx = clampi(int(float(z.get("die_t", 0.0)) / 0.06), 0, frames.size() - 1)
		else:
			idx = int(_anim_clock / 0.08) % frames.size()
		var aw := sz * 2.9
		var ah := sz * 2.9
		draw_set_transform(Vector2(zx * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))   # horizontal spiegeln -> Blick nach links
		draw_texture_rect(frames[idx], Rect2(zx - aw * 0.5, zy - ah * 0.62, aw, ah), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 2) Einzeldatei-Sprite (zombies/<kind>.png oder 0.png)
	var tex := _zombie_tex(kind)
	if tex != null:
		var w := sz * 1.7
		var h := sz * 2.0
		draw_set_transform(Vector2(zx * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(tex, Rect2(zx - w * 0.5, zy - h * 0.6, w, h), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 3) Gezeichneter Fallback
	draw_rect(Rect2(zx - sz * 0.72, zy - sz * 0.12, sz * 0.45, sz * 0.16), zc.darkened(0.3))   # ausgestreckter Arm
	draw_rect(Rect2(zx - sz / 2.0 - 2, zy - sz * 0.55 - 2, sz + 4, sz * 1.1 + 4), Color(0.06, 0.06, 0.09))  # Umriss
	draw_rect(Rect2(zx - sz / 2.0, zy - sz * 0.55, sz, sz * 1.1), zc)                          # Torso
	draw_rect(Rect2(zx - sz / 2.0, zy - sz * 0.55, sz, sz * 0.16), zc.lightened(0.12))         # Kopf-Highlight
	var fy := zy - sz * 0.28
	draw_circle(Vector2(zx - sz * 0.16, fy), sz * 0.11, Color(0.95, 0.95, 0.88))              # Augenweiss
	draw_circle(Vector2(zx + sz * 0.16, fy), sz * 0.11, Color(0.95, 0.95, 0.88))
	draw_circle(Vector2(zx - sz * 0.16, fy), sz * 0.055, Color(0.75, 0.1, 0.1))               # rote Pupille
	draw_circle(Vector2(zx + sz * 0.16, fy), sz * 0.055, Color(0.75, 0.1, 0.1))
	var my := zy + sz * 0.04
	draw_line(Vector2(zx - sz * 0.22, my), Vector2(zx + sz * 0.22, my), Color(0.1, 0.05, 0.05), 2.5)  # Mund
	for k in range(3):
		var mx := zx - sz * 0.15 + k * sz * 0.15
		draw_line(Vector2(mx, my), Vector2(mx + sz * 0.07, my - sz * 0.09), Color(0.1, 0.05, 0.05), 1.5)  # Zaehne

# ---- Richtige Sonne: Strahlen + Glow + Gesicht ----
func _draw_sun_icon(cx: float, cy: float, r: float) -> void:
	var ctr := Vector2(cx, cy)
	# Eigenes Sonnen-Sprite? -> zeichnen und fertig
	var tex := _tex("res://assets/sprites/sun.png")
	if tex != null:
		var sd := r * 2.8
		draw_texture_rect(tex, Rect2(cx - sd * 0.5, cy - sd * 0.5, sd, sd), false)
		return
	var pulse := 1.0 + 0.08 * sin(_anim_clock * 4.0 + cx * 0.05) + beat_pulse * 0.12
	var rr := r * pulse
	draw_circle(ctr, rr * 1.7, Color(1, 0.9, 0.3, 0.12))          # weiter Glow
	draw_circle(ctr, rr * 1.3, Color(1, 0.9, 0.3, 0.20))
	for i in range(12):
		var a := deg_to_rad(i * 30.0 + _anim_clock * 22.0)         # langsam rotierende Strahlen
		var d := Vector2(cos(a), sin(a))
		draw_line(ctr + d * rr * 0.95, ctr + d * rr * 1.55, Color(1, 0.8, 0.2), 3.0)
	draw_circle(ctr, rr, Color(1, 0.82, 0.15))
	draw_circle(ctr, rr, Color(0.95, 0.6, 0.1), false, 2.5)
	_face(cx, cy, rr * 0.95, "happy", Color(0.6, 0.35, 0.05))
	draw_circle(ctr + Vector2(-rr * 0.4, -rr * 0.4), rr * 0.22, Color(1, 1, 0.85, 0.6))

func _hp_bar(cx: float, y: float, frac: float, c: Color) -> void:
	if frac >= 1.0: return
	frac = clamp(frac, 0.0, 1.0)
	var w := 46.0
	var x := cx - w / 2.0
	draw_rect(Rect2(x - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.6))      # Rahmen
	draw_rect(Rect2(x, y, w, 5), Color(0.12, 0.14, 0.13, 0.9))         # Hintergrund
	# Farbe nach Gesundheit: bei niedrigem Stand Richtung Gelb/Rot
	var fill := c
	if frac < 0.55: fill = c.lerp(Color(1.0, 0.82, 0.2), (0.55 - frac) / 0.55)
	if frac < 0.25: fill = Color(0.95, 0.33, 0.24)
	draw_rect(Rect2(x, y, w * frac, 5), fill)
	draw_rect(Rect2(x, y, w * frac, 2), Color(1, 1, 1, 0.18))          # Glanzlinie
