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

# Sound-Effekte (optional) — sobald die Datei existiert, wird sie gespielt; sonst still.
const SFX := {
	"thunder": "res://Musik/thunder.mp3",
}

var _player: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _current_path := ""
var volume_db := -6.0
var muted := false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.volume_db = volume_db
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)

# Spielt einen kurzen Sound-Effekt (kein Loop). Fehlt die Datei -> still, kein Crash.
func play_sfx(key: String) -> void:
	var path: String = str(SFX.get(key, ""))
	if path == "" or not ResourceLoader.exists(path): return
	var s = load(path)
	if s == null: return
	if s is AudioStreamMP3: s.loop = false
	elif s is AudioStreamOggVorbis: s.loop = false
	_sfx.stream = s
	_sfx.volume_db = -80.0 if muted else volume_db
	_sfx.play()

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
