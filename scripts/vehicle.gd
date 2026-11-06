class_name Vehicle
extends Node3D
## 卡車／廂型車／火車／貨輪：進場、靠碼頭、卸貨或裝貨、離場。

const TRUCK_FILES := ["delivery", "delivery", "delivery-flat"]
const TINTS := [Color(1, 1, 1), Color(0.75, 0.9, 1.0), Color(1.0, 0.85, 0.7), Color(0.85, 1.0, 0.8), Color(1.0, 0.8, 0.85), Color(0.9, 0.85, 1.0)]
const SUSPICIOUS := [
	"司機的皮鞋擦得太亮了，跟這台破車很不搭。",
	"副駕駛座底下露出一截無線電天線。",
	"司機一直對著衣領小聲說話。",
	"車牌螺絲是全新的，車身卻滿是灰塵。",
	"司機問了兩次「貨主是誰」，好像在確認什麼。",
	"街角那台停了很久的轎車，車窗搖下了一點。",
]
const NORMAL := [
	"司機嚼著檳榔，不耐煩地敲著方向盤。",
	"車上飄出滷味的香氣，收音機在放老歌。",
	"司機戴著墨鏡，一句話也不說，只比了個手勢。",
	"車斗角落有幾個空的提神飲料罐。",
	"司機手臂上有刺青，看了你一眼就移開視線。",
	"引擎沒熄火，司機看起來只想快點走。",
]

var world: World
var kind := "truck"         # truck / van / rail / ship / police
var mode := "in"            # in / out
var cid := 0
var cargo := "general"
var dock = null
var state := "approach"     # approach / queue / docking / decide / docked / leaving / raid
var waypoints: Array = []   # [Vector3, rev]
var speed_road := 12.0
var length := 7.0
var left := 0               # 還要卸的托盤數
var target := 0             # 出貨：這一趟要裝幾板
var got := 0                # 出貨：這一趟已裝幾板
var stall := 0.0
var dock_min := 0.0
var queue_min := 0.0
var is_cop := false
var observed := false
var transfers: Array = []   # [{p, path, t}]
var lights: Array = []
var model: Node3D
var _flash := 0.0
var _queue_pt := Vector3.ZERO

func setup(w: World, c: Dictionary, m: String) -> void:
	world = w
	cid = int(c.id)
	mode = m
	cargo = c.cargo
	kind = c.get("tin", c.transport) if m == "in" else c.get("tout", c.transport)
	var cap: int = G.CAP.get(kind, 6)
	if m == "in":
		left = mini(cap, int(c.n) - int(c.unloaded))
	else:
		target = mini(cap, int(c.unloaded) - int(c.loaded))
	match kind:
		"air":
			model = M.plane()
			position = Vector3(-330, 42, World.RUNWAY_Z)
			rotation.y = PI / 2
			speed_road = 30.0
		"rail":
			model = Node3D.new()
			var loco := M.locomotive()
			model.add_child(loco)
			for k in 3:
				var wg := M.wagon()
				wg.position.x = -10.0 - k * 10.5
				model.add_child(wg)
			position = Vector3(-140, 0, World.RAIL_Z)
			speed_road = 10.0
		"ship":
			model = M.ship()
			model.rotation.y = PI / 2
			position = Vector3(-180, -0.55, World.SHIP_Z)
			speed_road = 7.0
		"van":
			length = 4.8
			model = M.vehicle_model("van", length, Color(0.32, 0.32, 0.35))
			position = Vector3(-50, 0, World.ROAD_Z - 2)
			rotation.y = PI / 2
			is_cop = randf() < G.cop_chance()
		_:
			var f: String = TRUCK_FILES[randi() % TRUCK_FILES.size()]
			length = 6.4
			model = M.vehicle_model(f, length, TINTS[randi() % TINTS.size()])
			position = Vector3(-50 - randf() * 10.0, 0, World.ROAD_Z - 2)
			rotation.y = PI / 2
	add_child(model)
	_request_dock()

func wants_pallets() -> bool:
	return mode == "out" and state == "docked"

# ── 路線 ──
func _request_dock() -> void:
	dock = world.claim_dock(kind, self)
	if dock == null:
		state = "queue"
		_go_queue()
		return
	state = "approach"
	waypoints.clear()
	match kind:
		"rail":
			waypoints.append([Vector3(world.cell_center(dock.cell).x + 10.0, 0, World.RAIL_Z), false])
		"ship":
			waypoints.append([Vector3(world.cell_center(dock.cell).x, -0.55, World.SHIP_Z), false])
		"air":
			var rz := World.RUNWAY_Z
			waypoints.append([Vector3(-185, 0, rz), false])
			waypoints.append([Vector3(-70, 0, rz), false])
			waypoints.append([Vector3(-48, 0, rz), false])
			waypoints.append([Vector3(-36, 0, World.APRON_Z), false])
			waypoints.append([Vector3(-21, 0, World.APRON_Z), false])
		_:
			var bx: float = world.cell_center(dock.cell).x
			var fz := World.FRONT_Z + 0.5 + length / 2.0
			waypoints.append([Vector3(bx + 9.0, 0, World.ROAD_Z - 2), false])
			waypoints.append([Vector3(bx + 7.0, 0, fz + 11.0), false])
			waypoints.append([Vector3(bx + 1.2, 0, fz + 7.0), true])
			waypoints.append([Vector3(bx, 0, fz + 4.0), true])
			waypoints.append([Vector3(bx, 0, fz), true])

func _go_queue() -> void:
	var idx := 0
	for v in world.vehicles:
		if v == self:
			break
		if v.state == "queue" and v.kind == kind:
			idx += 1
	waypoints.clear()
	match kind:
		"rail":
			_queue_pt = Vector3(-70 - idx * 45.0, 0, World.RAIL_Z)
		"ship":
			_queue_pt = Vector3(-90 - idx * 40.0, -0.55, World.SHIP_Z)
		"air":
			_queue_pt = Vector3(-330 - idx * 60.0, 42, World.RUNWAY_Z)
		_:
			_queue_pt = Vector3(-12 - idx * 9.0, 0, World.ROAD_Z - 2)
	waypoints.append([_queue_pt, false])

func _leave_route() -> void:
	waypoints.clear()
	var far: float = world.cols() * World.TILE + 160.0
	match kind:
		"rail":
			waypoints.append([Vector3(far + 60.0, 0, World.RAIL_Z), false])
		"ship":
			waypoints.append([Vector3(far + 80.0, -0.55, World.SHIP_Z), false])
		"air":
			var rz := World.RUNWAY_Z
			waypoints.append([Vector3(-34, 0, World.APRON_Z + 3.0), false])
			waypoints.append([Vector3(-44, 0, rz + 3.0), false])
			waypoints.append([Vector3(-56, 0, rz), false])
			waypoints.append([Vector3(-90, 0, rz), false])
			waypoints.append([Vector3(-200, 0, rz), false])
			waypoints.append([Vector3(-360, 55, rz), false])
		_:
			var x := position.x
			waypoints.append([Vector3(x, 0, World.FRONT_Z + 11.0), false])
			waypoints.append([Vector3(x + 6.0, 0, World.ROAD_Z - 2), false])
			waypoints.append([Vector3(far, 0, World.ROAD_Z - 2), false])

func _drive(dt: float) -> bool:
	if waypoints.is_empty():
		return true
	var wp: Array = waypoints[0]
	var tgt: Vector3 = wp[0]
	var rev: bool = wp[1]
	var to := tgt - position
	if kind != "air":
		to.y = 0.0
	var dist := to.length()
	var sp := speed_road
	if kind in ["truck", "van", "police"] and position.z < World.ROAD_Z - 4.0:
		sp = 5.0
	if kind == "air" and position.y < 0.5 and position.x > -80.0:
		sp = 6.0
	if rev:
		sp = 2.5
	if dist < 0.08:
		waypoints.remove_at(0)
		return waypoints.is_empty()
	var dir := to / dist
	var flat := Vector2(dir.x, dir.z)
	var yaw := atan2(dir.x, dir.z) if flat.length() > 0.05 else rotation.y
	if rev:
		yaw += PI
	if kind == "air":
		var diff2 := wrapf(yaw - rotation.y, -PI, PI)
		rotation.y += clampf(diff2, -1.4 * dt, 1.4 * dt)
		# 機頭俯仰：爬升時抬頭、降落時微微抬頭
		model.rotation.x = lerpf(model.rotation.x, -clampf(dir.y * 1.5, -0.12, 0.25), minf(1.0, dt * 2.0))
	if kind in ["truck", "van", "police"]:
		var diff := wrapf(yaw - rotation.y, -PI, PI)
		var tr := 3.5 if not rev else 2.5
		rotation.y += clampf(diff, -tr * dt, tr * dt)
		if rev and waypoints.size() <= 2:
			# 最後倒車段：車身對正碼頭
			rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, dt * 3.0))
	var step := minf(sp * dt, dist)
	# 停車減速
	if waypoints.size() == 1 and dist < 6.0:
		step = minf(maxf(sp * dt * dist / 6.0, 1.0 * dt), dist)
	position += dir * step
	return false

# ── 每幀 ──
func _process(delta: float) -> void:
	var dt := delta * G.speed
	_flash += delta
	for i in lights.size():
		var on := fmod(_flash * 3.0 + i * 0.5, 1.0) < 0.5
		(lights[i] as MeshInstance3D).visible = on
	if dt <= 0.0:
		return
	var dm := dt * G.MIN_PER_SEC
	if kind == "ship" and model:
		model.position.y = sin(_flash * 0.8) * 0.12
		model.rotation.z = sin(_flash * 0.55) * 0.012
	_update_transfers(dt)
	match state:
		"queue":
			queue_min += dm
			if mode == "out":
				dock_min += dm
			_drive(dt)
			if waypoints.is_empty():
				dock = world.claim_dock(kind, self)
				if dock:
					_request_dock_existing()
				elif mode == "in" and queue_min > 360.0 and kind != "van":
					_give_up("沒有空的碼頭")
				else:
					_go_queue()
		"approach":
			if mode == "out":
				dock_min += dm
			if _drive(dt):
				_arrive()
		"docked":
			_docked(dm)
		"leaving":
			if _drive(dt):
				world.vehicles.erase(self)
				queue_free()
		"police":
			_drive(dt)

func _request_dock_existing() -> void:
	var d = dock
	dock = null
	d.claimed_by = null
	_request_dock()

func _arrive() -> void:
	dock.vehicle = self
	state = "docked"
	if kind == "van":
		state = "decide"
		G.set_speed(0.0)
		get_tree().call_group("hud", "mystery_arrival", self)

func _docked(dm: float) -> void:
	var c := G.contract_by_id(cid)
	if c.is_empty():
		_depart()
		return
	if mode == "in":
		if left <= 0 and transfers.is_empty():
			if int(c.unloaded) >= int(c.n):
				c.state = "stored"
			G.contracts_changed.emit()
			_depart()
			return
		if left > 0 and transfers.is_empty():
			var i: int = dock.pad_free_index()
			if i >= 0:
				left -= 1
				c.unloaded = int(c.unloaded) + 1
				var p := world.new_pallet(cargo, cid)
				p.state = "veh"
				dock.pad_res[i] = true
				_start_transfer(p, _path_in(i), i, true)
				stall = 0.0
				G.contracts_changed.emit()
			else:
				stall += dm
				if stall > 300.0:
					_give_up("等太久沒人卸貨")
	else:
		dock_min += dm
		if dock_min > 180.0 and not c.mystery:
			var pen := int(int(c.pay) * 0.05 * dm / 60.0)
			c.late_pen = mini(int(c.late_pen) + pen, int(int(c.pay) * 0.5))
		if transfers.is_empty():
			for i in 2:
				var p = dock.pad[i]
				if p != null and p.cid == cid and p.state == "pad_out" and not p.claimed and got + transfers.size() < target:
					dock.pad[i] = null
					p.state = "veh"
					_start_transfer(p, _path_in(i).duplicate(), i, false)
					break
		if transfers.is_empty() and int(c.loaded) < int(c.unloaded):
			var exists := false
			for p in world.pallets:
				if p.cid == cid:
					exists = true
					break
			if not exists:
				c.unloaded = int(c.loaded)
		if transfers.is_empty() and int(c.loaded) >= int(c.unloaded):
			G.finish_contract(c)
			_depart()
		elif transfers.is_empty() and got >= target:
			G.toast.emit("%s 的第一批貨已出車，下一台馬上來。" % c.client if int(c.loaded) <= target else "%s 又出了一車，還剩 %d 板。" % [c.client, int(c.unloaded) - int(c.loaded)], "info")
			_depart()

func _path_in(i: int) -> Array:
	var pad: Vector3 = dock.pad_pos(i)
	match kind:
		"rail":
			var wx := position.x - 10.0
			return [Vector3(wx, 1.6, World.RAIL_Z), Vector3(pad.x, 1.0, -1.8), pad]
		"ship":
			var hx: float = pad.x
			return [Vector3(position.x, 4.2, World.SHIP_Z + 1.0), Vector3(hx, 6.0, World.SHIP_Z + 1.0), Vector3(hx, 5.5, -15.5), Vector3(hx, 5.5, -0.8), Vector3(hx, 1.2, -0.2), pad]
		"air":
			return [Vector3(position.x + 8.2, 2.6, position.z - 2.6), Vector3(-5.5, 2.4, position.z - 3.5), Vector3(-5.0, 2.4, pad.z), Vector3(-2.5, 2.3, pad.z), Vector3(-1.0, 0.6, pad.z), pad]
		_:
			var rear: Vector3 = pad + dock.out_dir * 2.4
			return [rear + Vector3(0, 1.1, 0), rear + Vector3(0, 0.4, -1.2), pad]

func _start_transfer(p, path: Array, i: int, inbound: bool) -> void:
	if not inbound:
		path.reverse()
	p.node.global_position = path[0]
	transfers.append({"p": p, "path": path, "t": 0.0, "i": i, "in": inbound})

func _update_transfers(dt: float) -> void:
	for k in range(transfers.size() - 1, -1, -1):
		var tr: Dictionary = transfers[k]
		var path: Array = tr.path
		var segs := path.size() - 1
		var dur := 1.0 + segs * 0.5
		if kind == "ship":
			dur = 4.0
		elif kind == "air":
			dur = 2.6
		tr.t = float(tr.t) + dt / dur
		var t := clampf(float(tr.t), 0.0, 1.0)
		var f := t * segs
		var si := mini(int(f), segs - 1)
		var lt := f - si
		var p = tr.p
		if is_instance_valid(p.node):
			p.node.global_position = (path[si] as Vector3).lerp(path[si + 1], lt)
		if t >= 1.0:
			transfers.remove_at(k)
			if tr["in"]:
				dock.pad_res[tr.i] = false
				dock.pad[tr.i] = p
				p.dock = dock
				p.pad_i = tr.i
				p.state = "pad_in"
				p.node.global_position = dock.pad_pos(tr.i)
			else:
				var c := G.contract_by_id(cid)
				got += 1
				if not c.is_empty():
					c.loaded = int(c.loaded) + 1
					G.contracts_changed.emit()
				world.drop_pallet(p)

func _depart() -> void:
	if state == "leaving":
		return
	state = "leaving"
	var c := G.contract_by_id(cid)
	if not c.is_empty():
		if mode == "in":
			c["veh_in"] = false
			c["next_in"] = G.minute + 15.0
		else:
			c["veh_out"] = false
			c["next_out"] = G.minute + 15.0
	world.release_dock(dock)
	dock = null
	_leave_route()

func _give_up(why: String) -> void:
	var c := G.contract_by_id(cid)
	if c.is_empty():
		_depart()
		return
	var refused := int(c.n) - int(c.unloaded)
	var old_n := int(c.n)
	left = 0
	if mode == "in":
		c.n = int(c.unloaded)
		if int(c.unloaded) == 0:
			G.contracts.erase(c)
			G.fail_contract(c, "%s %s，整批貨轉給別家倉庫了。" % [c.client, why], 8.0)
		else:
			c.pay = int(int(c.pay) * float(c.unloaded) / float(old_n))
			c.state = "stored"
			G.fail_contract(c, "%s %s，帶著 %d 板貨離開了。" % [c.client, why, refused], 6.0)
	_depart()

# ── 不明貨箱：決定 ──
func observe() -> String:
	observed = true
	G.minute += 30.0
	var sus := randf() < (0.7 if is_cop else 0.25)
	var arr: Array = SUSPICIOUS if sus else NORMAL
	return arr[randi() % arr.size()]

func decide(accept: bool) -> void:
	var c := G.contract_by_id(cid)
	if accept:
		if is_cop:
			_raid()
			return
		state = "docked"
		G.set_speed(G.speed_before_pause)
		return
	# 拒收
	G.set_speed(G.speed_before_pause)
	if not c.is_empty():
		G.contracts.erase(c)
		G.contracts_changed.emit()
		for p in world.pallets.duplicate():
			if p.cid == cid:
				if p.rack:
					p.rack.slots[p.slot] = null
				world.drop_pallet(p)
		world.refresh_capacity()
	if is_cop:
		G.heat = maxf(0.0, G.heat - 0.5)
		G.toast.emit("廂型車悻悻然開走了……後來聽說那是便衣警察。好險！", "good")
	else:
		var fine := int(c.get("advance", 1000)) * 2
		G.heat += 0.3
		G.money -= fine
		G.money_changed.emit()
		G.toast.emit("對方很不爽，派人來收「損失費」%s。" % G.fmt(fine), "bad")
	_depart()

func _raid() -> void:
	state = "raid"
	Snd.play("siren")
	G.set_speed(1.0)
	get_tree().call_group("main", "start_raid", self)
