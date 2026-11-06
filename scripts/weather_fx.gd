class_name WeatherFX
extends Node3D
## 天氣與災害畫面：雨、颱風（強風、閃電、大浪）、地震（搖晃、托盤掉落）。

var world: World
var cam: IsoCam
var rain: CPUParticles3D
var dim := 0.0          # 0 晴 → 1 颱風（平滑過渡）
var storm := 0.0        # 風浪強度
var wet := 0.0
var _flash := 0.0
var _next_bolt := 5.0
var _quake_t := 0.0
var _quake_mag := 0.0
var _quake_speed := 1.0
var _t := 0.0
var tint: ColorRect

func setup(w: World, c: IsoCam) -> void:
	world = w
	cam = c
	rain = CPUParticles3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.06, 1.6, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.82, 0.88, 1.0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = m
	rain.mesh = dm
	rain.amount = 2500
	rain.lifetime = 0.8
	rain.particle_flag_align_y = true
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(60, 1, 45)
	rain.direction = Vector3(0, -1, 0)
	rain.spread = 2.0
	rain.gravity = Vector3(0, -40, 0)
	rain.initial_velocity_min = 22.0
	rain.initial_velocity_max = 28.0
	rain.local_coords = false
	rain.emitting = false
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	tint = ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0, 0, 0, 0)
	cl.add_child(tint)
	G.quake.connect(start_quake)
	G.weather_changed.connect(_on_weather)
	_on_weather()

func _on_weather() -> void:
	var k := G.weather_kind()
	match k:
		"rain":
			Snd.ambient("rain", 0.55)
			Snd.stop_ambient("wind")
		"typhoon":
			Snd.ambient("rain", 0.9)
			Snd.ambient("wind", 0.9)
		_:
			Snd.stop_ambient("rain")
			Snd.stop_ambient("wind")

func _process(delta: float) -> void:
	_t += delta
	var k := G.weather_kind() if G.playing else "sunny"
	var want_dim: float = {"sunny": 0.0, "cloudy": 0.3, "rain": 0.6, "typhoon": 0.85}[k]
	var want_storm: float = {"sunny": 0.0, "cloudy": 0.1, "rain": 0.35, "typhoon": 1.0}[k]
	dim = move_toward(dim, want_dim, delta * 0.25)
	storm = move_toward(storm, want_storm, delta * 0.25)
	world.weather_dim = dim
	world.storm = storm
	# 雨
	var raining := k in ["rain", "typhoon"]
	rain.emitting = raining
	if raining:
		rain.global_position = Vector3(cam.global_position.x, 20.0, cam.global_position.z)
		rain.amount = 6000 if k == "rain" else 10000
		var z: float = cam.zoom
		rain.emission_box_extents = Vector3(z * 1.1, 1, z * 0.9)
		var wind := 0.0 if k == "rain" else 0.55
		rain.direction = Vector3(wind, -1, wind * 0.4).normalized()
		rain.gravity = Vector3(wind * 30.0, -40, wind * 12.0)
	# 樹木搖晃
	for i in world.trees.size():
		var tr: Node3D = world.trees[i]
		if is_instance_valid(tr):
			var sway := (0.02 + storm * 0.16) * sin(_t * (1.2 + storm * 1.8) + i * 0.7)
			tr.rotation.x = sway
			tr.rotation.z = sway * 0.6
	# 颱風閃電
	if k == "typhoon" and G.playing:
		_next_bolt -= delta
		if _next_bolt <= 0.0:
			_next_bolt = randf_range(4.0, 11.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.4, 1.4)).timeout.connect(func(): Snd.play("thunder", 0.8))
	_flash = maxf(0.0, _flash - delta * 3.0)
	world.lightning = _flash
	# 畫面色調：陰雨偏暗藍，閃電瞬間發白
	var a := dim * 0.32
	tint.color = Color(0.05, 0.08, 0.16, a).lerp(Color(0.9, 0.93, 1.0, 0.45), _flash)
	# 地震
	if _quake_t > 0.0:
		_quake_t -= delta
		var amp := clampf((_quake_mag - 3.5) / 3.0, 0.15, 1.0) * minf(1.0, _quake_t / 1.5)
		cam.cam.h_offset = randf_range(-1, 1) * amp * 0.6
		cam.cam.v_offset = randf_range(-1, 1) * amp * 0.4
		for r in world.racks:
			r.node.rotation.z = sin(_t * 23.0 + r.id) * 0.03 * amp
			r.node.rotation.x = sin(_t * 19.0 + r.id * 2.0) * 0.02 * amp
		if _quake_t <= 0.0:
			_end_quake()

# ── 地震 ──
func start_quake(mag: float) -> void:
	if _quake_t > 0.0 or G.over:
		return
	_quake_mag = mag
	_quake_speed = G.speed if G.speed > 0.0 else G.speed_before_pause
	if mag >= 5.0:
		Snd.play("alarm")
		G.toast.emit("【地震速報】強烈地震！請注意安全。", "bad")
		await get_tree().create_timer(1.6).timeout
	G.set_speed(0.0)
	_quake_t = 4.0 + mag
	Snd.play("quake", clampf(mag / 6.0, 0.5, 1.0))

func _intensity(mag: float) -> int:
	return clampi(int(mag - 1.5), 1, 7)

func _end_quake() -> void:
	cam.cam.h_offset = 0.0
	cam.cam.v_offset = 0.0
	for r in world.racks:
		r.node.rotation.x = 0.0
		r.node.rotation.z = 0.0
	var fallen := 0
	if _quake_mag >= 5.3:
		var chance := (_quake_mag - 5.0) * 0.14
		for p in world.pallets.duplicate():
			if p.state == "rack" and p.rack.kind != "inspect" and p.slot >= int(G.BUILD[p.rack.kind].cols) and not p.claimed and randf() < chance:
				if world.fall_pallet(p):
					fallen += 1
	var msg := "地震：芮氏規模 %.1f，本地震度 %d 級。" % [_quake_mag, _intensity(_quake_mag)]
	if fallen > 0:
		var cost := G.price(250) * fallen
		G.money -= cost
		G.money_changed.emit()
		G.add_rating(-minf(fallen, 5.0))
		msg += "有 %d 板貨從高處掉下來，貨損賠償 %s，堆高機會把它們放回去。" % [fallen, G.fmt(cost)]
		G.toast.emit(msg, "bad")
	else:
		msg += "倉庫一切正常。"
		G.toast.emit(msg, "info")
	G.set_speed(_quake_speed)
