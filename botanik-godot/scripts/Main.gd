extends Node2D
# Botanik-Labor — spielbarer Rasen-Slice (Godot 4 / GDScript)
# Alles wird per Code gezeichnet (_draw) und aktualisiert (_process).

const ROWS = 5
const COLS = 9
const CELL = 100
const LAWN_X = 120
const LAWN_Y = 110

enum PType { SUNFLOWER, PEASHOOTER, WALLNUT }

var plants: Array = []
var zombies: Array = []
var peas: Array = []
var suns: Array = []
var rng := RandomNumberGenerator.new()

var sun := 75
var wave := 0
var phase := "prep"           # "prep" oder "fight"
var selected := PType.SUNFLOWER
var to_spawn := 0
var spawn_timer := 0.0
var sky_timer := 5.0
var msg := ""
var msg_t := 0.0

var hud: Label
var hint: Label

func _ready() -> void:
    rng.randomize()
    hud = Label.new()
    hud.position = Vector2(20, 12)
    hud.add_theme_font_size_override("font_size", 20)
    add_child(hud)
    hint = Label.new()
    hint.position = Vector2(20, 630)
    hint.add_theme_font_size_override("font_size", 14)
    hint.text = "Tasten: [1] Sonnenblume  [2] Erbsenschuetze  [3] Wal-Nuss   |   Klick = setzen / Sonne sammeln   |   [Leertaste] Welle starten"
    add_child(hint)

func _process(delta: float) -> void:
    _update_game(delta)
    _update_hud()
    queue_redraw()

func _update_game(dt: float) -> void:
    if msg_t > 0:
        msg_t -= dt
    # Himmels-Sonne
    sky_timer -= dt
    if sky_timer <= 0:
        sky_timer = 8.0 + rng.randf() * 4.0
        var x = LAWN_X + 40 + rng.randf() * (COLS * CELL - 80)
        suns.append({"x": x, "y": float(LAWN_Y - 10), "ty": LAWN_Y + 50 + rng.randf() * (ROWS * CELL - 120), "vy": 70.0, "value": 25, "falling": true, "life": 12.0})
    # Wellensteuerung
    if phase == "fight":
        spawn_timer -= dt
        if to_spawn > 0 and spawn_timer <= 0:
            spawn_timer = 1.2 + rng.randf() * 1.4
            _spawn_zombie()
            to_spawn -= 1
        if to_spawn <= 0 and zombies.is_empty():
            phase = "prep"
            msg = "Welle %d geschafft!" % wave
            msg_t = 2.0
    # Pflanzen
    for p in plants:
        p.t += dt
        if p.type == PType.SUNFLOWER:
            if p.t >= 6.0:
                p.t = 0.0
                suns.append({"x": p.x, "y": p.y, "ty": p.y, "vy": 0.0, "value": 25, "falling": false, "life": 12.0})
        elif p.type == PType.PEASHOOTER:
            var ahead := false
            for z in zombies:
                if z.row == p.row and z.x > p.x:
                    ahead = true
                    break
            if p.t >= 1.4 and ahead:
                p.t = 0.0
                peas.append({"row": p.row, "x": p.x + 22, "y": p.y - 6, "vx": 380.0, "dmg": 25.0})
    # Erbsen
    for i in range(peas.size() - 1, -1, -1):
        var pe = peas[i]
        pe.x += pe.vx * dt
        if pe.x > LAWN_X + COLS * CELL + 20:
            peas.remove_at(i)
            continue
        for z in zombies:
            if z.row == pe.row and z.hp > 0 and abs(z.x - pe.x) < 26:
                z.hp -= pe.dmg
                peas.remove_at(i)
                break
    # Zombies
    for i in range(zombies.size() - 1, -1, -1):
        var z = zombies[i]
        if z.hp <= 0:
            zombies.remove_at(i)
            continue
        var tgt = null
        for p in plants:
            if p.row == z.row and abs(z.x - p.x) < CELL * 0.42 and z.x >= p.x - CELL * 0.2:
                tgt = p
                break
        if tgt != null:
            tgt.hp -= 40.0 * dt
            if tgt.hp <= 0:
                plants.erase(tgt)
        else:
            z.x -= z.speed * dt
        if z.x < LAWN_X - 6:
            _lose_run()
            return
    # Sonne (fallen + verfallen)
    for i in range(suns.size() - 1, -1, -1):
        var s = suns[i]
        if s.falling and s.y < s.ty:
            s.y += s.vy * dt
        else:
            s.falling = false
        s.life -= dt
        if s.life <= 0:
            suns.remove_at(i)

func _spawn_zombie() -> void:
    var row = rng.randi() % ROWS
    var hp = 200.0 + wave * 25.0
    zombies.append({"row": row, "x": float(LAWN_X + COLS * CELL + 20), "y": LAWN_Y + row * CELL + CELL / 2.0, "hp": hp, "maxhp": hp, "speed": 22.0 + wave})

func _start_wave() -> void:
    if phase != "prep":
        return
    wave += 1
    phase = "fight"
    to_spawn = 4 + wave * 2
    spawn_timer = 0.6
    msg = "Welle %d startet!" % wave
    msg_t = 1.5

func _lose_run() -> void:
    msg = "Ueberrannt! Neustart."
    msg_t = 2.5
    plants.clear()
    zombies.clear()
    peas.clear()
    suns.clear()
    sun = 75
    wave = 0
    phase = "prep"

func _cost_of(t: int) -> int:
    return 100 if t == PType.PEASHOOTER else 50

func _try_place(col: int, row: int) -> void:
    if col < 0 or col >= COLS or row < 0 or row >= ROWS:
        return
    for p in plants:
        if p.col == col and p.row == row:
            return
    var cost = _cost_of(selected)
    if sun < cost:
        msg = "Zu wenig Sonne!"
        msg_t = 1.2
        return
    sun -= cost
    var x = LAWN_X + col * CELL + CELL / 2.0
    var y = LAWN_Y + row * CELL + CELL / 2.0
    var hp = 400.0 if selected == PType.WALLNUT else 60.0
    plants.append({"type": selected, "row": row, "col": col, "x": x, "y": y, "hp": hp, "maxhp": hp, "t": 0.0})

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1: selected = PType.SUNFLOWER
            KEY_2: selected = PType.PEASHOOTER
            KEY_3: selected = PType.WALLNUT
            KEY_SPACE, KEY_ENTER: _start_wave()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var pos: Vector2 = event.position
        for i in range(suns.size() - 1, -1, -1):
            if pos.distance_to(Vector2(suns[i].x, suns[i].y)) < 30:
                sun += suns[i].value
                suns.remove_at(i)
                return
        var col = int((pos.x - LAWN_X) / CELL)
        var row = int((pos.y - LAWN_Y) / CELL)
        _try_place(col, row)

func _update_hud() -> void:
    var sel := "Wal-Nuss (50)"
    if selected == PType.SUNFLOWER:
        sel = "Sonnenblume (50)"
    elif selected == PType.PEASHOOTER:
        sel = "Erbsenschuetze (100)"
    var ph := ""
    if phase == "fight":
        ph = "Welle %d laeuft..." % wave
    elif wave == 0:
        ph = "Bereit - [Leertaste] fuer Welle 1"
    else:
        ph = "Welle %d geschafft - [Leertaste] fuer naechste" % wave
    var m := ("    ->  " + msg) if msg_t > 0 else ""
    hud.text = "Sonne: %d    |    Gewaehlt: %s    |    %s%s" % [sun, sel, ph, m]

func _draw() -> void:
    # Rasen
    for r in range(ROWS):
        for c in range(COLS):
            var g = Color(0.23, 0.42, 0.25) if (r + c) % 2 == 0 else Color(0.27, 0.49, 0.29)
            draw_rect(Rect2(LAWN_X + c * CELL, LAWN_Y + r * CELL, CELL, CELL), g)
    # Haus / linke Kante
    draw_rect(Rect2(LAWN_X - 12, LAWN_Y, 8, ROWS * CELL), Color(0.42, 0.32, 0.62))
    # Pflanzen
    for p in plants:
        var col = Color(0.6, 0.42, 0.24)
        if p.type == PType.SUNFLOWER:
            col = Color(1, 0.83, 0.2)
        elif p.type == PType.PEASHOOTER:
            col = Color(0.3, 0.8, 0.35)
        draw_circle(Vector2(p.x, p.y), 30, col)
        _hp_bar(p.x, p.y + 34, p.hp / p.maxhp, Color(0.3, 0.85, 0.35))
    # Erbsen
    for pe in peas:
        draw_circle(Vector2(pe.x, pe.y), 7, Color(0.62, 0.95, 0.4))
    # Zombies
    for z in zombies:
        draw_rect(Rect2(z.x - 22, z.y - 34, 44, 64), Color(0.5, 0.55, 0.5))
        _hp_bar(z.x, z.y - 42, z.hp / z.maxhp, Color(0.9, 0.3, 0.3))
    # Sonne
    for s in suns:
        draw_circle(Vector2(s.x, s.y), 16, Color(1, 0.85, 0.25))

func _hp_bar(cx: float, y: float, frac: float, c: Color) -> void:
    if frac >= 1.0:
        return
    frac = clamp(frac, 0.0, 1.0)
    var w := 46.0
    var h := 5.0
    draw_rect(Rect2(cx - w / 2.0, y, w, h), Color(0, 0, 0, 0.5))
    draw_rect(Rect2(cx - w / 2.0, y, w * frac, h), c)
