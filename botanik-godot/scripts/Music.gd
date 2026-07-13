extends Node
# ================================================================
# Autoload "Music" — Hintergrundmusik: Loop, Tag/Nacht-Wechsel, Lautstaerke.
# Defensiv: fehlt die Datei oder ist sie noch nicht von Godot importiert,
# bleibt es einfach still (kein Crash). Sobald das Projekt im Editor
# geoeffnet wurde (-> .import erzeugt), spielt die Musik automatisch.
# ================================================================

const TRACKS := {
	"menu":  "res://Musik/Whispering Garden(theme1).mp3",
	"day":   "res://Musik/Whispering Garden(theme1).mp3",
	"night": "res://Musik/Nighttheme1.mp3",
}

# Sound-Effekte — Datei fehlt/nicht importiert -> einfach still, kein Crash.
const SFX := {
	"thunder":       "res://Musik/Soundeffect/LightningStrike.mp3",
	"shoot_pea":     "res://Musik/Soundeffect/Peashooter(shooteffectfirst).mp3",
	"shoot_shroom":  "res://Musik/Soundeffect/plop_1(shootshroom).mp3",
	"pea_hit":       "res://Musik/Soundeffect/plop-1(peashooterHit).mp3",
	"collect_sun":   "res://Musik/Soundeffect/CollectSun.mp3",
	"boss_spawn":    "res://Musik/Soundeffect/BossSpawn.mp3",
	"boss_warning":  "res://Musik/Soundeffect/BossSpawningWavebefore.mp3",
	"jump":          "res://Musik/Soundeffect/JumpingZombieEffect.mp3",
	"rage":          "res://Musik/Soundeffect/AngryzombieMode.mp3",
	"dead":          "res://Musik/Soundeffect/phasmophobia-sound-board-effects-16-sound-effects-player-dying-sound-effect.mp3",
	"plant":         "res://Musik/Soundeffect/Plant Planted.mp3",
	"plant_died":    "res://Musik/Soundeffect/PlantdiedFromZombie.mp3",
	"eating":        "res://Musik/Soundeffect/Zombie Eating plant.mp3",
}

# Laengere/wichtige Effekte bekommen einen EIGENEN Player, damit sie nicht vom
# schnellen Kampf-Getroffel (Pool) abgeschnitten werden (z.B. der Donner).
const LONG_SFX := ["thunder", "boss_spawn", "dead", "boss_warning"]

# Regen-Hintergrund (Loop). Godot importiert KEIN .m4a -> bitte als .ogg/.mp3 ablegen.
# Erster existierender Kandidat wird genutzt:
const RAIN_CANDIDATES := [
	"res://Musik/Soundeffect/8MinRegenEffect.ogg",
	"res://Musik/Soundeffect/8MinRegenEffect.mp3",
	"res://Musik/Soundeffect/8MinRegenEffect.m4a",
	"res://Musik/Soundeffect/Rain.ogg",
]

var _player: AudioStreamPlayer
var _sfx_pool: Array = []      # mehrere Player -> Effekte duerfen sich ueberlappen
var _sfx_idx := 0
var _sfx_long: AudioStreamPlayer   # eigener Player fuer lange Effekte (Donner etc.) -> kein Abbruch
var _rain: AudioStreamPlayer       # Regen-Loop im Hintergrund
var _rain_on := false
var _sfx_last := {}            # key -> letzte Abspielzeit (Anti-Spam-Cooldown)
var _current_path := ""
var volume_db := -6.0
var sfx_volume_db := -4.0
var muted := false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.volume_db = volume_db
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	_sfx_long = AudioStreamPlayer.new()
	add_child(_sfx_long)
	_rain = AudioStreamPlayer.new()
	add_child(_rain)

# Spielt einen kurzen Sound-Effekt (kein Loop, Round-Robin-Player + Cooldown).
func play_sfx(key: String, min_gap := 0.06) -> void:
	var path: String = str(SFX.get(key, ""))
	if path == "" or not ResourceLoader.exists(path): return
	var now: float = Time.get_ticks_msec() / 1000.0
	if _sfx_last.has(key) and now - float(_sfx_last[key]) < min_gap: return
	_sfx_last[key] = now
	var s = load(path)
	if s == null: return
	if s is AudioStreamMP3: s.loop = false
	elif s is AudioStreamOggVorbis: s.loop = false
	var pl: AudioStreamPlayer
	if key in LONG_SFX:
		pl = _sfx_long            # laeuft aus, wird nicht vom Pool abgeschnitten
	else:
		pl = _sfx_pool[_sfx_idx]
		_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()
	pl.stream = s
	pl.volume_db = -80.0 if muted else sfx_volume_db
	pl.play()

func set_sfx_volume(db: float) -> void:
	sfx_volume_db = db
	if _rain != null and _rain_on and not muted: _rain.volume_db = sfx_volume_db - 10.0

# Regen-Loop leise im Hintergrund an/aus (waehrend Gewitter)
func set_rain(on: bool) -> void:
	if on == _rain_on: return
	_rain_on = on
	if not on:
		if _rain != null: _rain.stop()
		return
	var path := ""
	for cand in RAIN_CANDIDATES:
		if ResourceLoader.exists(cand): path = cand; break
	if path == "": return   # noch keine importierbare Regen-Datei -> still
	var s = load(path)
	if s == null: return
	if s is AudioStreamMP3: s.loop = true
	elif s is AudioStreamOggVorbis: s.loop = true
	_rain.stream = s
	_rain.volume_db = -80.0 if muted else (sfx_volume_db - 10.0)   # dezent leiser
	_rain.play()

# Spielt den Track fuer den Key. Gibt true zurueck, wenn ein NEUER Track gestartet wurde.
func play_key(key: String) -> bool:
	var path: String = str(TRACKS.get(key, ""))
	if path == "": return false
	if path == _current_path and _player != null and _player.playing: return false
	if not ResourceLoader.exists(path): return false   # (noch) nicht importiert -> still
	var stream = load(path)
	if stream == null: return false
	if stream is AudioStreamMP3: stream.loop = true
	elif stream is AudioStreamOggVorbis: stream.loop = true
	_player.stream = stream
	_player.volume_db = -80.0 if muted else volume_db
	_player.play()
	_current_path = path
	return true

func play_menu() -> bool:
	return play_key("menu")

func play_for_wave(night: bool) -> bool:
	return play_key("night" if night else "day")

func set_volume(db: float) -> void:
	volume_db = db
	if _player != null and not muted: _player.volume_db = db

func set_muted(m: bool) -> void:
	muted = m
	if _player != null: _player.volume_db = -80.0 if m else volume_db
	if _rain != null and _rain_on: _rain.volume_db = -80.0 if m else (sfx_volume_db - 10.0)
