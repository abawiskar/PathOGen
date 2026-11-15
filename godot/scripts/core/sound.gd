## Sound effects and background music (web: js/sound.js + js/music.js).
## The Music toggle also mutes the effects, as on the web. Settings persist in user://pathogen_audio.json.
class_name Sound
extends Node

const SFX := {
	"click": "click", "card_select": "card_select", "component_place": "component_place",
	"wire_connect": "wire_connect", "correct": "correct", "incorrect": "incorrect_v2",
	"monster_attack": "monster_attack_v2", "player_damage": "player_damage_v3", "victory": "victory",
}
const TRACKS := ["title", "battle", "critical", "defeat"]
const SFX_VOLUME := 0.85
const FADE_SEC := 0.18
const PREFS := "user://pathogen_audio.json"

static var instance: Sound

var enabled := true
var volume := 0.22        # music volume, 0..1
var current := ""         # playing track ("" = silence)

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _pending: Array = []  # SceneTreeTimers for delayed effects
var _fade := 0.0


static func play(name: String, delay := 0.0) -> void:
	if instance:
		instance._play(name, delay)


static func stop() -> void:
	if instance:
		instance._stop()


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_prefs()
	for k in SFX:
		var path := "res://audio/%s.wav" % SFX[k]
		if ResourceLoader.exists(path):
			_streams[k] = load(path)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)


func _play(name: String, delay: float) -> void:
	if not enabled or not _streams.has(name):
		return
	if delay > 0.0:
		var t := get_tree().create_timer(delay)
		_pending.append(t)
		t.timeout.connect(func():
			if _pending.has(t):
				_pending.erase(t)
				_play(name, 0.0))
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = linear_to_db(SFX_VOLUME)
			p.play()
			return


func _stop() -> void:
	_pending.clear()
	for p in _pool:
		p.stop()


## Pick the music for the game state: title outside battles, battle / critical / defeat in one, silence on a win.
func choose(track: String) -> void:
	if track == current:
		return
	current = track
	_music.stop()
	if track == "" or not enabled:
		return
	var path := "res://audio/bgm/%s.wav" % track
	if not ResourceLoader.exists(path):
		return
	var st: AudioStreamWAV = load(path)
	if track != "defeat":
		st = st.duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
	_music.stream = st
	_fade = 0.0 if track != "defeat" else FADE_SEC
	_music.volume_db = linear_to_db(maxf(volume * (_fade / FADE_SEC), 0.0001))
	_music.play()


func _process(delta: float) -> void:
	if _music and _music.playing and _fade < FADE_SEC:
		_fade = minf(FADE_SEC, _fade + delta)
		_music.volume_db = linear_to_db(maxf(volume * _fade / FADE_SEC, 0.0001))


func set_enabled(v: bool) -> void:
	enabled = v
	_save_prefs()
	if not v:
		_stop()
		_music.stop()
	else:
		var t := current
		current = ""
		choose(t)


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	if _music.playing:
		_music.volume_db = linear_to_db(maxf(volume, 0.0001))
	_save_prefs()


func _load_prefs() -> void:
	if not FileAccess.file_exists(PREFS):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PREFS))
	if d is Dictionary:
		enabled = d.get("enabled", true) != false
		volume = clampf(float(d.get("volume", volume)), 0.0, 1.0)


func _save_prefs() -> void:
	var f := FileAccess.open(PREFS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"enabled": enabled, "volume": volume}))
