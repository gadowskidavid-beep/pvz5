extends Node2D
# Baut die komplette UI (in Code) und verwaltet Overlays + den Rasen (Lawn).

var lawn
var ui: CanvasLayer
var sun_lbl: Label
var fp_lbl: Label
var coin_lbl: Label
var brain_lbl: Label
var status_lbl: Label
var seed_box: VBoxContainer
var wave_btn: Button
var overlays := {}     # name -> {"panel":Panel, "content":VBoxContainer}

func _ready() -> void:
	lawn = Node2D.new()
	lawn.set_script(load("res://scripts/Lawn.gd"))
	add_child(lawn)
	ui = CanvasLayer.new()
	add_child(ui)
	_build_topbar()
	_build_left()
	_build_wave_btn()
	for n in ["lab", "prestige", "almanac", "zombiebook", "shop"]:
		_make_overlay(n)
	refresh_seeds()

func _process(_delta: float) -> void:
	refresh_top()

# ================= TOPBAR =================
func _build_topbar() -> void:
	var hb := HBoxContainer.new()
	hb.position = Vector2(12, 10)
	hb.add_theme_constant_override("separation", 12)
	ui.add_child(hb)
	sun_lbl = _mk_lbl(hb, "Sonne: 0", Color(1, 0.85, 0.3))
	fp_lbl = _mk_lbl(hb, "FP: 0", Color(0.4, 0.9, 0.9))
	coin_lbl = _mk_lbl(hb, "Muenzen: 0", Color(1, 0.82, 0.35))
	brain_lbl = _mk_lbl(hb, "Gehirne: 0", Color(0.88, 0.68, 1))
	_nav(hb, "Labor", _open_lab)
	_nav(hb, "Wiedergeburt", _open_pres)
	_nav(hb, "Almanach", _open_alm)
	_nav(hb, "Zombie-Buch", _open_zom)
	_nav(hb, "Laden", _open_shop)
	var st := HBoxContainer.new()
	st.position = Vector2(12, 40)
	ui.add_child(st)
	status_lbl = _mk_lbl(st, "Welle 0", Color(0.8, 0.95, 0.8))

func _mk_lbl(parent, text: String, col := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)
	return l

func _nav(parent, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)

# Nav-Handler
func _open_lab() -> void: open_overlay("lab")
func _open_pres() -> void: open_overlay("prestige")
func _open_alm() -> void:
	if Game.has("u_almanac"): open_overlay("almanac")
func _open_zom() -> void:
	if Game.has("u_zombiebook"): open_overlay("zombiebook")
func _open_shop() -> void: open_overlay("shop")

# ================= LINKE PFLANZEN-LEISTE =================
func _build_left() -> void:
	seed_box = VBoxContainer.new()
	seed_box.position = Vector2(8, 74)
	seed_box.add_theme_constant_override("separation", 5)
	ui.add_child(seed_box)

func refresh_seeds() -> void:
	for c in seed_box.get_children():
		c.queue_free()
	var faust := Button.new()
	faust.text = "Faust (Klick)"
	faust.custom_minimum_size = Vector2(122, 0)
	faust.pressed.connect(_select.bind(""))
	seed_box.add_child(faust)
	for ck in Game.CH_ORDER:
		if not Game.has(ck): continue
		var s = Game.compute_chassis_stats(ck)
		var b := Button.new()
		b.text = "%s\n(Sonne %d)" % [Game.CHASSIS[ck].n, int(s.cost)]
		b.custom_minimum_size = Vector2(122, 0)
		b.pressed.connect(_select.bind(ck))
		seed_box.add_child(b)
	if Game.has("u_shovel"):
		var sh := Button.new()
		sh.text = "Schaufel"
		sh.custom_minimum_size = Vector2(122, 0)
		sh.pressed.connect(_toggle_shovel)
		seed_box.add_child(sh)

func _select(key: String) -> void:
	Game.selected = key
	Game.shovel = false

func _toggle_shovel() -> void:
	Game.shovel = not Game.shovel
	Game.selected = ""

# ================= WELLEN-BUTTON =================
func _build_wave_btn() -> void:
	wave_btn = Button.new()
	wave_btn.position = Vector2(Game.LAWN_X + 250, 40)
	wave_btn.custom_minimum_size = Vector2(230, 40)
	wave_btn.add_theme_font_size_override("font_size", 18)
	wave_btn.pressed.connect(_on_wave)
	ui.add_child(wave_btn)

func _on_wave() -> void:
	if Game.phase == "won": lawn.reset_run()
	else: lawn.start_wave()

# ================= HUD-REFRESH =================
func refresh_top() -> void:
	sun_lbl.text = "Sonne: %d" % int(Game.sun)
	fp_lbl.text = "FP: %d" % Game.fp
	coin_lbl.text = "Muenzen: %d" % Game.coins
	brain_lbl.text = "Gehirne: %d" % Game.brains
	var wname: String = lawn.world_of(Game.wave).name
	var sel := "Faust"
	if Game.shovel: sel = "Schaufel"
	elif Game.selected != "" and Game.has(Game.selected): sel = Game.CHASSIS[Game.selected].n
	var m := lawn.msg if lawn.msg_t > 0 else ""
	status_lbl.text = "Welle %d/100  [%s]   |   Gewaehlt: %s   |   %s" % [Game.wave, wname, sel, m]
	if Game.phase == "won":
		wave_btn.text = "GEWONNEN! Neuer Run"; wave_btn.disabled = false
	elif Game.phase == "fight":
		wave_btn.text = "Welle %d laeuft..." % Game.wave; wave_btn.disabled = true
	else:
		wave_btn.text = "Welle %d starten" % (Game.wave + 1); wave_btn.disabled = false

# ================= OVERLAYS =================
func _make_overlay(n: String) -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	ui.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.06, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 54
	scroll.offset_left = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)
	var close := Button.new()
	close.text = "X  Schliessen"
	close.position = Vector2(14, 12)
	close.pressed.connect(close_all)
	panel.add_child(close)
	overlays[n] = {"panel": panel, "content": vb}

func open_overlay(n: String) -> void:
	for k in overlays: overlays[k].panel.visible = (k == n)
	Game.paused = true
	_build_overlay_content(n)

func close_all() -> void:
	for k in overlays: overlays[k].panel.visible = false
	Game.paused = false
	refresh_seeds()

func _post_buy(n: String) -> void:
	_build_overlay_content(n)
	refresh_top()
	refresh_seeds()

func _build_overlay_content(n: String) -> void:
	var vb = overlays[n].content
	for c in vb.get_children(): c.queue_free()
	match n:
		"lab": _build_lab(vb)
		"prestige": _build_prestige(vb)
		"almanac": _build_almanac(vb)
		"zombiebook": _build_zombiebook(vb)
		"shop": _build_shop(vb)

# ---- Bau-Helfer ----
func _header(parent, text: String, col := Color(0.6, 0.9, 0.7)) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", 15)
	parent.add_child(l)

func _grid(parent, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	return g

func _card(grid, title: String, desc: String, btn_text: String, enabled: bool, cb: Callable) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(172, 0)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	var v := VBoxContainer.new()
	var t := Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 14)
	v.add_child(t)
	var d := Label.new(); d.text = desc; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(150, 0); d.modulate = Color(0.72, 0.82, 0.74)
	d.add_theme_font_size_override("font_size", 11)
	v.add_child(d)
	if btn_text != "":
		var b := Button.new(); b.text = btn_text; b.disabled = not enabled
		if cb.is_valid(): b.pressed.connect(cb)
		v.add_child(b)
	m.add_child(v); pc.add_child(m); grid.add_child(pc)

# ---- Kauf-Handler ----
func _buy_res(key: String) -> void:
	if Game.buy_research(key): _post_buy("lab")
func _buy_chassis(key: String) -> void:
	if Game.buy_chassis(key): _post_buy("lab")
func _buy_equip(key: String) -> void:
	if Game.buy_equip(key): _post_buy("lab")
func _buy_mut(key: String) -> void:
	if Game.buy_mut(key): _post_buy("lab")
func _buy_pres(key: String) -> void:
	if Game.buy_prestige(key): _post_buy("prestige")
func _zlab(key: String, d: int) -> void:
	Game.zlab_change(key, d); _post_buy("lab")
func _buy_item(key: String) -> void:
	var c := int(Game.SHOP_ITEMS[key].cost)
	if Game.coins >= c:
		Game.coins -= c; lawn.item(key); _post_buy("shop")
func _buy_pass(key: String) -> void:
	if Game.buy_pass(key): _post_buy("shop")

# ---- LABOR ----
func _build_lab(vb) -> void:
	_header(vb, "WISSENSCHAFT  —  Upgrades (unendlich levelbar)", Color(0.4, 0.9, 0.9))
	var g1 := _grid(vb, 3)
	for k in Game.RES_ORDER:
		var r = Game.RESEARCH[k]
		var lv := Game.res_lvl(k)
		var c := Game.res_cost(k)
		var eff := ("+%d%%" % int(r.per * 100 * lv)) if r.kind == "pct" else ("+%d" % int(r.per * lv))
		_card(g1, "%s  St.%d" % [r.n, lv], "%s  (%s)" % [r.d, eff], "FP %d" % c, Game.fp >= c, _buy_res.bind(k))
	_header(vb, "PFLANZEN freischalten", Color(0.5, 0.9, 0.55))
	var g2 := _grid(vb, 3)
	for k in Game.CH_ORDER:
		if k == "sonne": continue
		var c = Game.CHASSIS[k]
		if Game.has(k):
			_card(g2, "* " + c.n, c.d, "", false, Callable())
		else:
			var ok := Game.chassis_req_ok(k)
			var sub: String = c.d if ok else ("Braucht: " + Game.CHASSIS[c.req].n)
			_card(g2, c.n, sub, "FP %d" % int(c.fp), ok and Game.fp >= int(c.fp), _buy_chassis.bind(k))
	_header(vb, "AUSRUESTUNG", Color(0.55, 0.7, 1))
	var g3 := _grid(vb, 3)
	for k in Game.EQ_ORDER:
		var e = Game.EQUIP[k]
		if Game.has(k):
			_card(g3, "* " + e.n, e.d, "", false, Callable())
		else:
			var ok := Game.equip_req_ok(k)
			var sub: String = e.d if ok else ("Braucht: " + Game.EQUIP[e.req].n)
			_card(g3, e.n, sub, "FP %d" % int(e.fp), ok and Game.fp >= int(e.fp), _buy_equip.bind(k))
	_header(vb, "MUTATIONEN  (Feuer/Eis/Gift/Elektro fuer alle Angreifer)", Color(1, 0.6, 0.6))
	var g4 := _grid(vb, 4)
	for k in Game.MUT_ORDER:
		var m = Game.MUT[k]
		if Game.has(k):
			_card(g4, "* " + m.n, m.d, "", false, Callable())
		else:
			_card(g4, m.n, m.d, "FP %d" % int(m.fp), Game.fp >= int(m.fp), _buy_mut.bind(k))
	_header(vb, "ZOMBIE-LABOR  (hoeheres Risiko = mehr Belohnung)", Color(1, 0.55, 0.55))
	var zc := VBoxContainer.new(); vb.add_child(zc)
	for pair in [["str", "Staerke (HP + Schaden)"], ["arm", "Ruestung (Zaehigkeit)"], ["spd", "Geschwindigkeit"]]:
		var key: String = pair[0]
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8)
		var l := Label.new(); l.text = "%s  —  St.%d/10" % [pair[1], int(Game.zlab.get(key, 0))]
		l.custom_minimum_size = Vector2(300, 0)
		var minus := Button.new(); minus.text = " - "; minus.pressed.connect(_zlab.bind(key, -1))
		var plus := Button.new(); plus.text = " + "; plus.pressed.connect(_zlab.bind(key, 1))
		hb.add_child(l); hb.add_child(minus); hb.add_child(plus); zc.add_child(hb)
	var rl := Label.new()
	rl.text = "Risiko-Stufe %d / 30   ->   +%d%% auf FP, Muenzen & Gehirne" % [Game.risk_level(), int((Game.reward_mul() - 1) * 100)]
	rl.modulate = Color(1, 0.7, 0.4)
	zc.add_child(rl)

# ---- WIEDERGEBURT ----
func _build_prestige(vb) -> void:
	_header(vb, "WIEDERGEBURT  —  Gehirne: %d  (bleiben dauerhaft)" % Game.brains, Color(0.88, 0.68, 1))
	var g := _grid(vb, 3)
	for k in Game.PRES_ORDER:
		var p = Game.PRESTIGE[k]
		var lv := Game.pres_lvl(k)
		if Game.pres_max(k):
			_card(g, "%s  (MAX)" % p.n, p.d, "", false, Callable())
		else:
			var c := Game.pres_cost(k)
			_card(g, "%s  St.%d/%d" % [p.n, lv, int(p.max)], p.d, "Gehirn %d" % c, Game.brains >= c, _buy_pres.bind(k))

# ---- ALMANACH ----
func _build_almanac(vb) -> void:
	_header(vb, "ALMANACH  —  deine Pflanzen", Color(0.5, 0.9, 0.55))
	var g := _grid(vb, 3)
	for ck in Game.CH_ORDER:
		var c = Game.CHASSIS[ck]
		if Game.has(ck):
			var s = Game.compute_chassis_stats(ck)
			_card(g, c.n, "%s\nSonne %d  HP %d" % [c.d, int(s.cost), int(s.hp)], "", false, Callable())
		else:
			_card(g, "???", "Noch nicht freigeschaltet", "", false, Callable())

# ---- ZOMBIE-BUCH ----
func _build_zombiebook(vb) -> void:
	_header(vb, "ZOMBIE-BUCH", Color(1, 0.6, 0.6))
	var g := _grid(vb, 3)
	for zk in Game.ZTYPES:
		var z = Game.ZTYPES[zk]
		if Game.seen.has(zk):
			var extra := ""
			if z.get("boss", false): extra = "  BOSS (Gehirne!)"
			elif z.get("vault", false): extra = "  springt"
			_card(g, z.n, "HP %d  Schaden %d%s" % [int(z.hp), int(z.dmg), extra], "", false, Callable())
		else:
			_card(g, "???", "Noch nicht begegnet", "", false, Callable())

# ---- LADEN ----
func _build_shop(vb) -> void:
	_header(vb, "LADEN  —  Muenzen: %d  (nur fuer diesen Run)" % Game.coins, Color(1, 0.82, 0.35))
	_header(vb, "Items (sofort)", Color(1, 0.82, 0.35))
	var g1 := _grid(vb, 3)
	for k in Game.SHOP_ITEM_ORDER:
		var it = Game.SHOP_ITEMS[k]
		_card(g1, it.n, it.d, "Muenze %d" % int(it.cost), Game.coins >= int(it.cost), _buy_item.bind(k))
	_header(vb, "Passive (ganzer Run)", Color(1, 0.82, 0.35))
	var g2 := _grid(vb, 3)
	for k in Game.SHOP_PASS_ORDER:
		var p = Game.SHOP_PASS[k]
		var c := Game.pass_cost(k)
		_card(g2, "%s  St.%d" % [p.n, int(Game.run_shop.get(k, 0))], p.d, "Muenze %d" % c, Game.coins >= c, _buy_pass.bind(k))
