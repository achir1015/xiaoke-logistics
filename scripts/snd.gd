extends Node
## 音樂與音效（素材由 tools/gen_audio.py 程序合成，全部原創）。

const TRACKS := ["morning_dock", "forklift_waltz", "night_shift"]
const TRACK_NAMES := {"morning_dock": "早班碼頭", "forklift_waltz": "堆高機圓舞曲", "night_shift": "夜班慢板"}
const SFX := ["build", "cash", "ding", "sign", "error", "phone", "siren", "beep", "fanfare", "click", "horn"]

var music := AudioStreamPlayer.new()
var pool: Array = []
var streams: Dictionary = {}
var music_vol := 0.6
var sfx_vol := 0.8
var _track := -1
var _cooldown: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	music.finished.connect(next_track)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	for s in SFX:
		var path := "res://assets/sfx/%s.wav" % s
		if ResourceLoader.exists(path):
			streams[s] = load(path)
	_load_settings()

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		music_vol = float(cf.get_value("audio", "music", 0.6))
		sfx_vol = float(cf.get_value("audio", "sfx", 0.8))
	_apply()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.save("user://settings.cfg")

func _apply() -> void:
	music.volume_db = linear_to_db(maxf(music_vol, 0.001)) - 6.0
	music.stream_paused = music_vol <= 0.001

func set_music(v: float) -> void:
	music_vol = v
	_apply()
	if not music.playing and v > 0.001:
		next_track()

func set_sfx(v: float) -> void:
	sfx_vol = v

func start_music() -> void:
	if not music.playing:
		next_track()

func next_track() -> void:
	_track = (_track + 1) % TRACKS.size()
	var path := "res://assets/music/%s.ogg" % TRACKS[_track]
	if ResourceLoader.exists(path):
		music.stream = load(path)
		music.play()

func current_track_name() -> String:
	if _track < 0:
		return ""
	return TRACK_NAMES[TRACKS[_track]]

func play(name: String, vol := 1.0) -> void:
	if sfx_vol <= 0.001 or not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_cooldown.get(name, 0)) < 80:
		return
	_cooldown[name] = now
	for p in pool:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = streams[name]
			ap.volume_db = linear_to_db(maxf(sfx_vol * vol, 0.001))
			ap.play()
			return

func play_at(name: String, _pos: Vector3, vol := 1.0) -> void:
	play(name, vol)
