extends Node3D
## 主場景：遊戲流程、建造模式、依委託產生車輛、警方臨檢。

static var pending := ""        # "" = 標題畫面、"new"、"load"

var world: World
var wfx: WeatherFX
var cam: IsoCam
var hud: Hud
var build_kind := ""            # rack / cold / fragile / demolish
var build_rot := 0
var ghost: Node3D
var ghost_mesh: MeshInstance3D
var ghost_cell := Vector2i(-99, -99)
var _press_pos := Vector2.ZERO
var _press_t := 0
var _title_spin := true

func _ready() -> void:
	add_to_group("main")
	world = World.new()
	add_child(world)
	cam = IsoCam.new()
	add_child(cam)
	wfx = WeatherFX.new()
	add_child(wfx)
	wfx.setup(world, cam)
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	_make_ghost()
	var ua := OS.get_cmdline_user_args()
	if pending == "" and "--test" in ua:
		for a in ua:
			if a == "--mode=new":
				pending = "new"
			elif a == "--mode=load":
				pending = "load"
	match pending:
		"new":
			_start_new()
		"load":
			if not _start_load():
				_start_new()
		_:
			_title()
	pending = ""
	if "--test" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tools/autotest.gd"):
		var at: Node = load("res://tools/autotest.gd").new()
		at.set("main", self)
		add_child(at)
	G.game_over.connect(func(_a, _b): build_cancel())

# ── 流程 ──
func _title() -> void:
	G.playing = false
	G.plots = 2
	G.doors = [0, 1, 3]
	G.rail = true
	G.harbour = true
	G.airport = true
	G.minute = 1440.0 + 16.5 * 60.0
	world.rebuild_all()
	for i in 4:
		var r := world.place_rack("rack" if i < 3 else "cold", Vector2i(1 + i * 3, 2), 1, true)
		for s in r.slots.size():
			if randf() < 0.7:
				var p := world.new_pallet("general" if r.kind == "rack" else "cold", 0)
				world._put_in_rack(p, r, s)
	for i in 2:
		_add_forklift(Vector2i(4 + i * 5, 5))
	cam.position = Vector3(16, 0, 10)
	cam.zoom_target = 30.0
	hud.show_title()

func _start_new() -> void:
	G.new_game()
	world.rebuild_all()
	world.place_rack("rack", Vector2i(1, 1), 0, true)
	world.place_rack("rack", Vector2i(1, 4), 0, true)
	_add_forklift(Vector2i(4, 5))
	world.refresh_capacity()
	_begin()
	if not G.tutorial_done:
		hud.show_welcome()

func _start_load() -> bool:
	if not G.load_game():
		return false
	world.rebuild_all()
	world.restore(G.world_snapshot)
	var nf: int = maxi(1, int(G.world_snapshot.get("forklifts", 1)))
	for i in nf:
		_add_forklift(world.nearest_walkable(Vector2i(4 + i, 5)))
	for c in G.contracts:
		if c.state == "inbound" and int(c.n) - int(c.unloaded) <= 0:
			c.state = "stored"
	world.refresh_capacity()
	_begin()
	return true

func _begin() -> void:
	_title_spin = false
	G.playing = true
	_update_bounds()
	cam.position = Vector3(12, 0, 12)
	cam.zoom_target = 34.0
	hud.show_game()
	Snd.start_music()

func restart(mode: String) -> void:
	G.playing = false
	pending = mode
	get_tree().reload_current_scene()

func _update_bounds() -> void:
	var W := world.cols() * World.TILE
	var x0 := -90.0 if G.airport else -30.0
	cam.bounds = Rect2(x0, -25, W + 70 - x0 - 30, 75)

func _add_forklift(c: Vector2i) -> Forklift:
	var f := Forklift.new()
	world.dyn.add_child(f)
	f.setup(world, c)
	world.forklifts.append(f)
	return f

# ── 每幀 ──
func _process(delta: float) -> void:
	if _title_spin:
		cam.yaw_target += delta * 0.05
		return
	if not G.playing or G.over:
		return
	# 依委託派車：一趟裝不完就分批，一次一台
	for c in G.contracts.duplicate():
		if c.state in ["booked", "inbound"] and G.minute >= float(c.arrive) and not c.get("veh_in", false) \
				and int(c.unloaded) < int(c.n) and G.minute >= float(c.get("next_in", 0.0)) and G.transport_ok(c.get("tin", "truck")):
			c["veh_in"] = true
			c.state = "inbound"
			_spawn(c, "in")
			G.contracts_changed.emit()
		elif c.state in ["stored", "outbound"] and G.minute >= float(c.pickup) and not c.get("veh_out", false) \
				and int(c.loaded) < int(c.unloaded) and G.customs_released(c) and G.minute >= float(c.get("next_out", 0.0)) and G.transport_ok(c.get("tout", "truck")):
			c["veh_out"] = true
			c.state = "outbound"
			_spawn(c, "out")
			G.contracts_changed.emit()
	_update_ghost()

func _spawn(c: Dictionary, mode: String) -> void:
	var v := Vehicle.new()
	world.dyn.add_child(v)
	world.vehicles.append(v)
	v.setup(world, c, mode)
	if c.get("tin", "truck") in ["truck", "van"] and randf() < 0.3:
		Snd.play("horn", 0.4)

# ── 建造 ──
func _make_ghost() -> void:
	ghost = Node3D.new()
	add_child(ghost)
	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.mesh = BoxMesh.new()
	ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(ghost_mesh)
	ghost.visible = false

func build_start(kind: String) -> void:
	build_kind = kind
	ghost.visible = false
	ghost_cell = Vector2i(-99, -99)
	cam.touch_pan_enabled = true
	hud.show_build_hint(kind)

func build_cancel() -> void:
	build_kind = ""
	ghost.visible = false
	hud.hide_build_hint()

func build_rotate() -> void:
	build_rot = 1 - build_rot
	ghost_cell = Vector2i(-99, -99)
	_update_ghost()

func _update_ghost() -> void:
	if build_kind == "":
		return
	var mp := get_viewport().get_mouse_position()
	_ghost_at(mp)

func _ghost_at(screen: Vector2) -> void:
	var gp = cam.ground_point(screen)
	if gp == null:
		ghost.visible = false
		return
	var p: Vector3 = gp
	if build_kind == "demolish":
		var c := world.world_to_cell(p)
		var r = world.occ.get(c, null)
		ghost.visible = r != null
		if r:
			var cells: Array = r.cells()
			var a: Vector3 = world.cell_center(cells[0])
			var b: Vector3 = world.cell_center(cells[1])
			ghost.position = (a + b) / 2.0
			(ghost_mesh.mesh as BoxMesh).size = Vector3(absf(b.x - a.x) + 2.0, 4.2, absf(b.z - a.z) + 2.0)
			ghost_mesh.position = Vector3(0, 2.1, 0)
			ghost_mesh.material_override = M.mat(Color(1, 0.3, 0.25, 0.35))
		return
	# 以兩格中心對齊滑鼠
	var c := Vector2i(floori(p.x / World.TILE - 0.5), floori(p.z / World.TILE))
	if build_rot == 1:
		c = Vector2i(floori(p.x / World.TILE), floori(p.z / World.TILE - 0.5))
	if c == ghost_cell and ghost.visible:
		return
	ghost_cell = c
	ghost.visible = true
	var ok := world.can_place(c, build_rot)
	var size := Vector3(4.0, 0.3, 2.0) if build_rot == 0 else Vector3(2.0, 0.3, 4.0)
	(ghost_mesh.mesh as BoxMesh).size = size
	ghost_mesh.position = Vector3(0, 0.2, 0)
	ghost_mesh.material_override = M.mat(Color(0.3, 0.95, 0.45, 0.5) if ok else Color(1, 0.3, 0.25, 0.5))
	if build_rot == 0:
		ghost.position = Vector3((c.x + 1) * World.TILE, 0, (c.y + 0.5) * World.TILE)
	else:
		ghost.position = Vector3((c.x + 0.5) * World.TILE, 0, (c.y + 1) * World.TILE)

func _try_place(screen: Vector2) -> void:
	_ghost_at(screen)
	if build_kind == "demolish":
		var gp = cam.ground_point(screen)
		if gp == null:
			return
		var r = world.occ.get(world.world_to_cell(gp), null)
		if r == null:
			return
		if r.used() > 0:
			G.toast.emit("貨架上還有貨，清空才能拆除", "bad")
			Snd.play("error")
			return
		var refund := G.price(int(G.BUILD[r.kind].price)) / 2
		if world.remove_rack(r):
			G.earn(refund, "拆除%s，退回" % G.BUILD[r.kind].name)
			world.refresh_capacity()
			Snd.play("build")
		ghost.visible = false
		return
	if not world.can_place(ghost_cell, build_rot):
		G.toast.emit("這裡不能擺（超出倉庫、壓到別的東西或碼頭作業區）", "bad")
		Snd.play("error")
		return
	var d: Dictionary = G.BUILD[build_kind]
	if not G.spend(G.price(int(d.price))):
		return
	var r = world.place_rack(build_kind, ghost_cell, build_rot)
	world.refresh_capacity()
	var kind := build_kind
	G.undo_offer.emit("已建造%s　%s" % [d.name, G.fmt(G.price(int(d.price)))], G.price(int(d.price)), func():
		if r in world.racks and world.remove_rack(r):
			G.money += G.price(int(G.BUILD[kind].price))
			G.money_changed.emit()
			world.refresh_capacity()
			return true
		return false)
	ghost_cell = Vector2i(-99, -99)

# ── 購買 ──
func buy_forklift() -> void:
	if not G.spend(G.price(G.FORKLIFT_PRICE)):
		return
	var f := _add_forklift(world.nearest_walkable(Vector2i(4, 5)))
	world.refresh_capacity()
	Snd.play("build")
	cam.focus(f.position)
	G.undo_offer.emit("已購買堆高機　%s" % G.fmt(G.price(G.FORKLIFT_PRICE)), G.price(G.FORKLIFT_PRICE), func():
		if f.is_idle() and f in world.forklifts and world.forklifts.size() > 1:
			world.forklifts.erase(f)
			f.queue_free()
			G.money += G.price(G.FORKLIFT_PRICE)
			G.money_changed.emit()
			world.refresh_capacity()
			return true
		return false)

func next_door() -> int:
	for gi in G.plots * 3:
		if not (gi in G.doors):
			return gi
	return -1

func buy_door() -> void:
	var gi := next_door()
	if gi < 0:
		G.toast.emit("所有門都開了，先買隔壁的地", "bad")
		return
	if not G.spend(G.price(G.DOOR_PRICE)):
		return
	G.doors.append(gi)
	G.doors.sort()
	_rebuild_property()
	G.toast.emit("開了 %d 號碼頭門" % (gi + 1), "good")

func buy_plot() -> void:
	if G.plots >= G.PLOT_PRICES.size():
		return
	var price: int = G.price(G.PLOT_PRICES[G.plots])
	if not G.spend(price):
		return
	G.plots += 1
	G.doors.append((G.plots - 1) * 3 + 1)
	G.doors.sort()
	_rebuild_property()
	_update_bounds()
	cam.focus(Vector3((G.plots - 0.5) * World.PW * World.TILE, 0, 10))
	G.toast.emit("買下隔壁的地！倉庫變大了，還附一扇碼頭門。", "good")
	Snd.play("fanfare")

func buy_rail() -> void:
	if not _door_clear("rail"):
		return
	if G.rail or not G.spend(G.price(G.RAIL_PRICE)):
		return
	G.rail = true
	_rebuild_property()
	cam.focus(Vector3(8, 0, -2), 40.0)
	G.toast.emit("鐵路支線通車！之後會有火車的大宗委託。", "good")
	Snd.play("fanfare")

func _door_clear(what: String) -> bool:
	var bad: Array = world.blocked_cells(world.door_cells(what))
	if bad.is_empty():
		return true
	var c: Vector2i = bad[0]
	G.toast.emit("新門口的位置（第 %d 欄、第 %d 列）被貨架擋住了，請先拆掉那座貨架再擴建。" % [c.x + 1, c.y + 1], "bad")
	Snd.play("error")
	cam.focus(world.cell_center(c), 26.0)
	return false

func buy_airport() -> void:
	if not _door_clear("air"):
		return
	if G.airport or not G.spend(G.price(G.AIRPORT_PRICE)):
		return
	G.airport = true
	_rebuild_property()
	_update_bounds()
	cam.focus(Vector3(-30, 0, 12), 50.0)
	G.toast.emit("航空貨運站啟用！貨機會帶來高價值的國際空運貨。", "good")
	Snd.play("fanfare")

func buy_harbour() -> void:
	if not _door_clear("harbour"):
		return
	if G.harbour or not G.spend(G.price(G.HARBOUR_PRICE)):
		return
	G.harbour = true
	_rebuild_property()
	cam.focus(Vector3(15, 0, -8), 50.0)
	G.toast.emit("港口啟用！貨輪的委託會開始出現。", "good")
	Snd.play("fanfare")

func _rebuild_property() -> void:
	world.rebuild_all()
	world.refresh_capacity()
	for f in world.forklifts:
		f.unstick()
	G.property_changed.emit()
	G.save_game()

# ── 事件（截獲歹徒、查獲夾帶）──
var _incident_busy := false

func start_incident(kind: String, target: Vector3, headline: String, suspects: int, door: Vector3, on_done: Callable) -> void:
	if _incident_busy:
		on_done.call()
		return
	_incident_busy = true
	build_cancel()
	hud.close_modal()
	var resume := G.speed if G.speed > 0.0 else G.speed_before_pause
	G.set_speed(0.0)
	var inc := Incident.new()
	add_child(inc)
	inc.setup(world, cam, hud)
	hud.cinematic(true)
	inc.tree_exited.connect(func():
		_incident_busy = false
		hud.cinematic(false)
		if not G.over:
			G.set_speed(resume)
		on_done.call())
	inc.run(kind, target, headline, suspects, door)

func door_point_near(p: Vector3) -> Vector3:
	var best := Vector3(world.cell_center(Vector2i(2, World.PD - 1)).x, 0, World.FRONT_Z)
	var bd := 1e9
	for d in world.docks:
		if d.kind == "truck":
			var dp := Vector3(world.cell_center(d.cell).x, 0, World.FRONT_Z)
			if dp.distance_to(p) < bd:
				bd = dp.distance_to(p)
				best = dp
	return best

# ── 警方臨檢（自己被抓）──
func start_raid(van: Vehicle) -> void:
	start_incident("raid", van.position, "【新聞快報】警方在小柯物流攔查可疑廂型車，特勤人員持槍包圍", 2, Vector3.INF, func():
		G.trigger_game_over("警方臨檢，人贓俱獲", "那台廂型車的司機亮出了警徽。\n不明貨箱被當場查扣，倉庫被查封，所有財產都沒收了。\n\n你經營了 %d 天，總共收入 %s。" % [G.day(), G.fmt(int(G.stats.earned))]))

func _old_raid(van: Vehicle) -> void:
	build_cancel()
	cam.focus(van.position, 26.0)
	for i in 3:
		var pv := Vehicle.new()
		pv.world = world
		pv.kind = "police"
		pv.model = M.vehicle_model("police", 4.4)
		pv.add_child(pv.model)
		var red := M.box(pv, Vector3(0.4, 0.15, 0.25), Vector3(-0.3, 1.75, 0), Color(1, 0.1, 0.1))
		red.material_override = M.mat(Color(1, 0.15, 0.15), 4.0)
		var blue := M.box(pv, Vector3(0.4, 0.15, 0.25), Vector3(0.3, 1.75, 0), Color(0.1, 0.3, 1))
		blue.material_override = M.mat(Color(0.2, 0.4, 1.0), 4.0)
		pv.lights = [red, blue]
		pv.position = Vector3(van.position.x - 40 - i * 9.0, 0, World.ROAD_Z - 2)
		pv.rotation.y = PI / 2
		pv.speed_road = 18.0
		pv.state = "police"
		pv.waypoints = [[Vector3(van.position.x - 8 + i * 6.0, 0, World.ROAD_Z - 2), false], [Vector3(van.position.x - 6 + i * 6.0, 0, van.position.z + 7.0 + (i % 2) * 2.0), false]]
		world.dyn.add_child(pv)
	await get_tree().create_timer(4.5).timeout
	G.trigger_game_over("警方臨檢，人贓俱獲", "那台廂型車的司機亮出了警徽。\n不明貨箱被當場查扣，倉庫被查封，所有財產都沒收了。\n\n你經營了 %d 天，總共收入 %s。" % [G.day(), G.fmt(int(G.stats.earned))])

# ── 輸入 ──
func _unhandled_input(e: InputEvent) -> void:
	if not G.playing:
		return
	if (e is InputEventScreenTouch or e is InputEventScreenDrag) and hud.over_ui(e.position) and not cam.touches.has(e.index):
		return
	if cam.handle_input(e):
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		match k:
			KEY_SPACE:
				G.toggle_pause()
			KEY_1:
				G.set_speed(1.0)
			KEY_2:
				G.set_speed(2.0)
			KEY_3:
				G.set_speed(4.0)
			KEY_R:
				if build_kind != "":
					build_rotate()
			KEY_ESCAPE:
				if build_kind != "":
					build_cancel()
				else:
					hud.toggle_menu()
		return
	if (e is InputEventMouseButton or e is InputEventMouseMotion) and e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and build_kind != "":
			_press_pos = mb.position
		if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and build_kind != "":
			if mb.position.distance_to(_press_pos) < 6.0:
				build_cancel()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_press_t = Time.get_ticks_msec()
			elif mb.position.distance_to(_press_pos) < 10.0:
				_click(mb.position)
	elif e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.index != 0:
			return
		if st.pressed:
			_press_pos = st.position
			_press_t = Time.get_ticks_msec()
		elif st.position.distance_to(_press_pos) < 14.0 and Time.get_ticks_msec() - _press_t < 600:
			_click(st.position)
	elif e is InputEventMouseMotion and (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT and build_kind == "":
		cam.pan_pixels((e as InputEventMouseMotion).relative)

func _click(pos: Vector2) -> void:
	if build_kind != "":
		_try_place(pos)
		return
	# 點車輛或貨架看資訊
	var best = null
	var bd := 50.0
	for v in world.vehicles:
		if not is_instance_valid(v) or v.kind == "police":
			continue
		var sp := cam.cam.unproject_position(v.global_position + Vector3(0, 1.5, 0))
		var d := sp.distance_to(pos)
		if d < bd:
			bd = d
			best = v
	if best:
		hud.show_vehicle_info(best)
		return
	var gp = cam.ground_point(pos)
	if gp != null:
		var r = world.occ.get(world.world_to_cell(gp), null)
		if r:
			hud.show_rack_info(r)
			return
	hud.hide_info()
