extends Node2D
# ============================================================================
# UI-Aufbau (in Code) — modular, damit spaeter ein eigenes Design rein kann.
# Layout:
#   - Rasen (Lawn) laeuft IMMER sichtbar oben, wird NIE pausiert vom Skill-Panel.
#   - HUD oben: Waehrungs-Pills (links), Wellen-Balken + START (rechts).
#   - Untere Leiste: Pflanzen-Karten + Skill-Trees/Hammer/Schaufel + Pfeil.
#   - Skill-Trees als aufziehbarer DRAWER von unten (animiert, ohne Pause).
#   - Pausierende Overlays nur fuer Menue/Laden/Almanach/Buch/Dev/Tod.
# Zum Reskin: Tausche die _build_* / _tree_node / _sb Funktionen gegen dein Design.
# ============================================================================

var lawn
var ui: CanvasLayer
var root: Control

# HUD
var sun_lbl: Label
var fp_lbl: Label
var brain_lbl: Label
var wave_lbl: Label
var wave_bar: Control
var msg_lbl: Label
var wave_btn: Button
var seed_box: HBoxContainer

# Drawer (Skill-Trees)
var drawer: Control
var d_fp: Label
var d_tabs: HBoxContainer
var d_treewrap: ScrollContainer
var d_info: VBoxContainer
var drawer_open := false
var _dragging := false
var _drag_moved := false
var _dtween: Tween

# Pausierende Overlays
var overlays := {}
var _nav_return := ""
var _death_open := false

# Skill-Tree Zustand
var _tree_sel := "sonne"
var _tree_px := {}
var _tree_ck := ""
var info_ck := ""
var info_node := ""

const SCREEN_W := 1152
const SCREEN_H := 648
const DRAWER_H := 384

# ================= FARBEN (zentral -> leicht reskinnbar) =================
const COL_BG := Color(0.07, 0.11, 0.09)
const COL_ACCENT := Color(0.45, 0.85, 0.5)
const COL_GOLD := Color(1, 0.82, 0.35)
const COL_PURPLE := Color(0.85, 0.66, 1)
const COL_CYAN := Color(0.4, 0.9, 0.9)
const COL_PINK := Color(1, 0.5, 0.8)

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
	_build_hud()
	_build_bottom()
	_build_drawer()
	for n in ["prestige", "almanac", "zombiebook", "shop", "menu", "death", "options", "dev"]:
		_make_overlay(n)
	refresh_seeds()
	open_overlay("menu")

func _process(_delta: float) -> void:
	# HUD lebt jedes Frame (Spiel laeuft weiter, egal ob Drawer offen)
	sun_lbl.text = "Sonne  %d" % int(Game.sun)
	fp_lbl.text = "FP  %d" % Game.fp
	brain_lbl.text = "Gehirne  %d" % Game.brains
	wave_lbl.text = "Welle %d / 100" % Game.wave
	wave_bar.queue_redraw()
	if d_fp != null: d_fp.text = "%d FP" % Game.fp
	msg_lbl.text = str(lawn.msg) if lawn.msg_t > 0 else ""
	if Game.phase == "won":
		wave_btn.visible = true; wave_btn.disabled = false; wave_btn.text = "Neuer Run"
	elif Game.phase == "fight":
		wave_btn.visible = true; wave_btn.disabled = true; wave_btn.text = "Welle laeuft"
	elif Game.phase == "dead":
		wave_btn.visible = false
	else:
		wave_btn.visible = true; wave_btn.disabled = false; wave_btn.text = "START"
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

# ================= HUD (oben) =================
func _build_hud() -> void:
	# Waehrungs-Pills oben links
	var pills := HBoxContainer.new()
	pills.position = Vector2(14, 10)
	pills.add_theme_constant_override("separation", 8)
	root.add_child(pills)
	sun_lbl = _hud_pill(pills, COL_GOLD)
	fp_lbl = _hud_pill(pills, COL_CYAN)
	brain_lbl = _hud_pill(pills, COL_PINK)
	# kleine Navigation
	var nav := HBoxContainer.new()
	nav.position = Vector2(14, 46)
	nav.add_theme_constant_override("separation", 5)
	root.add_child(nav)
	_nav(nav, "Menue", _open_menu)
	_nav(nav, "Laden", _open_shop)
	_nav(nav, "Almanach", _open_alm)
	_nav(nav, "Buch", _open_zom)
	_nav(nav, "Dev", _open_dev)
	# Meldung mittig
	msg_lbl = Label.new()
	msg_lbl.position = Vector2(SCREEN_W / 2.0 - 200, 44)
	msg_lbl.custom_minimum_size = Vector2(400, 0)
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.modulate = Color(0.95, 0.95, 0.75)
	msg_lbl.add_theme_font_size_override("font_size", 16)
	root.add_child(msg_lbl)
	# Wellen-Anzeige oben rechts
	wave_lbl = Label.new()
	wave_lbl.text = "Welle 0 / 100"
	wave_lbl.position = Vector2(SCREEN_W - 336, 8)
	wave_lbl.add_theme_font_size_override("font_size", 18)
	wave_lbl.modulate = Color(0.95, 0.95, 0.7)
	root.add_child(wave_lbl)
	wave_bar = Control.new()
	wave_bar.position = Vector2(SCREEN_W - 336, 36)
	wave_bar.size = Vector2(322, 16)
	wave_bar.custom_minimum_size = Vector2(322, 16)
	wave_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_bar.draw.connect(_draw_wavebar.bind(wave_bar))
	root.add_child(wave_bar)
	# START-Button oben rechts (immer erreichbar, auch bei offenem Drawer)
	wave_btn = Button.new()
	wave_btn.custom_minimum_size = Vector2(150, 38)
	wave_btn.position = Vector2(SCREEN_W - 166, 58)
	wave_btn.add_theme_font_size_override("font_size", 18)
	wave_btn.add_theme_stylebox_override("normal", _sb(Color(0.85, 0.55, 0.15), Color(1, 0.82, 0.4), 2, 9, 8))
	wave_btn.add_theme_stylebox_override("hover", _sb(Color(0.96, 0.66, 0.2), Color(1, 0.92, 0.5), 2, 9, 8))
	wave_btn.add_theme_stylebox_override("pressed", _sb(Color(0.7, 0.45, 0.1), Color(1, 0.82, 0.4), 2, 9, 8))
	wave_btn.add_theme_stylebox_override("disabled", _sb(Color(0.28, 0.27, 0.2), Color(0.4, 0.38, 0.3), 1, 9, 8))
	wave_btn.add_theme_color_override("font_color", Color(0.15, 0.09, 0.02))
	wave_btn.pressed.connect(_on_wave)
	root.add_child(wave_btn)

func _hud_pill(parent, col: Color) -> Label:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.11, 0.1), col, 1, 12, 6))
	var l := Label.new(); l.text = "0"; l.modulate = col; l.add_theme_font_size_override("font_size", 16)
	pc.add_child(l); parent.add_child(pc)
	return l

func _nav(parent, text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.pressed.connect(cb)
	parent.add_child(b)

func _draw_wavebar(bar: Control) -> void:
	var w := bar.size.x
	var h := bar.size.y
	if w <= 1.0: return
	bar.draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.13, 0.16))
	var frac: float = clamp(float(Game.wave) / 100.0, 0.0, 1.0)
	bar.draw_rect(Rect2(0, 0, w * frac, h), Color(0.4, 0.82, 0.5))
	var nb := _next_boss()
	for m in [25, 50, 75, 100]:
		var x: float = w * float(m) / 100.0
		var c: Color = Color(1, 0.3, 0.3) if m == nb else Color(0.85, 0.8, 0.5)
		bar.draw_rect(Rect2(x - 2, -3, 4, h + 6), c)

func _next_boss() -> int:
	for m in [25, 50, 75, 100]:
		if Game.wave < m: return m
	return 100

# Nav-Handler
func _open_alm() -> void: open_overlay("almanac")
func _open_zom() -> void: open_overlay("zombiebook")
func _open_shop() -> void: open_overlay("shop")
func _open_menu() -> void: open_overlay("menu")
func _open_dev() -> void: open_overlay("dev")

# ================= UNTERE LEISTE =================
func _build_bottom() -> void:
	# Pflanzen-Karten links
	seed_box = HBoxContainer.new()
	seed_box.position = Vector2(12, SCREEN_H - 60)
	seed_box.add_theme_constant_override("separation", 6)
	root.add_child(seed_box)
	# Werkzeuge rechts
	var tools := HBoxContainer.new()
	tools.position = Vector2(SCREEN_W - 372, SCREEN_H - 58)
	tools.add_theme_constant_override("separation", 6)
	root.add_child(tools)
	var st := Button.new(); st.text = "Skill Trees"; st.custom_minimum_size = Vector2(130, 46)
	st.pressed.connect(_toggle_drawer); tools.add_child(st)
	var ham := Button.new(); ham.text = "Hammer"; ham.custom_minimum_size = Vector2(96, 46)
	ham.pressed.connect(_select.bind("")); tools.add_child(ham)
	var sho := Button.new(); sho.text = "Schaufel"; sho.custom_minimum_size = Vector2(96, 46)
	sho.pressed.connect(_toggle_shovel); tools.add_child(sho)
	# Pfeil zum Aufziehen (mittig unten)
	var arrow := Button.new(); arrow.text = "^  Skill Trees  ^"; arrow.custom_minimum_size = Vector2(190, 26)
	arrow.position = Vector2(SCREEN_W / 2.0 - 95, SCREEN_H - 90)
	arrow.add_theme_font_size_override("font_size", 13)
	arrow.pressed.connect(_toggle_drawer)
	root.add_child(arrow)

func refresh_seeds() -> void:
	for c in seed_box.get_children():
		c.queue_free()
	for ck in Game.CH_ORDER:
		var card := Button.new()
		card.custom_minimum_size = Vector2(104, 52)
		card.add_theme_font_size_override("font_size", 12)
		if Game.has(ck):
			var s = Game.compute_chassis_stats(ck)
			card.text = "%s\nSonne %d · Lv%d" % [Game.CHASSIS[ck].n, int(s.cost), _plant_level(ck)]
			card.pressed.connect(_select.bind(ck))
		else:
			card.text = "%s\n(gesperrt)" % Game.CHASSIS[ck].n
			card.disabled = true
		seed_box.add_child(card)

func _plant_level(ck: String) -> int:
	var n := 0
	for id in Game.tree_nodes(ck):
		if id != "root" and Game.pt_owned(ck, id): n += 1
	return n

func _select(key: String) -> void:
	Game.selected = key
	Game.shovel = false

func _toggle_shovel() -> void:
	Game.shovel = not Game.shovel
	Game.selected = ""

func _on_wave() -> void:
	if Game.phase == "won": lawn.reset_run()
	else: lawn.start_wave()

# ================= DRAWER (Skill-Trees, ohne Pause) =================
func _build_drawer() -> void:
	drawer = Control.new()
	drawer.size = Vector2(SCREEN_W, DRAWER_H)
	drawer.position = Vector2(0, SCREEN_H)   # geschlossen (unter dem Bildschirm)
	root.add_child(drawer)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.09, 0.08, 0.99), COL_ACCENT, 2, 0))
	drawer.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14; col.offset_right = -14; col.offset_top = 6; col.offset_bottom = -10
	col.add_theme_constant_override("separation", 6)
	drawer.add_child(col)
	# Griff-Leiste (ziehbar + tippen zum Schliessen)
	var grab := Panel.new()
	grab.custom_minimum_size = Vector2(0, 22)
	grab.add_theme_stylebox_override("panel", _sb(Color(0.15, 0.24, 0.19), Color(0.35, 0.6, 0.45), 0, 6))
	grab.mouse_filter = Control.MOUSE_FILTER_STOP
	grab.gui_input.connect(_grab_input)
	col.add_child(grab)
	# Kopfzeile
	var hrow := HBoxContainer.new(); hrow.add_theme_constant_override("separation", 10)
	var closeb := Button.new(); closeb.text = "v  Schliessen"; closeb.pressed.connect(_toggle_drawer)
	hrow.add_child(closeb)
	var ttl := Label.new(); ttl.text = "Skill Trees"; ttl.add_theme_font_size_override("font_size", 22); ttl.modulate = COL_ACCENT
	hrow.add_child(ttl)
	var hsp := Control.new(); hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hrow.add_child(hsp)
	d_fp = Label.new(); d_fp.text = "0 FP"; d_fp.modulate = COL_CYAN; d_fp.add_theme_font_size_override("font_size", 18)
	hrow.add_child(d_fp)
	col.add_child(hrow)
	# Tabs
	d_tabs = HBoxContainer.new(); d_tabs.add_theme_constant_override("separation", 6)
	col.add_child(d_tabs)
	# Body: Baum-Scroll (links) + Info (rechts)
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	d_treewrap = ScrollContainer.new()
	d_treewrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_treewrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(d_treewrap)
	var infopanel := PanelContainer.new()
	infopanel.custom_minimum_size = Vector2(300, 0)
	infopanel.add_theme_stylebox_override("panel", _sb(Color(0.09, 0.12, 0.11), Color(0.25, 0.4, 0.32), 1, 10))
	body.add_child(infopanel)
	d_info = VBoxContainer.new(); d_info.add_theme_constant_override("separation", 6)
	infopanel.add_child(d_info)

func _grab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true; _drag_moved = false
			if not drawer_open: _rebuild_drawer()
		else:
			_dragging = false
			if _drag_moved:
				var mid := float(SCREEN_H) - DRAWER_H * 0.5
				drawer_open = drawer.position.y < mid
				_animate_drawer()
			else:
				_toggle_drawer()
	elif event is InputEventMouseMotion and _dragging:
		_drag_moved = true
		drawer.position.y = clamp(drawer.position.y + event.relative.y, float(SCREEN_H - DRAWER_H), float(SCREEN_H))

func _toggle_drawer() -> void:
	drawer_open = not drawer_open
	if drawer_open: _rebuild_drawer()
	_animate_drawer()

func _animate_drawer() -> void:
	var ty := float(SCREEN_H - DRAWER_H) if drawer_open else float(SCREEN_H)
	if _dtween != null and _dtween.is_valid(): _dtween.kill()
	_dtween = create_tween()
	_dtween.tween_property(drawer, "position:y", ty, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _rebuild_drawer() -> void:
	# Tabs
	for c in d_tabs.get_children(): c.queue_free()
	for ck in Game.CH_ORDER:
		if Game.has(ck): _tab(d_tabs, Game.CHASSIS[ck].n, ck)
	_tab(d_tabs, "Spiel", "spiel")
	_tab(d_tabs, "Zombies", "zombies")
	# Baum-Bereich
	for c in d_treewrap.get_children(): c.queue_free()
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	d_treewrap.add_child(holder)
	if _tree_sel == "spiel":
		_build_general(holder)
	elif _tree_sel == "zombies":
		_build_ztab(holder)
	else:
		if not Game.has(_tree_sel): _tree_sel = "sonne"
		var owned := 0
		var total := 0
		for id in Game.tree_nodes(_tree_sel):
			if id == "root": continue
			total += 1
			if Game.pt_owned(_tree_sel, id): owned += 1
		var sl := Label.new()
		sl.text = "%s   ·   Stufe %d   ·   %d/%d Skills" % [Game.CHASSIS[_tree_sel].n, owned, owned, total]
		sl.add_theme_font_size_override("font_size", 15); sl.modulate = Color(0.88, 0.97, 0.88)
		holder.add_child(sl)
		_build_tree_canvas(holder, _tree_sel)
	_rebuild_info()

func _tab(parent, label: String, key: String) -> void:
	var b := Button.new(); b.text = label; b.custom_minimum_size = Vector2(118, 34)
	b.add_theme_font_size_override("font_size", 14)
	if _tree_sel == key:
		b.add_theme_stylebox_override("normal", _sb(Color(0.17, 0.4, 0.24), COL_ACCENT, 2, 8, 8))
		b.add_theme_color_override("font_color", Color(0.82, 1, 0.86))
	b.pressed.connect(_pick_tree.bind(key))
	parent.add_child(b)

func _pick_tree(key: String) -> void:
	_tree_sel = key
	info_ck = ""; info_node = ""
	_rebuild_drawer()

func _select_node(ck: String, id: String) -> void:
	info_ck = ck; info_node = id
	_rebuild_info()

func _buy_selected() -> void:
	if Game.buy_pt(info_ck, info_node):
		_rebuild_drawer()
		refresh_seeds()

# ---- Info-Feld rechts ----
func _rebuild_info() -> void:
	for c in d_info.get_children(): c.queue_free()
	_big(d_info, "Info", 18, COL_ACCENT)
	if info_ck == "" or not BAL.PLANT_TREES.has(info_ck) or _tree_sel == "spiel" or _tree_sel == "zombies":
		var h := Label.new(); h.text = "Klicke einen Skill-Knoten, um Name, Effekt und Kosten zu sehen."
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; h.custom_minimum_size = Vector2(280, 0); h.modulate = Color(0.7, 0.78, 0.72)
		d_info.add_child(h); return
	var nodes = Game.tree_nodes(info_ck)
	if not nodes.has(info_node): return
	var nd = nodes[info_node]
	var rare := bool(nd.get("rare", false))
	var title := Label.new(); title.text = str(nd.n); title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(0.85, 0.6, 1) if rare else Color(0.95, 1, 0.9)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title.custom_minimum_size = Vector2(280, 0)
	d_info.add_child(title)
	var desc := Label.new(); desc.text = str(nd.d); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(280, 0); desc.modulate = Color(0.78, 0.85, 0.78)
	d_info.add_child(desc)
	if nd.has("cd"):
		var cdl := Label.new(); cdl.text = "Cooldown: %d Sek." % int(nd.cd); cdl.modulate = Color(0.7, 0.8, 1)
		d_info.add_child(cdl)
	_spacer(d_info, 8)
	if info_node == "root":
		var b0 := Label.new(); b0.text = "Basis-Chassis (immer aktiv)"; b0.modulate = Color(0.6, 0.9, 0.68)
		d_info.add_child(b0)
	elif Game.pt_owned(info_ck, info_node):
		var b1 := Label.new(); b1.text = "Freigeschaltet"; b1.modulate = Color(0.5, 0.95, 0.6); b1.add_theme_font_size_override("font_size", 16)
		d_info.add_child(b1)
	elif Game.pt_can(info_ck, info_node):
		var cost := int(nd.cost)
		var btn := Button.new(); btn.text = "Freischalten  (%d FP)" % cost; btn.custom_minimum_size = Vector2(0, 42)
		btn.add_theme_font_size_override("font_size", 16); btn.disabled = Game.fp < cost
		btn.pressed.connect(_buy_selected)
		d_info.add_child(btn)
		if Game.fp < cost:
			var w := Label.new(); w.text = "Zu wenig FP (%d / %d)" % [Game.fp, cost]; w.modulate = Color(1, 0.6, 0.5)
			d_info.add_child(w)
	else:
		var reqk := Game.pt_req(info_ck, info_node)
		var reqn: String = str(nodes.get(reqk, {}).get("n", reqk))
		var l := Label.new(); l.text = "Gesperrt — schalte zuerst frei:\n%s" % reqn
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(280, 0); l.modulate = Color(0.85, 0.72, 0.5)
		d_info.add_child(l)

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
	var sy := 122.0
	var width := (maxc - minc) * sx + 340.0
	var height := maxr * sy + 200.0
	var ox := -minc * sx + 170.0
	var oy := height - 96.0
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
	for br in tree.get("branches", []):
		var lb := Label.new(); lb.text = "Ast: " + str(br[1]); lb.modulate = Color(0.55, 0.62, 0.58)
		lb.add_theme_font_size_override("font_size", 12)
		lb.position = Vector2(ox + float(br[0]) * sx - 34, oy + 46)
		canvas.add_child(lb)
	for id in nodes:
		var nd = nodes[id]
		var center: Vector2 = _tree_px[id]
		var rare := bool(nd.get("rare", false))
		var selected := (ck == info_ck and id == info_node)
		if id == "root":
			_tree_node(canvas, center, str(nd.n), "Basis", 0, false, "root", false, Callable())
		else:
			var cost := int(nd.cost)
			var owned := Game.pt_owned(ck, id)
			var can := Game.pt_can(ck, id)
			var state := "lock"
			if owned: state = "legend_owned" if rare else "owned"
			elif can and Game.fp >= cost: state = "legend_avail" if rare else "avail"
			elif can: state = "legend_lock" if rare else "need"
			else: state = "legend_lock" if rare else "lock"
			_tree_node(canvas, center, str(nd.n), str(nd.d), cost, not owned, state, selected, _select_node.bind(ck, id))
	canvas.queue_redraw()

func _tree_node(canvas, center: Vector2, title: String, subtitle: String, cost: int, show_cost: bool, state: String, selected: bool, cb: Callable) -> void:
	var w := 160.0
	var h := 60.0
	var holder := Control.new()
	holder.size = Vector2(w, h)
	holder.position = center - Vector2(w / 2.0, h / 2.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(holder)
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_tree_node(btn, state, selected)
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
	holder.add_child(box)
	if show_cost:
		var pill := Label.new(); pill.text = "%d FP" % cost
		pill.add_theme_font_size_override("font_size", 12); pill.modulate = Color(1, 0.96, 0.82)
		pill.add_theme_stylebox_override("normal", _sb(_pill_bg(state), _pill_bd(state), 1, 9, 4))
		pill.position = Vector2(w / 2.0 - 30, -22)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pill)

func _pill_bg(state: String) -> Color:
	if state.begins_with("legend"): return Color(0.25, 0.15, 0.35)
	if state == "avail": return Color(0.35, 0.28, 0.1)
	return Color(0.15, 0.16, 0.18)

func _pill_bd(state: String) -> Color:
	if state.begins_with("legend"): return Color(0.8, 0.55, 1)
	if state == "avail": return Color(1, 0.82, 0.4)
	return Color(0.4, 0.42, 0.46)

func _style_tree_node(b: Button, state: String, selected: bool) -> void:
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
	var bw := 2
	if selected: bd = Color(1, 1, 1); bw = 3
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _sb(bg, bd, bw, 9, 6))

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

# ================= PAUSIERENDE OVERLAYS =================
func _make_overlay(n: String) -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 58; scroll.offset_left = 20; scroll.offset_right = -20; scroll.offset_bottom = -20
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)
	var close := Button.new()
	close.text = "X  Schliessen"; close.position = Vector2(16, 14); close.custom_minimum_size = Vector2(140, 34)
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
	refresh_seeds()

func _build_overlay_content(n: String) -> void:
	var vb = overlays[n].content
	for c in vb.get_children(): c.queue_free()
	match n:
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
	var l := Label.new(); l.text = text; l.modulate = col; l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)

func _big(parent, text: String, size: int, col: Color) -> void:
	var l := Label.new(); l.text = text; l.modulate = col; l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)

func _spacer(parent, h: int) -> void:
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, h); parent.add_child(sp)

func _menu_btn(parent, text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 19); b.pressed.connect(cb)
	parent.add_child(b)

func _grid(parent, cols: int) -> GridContainer:
	var g := GridContainer.new(); g.columns = cols
	g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	return g

func _card(grid, title: String, desc: String, btn_text: String, enabled: bool, cb: Callable) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(176, 0)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	var v := VBoxContainer.new()
	var t := Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 14); t.modulate = Color(0.95, 1, 0.9)
	v.add_child(t)
	var d := Label.new(); d.text = desc; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(154, 0); d.modulate = Color(0.72, 0.82, 0.74); d.add_theme_font_size_override("font_size", 11)
	v.add_child(d)
	if btn_text != "":
		var b := Button.new(); b.text = btn_text; b.disabled = not enabled
		if cb.is_valid(): b.pressed.connect(cb)
		v.add_child(b)
	m.add_child(v); pc.add_child(m); grid.add_child(pc)

# ---- Kauf-Handler (Drawer-Inhalt -> Drawer neu bauen) ----
func _buy_res(key: String) -> void:
	if Game.buy_research(key): _rebuild_drawer(); refresh_seeds()
func _buy_chassis(key: String) -> void:
	if Game.buy_chassis(key): _rebuild_drawer(); refresh_seeds()
func _buy_equip(key: String) -> void:
	if Game.buy_equip(key): _rebuild_drawer(); refresh_seeds()
func _buy_lure() -> void:
	if Game.buy_lure(): _rebuild_drawer()
func _buy_pres(key: String) -> void:
	if Game.buy_prestige(key):
		if overlays["death"].panel.visible: _post_buy("death")
		else: _post_buy("prestige")
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
	_big(vb, "Tipp: Zieh unten das Skill-Trees-Panel hoch, waehrend oben das Spiel laeuft.", 13, Color(0.65, 0.8, 0.68))

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
	_header(vb, "Steuerung: Linksklick = Sonne sammeln / Pflanze setzen / Zombie schlagen (Hammer).", Color(0.75, 0.85, 0.78))
	_header(vb, "Leertaste = Welle starten.  Unten der Pfeil oeffnet die Skill-Trees.", Color(0.75, 0.85, 0.78))
	_spacer(vb, 12)
	_header(vb, "Gehirne & Prestige zuruecksetzen (kann nicht rueckgaengig gemacht werden):", Color(1, 0.6, 0.6))
	var b := Button.new(); b.text = "Kompletten Fortschritt loeschen"; b.custom_minimum_size = Vector2(320, 40)
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

# ---- ENTWICKLER-MENUE ----
func _build_dev(vb) -> void:
	_big(vb, "ENTWICKLER-MENUE", 30, Color(1, 0.75, 0.4))
	_big(vb, "Regler zum Ausprobieren.", 13, Color(0.75, 0.8, 0.7))
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
	var god := CheckButton.new(); god.text = "Gott-Modus (Rasen unverlierbar)"; god.button_pressed = Game.god
	god.toggled.connect(_dev_god); vb.add_child(god)
	var g := _grid(vb, 3)
	_dev_button(g, "Alles freischalten", _dev_unlock_all)
	_dev_button(g, "Feld leeren (Zombies weg)", _dev_clear_field)
	_dev_button(g, "Welle sofort gewinnen", _dev_win)
	_dev_button(g, "Alle Zombies ins Buch", _dev_seen_all)
	_dev_button(g, "Tempo zuruecksetzen (1x)", _dev_speed_reset)

func _dev_button(parent, text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(210, 40); b.pressed.connect(cb)
	parent.add_child(b)

func _dev_slider(parent, label: String, minv: float, maxv: float, step: float, cur: float, key: String) -> void:
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 12)
	var l := Label.new(); l.custom_minimum_size = Vector2(320, 0)
	if key == "speed": l.text = "%s: %.2fx" % [label, cur]
	else: l.text = "%s: %d" % [label, int(cur)]
	var sl := HSlider.new(); sl.min_value = minv; sl.max_value = maxv; sl.step = step; sl.value = cur
	sl.custom_minimum_size = Vector2(360, 24)
	sl.value_changed.connect(_dev_set.bind(key, l, label))
	hb.add_child(l); hb.add_child(sl); parent.add_child(hb)

func _dev_set(value: float, key: String, l: Label, label: String) -> void:
	match key:
		"speed": Engine.time_scale = value; l.text = "%s: %.2fx" % [label, value]
		"sun": Game.sun = int(value); l.text = "%s: %d" % [label, int(value)]
		"fp": Game.fp = int(value); l.text = "%s: %d" % [label, int(value)]
		"coins": Game.coins = int(value); l.text = "%s: %d" % [label, int(value)]
		"brains": Game.brains = int(value); l.text = "%s: %d" % [label, int(value)]
		"wave": Game.wave = int(value); l.text = "%s: %d" % [label, int(value)]

func _dev_god(pressed: bool) -> void:
	Game.god = pressed

func _dev_unlock_all() -> void:
	for k in Game.CH_ORDER: Game.unlocked[k] = true
	for k in Game.EQ_ORDER: Game.unlocked[k] = true
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
	var b := Button.new(); b.text = "WIEDERGEBURT  -  Neuer Versuch"; b.custom_minimum_size = Vector2(360, 54)
	b.add_theme_font_size_override("font_size", 20); b.pressed.connect(_do_rebirth)
	vb.add_child(b)

func _do_rebirth() -> void:
	_nav_return = ""
	for k in overlays: overlays[k].panel.visible = false
	Game.paused = false
	lawn.reset_run()
	refresh_seeds()

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
