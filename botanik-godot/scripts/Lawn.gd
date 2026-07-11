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
var rng := RandomNumberGenerator.new()

var to_spawn := 0
var spawn_timer := 0.0
var sky_timer := 5.0
var idle_timer := 6.0
var hazard_timer := 8.0
var msg := ""
var msg_t := 0.0

func _ready() -> void:
	rng.randomize()
	reset_run()

func world_of(w: int) -> Dictionary:
	return BAL.act_of(w)

func reset_run() -> void:
	Game.rebirth()
	plants.clear(); zombies.clear(); peas.clear(); suns.clear(); fx.clear()
	rows = Game.lanes_count()
	mowers.clear()
	for r in range(rows):
		mowers.append({"row": r, "x": float(Game.LAWN_X - 30), "active": false, "used": false})
	sky_timer = 5.0; to_spawn = 0; idle_timer = 6.0; hazard_timer = 9.0; msg = "Bereit!"; msg_t = 2.0

# Reihen nachziehen, wenn neue freigeschaltet wurden (mid-run kaufbar)
func _sync_rows() -> void:
	var want := Game.lanes_count()
	if want > rows:
		for r in range(rows, want):
			mowers.append({"row": r, "x": float(Game.LAWN_X - 30), "active": false, "used": false})
		rows = want

func start_wave() -> void:
	if Game.phase != "prep": return
	Game.wave += 1
	Game.phase = "fight"
	_sync_rows()
	to_spawn = BAL.WAVE_BASE + int(Game.wave * BAL.WAVE_PER) + int(Game.wave / 6.0) * Game.lanes_count()
	spawn_timer = 0.5
	_spawn("flag")
	to_spawn = max(0, to_spawn - 1)
	if BAL.is_boss_wave(Game.wave):
		var bk := BAL.boss_key(Game.wave)
		_spawn(bk)
		to_spawn += int(Game.ZTYPES[bk].get("summon", 0))
		var wo := world_of(Game.wave)
		msg = "%s  —  BOSS: %s!" % [wo.name, Game.ZTYPES[bk].n]; msg_t = 3.0
		return
	elif Game.wave == BAL.MINIBOSS_WAVE:
		_spawn("miniboss")
	msg = "Welle %d startet!" % Game.wave; msg_t = 1.6

func _end_wave() -> void:
	if Game.wave >= 100:
		var rew := 150 + int(Game.brains * 0.25)
		Game.brains += rew; Game.save_game()
		Game.phase = "won"
		msg = "SIEG! Welle 100 geschafft! +%d Gehirne" % rew; msg_t = 6.0
		return
	Game.phase = "prep"
	Game.fp += Game.wave
	if Game.mower_fix():
		for m in mowers: m.used = false; m.active = false; m.x = float(Game.LAWN_X - 30)
	msg = "Welle %d geschafft! +%d FP" % [Game.wave, Game.wave]; msg_t = 2.0

func _spawn(kind: String) -> void:
	var b = Game.ZTYPES[kind]
	Game.seen[kind] = true
	var row := rng.randi() % rows
	var hp_mul := 1.0 + Game.wave * BAL.Z_HP_PER_WAVE + pow(Game.wave, BAL.Z_HP_POW) * BAL.Z_HP_POW_MUL
	var hp := float(b.hp) * hp_mul
	zombies.append({
		"kind": kind, "row": row, "x": float(Game.LAWN_X + Game.COLS * Game.CELL + 20),
		"y": Game.LAWN_Y + row * Game.CELL + Game.CELL / 2.0,
		"hp": hp, "maxhp": hp, "speed": float(b.speed) * (1.0 + Game.wave * BAL.Z_SPD_PER_WAVE),
		"dmg": float(b.dmg), "col": b.col,
		"boss": b.get("boss", false), "final": b.get("final", false), "vault": b.get("vault", false),
		"smash": b.get("smash", false), "carrier": b.get("carrier", false),
		"jumped": false, "fp": int(b.fp), "brain": int(b.get("brain", 0)),
		"slow": 0.0, "burn": 0.0, "poison": 0.0, "dropped": false
	})

func _spawn_one() -> void:
	var act := world_of(Game.wave)
	var k := _weighted(act.spawn)
	# Gehirn-Traeger tauchen selten zusaetzlich auf (nur sie + Bosse droppen Gehirne)
	if Game.wave >= BAL.BRAIN_MIN_WAVE and k != "brainz" and rng.randf() < BAL.BRAIN_CHANCE:
		k = "brainz"
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
		_update(delta)
	if msg_t > 0: msg_t -= delta
	queue_redraw()

func _update(dt: float) -> void:
	var wo := world_of(Game.wave)
	# Himmels-Sonne
	sky_timer -= dt
	if sky_timer <= 0:
		sky_timer = (8.0 + rng.randf() * 4.0) * (1.7 if wo.night else 1.0)
		var x := Game.LAWN_X + 40 + rng.randf() * (Game.COLS * Game.CELL - 80)
		var val := int(round(25 * (0.5 if wo.night else 1.0)))
		suns.append({"x": x, "y": float(Game.LAWN_Y - 10), "ty": Game.LAWN_Y + 50 + rng.randf() * (rows * Game.CELL - 120), "vy": 70.0, "value": val, "falling": true, "life": 12.0})
	# Wellensteuerung
	if Game.phase == "fight":
		spawn_timer -= dt
		if to_spawn > 0 and spawn_timer <= 0:
			spawn_timer = 0.9 + rng.randf() * 1.2
			_spawn_one(); to_spawn -= 1
		if to_spawn <= 0 and zombies.is_empty():
			_end_wave()
	elif Game.phase == "prep":
		# Zwischen den Wellen kommen vereinzelt Zombies (Cap = idle_cap, im Labor upgradebar)
		idle_timer -= dt
		if idle_timer <= 0 and zombies.size() < Game.idle_cap():
			idle_timer = rng.randf_range(5.0, 9.0)
			_spawn("basic")
	# Umwelt-Zerstoerung (Dachterrasse/Finstere Zone): beschaedigt zufaellige Pflanzen
	if wo.get("hazard", false) and not plants.is_empty():
		hazard_timer -= dt
		if hazard_timer <= 0:
			hazard_timer = rng.randf_range(BAL.HAZARD_MIN, BAL.HAZARD_MAX)
			var ph = plants[rng.randi() % plants.size()]
			ph.hp -= BAL.HAZARD_DMG
			fx.append({"t": "boom", "x": ph.x, "y": ph.y, "life": 0.3})
			if ph.hp <= 0: plants.erase(ph)
			msg = "Umwelt-Schaden!"; msg_t = 1.0
	# Pflanzen
	for p in plants:
		var s = p.s
		if float(s.get("regen", 0.0)) > 0.0 and p.hp < p.maxhp:
			p.hp = min(p.maxhp, p.hp + float(s.regen) * dt)
		if p.arch == "bomb":
			p.fuse -= dt
			if p.fuse <= 0 and not p.done: _bomb(p); p.done = true
			continue
		p.t += dt
		if p.arch == "sun":
			if p.t >= s.interval: p.t = 0.0; suns.append({"x": p.x + rng.randf_range(-8,8), "y": p.y, "ty": p.y, "vy": 0.0, "value": int(s.amount), "falling": false, "life": 12.0})
		elif p.arch == "shooter":
			if p.t >= s.shot_int and _lane_has(p): p.t = 0.0; _shoot(p)
		elif p.arch == "beam":
			if p.t >= s.shot_int and _lane_has(p): p.t = 0.0; _beam(p)
		elif p.arch == "fume":
			if p.t >= s.shot_int and _lane_has(p): p.t = 0.0; _fume(p)
		elif p.arch == "lobber":
			if p.t >= s.shot_int and _lane_has(p): p.t = 0.0; _lob(p)
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
				z.hp -= pe.dmg; _apply_fx(z, pe.effects, pe.dmg)
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
		if z.burn > 0: z.hp -= 8.0 * dt; z.burn -= dt
		if z.poison > 0: z.hp -= 9.0 * dt; z.poison -= dt
		if z.slow > 0: z.slow -= dt
		if z.hp <= 0: _kill(z); zombies.remove_at(i); continue
		var sl := 0.5 if z.slow > 0 else 1.0
		var tgt = null
		for p in plants:
			if p.arch == "spike" or p.arch == "bomb": continue
			if p.row == z.row and abs(z.x - p.x) < Game.CELL * 0.42 and z.x >= p.x - Game.CELL * 0.2:
				tgt = p; break
		# Stachel-Schaden
		for p in plants:
			if p.arch == "spike" and p.row == z.row and abs(z.x - p.x) < Game.CELL * 0.5:
				z.hp -= float(p.s.dmg) * dt * 2.0
				_apply_fx(z, p.s.effects, float(p.s.dmg))
		if tgt != null and z.vault and not z.jumped:
			z.x = tgt.x - Game.CELL * 0.55; z.jumped = true
		elif tgt != null and z.smash:
			# Smasher/Boss zerschmettert die Pflanze sofort -> Meta muss sich anpassen
			var px = tgt.x; var py = tgt.y
			plants.erase(tgt)
			fx.append({"t": "boom", "x": px, "y": py, "life": 0.28})
		elif tgt != null:
			tgt.hp -= z.dmg * dt
			if float(tgt.s.get("thorns", 0.0)) > 0.0:
				z.hp -= z.dmg * float(tgt.s.thorns) * dt
			if tgt.hp <= 0: plants.erase(tgt)
		else:
			z.x -= z.speed * sl * dt
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
		if zombies[i].hp <= 0: zombies.remove_at(i)
	# Sonne
	for i in range(suns.size() - 1, -1, -1):
		var su = suns[i]
		if su.falling and su.y < su.ty: su.y += su.vy * dt
		else: su.falling = false
		su.life -= dt
		if su.life <= 0: suns.remove_at(i)
	# Effekte
	for i in range(fx.size() - 1, -1, -1):
		fx[i].life -= dt
		if fx[i].life <= 0: fx.remove_at(i)

func _lane_has(p) -> bool:
	for z in zombies:
		if z.row == p.row and z.x > p.x - 10 and z.hp > 0: return true
	return false

func _shoot(p) -> void:
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
	var s = p.s
	var reach = p.x + (s.range if s.range > 0 else 2.6) * Game.CELL
	for z in zombies:
		if z.row == p.row and z.x > p.x - 6 and z.x < reach and z.hp > 0: z.hp -= s.dmg; _apply_fx(z, s.effects, s.dmg)
	fx.append({"t": "fume", "x": p.x, "y": p.y, "w": (s.range if s.range > 0 else 2.6) * Game.CELL, "life": 0.2})

func _lob(p) -> void:
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
	var others := []
	for o in zombies:
		if o != z and o.hp > 0: others.append(o)
	others.sort_custom(func(a, b): return Vector2(a.x,a.y).distance_to(Vector2(z.x,z.y)) < Vector2(b.x,b.y).distance_to(Vector2(z.x,z.y)))
	for i in range(min(2, others.size())):
		others[i].hp -= dmg * 0.5
		fx.append({"t": "bolt", "x": z.x, "y": z.y, "x2": others[i].x, "y2": others[i].y, "life": 0.2})

func _mow(row: int) -> bool:
	for m in mowers:
		if m.row == row and not m.used:
			if not m.active: m.active = true
			return true
	return false

func _kill(z) -> void:
	if z.dropped: return
	z.dropped = true
	var rew := Game.reward_mul()
	if z.boss:
		var b := int(max(1, round((z.brain + int(Game.wave / 5.0)) * Game.brain_mul() * rew)))
		Game.brains += b; Game.save_game()
		fx.append({"t": "boom", "x": z.x, "y": z.y, "life": 0.4})
		msg = "Boss besiegt! +%d Gehirne" % b; msg_t = 2.5
	elif z.get("carrier", false) and int(z.get("brain", 0)) > 0:
		var bc := int(max(1, round(z.brain * Game.brain_mul() * rew)))
		Game.brains += bc; Game.save_game()
		msg = "Gehirn erbeutet! +%d" % bc; msg_t = 1.5
	Game.fp += int(max(1, round(z.fp * Game.fp_mul() * rew)))
	Game.coins += int(max(1, round((1 + Game.wave * 0.08 + (8 if z.boss else 0)) * Game.coin_mul() * rew)))

func _lose() -> void:
	Game.phase = "dead"
	msg = "Überrannt!"; msg_t = 4.0

# ---- Eingabe ----
func _unhandled_input(event: InputEvent) -> void:
	if Game.paused: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		lawn_click(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if Game.phase == "won": reset_run()
			else: start_wave()

# ---- Klick-Steuerung ----
func lawn_click(pos: Vector2) -> void:
	if Game.phase == "won" or Game.phase == "dead": return
	# Sonne einsammeln
	for i in range(suns.size() - 1, -1, -1):
		if pos.distance_to(Vector2(suns[i].x, suns[i].y)) < 30:
			Game.sun += suns[i].value; suns.remove_at(i); return
	var col := int((pos.x - Game.LAWN_X) / Game.CELL)
	var row := int((pos.y - Game.LAWN_Y) / Game.CELL)
	if col < 0 or col >= Game.COLS or row < 0 or row >= rows: return
	# Schaufel
	if Game.shovel:
		for p in plants:
			if p.col == col and p.row == row: plants.erase(p); return
		return
	# Hammer/Faust (kein Samen gewählt)
	if Game.place_slot < 0:
		var best = null; var bd := 1.0e9
		for z in zombies:
			if z.hp > 0:
				var d = pos.distance_to(Vector2(z.x, z.y))
				if d < Game.CELL * 0.55 and d < bd: bd = d; best = z
		if best != null:
			best.hp -= Game.click_dmg()
			if Game.has_click_coin(): Game.coins += int(max(1, round(Game.coin_mul())))
		return
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
	plants.append({"ck": ck, "arch": s.arch, "row": row, "col": col, "x": x, "y": y, "hp": float(s.hp), "maxhp": float(s.hp), "s": s, "t": 0.0, "fuse": (0.7 if s.arch == "bomb" else 0.0), "done": false})

# ---- Zeichnen ----
func _draw() -> void:
	var wo := world_of(Game.wave)
	for r in range(rows):
		for c in range(Game.COLS):
			var g: Color
			if wo.pond and r == rows - 1: g = (Color(0.11,0.33,0.4) if (r+c)%2==0 else Color(0.13,0.39,0.45))
			else: g = (wo.g1 if (r + c) % 2 == 0 else wo.g2)
			draw_rect(Rect2(Game.LAWN_X + c * Game.CELL, Game.LAWN_Y + r * Game.CELL, Game.CELL, Game.CELL), g)
	if wo.night: draw_rect(Rect2(Game.LAWN_X, Game.LAWN_Y, Game.COLS * Game.CELL, rows * Game.CELL), Color(0.08,0.12,0.25,0.30))
	if wo.get("roof", false): draw_rect(Rect2(Game.LAWN_X, Game.LAWN_Y, Game.COLS * Game.CELL, rows * Game.CELL), Color(0.5,0.35,0.18,0.14))
	draw_rect(Rect2(Game.LAWN_X - 14, Game.LAWN_Y, 9, rows * Game.CELL), Color(0.42,0.32,0.62))
	# Rasenmäher
	for m in mowers:
		if m.used: continue
		draw_rect(Rect2(m.x, Game.LAWN_Y + m.row * Game.CELL + Game.CELL * 0.55, 34, 20), Color(0.85,0.29,0.22))
	# Pflanzen
	for p in plants:
		var col: Color = Game.CHASSIS[p.ck].col
		draw_circle(Vector2(p.x, p.y), 28, col)
		_hp_bar(p.x, p.y + 30, p.hp / p.maxhp, Color(0.35,0.85,0.4))
	# Erbsen
	for pe in peas:
		if pe.get("lob", false):
			var arc = sin(PI * pe.pt) * Game.CELL * 0.7
			draw_circle(Vector2(pe.x, Game.LAWN_Y + pe.row * Game.CELL + Game.CELL/2.0 - arc), 8, Color(0.6,0.9,0.4))
		else:
			draw_circle(Vector2(pe.x, pe.y), 6, Color(0.62,0.95,0.4))
	# Zombies
	for z in zombies:
		var zc: Color = z.col
		if z.slow > 0: zc = zc.lerp(Color(0.6,0.8,1), 0.4)
		var sz = 60 if z.boss else 40
		draw_rect(Rect2(z.x - sz/2.0, z.y - sz*0.55, sz, sz*1.1), zc)
		_hp_bar(z.x, z.y - sz*0.62, z.hp / z.maxhp, Color(0.9,0.3,0.3))
		var ix = z.x + sz*0.4
		if z.burn > 0: draw_circle(Vector2(ix, z.y - sz*0.5), 4, Color(1,0.5,0.1))
		if z.poison > 0: draw_circle(Vector2(ix, z.y - sz*0.5 + 10), 4, Color(0.6,0.9,0.3))
	# Sonne
	for s in suns:
		draw_circle(Vector2(s.x, s.y), 15, Color(1,0.85,0.25))
		draw_circle(Vector2(s.x, s.y), 15, Color(0.9,0.6,0.1), false, 2.0)
	# Effekte
	for e in fx:
		if e.t == "boom": draw_circle(Vector2(e.x, e.y), 60 * (e.life/0.4), Color(1,0.6,0.1, e.life/0.4))
		elif e.t == "beam": draw_line(Vector2(e.x, e.y), Vector2(Game.LAWN_X + Game.COLS*Game.CELL, e.y), Color(1,0.3,0.3, e.life/0.12), 5)
		elif e.t == "fume": draw_rect(Rect2(e.x, e.y - Game.CELL*0.4, e.w, Game.CELL*0.8), Color(0.6,0.6,0.6, e.life/0.2*0.5))
		elif e.t == "splat": draw_circle(Vector2(e.x, e.y), 11, Color(0.7,0.95,0.5, e.life/0.2))
		elif e.t == "bolt": draw_line(Vector2(e.x, e.y), Vector2(e.x2, e.y2), Color(1,0.95,0.4, e.life/0.2), 3)

func _hp_bar(cx: float, y: float, frac: float, c: Color) -> void:
	if frac >= 1.0: return
	frac = clamp(frac, 0.0, 1.0)
	var w := 46.0
	draw_rect(Rect2(cx - w/2.0, y, w, 5), Color(0,0,0,0.5))
	draw_rect(Rect2(cx - w/2.0, y, w * frac, 5), c)
