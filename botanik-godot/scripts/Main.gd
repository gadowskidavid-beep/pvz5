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
var tool_ham: Button
var tool_sho: Button

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
var _tree_sel := "seed"   # aktueller Tab: "seed" | "element" | "spiel" | "zombies"
var _tree_px := {}
var _tree_mode := "slot"  # "slot" | "element" | "none"  (Datenquelle der Leinwand)
var _tree_ref := 0        # Slot-Index bei mode "slot"
var _tree_zoom := 1.0     # Zoom-Faktor fuer den Skill-Baum
var info_node := ""       # aktuell gewaehlter Knoten (im aktuellen Baum)

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
	# Werkzeug-Highlight
	if tool_ham != null:
		tool_ham.modulate = Color(1, 1, 0.6) if (Game.place_slot < 0 and not Game.shovel) else Color(1, 1, 1)
	if tool_sho != null:
		tool_sho.modulate = Color(1, 1, 0.6) if Game.shovel else Color(1, 1, 1)
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
	tool_ham = Button.new(); tool_ham.text = "Hammer"; tool_ham.custom_minimum_size = Vector2(96, 46)
	tool_ham.pressed.connect(_pick_hammer); tools.add_child(tool_ham)
	tool_sho = Button.new(); tool_sho.text = "Schaufel"; tool_sho.custom_minimum_size = Vector2(96, 46)
	tool_sho.pressed.connect(_toggle_shovel); tools.add_child(tool_sho)
	# Pfeil zum Aufziehen (mittig unten)
	var arrow := Button.new(); arrow.text = "^  Skill Trees  ^"; arrow.custom_minimum_size = Vector2(190, 26)
	arrow.position = Vector2(SCREEN_W / 2.0 - 95, SCREEN_H - 90)
	arrow.add_theme_font_size_override("font_size", 13)
	arrow.pressed.connect(_toggle_drawer)
	root.add_child(arrow)

func refresh_seeds() -> void:
	for c in seed_box.get_children():
		c.queue_free()
	# Ein Kaertchen je Samen-Slot
	for i in range(Game.slot_count()):
		var card := Button.new()
		card.custom_minimum_size = Vector2(112, 52)
		card.add_theme_font_size_override("font_size", 12)
		var ck: String = Game.seed_chain(i)
		if ck == "":
			card.text = "Slot %d\n(leer)" % (i + 1)
			card.add_theme_color_override("font_color", Color(0.6, 0.66, 0.6))
			card.pressed.connect(_edit_slot_open.bind(i))
		else:
			var s = Game.seed_stats(i)
			card.text = "%s\nSonne %d · Lv%d" % [Game.CHASSIS[ck].n, int(s.cost), _plant_level(i)]
			if Game.place_slot == i and not Game.shovel:
				card.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.45, 0.28), Color(0.6, 1, 0.7), 3, 8))
				card.add_theme_color_override("font_color", Color(1, 1, 0.85))
			card.pressed.connect(_pick_slot.bind(i))
		seed_box.add_child(card)

func _plant_level(slot: int) -> int:
	var n := 0
	var ck := Game.seed_chain(slot)
	if ck == "": return 0
	var owned := Game.seed_nodes(slot)
	for id in Game.tree_nodes(ck):
		if id != "root" and owned.has(id): n += 1
	return n

func _pick_slot(i: int) -> void:
	if Game.seed_chain(i) == "":
		_edit_slot_open(i); return
	Game.place_slot = i
	Game.shovel = false
	refresh_seeds()

func _pick_hammer() -> void:
	Game.place_slot = -1
	Game.shovel = false
	refresh_seeds()

func _edit_slot_open(i: int) -> void:
	Game.edit_slot = i
	_tree_sel = "seed"; info_node = ""
	if not drawer_open: _toggle_drawer()
	else: _rebuild_drawer()

func _toggle_shovel() -> void:
	Game.shovel = not Game.shovel
	if Game.shovel: Game.place_slot = -1
	refresh_seeds()

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
	var zo := Button.new(); zo.text = "  -  "; zo.tooltip_text = "Rauszoomen"; zo.pressed.connect(_zoom_out); hrow.add_child(zo)
	var zlbl := Label.new(); zlbl.text = "Zoom"; zlbl.modulate = Color(0.7, 0.8, 0.72); hrow.add_child(zlbl)
	var zi := Button.new(); zi.text = "  +  "; zi.tooltip_text = "Reinzoomen"; zi.pressed.connect(_zoom_in); hrow.add_child(zi)
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
	# Tabs: die Samen-Slots + Element + Spiel + Zombies
	for c in d_tabs.get_children(): c.queue_free()
	for i in range(Game.slot_count()):
		var sck: String = Game.seed_chain(i)
		var lbl: String = ("S%d: %s" % [i + 1, Game.CHASSIS[sck].n]) if sck != "" else ("Samen %d" % (i + 1))
		_tab(d_tabs, lbl, "seed" + str(i))
	_tab(d_tabs, "Spiel", "spiel")
	_tab(d_tabs, "Zombies", "zombies")
	# Inhalt
	for c in d_treewrap.get_children(): c.queue_free()
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	d_treewrap.add_child(holder)
	if _tree_sel == "spiel":
		_tree_mode = "none"; _build_general(holder)
	elif _tree_sel == "zombies":
		_tree_mode = "none"; _build_ztab(holder)
	else:
		_tree_mode = "slot"; _tree_ref = Game.edit_slot
		var ck: String = Game.seed_chain(Game.edit_slot)
		if ck == "":
			_build_origin_picker(holder)
		else:
			_build_seed_header(holder, ck)
			_build_tree_canvas(holder)
	_rebuild_info()

# Leerer Slot -> 8 Chains zur Auswahl (Ursprung)
func _build_origin_picker(holder) -> void:
	_header(holder, "Samen %d  —  waehle eine Pflanze:" % (Game.edit_slot + 1), COL_ACCENT)
	var g := _grid(holder, 4)
	for ck in Game.CH_ORDER:
		var s = Game.compute_chassis_stats(ck)
		_card(g, Game.CHASSIS[ck].n, "%s\nSonne %d" % [Game.CHASSIS[ck].d, int(s.cost)], "Waehlen", true, _choose_chain.bind(ck))
	_header(holder, "Mehr Samen-Slots (dauerhaft, Gehirne)", COL_PURPLE)
	var b := Button.new()
	if Game.seed_slot_max():
		b.text = "Maximale Slots erreicht (%d)" % Game.slot_count(); b.disabled = true
	else:
		b.text = "Neuer Slot  (%d Gehirne)" % Game.seed_slot_cost()
		b.disabled = Game.brains < Game.seed_slot_cost()
		b.pressed.connect(_buy_slot)
	b.custom_minimum_size = Vector2(300, 38)
	holder.add_child(b)

func _choose_chain(ck: String) -> void:
	Game.seed_set_chain(Game.edit_slot, ck)
	Game.place_slot = Game.edit_slot
	_rebuild_drawer(); refresh_seeds()

func _build_seed_header(holder, ck: String) -> void:
	var owned := 0
	var total := 0
	var on := Game.seed_nodes(Game.edit_slot)
	for id in Game.tree_nodes(ck):
		if id == "root": continue
		total += 1
		if on.has(id): owned += 1
	var arow := HBoxContainer.new(); arow.add_theme_constant_override("separation", 12)
	var sl := Label.new()
	sl.text = "Samen %d: %s   ·   %d/%d Skills" % [Game.edit_slot + 1, Game.CHASSIS[ck].n, owned, total]
	sl.add_theme_font_size_override("font_size", 15); sl.modulate = Color(0.88, 0.97, 0.88)
	arow.add_child(sl)
	var asp := Control.new(); asp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; arow.add_child(asp)
	var rb := Button.new(); rb.text = "Pflanze wechseln (kein FP zurueck)"
	rb.add_theme_stylebox_override("normal", _sb(Color(0.4, 0.2, 0.2), Color(0.9, 0.5, 0.5), 2, 8))
	rb.pressed.connect(_reset_slot)
	arow.add_child(rb)
	holder.add_child(arow)
	# Hinweis zur Element-Wahl
	var comm := Game.seed_element(Game.edit_slot)
	var hint := Label.new()
	if comm == "":
		hint.text = "Waehle EINE Element-Richtung:  rot=Feuer · blau=Eis · gelb=Blitz · lila=Untod"
	else:
		var enames := {"f": "Feuer (rot)", "e": "Eis (blau)", "b": "Blitz (gelb)", "u": "Untod (lila)"}
		hint.text = "Element: %s  —  die anderen Richtungen sind gesperrt." % enames[comm]
	hint.modulate = Color(0.72, 0.8, 0.72); hint.add_theme_font_size_override("font_size", 13)
	holder.add_child(hint)

func _reset_slot() -> void:
	Game.seed_reset(Game.edit_slot)
	_rebuild_drawer(); refresh_seeds()

func _buy_slot() -> void:
	if Game.buy_seed_slot(): _rebuild_drawer(); refresh_seeds()

# ---- Dispatcher: Leinwand nutzt je nach _tree_mode Slot- oder Element-Daten ----
func _n_nodes() -> Dictionary:
	return Game.tree_nodes(Game.seed_chain(_tree_ref))
func _n_owned(id: String) -> bool:
	return Game.pt_owned(_tree_ref, id)
func _n_can(id: String) -> bool:
	return Game.pt_can(_tree_ref, id)
func _n_cost(id: String) -> int:
	return Game.pt_node_cost(_tree_ref, id)
func _n_req(id: String) -> String:
	return Game.pt_req(_tree_ref, id)
func _n_buy(id: String) -> bool:
	return Game.buy_pt(_tree_ref, id)

func _tab(parent, label: String, key: String) -> void:
	var b := Button.new(); b.text = label; b.custom_minimum_size = Vector2(100, 32)
	b.add_theme_font_size_override("font_size", 12)
	b.clip_text = true
	var active := (key == _tree_sel)
	if key.begins_with("seed") and _tree_sel == "seed" and key == "seed" + str(Game.edit_slot):
		active = true
	if active:
		b.add_theme_stylebox_override("normal", _sb(Color(0.17, 0.4, 0.24), COL_ACCENT, 2, 8, 8))
		b.add_theme_color_override("font_color", Color(0.82, 1, 0.86))
	b.pressed.connect(_pick_tree.bind(key))
	parent.add_child(b)

func _pick_tree(key: String) -> void:
	if key.begins_with("seed"):
		Game.edit_slot = int(key.substr(4))
		_tree_sel = "seed"
	else:
		_tree_sel = key
	info_node = ""
	_rebuild_drawer()

func _zoom_out() -> void:
	_tree_zoom = max(0.45, _tree_zoom - 0.15)
	_rebuild_drawer()

func _zoom_in() -> void:
	_tree_zoom = min(1.15, _tree_zoom + 0.15)
	_rebuild_drawer()

func _select_node(id: String) -> void:
	info_node = id
	_rebuild_info()

func _buy_selected() -> void:
	if _n_buy(info_node):
		_rebuild_drawer()
		refresh_seeds()

# ---- Info-Feld rechts ----
func _rebuild_info() -> void:
	for c in d_info.get_children(): c.queue_free()
	_big(d_info, "Info", 18, COL_ACCENT)
	var nodes := _n_nodes()
	if _tree_sel == "spiel" or _tree_sel == "zombies" or info_node == "" or nodes.is_empty() or not nodes.has(info_node):
		var h := Label.new(); h.text = "Klicke einen Skill-Knoten, um Name, Effekt und Kosten zu sehen."
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; h.custom_minimum_size = Vector2(280, 0); h.modulate = Color(0.7, 0.78, 0.72)
		d_info.add_child(h); return
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
		var b0 := Label.new(); b0.text = "Basis (immer aktiv)"; b0.modulate = Color(0.6, 0.9, 0.68)
		d_info.add_child(b0)
	elif _n_owned(info_node):
		var b1 := Label.new(); b1.text = "Freigeschaltet"; b1.modulate = Color(0.5, 0.95, 0.6); b1.add_theme_font_size_override("font_size", 16)
		d_info.add_child(b1)
	elif _n_can(info_node):
		var cost := _n_cost(info_node)
		var btn := Button.new(); btn.text = "Freischalten  (%d FP)" % cost; btn.custom_minimum_size = Vector2(0, 42)
		btn.add_theme_font_size_override("font_size", 16); btn.disabled = Game.fp < cost
		btn.pressed.connect(_buy_selected)
		d_info.add_child(btn)
		if Game.fp < cost:
			var w := Label.new(); w.text = "Zu wenig FP (%d / %d)" % [Game.fp, cost]; w.modulate = Color(1, 0.6, 0.5)
			d_info.add_child(w)
	else:
		var txt := ""
		var np := info_node.substr(0, 1)
		var comm := Game.seed_element(_tree_ref)
		if (np == "f" or np == "e" or np == "b" or np == "u") and comm != "" and comm != np:
			txt = "Gesperrt — dieser Samen ist bereits auf ein anderes Element festgelegt.\n(Pflanze wechseln, um neu zu waehlen.)"
		else:
			var reqk := _n_req(info_node)
			var reqn: String = str(nodes.get(reqk, {}).get("n", reqk))
			txt = "Gesperrt — schalte zuerst frei:\n%s" % reqn
		var l := Label.new(); l.text = txt
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(280, 0); l.modulate = Color(0.85, 0.72, 0.5)
		d_info.add_child(l)

# ---- Visueller Skill-Baum (Karten-Knoten + Pfade + Aeste) ----
func _build_tree_canvas(parent) -> void:
	var nodes := _n_nodes()
	if nodes.is_empty(): return
	var branches := []
	if _tree_mode == "slot":
		branches = BAL.PLANT_TREES.get(Game.seed_chain(_tree_ref), {}).get("branches", [])
	var minc := 0.0
	var maxc := 0.0
	var maxr := 0.0
	var minr := 0.0
	for id in nodes:
		var p = nodes[id].pos
		minc = min(minc, p.x); maxc = max(maxc, p.x)
		maxr = max(maxr, p.y); minr = min(minr, p.y)
	var z := _tree_zoom
	var sx := 190.0 * z
	var sy := 122.0 * z
	var width := (maxc - minc) * sx + 340.0 * z
	var height := (maxr - minr) * sy + 200.0 * z
	var ox := -minc * sx + 170.0 * z
	var oy := maxr * sy + 100.0 * z
	_tree_px = {}
	for id in nodes:
		var pp = nodes[id].pos
		_tree_px[id] = Vector2(ox + pp.x * sx, oy - pp.y * sy)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(width, height)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_tree.bind(canvas))
	parent.add_child(canvas)
	for br in branches:
		var lb := Label.new(); lb.text = "Ast: " + str(br[1]); lb.modulate = Color(0.55, 0.62, 0.58)
		lb.add_theme_font_size_override("font_size", int(max(9, 12 * z)))
		lb.position = Vector2(ox + float(br[0]) * sx - 34 * z, oy + 46 * z)
		canvas.add_child(lb)
	for id in nodes:
		var nd = nodes[id]
		var center: Vector2 = _tree_px[id]
		var rare := bool(nd.get("rare", false))
		var selected: bool = (id == info_node)
		var ecol := _elem_color(id)
		if id == "root":
			_tree_node(canvas, center, str(nd.n), "Basis", 0, false, "root", selected, ecol, _select_node.bind(id))
		else:
			var cost := _n_cost(id)
			var owned := _n_owned(id)
			var can := _n_can(id)
			var state := "lock"
			if owned: state = "legend_owned" if rare else "owned"
			elif can and Game.fp >= cost: state = "legend_avail" if rare else "avail"
			elif can: state = "legend_lock" if rare else "need"
			else: state = "legend_lock" if rare else "lock"
			_tree_node(canvas, center, str(nd.n), str(nd.d), cost, not owned, state, selected, ecol, _select_node.bind(id))
	canvas.queue_redraw()

func _elem_color(id: String) -> Color:
	var p := id.substr(0, 1)
	if p == "f": return Color(1.0, 0.45, 0.25)   # Feuer = rot
	if p == "e": return Color(0.45, 0.7, 1.0)    # Eis = blau
	if p == "b": return Color(1.0, 0.9, 0.35)    # Blitz = gelb
	if p == "u": return Color(0.72, 0.45, 1.0)   # Untod = lila
	return COL_ACCENT                            # Kern / Wurzel = gruen

func _tree_node(canvas, center: Vector2, title: String, subtitle: String, cost: int, show_cost: bool, state: String, selected: bool, ecol: Color, cb: Callable) -> void:
	var z := _tree_zoom
	var w := 160.0 * z
	var h := 60.0 * z
	var holder := Control.new()
	holder.size = Vector2(w, h)
	holder.position = center - Vector2(w / 2.0, h / 2.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(holder)
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_tree_node(btn, state, selected, ecol)
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
	t.add_theme_font_size_override("font_size", int(max(9, 13 * z))); t.modulate = Color(0.96, 0.99, 0.96)
	box.add_child(t)
	holder.add_child(box)
	if show_cost:
		var pill := Label.new(); pill.text = "%d FP" % cost
		pill.add_theme_font_size_override("font_size", int(max(8, 12 * z))); pill.modulate = Color(1, 0.96, 0.82)
		pill.add_theme_stylebox_override("normal", _sb(_pill_bg(state), _pill_bd(state), 1, 9, 4))
		pill.position = Vector2(w / 2.0 - 30 * z, -22 * z)
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

func _style_tree_node(b: Button, state: String, selected: bool, ecol: Color) -> void:
	# Farbe kommt vom Element (rot/blau/gelb/lila), Helligkeit vom Zustand
	var bd := ecol
	var bg := ecol.darkened(0.80)
	if state == "owned" or state == "root" or state == "legend_owned":
		bg = ecol.darkened(0.58)
	elif state == "avail" or state == "legend_avail":
		bg = ecol.darkened(0.74)
	else:  # lock / need / legend_lock -> abgedunkelt
		bd = ecol.darkened(0.5)
		bg = ecol.darkened(0.88)
	var bw := 3 if state.begins_with("legend") else 2
	if selected: bd = Color(1, 1, 1); bw = 3
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _sb(bg, bd, bw, 9, 6))

func _draw_tree(canvas) -> void:
	var nodes := _n_nodes()
	for id in nodes:
		var req := str(nodes[id].get("req", ""))
		if req == "" or not _tree_px.has(id) or not _tree_px.has(req): continue
		var a: Vector2 = _tree_px[req]
		var bp: Vector2 = _tree_px[id]
		var ec := _elem_color(id)
		if _n_owned(id):
			canvas.draw_line(a, bp, Color(ec.r, ec.g, ec.b, 0.95), 5.0 * _tree_zoom)
		elif _n_can(id):
			canvas.draw_line(a, bp, Color(ec.r, ec.g, ec.b, 0.7), 4.0 * _tree_zoom)
		else:
			canvas.draw_dashed_line(a, bp, ec.darkened(0.45), 3.0 * _tree_zoom, 9.0)

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
	Game.unlocked_slots = 3
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
	for k in Game.EQ_ORDER: Game.unlocked[k] = true
	# Samen-Slots mit Chains fuellen + deren Baeume voll
	for i in range(Game.slot_count()):
		if Game.seed_chain(i) == "":
			Game.seed_set_chain(i, Game.CH_ORDER[i % Game.CH_ORDER.size()])
		var ck := Game.seed_chain(i)
		for node in Game.tree_nodes(ck):
			if node != "root": Game.seed_nodes(i)[node] = true
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
		var s = Game.compute_chassis_stats(ck)
		_card(g, c.n, "%s\nSonne %d  HP %d" % [c.d, int(s.cost), int(s.hp)], "", false, Callable())

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


# ---- TAB "Spiel": Pflanzen freischalten + Ausruestung + Oekonomie ----
func _build_general(vb) -> void:
	_header(vb, "SPIEL & AUSRUESTUNG", Color(0.7, 0.85, 1))
	_header(vb, "Info: Pflanzen (Chains) waehlst du frei in den Samen-Slots.", Color(0.65, 0.78, 0.68))
	_header(vb, "Ausruestung (FP)", Color(0.55, 0.7, 1))
	var g3 := _grid(vb, 3)
	for k in Game.EQ_ORDER:
		var e = Game.EQUIP[k]
		if Game.has(k):
			_card(g3, "* " + e.n, e.d, "", false, Callable())
		else:
			var ok_e := Game.equip_req_ok(k)
			var sub_e: String = e.d if ok_e else ("Braucht: " + str(Game.EQUIP[e.req].n))
			_card(g3, e.n, sub_e, "FP %d" % int(e.fp), ok_e and Game.fp >= int(e.fp), _buy_equip.bind(k))
	_header(vb, "Oekonomie (FP)", Color(0.8, 0.85, 0.6))
	var g1 := _grid(vb, 3)
	for k in Game.RES_ORDER:
		var r = Game.RESEARCH[k]
		var lv_r := Game.res_lvl(k)
		var c_r := Game.res_cost(k)
		var eff := ("+%d%%" % int(r.per * 100 * lv_r)) if r.kind == "pct" else ("+%d" % int(r.per * lv_r))
		_card(g1, "%s  St.%d" % [r.n, lv_r], "%s  (%s)" % [r.d, eff], "FP %d" % c_r, Game.fp >= c_r, _buy_res.bind(k))

# ---- TAB "Zombies": Lockstoff ----
func _build_ztab(vb) -> void:
	_header(vb, "ZOMBIES  —  Lockstoff (mehr Idle-Zombies zwischen den Wellen zum Farmen)", Color(1, 0.55, 0.55))
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
