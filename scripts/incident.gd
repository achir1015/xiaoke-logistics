class_name Incident
extends Node3D
## 截獲歹徒事件：警車包圍、特勤人員持槍就位、嫌犯舉手投降被帶走、新聞轉播車採訪，最後平息撤離。
## 全程用真實時間播放（遊戲時間暫停）。

var world: World
var cam: IsoCam
var hud
var lights: Array = []
var flashes: Array = []
var _t := 0.0
var _road_z := World.ROAD_Z - 2.0

func setup(w: World, c: IsoCam, h) -> void:
	world = w
	cam = c
	hud = h
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_t += delta
	for i in lights.size():
		if is_instance_valid(lights[i]):
			(lights[i] as Node3D).visible = fmod(_t * 3.0 + i * 0.5, 1.0) < 0.5
	for f in flashes:
		if is_instance_valid(f):
			(f as Node3D).visible = randf() < 0.08

static func _yaw(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)

func _move(n: Node3D, pts: Array, speed: float, delay := 0.0) -> Tween:
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	var from := n.position
	for p in pts:
		var to: Vector3 = p
		var d := to - from
		d.y = 0.0
		if d.length() > 0.01:
			var yaw := _yaw(d)
			tw.tween_callback(func(): n.rotation.y = yaw)
		tw.tween_property(n, "position", to, maxf(0.15, d.length() / speed)).set_trans(Tween.TRANS_SINE)
		from = to
	return tw

func _face(n: Node3D, target: Vector3) -> void:
	var d := target - n.position
	d.y = 0.0
	if d.length() > 0.01:
		n.rotation.y = _yaw(d)

func _police_car() -> Node3D:
	var car := M.vehicle_model("police", 4.4)
	var red := M.box(car, Vector3(0.4, 0.15, 0.25), Vector3(-0.3, 1.75, 0), Color(1, 0.1, 0.1))
	red.material_override = M.mat(Color(1, 0.15, 0.15), 4.0)
	var blue := M.box(car, Vector3(0.4, 0.15, 0.25), Vector3(0.3, 1.75, 0), Color(0.1, 0.3, 1))
	blue.material_override = M.mat(Color(0.2, 0.4, 1.0), 4.0)
	lights.append(red)
	lights.append(blue)
	add_child(car)
	return car

## kind：intercept（攔截歹徒）、contraband（查獲夾帶）、raid（自己被抓）
## target：事件中心（地面座標）；inside：目標在倉庫內時，人員從最近的門進出
func run(kind: String, target: Vector3, headline: String, suspects := 2, door := Vector3.INF) -> void:
	var outside := target if door == Vector3.INF else door + Vector3(0, 0, 7.0)
	cam.focus(target.lerp(outside, 0.5), 30.0)
	Snd.play("siren")
	hud.show_news(headline)
	# 嫌犯
	var crooks: Array = []
	for i in suspects:
		var s := M.person("suspect")
		s.position = target + Vector3(-0.8 + i * 1.6, 0, 0.6)
		add_child(s)
		crooks.append(s)
	# 警車包圍
	var cars: Array = []
	var spots := [outside + Vector3(-7, 0, 4), outside + Vector3(7, 0, 4), outside + Vector3(0, 0, 9)]
	for i in 3:
		var car := _police_car()
		car.position = Vector3(outside.x - 50.0 - i * 9.0, 0, _road_z)
		car.rotation.y = PI / 2
		cars.append(car)
		var sp: Vector3 = spots[i]
		_move(car, [Vector3(sp.x - 4.0, 0, _road_z), sp], 16.0, i * 0.5)
	await get_tree().create_timer(1.5).timeout
	# 特勤車
	var truck := M.swat_truck()
	truck.position = Vector3(outside.x - 60.0, 0, _road_z)
	truck.rotation.y = PI / 2
	add_child(truck)
	var tpos := outside + Vector3(-12, 0, 9)
	_move(truck, [Vector3(tpos.x - 3.0, 0, _road_z), tpos], 16.0)
	await get_tree().create_timer(2.2).timeout
	Snd.play("siren", 0.6)
	# 特勤人員持槍就位（半圓包圍）
	var swat: Array = []
	for i in 6:
		var o := M.person("swat")
		o.position = tpos + Vector3(1.5 + (i % 3) * 0.6, 0, -1.0 + (i / 3) * 0.8)
		add_child(o)
		swat.append(o)
		var ang := deg_to_rad(20.0 + i * 28.0)
		var spot := target + Vector3(cos(ang), 0, sin(ang)) * 4.5
		var path: Array = []
		if door != Vector3.INF:
			path = [outside + Vector3(0, 0, -3.0), door + Vector3(0, 0, -1.5), spot]
		else:
			path = [spot]
		var tw := _move(o, path, 6.0, i * 0.15)
		tw.tween_callback(func(): _face(o, target))
	# 兩名制服警察守在警車旁
	for i in 2:
		var pc := M.person("police")
		pc.position = (spots[i] as Vector3) + Vector3(0, 0, -2.0)
		add_child(pc)
		_face(pc, target)
	await get_tree().create_timer(2.0).timeout
	for s in crooks:
		_face(s, outside)
		M.hands_up(s, true)
	hud.show_news(headline + "　嫌犯已舉手投降")
	# 新聞轉播車
	var nv := M.news_van()
	nv.position = Vector3(outside.x + 60.0, 0, _road_z + 4.0)
	nv.rotation.y = -PI / 2
	add_child(nv)
	var npos := outside + Vector3(15, 0, 12)
	_move(nv, [Vector3(npos.x + 4.0, 0, _road_z + 4.0), npos], 14.0)
	await get_tree().create_timer(2.5).timeout
	var rep := M.person("reporter")
	rep.position = npos + Vector3(-2.5, 0, -2.0)
	add_child(rep)
	_face(rep, npos + Vector3(-2.5, 0, 2.0))
	var cm := M.person("camera")
	cm.position = npos + Vector3(-2.5, 0, 1.2)
	add_child(cm)
	_face(cm, rep.position)
	flashes.append(cm.get_node("Flash"))
	var cm2 := M.person("camera")
	cm2.position = npos + Vector3(-5.0, 0, -0.5)
	add_child(cm2)
	_face(cm2, target)
	flashes.append(cm2.get_node("Flash"))
	await get_tree().create_timer(1.5).timeout
	# 嫌犯被押上警車
	var car3: Node3D = cars[2]
	for i in crooks.size():
		var s: Node3D = crooks[i]
		var path: Array = []
		if door != Vector3.INF:
			path = [door + Vector3(0, 0, -1.5), outside + Vector3(0, 0, -2.0), car3.position + Vector3(-1.5 + i, 0, -1.6)]
		else:
			path = [car3.position + Vector3(-1.5 + i, 0, -1.6)]
		var tw := _move(s, path, 2.5, i * 0.4)
		tw.tween_callback(func(): s.visible = false)
	await get_tree().create_timer(4.0 if door != Vector3.INF else 3.0).timeout
	if kind == "raid":
		hud.show_news("【快訊】小柯物流涉嫌藏匿不明貨箱，負責人遭警方帶回偵訊")
	else:
		hud.show_news("【快訊】現場已經平息，警方感謝小柯物流配合查緝")
	# 撤離
	for o in swat:
		var path2: Array = []
		if door != Vector3.INF:
			path2 = [door + Vector3(0, 0, -1.5), outside + Vector3(0, 0, -3.0), tpos]
		else:
			path2 = [tpos]
		var tw2 := _move(o, path2, 6.0, randf() * 0.6)
		tw2.tween_callback(func(): o.visible = false)
	await get_tree().create_timer(2.8).timeout
	_move(truck, [Vector3(tpos.x, 0, _road_z), Vector3(outside.x + 90.0, 0, _road_z)], 16.0)
	for i in cars.size():
		var car: Node3D = cars[i]
		_move(car, [Vector3(car.position.x, 0, _road_z), Vector3(outside.x + 90.0 + i * 9.0, 0, _road_z)], 16.0, 0.6 + i * 0.5)
	await get_tree().create_timer(3.5).timeout
	rep.visible = false
	cm.visible = false
	cm2.visible = false
	_move(nv, [Vector3(npos.x, 0, _road_z + 4.0), Vector3(outside.x - 90.0, 0, _road_z + 4.0)], 14.0)
	await get_tree().create_timer(3.0).timeout
	hud.hide_news()
	queue_free()
