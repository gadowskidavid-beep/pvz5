extends Node2D
# Baut die komplette UI (in Code) mit Theme + Overlays + verwaltet den Rasen (Lawn).

var lawn
var ui: CanvasLayer
var root: Control        # Theme-Wurzel, alle Controls haengen hier drunter
var sun_lbl: Label
var fp_lbl: Label
var coin_lbl: Label
var brain_lbl: Label
var status_lbl: Label
var wave_lbl: Label
var seed_box: VBoxContainer
var wave_btn: Button
var overlays := {}       # name -> {"panel":Panel, "content":VBoxContainer, "close":Button}
var _nav_return := ""     # Overlay, zu dem "Zurueck" springt (sonst Spiel)
var _death_open := false  # ist der Todes-Screen bereits offen?
var _tree_sel := "sonne"  # welche Pflanze ist im Skill-Tree gewaehlt
var _tree_px := {}        # node_id -> Vector2 (Zentrum) fuer die aktuelle Baum-Leinwand
var _tree_ck := ""        # welche Pflanze wird gerade gezeichnet

const SCREEN_W := 1152
const SCREEN_H := 648

# ================= FARBEN =================
const COL_BG := Color(0.07, 0.11, 0.09)
const COL_ACCENT := Color(0.45, 0.85, 0.5)
const COL_GOLD := Color(1, 0.82, 0.35)
const COL_PURPLE := Color(0.85, 0.66, 1)
const COL_CYAN := Color(0.4, 0.9, 0.9)

func _ready() -> void:
	lawn = Node2D.new()
	lawn.set_script(load("res://scripts/Lawn.gd"))
	add_child(lawn)
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # Klicks zum Rasen durchlassen
	root.theme = _make_theme()
	ui.add_child(root)
	_build_topbar()
	_build_left()
	_build_wave_btn()
	for n in ["lab", "prestige", "almanac", "zombiebook", "shop", "menu", "death", "options", "dev"]:
		_make_overlay(n)
	refresh_seeds()
	open_overlay("menu")

func _process(_delta: float) -> void:
	refresh_top()
	if Game.phase == "dead":
		if not _death_open:
			_death_open = true
			open_overlay("death")
	else:
		_death_open = false

# ================= THEME =================
func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 15
	th.set_stylebox("normal", "Button", _sb(Color(0.16, 0.29, 0.23), Color(0.32, 0.55, 0.42), 2, 8))
	th.set_stylebox("hover", "Button", _sb(Color(0.23, 0.40, 0.31), Color(0.5, 0.8, 0.58), 2, 8))
	th.set_stylebox("pressed", "Button", _sb(Color(0.30, 0.52, 0.36), Color(0.6, 0.95, 0.65), 2, 8))
	th.set_stylebox("disabled", "Button", _sb(Color(0.13, 0.16, 0.15), Color(0.2, 0.25, 0.22), 1, 8))
	th.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), Color(0.6, 0.9, 0.65), 1, 8))
	th.set_color("font_color", "Button", Color(0.9, 0.98, 0.9))
	th.set_color("font_hover_color", "Button", Color(1, 1, 1))
	th.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.52))
	th.set_stylebox("panel", "Panel", _sb(Color(0.05, 0.09, 0.07, 0.99), Color(0.2, 0.4, 0.3), 0, 0))
	th.set_stylebox("panel", "PanelContainer", _sb(Color(0.11, 0.17, 0.14), Color(0.26, 0.44, 0.33), 1, 10))
	th.set_color("font_color", "Label", Color(0.92, 0.97, 0.92))
	return th

func _sb(bg: Color, border: Color, bw: int, radius: int, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

# ================= TOPBAR =================
func _build_topbar() -> void:
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 68
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.07, 0.06, 0.92), Color(0.2, 0.4, 0.3), 0, 0))
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.position = Vector2(14, 9)
	hb.add_theme_constant_override("separation", 14)
	root.add_child(hb)
	sun_lbl = _mk_lbl(hb, "Sonne: 0", COL_GOLD, 17)
	fp_lbl = _mk_lbl(hb, "FP: 0", COL_CYAN, 17)
	coin_lbl = _mk_lbl(hb, "Muenzen: 0", COL_GOLD, 17)
	brain_lbl = _mk_lbl(hb, "Gehirne: 0", COL_PURPLE, 17)
	var nav := HBoxContainer.new()
	nav.position = Vector2(14, 37)
	nav.add_theme_constant_override("separation", 6)
	root.add_child(nav)
	_nav(nav, "Labor", _open_lab)
	_nav(nav, "Almanach", _open_alm)
	_nav(nav, "Zombie-Buch", _open_zom)
	_nav(nav, "Laden", _open_shop)
	_nav(nav, "Menue", _open_menu)
	_nav(nav, "Dev", _open_dev)
	wave_lbl = Label.new()
	wave_lbl.text = "WELLE 0 / 100"
	wave_lbl.modulate = Color(0.98, 0.95, 0.7)
	wave_lbl.add_theme_font_size_override("font_size", 24)
	wave_lbl.position = Vector2(SCREEN_W - 400, 16)
	root.add_child(wave_lbl)
	status_lbl = Label.new()
	status_lbl.modulate = Color(0.8, 0.95, 0.8)
	status_lbl.add_theme_font_size_override("font_size", 15)
	status_lbl.position = Vector2(SCREEN_W - 470, 44)
	root.add_child(status_lbl)

func _mk_lbl(parent, text: String, col := Color(1, 1, 1), size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

func _nav(parent, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)

func _open_lab() -> void: open_overlay("lab")
func _open_alm() -> void: open_overlay("almanac")
func _open_zom() -> void: open_overlay("zombiebook")
func _open_shop() -> void: open_overlay("shop")
func _open_menu() -> void: open_overlay("menu")
func _open_dev() -> void: open_overlay("dev")

# ================= LINKE PFLANZEN-LEISTE =================
func _build_left() -> void:
	seed_box = VBoxContainer.new()
	seed_box.position = Vector2(8, 76)
	seed_box.add_theme_constant_override("separation", 5)
	root.add_child(seed_box)

func refresh_seeds() -> void:
	for c in seed_box.get_children():
		c.queue_free()
	var faust := Button.new()
	faust.text = "Faust (Klick)"
	faust.custom_minimum_size = Vector2(124, 0)
	faust.pressed.connect(_select.bind(""))
	seed_box.add_child(faust)
	for ck in Game.CH_ORDER:
		if not Game.has(ck): continue
		var s = Game.compute_chassis_stats(ck)
		var b := Button.new()
		b.text = "%s\n(Sonne %d)" % [Game.CHASSIS[ck].n, int(s.cost)]
		b.custom_minimum_size = Vector2(124, 0)
		b.pressed.connect(_select.bind(ck))
		seed_box.add_child(b)
	if Game.has("u_shovel"):
		var sh := Button.new()
		sh.text = "Schaufel"
		sh.custom_minimum_size = Vector2(124, 0)
		sh.pressed.connect(_toggle_shovel)
		seed_box.add_child(sh)

func _select(key: String) -> void:
	Game.selected = key
	Game.shovel = false

func _toggle_shovel() -> void:
	Game.shovel = not Game.shovel
	Game.selected = ""

# ================= WELLEN-BUTTON (unten rechts, Akzentfarbe) =================
func _build_wave_btn() -> void:
	wave_btn = Button.new()
	wave_btn.custom_minimum_size = Vector2(168, 56)
	wave_btn.position = Vector2(SCREEN_W - 188, SCREEN_H - 76)
	wave_btn.add_theme_font_size_override("font_size", 24)
	wave_btn.add_theme_stylebox_override("normal", _sb(Color(0.85, 0.55, 0.15), Color(1, 0.82, 0.4), 2, 10, 10))
	wave_btn.add_theme_stylebox_override("hover", _sb(Color(0.96, 0.66, 0.2), Color(1, 0.92, 0.5), 2, 10, 10))
	wave_btn.add_theme_stylebox_override("pressed", _sb(Color(0.7, 0.45, 0.1), Color(1, 0.82, 0.4), 2, 10, 10))
	wave_btn.add_theme_stylebox_override("disabled", _sb(Color(0.28, 0.27, 0.2), Color(0.4, 0.38, 0.3), 1, 10, 10))
	wave_btn.add_theme_color_override("font_color", Color(0.15, 0.09, 0.02))
	wave_btn.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0))
	wave_btn.pressed.connect(_on_wave)
	root.add_child(wave_btn)

func _on_wave() -> void:
	if Game.phase == "won": lawn.reset_run()
	else: lawn.start_wave()

# ================= HUD-REFRESH =================
func refresh_top() -> void:
	sun_lbl.text = "Sonne: %d" % int(Game.sun)
	fp_lbl.text = "FP: %d" % Game.fp
	coin_lbl.text = "Muenzen: %d" % Game.coins
	brain_lbl.text = "Gehirne: %d" % Game.brains
	var wn: String = str(lawn.world_of(Game.wave).name)
	wave_lbl.text = "WELLE %d / 100  —  %s" % [Game.wave, wn]
	var sel_name: String = "Faust"
	if Game.shovel:
		sel_name = "Schaufel"
	elif Game.selected != "" and Game.has(Game.selected):
		sel_name = str(Game.CHASSIS[Game.selected].n)
	var m: String = ""
	if lawn.msg_t > 0:
		m = str(lawn.msg)
	status_lbl.text = "Gewaehlt: %s     %s" % [sel_name, m]
	if Game.phase == "won":
		wave_btn.visible = true; wave_btn.disabled = false; wave_btn.text = "Neuer Run"
	elif Game.phase == "fight":
		wave_btn.visible = true; wave_btn.disabled = true; wave_btn.text = "..."
	elif Game.phase == "dead":
		wave_btn.visible = false
	else:
		wave_btn.visible = true; wave_btn.disabled = false; wave_btn.text = "START"

# ================= OVERLAYS =================
func _make_overlay(n: String) -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 58
	scroll.offset_left = 20
	scroll.offset_right = -20
	scroll.offset_bottom = -20
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)
	var close := Button.new()
	close.text = "X  Schliessen"
	close.position = Vector2(16, 14)
	close.custom_minimum_size = Vector2(140, 34)
	close.pressed.connect(close_all)
	panel.add_child(close)
	overlays[n] = {"panel": panel, "content": vb, "close": close}

func open_overlay(n: String, return_to := "") -> void:
	_nav_return = return_to
	for k in overlays: overlays[k].panel.visible = (k == n)
	Game.paused = true
	_customize_close(n)
	_build_overlay_content(n)

func _customize_close(n: String) -> void:
	var cb: Button = overlays[n].close
	if n == "death":
		cb.visible = false
	elif n == "menu":
		cb.visible = true; cb.text = "> Spielen"
	elif _nav_return != "":
		cb.visible = true; cb.text = "< Zurueck"
	else:
		cb.visible = true; cb.text = "X  Schliessen"

func close_all() -> void:
	if _nav_return != "":
		var r: String = _nav_return
		_nav_return = ""
		open_overlay(r)
		return
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
		"menu": _build_menu(vb)
		"death": _build_death(vb)
		"options": _build_options(vb)
		"dev": _build_dev(vb)

# ---- Bau-Helfer ----
func _header(parent, text: String, col := Color(0.6, 0.9, 0.7)) -> void:
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 4); parent.add_child(sp)
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)

func _big(parent, text: String, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)

func _spacer(parent, h: int) -> void:
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, h); parent.add_child(sp)

func _menu_btn(parent, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	parent.add_child(b)

func _grid(parent, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	return g

func _card(grid, title: String, desc: String, btn_text: String, enabled: bool, cb: Callable) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(176, 0)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	var v := VBoxContainer.new()
	var t := Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 14)
	t.modulate = Color(0.95, 1, 0.9)
	v.add_child(t)
	var d := Label.new(); d.text = desc; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(154, 0); d.modulate = Color(0.72, 0.82, 0.74)
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
func _pick_tree(ck: String) -> void:
	_tree_sel = ck
	_build_overlay_content("lab")
func _buy_pt(ck: String, node: String) -> void:
	if Game.buy_pt(ck, node): _post_buy("lab")

# ---- Visueller Skill-Baum (Karten-Knoten + Pfade + Aeste) ----
func _build_tree_canvas(parent, ck: String) -> void:
	var tree = BAL.PLANT_TREES.get(ck, {})
	var nodes = tree.get("nodes", {})
	var minc := 0.0
	var maxc := 0.0
	var maxr := 0.0
	for id in nodes:
		var p = nodes[id].pos
		minc = min(minc, p.x); maxc = max(maxc, p.x); maxr = max(maxr, p.y)
	var sx := 190.0
	var sy := 124.0
	var width := (maxc - minc) * sx + 340.0
	var height := maxr * sy + 200.0
	var ox := -minc * sx + 170.0
	var oy := height - 100.0
	_tree_px = {}
	for id in nodes:
		var pp = nodes[id].pos
		_tree_px[id] = Vector2(ox + pp.x * sx, oy - pp.y * sy)
	_tree_ck = ck
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(width, height)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_tree.bind(canvas))
	parent.add_child(canvas)
	# Ast-Labels unten
	for br in tree.get("branches", []):
		var lb := Label.new(); lb.text = "Ast: " + str(br[1]); lb.modulate = Color(0.55, 0.62, 0.58)
		lb.add_theme_font_size_override("font_size", 12)
		lb.position = Vector2(ox + float(br[0]) * sx - 34, oy + 46)
		canvas.add_child(lb)
	# Knoten
	for id in nodes:
		var nd = nodes[id]
		var center: Vector2 = _tree_px[id]
		var rare := bool(nd.get("rare", false))
		if id == "root":
			_tree_node(canvas, center, str(nd.n), "Freigeschaltet", 0, false, "root", Callable())
		else:
			var cost := int(nd.cost)
			var owned := Game.pt_owned(ck, id)
			var can := Game.pt_can(ck, id)
			var state := "lock"
			var cb := Callable()
			if owned: state = "legend_owned" if rare else "owned"
			elif can and Game.fp >= cost:
				state = "legend_avail" if rare else "avail"
				cb = _buy_pt.bind(ck, id)
			elif can: state = "legend_lock" if rare else "need"
			else: state = "legend_lock" if rare else "lock"
			_tree_node(canvas, center, str(nd.n), str(nd.d), cost, not owned, state, cb)
	canvas.queue_redraw()

func _tree_node(canvas, center: Vector2, title: String, subtitle: String, cost: int, show_cost: bool, state: String, cb: Callable) -> void:
	var w := 160.0
	var h := 62.0
	var holder := Control.new()
	holder.size = Vector2(w, h)
	holder.position = center - Vector2(w / 2.0, h / 2.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(holder)
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_tree_node(btn, state)
	btn.tooltip_text = "%s\n%s" % [title, subtitle]
	if cb.is_valid(): btn.pressed.connect(cb)
	else: btn.disabled = true
	holder.add_child(btn)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	var t := Label.new(); t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_size_override("font_size", 13); t.modulate = Color(0.96, 0.99, 0.96)
	box.add_child(t)
	var stl := Label.new(); stl.text = subtitle
	stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stl.add_theme_font_size_override("font_size", 10); stl.modulate = _node_sub_col(state)
	stl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; stl.custom_minimum_size = Vector2(w - 10, 0)
	box.add_child(stl)
	holder.add_child(box)
	if show_cost:
		var pill := Label.new(); pill.text = "%d FP" % cost
		pill.add_theme_font_size_override("font_size", 12); pill.modulate = Color(1, 0.96, 0.82)
		pill.add_theme_stylebox_override("normal", _sb(_pill_bg(state), _pill_bd(state), 1, 9, 4))
		pill.position = Vector2(w / 2.0 - 30, -22)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pill)

func _node_sub_col(state: String) -> Color:
	if state.begins_with("legend"): return Color(0.82, 0.62, 1)
	if state == "owned" or state == "root": return Color(0.6, 0.9, 0.68)
	if state == "avail": return Color(0.92, 0.84, 0.5)
	return Color(0.6, 0.66, 0.7)

func _pill_bg(state: String) -> Color:
	if state.begins_with("legend"): return Color(0.25, 0.15, 0.35)
	if state == "avail": return Color(0.35, 0.28, 0.1)
	return Color(0.15, 0.16, 0.18)

func _pill_bd(state: String) -> Color:
	if state.begins_with("legend"): return Color(0.8, 0.55, 1)
	if state == "avail": return Color(1, 0.82, 0.4)
	return Color(0.4, 0.42, 0.46)

func _style_tree_node(b: Button, state: String) -> void:
	var bg := Color(0.12, 0.13, 0.16)
	var bd := Color(0.3, 0.34, 0.4)
	if state == "owned": bg = Color(0.13, 0.32, 0.2); bd = Color(0.42, 0.9, 0.56)
	elif state == "root": bg = Color(0.12, 0.3, 0.2); bd = Color(0.45, 0.9, 0.6)
	elif state == "avail": bg = Color(0.17, 0.17, 0.13); bd = Color(1, 0.82, 0.35)
	elif state == "need": bg = Color(0.15, 0.15, 0.14); bd = Color(0.55, 0.5, 0.32)
	elif state == "lock": bg = Color(0.11, 0.12, 0.14); bd = Color(0.28, 0.32, 0.38)
	elif state == "legend_owned": bg = Color(0.24, 0.14, 0.34); bd = Color(0.85, 0.55, 1)
	elif state == "legend_avail": bg = Color(0.2, 0.12, 0.3); bd = Color(0.8, 0.5, 1)
	elif state == "legend_lock": bg = Color(0.14, 0.1, 0.18); bd = Color(0.45, 0.35, 0.55)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _sb(bg, bd, 2, 9, 6))

func _draw_tree(canvas) -> void:
	if _tree_ck == "": return
	var nodes = Game.tree_nodes(_tree_ck)
	for id in nodes:
		var req := str(nodes[id].get("req", ""))
		if req == "" or not _tree_px.has(id) or not _tree_px.has(req): continue
		var a: Vector2 = _tree_px[req]
		var bp: Vector2 = _tree_px[id]
		if Game.pt_owned(_tree_ck, id):
			canvas.draw_line(a, bp, Color(0.42, 0.9, 0.55, 0.9), 5.0)
		elif Game.pt_can(_tree_ck, id):
			canvas.draw_line(a, bp, Color(1, 0.82, 0.4, 0.8), 4.0)
		else:
			canvas.draw_dashed_line(a, bp, Color(0.5, 0.55, 0.6, 0.5), 3.0, 9.0)
func _buy_lure() -> void:
	if Game.buy_lure(): _post_buy("lab")
func _buy_pres(key: String) -> void:
	if Game.buy_prestige(key):
		if overlays["death"].panel.visible: _post_buy("death")
		else: _post_buy("prestige")
func _zlab(key: String, d: int) -> void:
	Game.zlab_change(key, d); _post_buy("lab")
func _buy_item(key: String) -> void:
	var c := int(Game.SHOP_ITEMS[key].cost)
	if Game.coins >= c:
		Game.coins -= c; lawn.item(key); _post_buy("shop")
func _buy_pass(key: String) -> void:
	if Game.buy_pass(key): _post_buy("shop")

# ---- STARTMENUE ----
func _build_menu(vb) -> void:
	_spacer(vb, 10)
	_big(vb, "BOTANIK - LABOR", 44, COL_ACCENT)
	_big(vb, "Ein idle Pflanzen-vs-Zombies Labor.  Ueberlebe bis Welle 100!", 15, Color(0.7, 0.85, 0.72))
	_spacer(vb, 16)
	_menu_btn(vb, "> Abenteuer starten", close_all)
	_menu_btn(vb, "Almanach (Pflanzen)", _menu_open_alm)
	_menu_btn(vb, "Zombie-Buch", _menu_open_zom)
	_menu_btn(vb, "Optionen", _menu_open_opt)
	_menu_btn(vb, "Entwickler-Menue (Regler & Cheats)", _menu_open_dev)
	_spacer(vb, 16)
	_big(vb, "Gehirne (dauerhaft): %d     Prestige-Stufen: %d" % [Game.brains, _pres_total()], 14, COL_PURPLE)
	_big(vb, "Tipp: Zwischen den Wellen kommen einzelne Zombies zum Farmen.", 13, Color(0.65, 0.8, 0.68))

func _menu_open_alm() -> void: open_overlay("almanac", "menu")
func _menu_open_zom() -> void: open_overlay("zombiebook", "menu")
func _menu_open_opt() -> void: open_overlay("options", "menu")
func _menu_open_dev() -> void: open_overlay("dev", "menu")

func _pres_total() -> int:
	var t := 0
	for k in Game.PRES_ORDER: t += Game.pres_lvl(k)
	return t

# ---- OPTIONEN ----
func _build_options(vb) -> void:
	_big(vb, "OPTIONEN", 28, Color(0.8, 0.9, 1))
	_header(vb, "Steuerung: Linksklick = Sonne sammeln / Pflanze setzen / Zombie schlagen (Faust).", Color(0.75, 0.85, 0.78))
	_header(vb, "Leertaste = Welle starten.", Color(0.75, 0.85, 0.78))
	_spacer(vb, 12)
	_header(vb, "Gehirne & Prestige zuruecksetzen (kann nicht rueckgaengig gemacht werden):", Color(1, 0.6, 0.6))
	var b := Button.new()
	b.text = "Kompletten Fortschritt loeschen"
	b.custom_minimum_size = Vector2(320, 40)
	b.pressed.connect(_reset_progress)
	vb.add_child(b)

func _reset_progress() -> void:
	Game.brains = 0
	Game.prestige = {}
	Game.zlab = {"str": 0, "arm": 0, "spd": 0}
	Game.carry_coins = 0
	Game.seen = {}
	Game.save_game()
	lawn.reset_run()
	_build_overlay_content("options")
	refresh_seeds()

# ---- ENTWICKLER-MENUE (Regler & Cheats) ----
func _build_dev(vb) -> void:
	_big(vb, "ENTWICKLER-MENUE", 30, Color(1, 0.75, 0.4))
	_big(vb, "Regler zum Ausprobieren. (Nur fuer dich - kommt spaeter wieder raus.)", 13, Color(0.75, 0.8, 0.7))
	_spacer(vb, 8)
	_header(vb, "REGLER", COL_CYAN)
	_dev_slider(vb, "Spielgeschwindigkeit", 0.25, 4.0, 0.25, Engine.time_scale, "speed")
	_dev_slider(vb, "Sonne", 0, 3000, 25, float(Game.sun), "sun")
	_dev_slider(vb, "Forschungspunkte (FP)", 0, 20000, 100, float(Game.fp), "fp")
	_dev_slider(vb, "Muenzen", 0, 5000, 25, float(Game.coins), "coins")
	_dev_slider(vb, "Gehirne", 0, 999, 5, float(Game.brains), "brains")
	_dev_slider(vb, "Welle (Zaehler)", 0, 100, 1, float(Game.wave), "wave")
	_spacer(vb, 8)
	_header(vb, "CHEATS", Color(1, 0.6, 0.6))
	var god := CheckButton.new()
	god.text = "Gott-Modus (Rasen unverlierbar)"
	god.button_pressed = Game.god
	god.toggled.connect(_dev_god)
	vb.add_child(god)
	var g := _grid(vb, 3)
	_dev_button(g, "Alles freischalten", _dev_unlock_all)
	_dev_button(g, "Feld leeren (Zombies weg)", _dev_clear_field)
	_dev_button(g, "Welle sofort gewinnen", _dev_win)
	_dev_button(g, "Alle Zombies ins Buch", _dev_seen_all)
	_dev_button(g, "Tempo zuruecksetzen (1x)", _dev_speed_reset)

func _dev_button(parent, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(210, 40)
	b.pressed.connect(cb)
	parent.add_child(b)

func _dev_slider(parent, label: String, minv: float, maxv: float, step: float, cur: float, key: String) -> void:
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.custom_minimum_size = Vector2(320, 0)
	if key == "speed": l.text = "%s: %.2fx" % [label, cur]
	else: l.text = "%s: %d" % [label, int(cur)]
	var sl := HSlider.new()
	sl.min_value = minv; sl.max_value = maxv; sl.step = step; sl.value = cur
	sl.custom_minimum_size = Vector2(360, 24)
	sl.value_changed.connect(_dev_set.bind(key, l, label))
	hb.add_child(l); hb.add_child(sl); parent.add_child(hb)

func _dev_set(value: float, key: String, l: Label, label: String) -> void:
	match key:
		"speed":
			Engine.time_scale = value; l.text = "%s: %.2fx" % [label, value]
		"sun":
			Game.sun = int(value); l.text = "%s: %d" % [label, int(value)]
		"fp":
			Game.fp = int(value); l.text = "%s: %d" % [label, int(value)]
		"coins":
			Game.coins = int(value); l.text = "%s: %d" % [label, int(value)]
		"brains":
			Game.brains = int(value); l.text = "%s: %d" % [label, int(value)]
		"wave":
			Game.wave = int(value); l.text = "%s: %d" % [label, int(value)]

func _dev_god(pressed: bool) -> void:
	Game.god = pressed

func _dev_unlock_all() -> void:
	for k in Game.CH_ORDER: Game.unlocked[k] = true
	for k in Game.EQ_ORDER: Game.unlocked[k] = true
	# alle Pflanzen-Skill-Baeume komplett freischalten
	for ck in BAL.PLANT_TREES:
		if not Game.ptree.has(ck): Game.ptree[ck] = {}
		for node in Game.tree_nodes(ck):
			if node != "root": Game.ptree[ck][node] = true
	refresh_seeds(); _build_overlay_content("dev")

func _dev_seen_all() -> void:
	for zk in Game.ZTYPES: Game.seen[zk] = true

func _dev_clear_field() -> void:
	lawn.zombies.clear(); lawn.peas.clear()

func _dev_win() -> void:
	Game.phase = "won"

func _dev_speed_reset() -> void:
	Engine.time_scale = 1.0
	_build_overlay_content("dev")

# ---- TODES-SCREEN ----
func _build_death(vb) -> void:
	_spacer(vb, 8)
	_big(vb, "DU WURDEST UEBERRANNT!", 36, Color(1, 0.4, 0.4))
	_big(vb, "Es ist noch nicht vorbei. Du verlierst alle Skills dieses Runs,", 15, Color(0.9, 0.8, 0.8))
	_big(vb, "aber deine GEHIRNE bleiben - dafuer sind sie da!", 15, COL_PURPLE)
	_spacer(vb, 10)
	_build_prestige(vb)
	_spacer(vb, 14)
	var b := Button.new()
	b.text = "WIEDERGEBURT  -  Neuer Versuch"
	b.custom_minimum_size = Vector2(360, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(_do_rebirth)
	vb.add_child(b)

func _do_rebirth() -> void:
	_nav_return = ""
	for k in overlays: overlays[k].panel.visible = false
	Game.paused = false
	lawn.reset_run()
	refresh_seeds()

# ---- LABOR ----
func _build_lab(vb) -> void:
	# ===== KOPFZEILE: Titel + FP/Sonne-Pillen =====
	var hdr := HBoxContainer.new(); hdr.add_theme_constant_override("separation", 12)
	var title := Label.new(); title.text = "Skill Trees"; title.add_theme_font_size_override("font_size", 27); title.modulate = COL_ACCENT
	hdr.add_child(title)
	var hsp := Control.new(); hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hsp.custom_minimum_size = Vector2(160, 0)
	hdr.add_child(hsp)
	_pill(hdr, "%d FP" % Game.fp, COL_CYAN)
	_pill(hdr, "%d Sonne" % int(Game.sun), COL_GOLD)
	vb.add_child(hdr)
	# ===== TABS =====
	var tabs := _grid(vb, 7)
	for ck in Game.CH_ORDER:
		if Game.has(ck): _tab(tabs, Game.CHASSIS[ck].n, ck)
	_tab(tabs, "Spiel", "spiel")
	_tab(tabs, "Zombies", "zombies")
	# ===== INHALT je Tab =====
	if _tree_sel == "spiel": _build_general(vb); return
	if _tree_sel == "zombies": _build_ztab(vb); return
	if not Game.has(_tree_sel): _tree_sel = "sonne"
	var ck2: String = _tree_sel
	var owned := 0
	var total := 0
	for id in Game.tree_nodes(ck2):
		if id == "root": continue
		total += 1
		if Game.pt_owned(ck2, id): owned += 1
	var sub := HBoxContainer.new(); sub.add_theme_constant_override("separation", 10)
	var sl := Label.new()
	sl.text = "%s   ·   Stufe %d   ·   %d/%d Skills" % [Game.CHASSIS[ck2].n, owned, owned, total]
	sl.add_theme_font_size_override("font_size", 16); sl.modulate = Color(0.88, 0.97, 0.88)
	sub.add_child(sl)
	var ssp := Control.new(); ssp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sub.add_child(ssp)
	var hint := Label.new(); hint.text = "FP durch getötete Zombies"; hint.modulate = Color(0.58, 0.66, 0.6); hint.add_theme_font_size_override("font_size", 13)
	sub.add_child(hint)
	vb.add_child(sub)
	_build_tree_canvas(vb, ck2)

func _pill(parent, text: String, col: Color) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sb(Color(0.09, 0.13, 0.11), col, 1, 13, 6))
	var l := Label.new(); l.text = text; l.modulate = col; l.add_theme_font_size_override("font_size", 15)
	pc.add_child(l); parent.add_child(pc)

func _tab(parent, label: String, key: String) -> void:
	var b := Button.new(); b.text = label; b.custom_minimum_size = Vector2(120, 38)
	b.add_theme_font_size_override("font_size", 15)
	if _tree_sel == key:
		b.add_theme_stylebox_override("normal", _sb(Color(0.17, 0.4, 0.24), COL_ACCENT, 2, 8, 8))
		b.add_theme_color_override("font_color", Color(0.82, 1, 0.86))
	b.pressed.connect(_pick_tree.bind(key))
	parent.add_child(b)

func _build_general(vb) -> void:
	_header(vb, "SPIEL & AUSRUESTUNG", Color(0.7, 0.85, 1))
	_header(vb, "Pflanzen freischalten", Color(0.5, 0.9, 0.55))
	var g2 := _grid(vb, 3)
	for k in Game.CH_ORDER:
		if k == "sonne": continue
		var ch = Game.CHASSIS[k]
		if Game.has(k):
			_card(g2, "* " + ch.n, ch.d, "", false, Callable())
		else:
			var ok_c := Game.chassis_req_ok(k)
			var sub_c: String = ch.d if ok_c else ("Braucht: " + str(Game.CHASSIS[ch.req].n))
			_card(g2, ch.n, sub_c, "FP %d" % int(ch.fp), ok_c and Game.fp >= int(ch.fp), _buy_chassis.bind(k))
	_header(vb, "Ausruestung", Color(0.55, 0.7, 1))
	var g3 := _grid(vb, 3)
	for k in Game.EQ_ORDER:
		var e = Game.EQUIP[k]
		if Game.has(k):
			_card(g3, "* " + e.n, e.d, "", false, Callable())
		else:
			var ok_e := Game.equip_req_ok(k)
			var sub_e: String = e.d if ok_e else ("Braucht: " + str(Game.EQUIP[e.req].n))
			_card(g3, e.n, sub_e, "FP %d" % int(e.fp), ok_e and Game.fp >= int(e.fp), _buy_equip.bind(k))
	_header(vb, "Oekonomie", Color(0.8, 0.85, 0.6))
	var g1 := _grid(vb, 3)
	for k in Game.RES_ORDER:
		var r = Game.RESEARCH[k]
		var lv_r := Game.res_lvl(k)
		var c_r := Game.res_cost(k)
		var eff := ("+%d%%" % int(r.per * 100 * lv_r)) if r.kind == "pct" else ("+%d" % int(r.per * lv_r))
		_card(g1, "%s  St.%d" % [r.n, lv_r], "%s  (%s)" % [r.d, eff], "FP %d" % c_r, Game.fp >= c_r, _buy_res.bind(k))

func _build_ztab(vb) -> void:
	_header(vb, "ZOMBIES  —  Lockstoff (mehr Idle-Zombies zum Farmen)", Color(1, 0.55, 0.55))
	var zc := VBoxContainer.new(); vb.add_child(zc)
	var lure_hb := HBoxContainer.new(); lure_hb.add_theme_constant_override("separation", 8)
	var lure_l := Label.new()
	lure_l.text = "Lockstoff  —  Zombies zwischen Wellen: %d / 6" % Game.idle_cap()
	lure_l.custom_minimum_size = Vector2(360, 0)
	lure_hb.add_child(lure_l)
	var lure_b := Button.new()
	if Game.lure_max(): lure_b.text = "MAX"; lure_b.disabled = true
	else: lure_b.text = "FP %d" % Game.lure_cost(); lure_b.disabled = Game.fp < Game.lure_cost()
	lure_b.pressed.connect(_buy_lure)
	lure_hb.add_child(lure_b); zc.add_child(lure_hb)

# ---- WIEDERGEBURT / PRESTIGE-BAUM ----
func _build_prestige(vb) -> void:
	_header(vb, "GEHIRN-UPGRADES  —  Gehirne: %d  (bleiben dauerhaft)" % Game.brains, COL_PURPLE)
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
	_big(vb, "ALMANACH", 28, Color(0.5, 0.9, 0.55))
	_header(vb, "Deine Pflanzen", Color(0.5, 0.9, 0.55))
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
	_big(vb, "ZOMBIE-BUCH", 28, Color(1, 0.6, 0.6))
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
	_big(vb, "LADEN", 28, COL_GOLD)
	_header(vb, "Muenzen: %d  (nur fuer diesen Run)" % Game.coins, COL_GOLD)
	_header(vb, "Items (sofort)", COL_GOLD)
	var g1 := _grid(vb, 3)
	for k in Game.SHOP_ITEM_ORDER:
		var it = Game.SHOP_ITEMS[k]
		_card(g1, it.n, it.d, "Muenze %d" % int(it.cost), Game.coins >= int(it.cost), _buy_item.bind(k))
	_header(vb, "Passive (ganzer Run)", COL_GOLD)
	var g2 := _grid(vb, 3)
	for k in Game.SHOP_PASS_ORDER:
		var p = Game.SHOP_PASS[k]
		var c := Game.pass_cost(k)
		_card(g2, "%s  St.%d" % [p.n, int(Game.run_shop.get(k, 0))], p.d, "Muenze %d" % c, Game.coins >= c, _buy_pass.bind(k))
