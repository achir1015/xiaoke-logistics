extends Node
## 音樂與音效（素材由 tools/gen_audio.py 程序合成，全部原創）。

const TRACKS := ["morning_dock", "forklift_waltz", "night_shift"]
const TRACK_NAMES := {"morning_dock": "早班碼頭", "forklift_waltz": "堆高機圓舞曲", "night_shift": "夜班慢板"}
const SFX := ["build", "cash", "ding", "sign", "error", "phone", "siren", "beep", "fanfare", "click", "horn", "rain", "wind", "thunder", "quake", "alarm"]

var music := AudioStreamPlayer.new()
var voice := AudioStreamPlayer.new()
var voice_vol := 1.0
var auto_voice := true
var _duck := 0.0
var pool: Array = []
var streams: Dictionary = {}
var music_vol := 0.6
var sfx_vol := 0.8
var _track := -1
var _cooldown: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	add_child(voice)
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
		voice_vol = float(cf.get_value("audio", "voice", 1.0))
		auto_voice = bool(cf.get_value("audio", "auto_voice", true))
	_apply()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.set_value("audio", "voice", voice_vol)
	cf.set_value("audio", "auto_voice", auto_voice)
	cf.save("user://settings.cfg")

func _apply() -> void:
	music.volume_db = linear_to_db(maxf(music_vol, 0.001)) - 6.0 - _duck
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

# ── 環境音（雨、風，循環）──
var _amb: Dictionary = {}

func ambient(name: String, vol := 1.0) -> void:
	if not streams.has(name):
		return
	var ap: AudioStreamPlayer = _amb.get(name, null)
	if ap == null:
		ap = AudioStreamPlayer.new()
		add_child(ap)
		var st: AudioStream = streams[name]
		if st is AudioStreamWAV:
			var w: AudioStreamWAV = (st as AudioStreamWAV).duplicate()
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate) - 1
			st = w
		ap.stream = st
		_amb[name] = ap
	ap.volume_db = linear_to_db(maxf(sfx_vol * vol, 0.001)) - 4.0
	if not ap.playing:
		ap.play()

func stop_ambient(name: String) -> void:
	var ap: AudioStreamPlayer = _amb.get(name, null)
	if ap and ap.playing:
		ap.stop()

# ── 語音 ──
func play_voice(name: String) -> bool:
	var path := "res://assets/voice/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return false
	voice.stream = load(path)
	voice.volume_db = linear_to_db(maxf(voice_vol, 0.001))
	voice.play()
	return true

func stop_voice() -> void:
	voice.stop()

func voice_playing() -> bool:
	return voice.playing

func _process(delta: float) -> void:
	# 播語音時把音樂壓低 12 dB
	var want := 12.0 if voice.playing else 0.0
	if absf(_duck - want) > 0.05:
		_duck = move_toward(_duck, want, delta * 30.0)
		_apply()

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
