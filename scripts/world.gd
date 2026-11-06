class_name World
extends Node3D
## 場地、網格、碼頭、貨架、托盤與堆高機調度。

const TILE := 2.0
const PW := 10          # 每塊地寬（格）
const PD := 8           # 倉庫深（格）
const FRONT_Z := 16.0
const ROAD_Z := 37.0
const RAIL_Z := -4.5
const SHIP_Z := -18.0
const DOOR_OFFS := [2, 5, 8]
const RAIL_CELL := Vector2i(3, 0)
const HARBOUR_CELL := Vector2i(7, 0)

class Pallet:
	var node: Node3D
	var cargo: String
	var cid: int
	var state: String = "veh"      # veh / pad_in / pad_out / fork / rack
	var claimed: bool = false
	var rack = null
	var slot: int = -1
	var dock = null
	var pad_i: int = -1

class Rack:
	var id: int
	var kind: String
	var cell: Vector2i
	var rot: int
	var node: Node3D
	var slots: Array = []
	var reserved: Array = []
	func cells() -> Array:
		if rot == 0:
			return [cell, cell + Vector2i(1, 0)]
		return [cell, cell + Vector2i(0, 1)]
	func free_count() -> int:
		var n := 0
		for i in slots.size():
			if slots[i] == null and not reserved[i]:
				n += 1
		return n
	func used() -> int:
		var n := 0
		for s in slots:
			if s != null:
				n += 1
		return n

class Dock:
	var id: int
	var kind: String           # truck / rail / harbour
	var cell: Vector2i
	var out_dir: Vector3       # 指向牆外
	var pad: Array = [null, null]
	var pad_res: Array = [false, false]
	var vehicle = null
	var claimed_by = null
	var node: Node3D
	var shutter: Node3D
	var number: int = 0
	func pad_pos(i: int) -> Vector3:
		var c := Vector3((cell.x + 0.5) * 2.0, 0.0, (cell.y + 0.5) * 2.0)
		return c + out_dir * (-0.5 + i * 1.0)
	func inner_cell() -> Vector2i:
		return cell - Vector2i(int(out_dir.x), int(out_dir.z))
	func pad_free_index() -> int:
		for i in 2:
			if pad[i] == null and not pad_res[i]:
				return i
		return -1

var astar := AStarGrid2D.new()
var racks: Array = []
var docks: Array = []
var forklifts: Array = []
var vehicles: Array = []
var pallets: Array = []
var occ: Dictionary = {}          # Vector2i -> Rack
var env: Node3D
var dyn: Node3D
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var lamp_mats: Array = []
var _next_rack := 1
var _dispatch_t := 0.0
var _plot_signs: Array = []

func _ready() -> void:
	add_to_group("world")
	M.init_fonts()
	env = Node3D.new()
	add_child(env)
	dyn = Node3D.new()
	add_child(dyn)
	_make_lights()

# ── 座標 ──
func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * TILE, 0.0, (c.y + 0.5) * TILE)

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.z / TILE))

func cols() -> int:
	return G.plots * PW

func in_floor(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols() and c.y < PD

func reserved_cell(c: Vector2i) -> bool:
	for d in docks:
		if d.cell == c or d.inner_cell() == c:
			return true
	# 所有前門位置（含未開）與鐵路／港口門位置保留
	for p in G.plots:
		for o in DOOR_OFFS:
			var dc := Vector2i(p * PW + o, PD - 1)
			if c == dc or c == dc + Vector2i(0, -1):
				return true
	for dc in [RAIL_CELL, HARBOUR_CELL]:
		if c == dc or c == dc + Vector2i(0, 1):
			return true
	return false

# ── 建置整個場景 ──
func rebuild_all() -> void:
	_rebuild_docks()
	_rebuild_env()
	_rebuild_grid()

func _rebuild_grid() -> void:
	astar.region = Rect2i(0, 0, cols(), PD)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for r in racks:
		for c in r.cells():
			astar.set_point_solid(c, true)

func _rebuild_docks() -> void:
	var old := {}
	for d in docks:
		old[_dock_key(d.kind, d.cell)] = d
	var list: Array = []
	var num := 1
	for p in G.plots:
		for i in 3:
			var gi := p * 3 + i
			var c := Vector2i(p * PW + DOOR_OFFS[i], PD - 1)
			if gi in G.doors:
				var d: Dock = old.get(_dock_key("truck", c), null)
				if d == null:
					d = Dock.new()
					d.kind = "truck"
					d.cell = c
					d.out_dir = Vector3(0, 0, 1)
				d.number = num
				list.append(d)
			num += 1
	if G.rail:
		var d: Dock = old.get(_dock_key("rail", RAIL_CELL), null)
		if d == null:
			d = Dock.new()
			d.kind = "rail"
			d.cell = RAIL_CELL
			d.out_dir = Vector3(0, 0, -1)
		list.append(d)
	if G.harbour:
		var d: Dock = old.get(_dock_key("harbour", HARBOUR_CELL), null)
		if d == null:
			d = Dock.new()
			d.kind = "harbour"
			d.cell = HARBOUR_CELL
			d.out_dir = Vector3(0, 0, -1)
		list.append(d)
	for i in list.size():
		list[i].id = i
	docks = list

func _dock_key(k: String, c: Vector2i) -> String:
	return "%s:%d:%d" % [k, c.x, c.y]

func _make_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.light_energy = 1.0
	add_child(sun)
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.75, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.9)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_env.environment = e
	add_child(world_env)

func update_daylight() -> void:
	var h := G.hour()
	# 0 = 深夜，1 = 正午
	var day_f := clampf(sin((h - 6.0) / 12.0 * PI) * 1.4, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(h - 18.5) / 1.6, 0.0, 1.0) + clampf(1.0 - absf(h - 6.0) / 1.4, 0.0, 1.0)
	sun.light_energy = lerpf(0.1, 0.78, day_f)
	sun.light_color = Color(1, 1, 1).lerp(Color(1.0, 0.7, 0.45), clampf(dusk, 0.0, 1.0)).lerp(Color(0.6, 0.7, 1.0), 1.0 - day_f)
	sun.rotation_degrees.y = -38.0 + (h - 12.0) * 4.0
	var e := world_env.environment
	e.ambient_light_energy = lerpf(0.3, 0.42, day_f)
	e.ambient_light_color = Color(0.86, 0.88, 0.92).lerp(Color(0.45, 0.52, 0.85), 1.0 - day_f)
	e.background_color = Color(0.42, 0.62, 0.45).lerp(Color(0.08, 0.11, 0.18), 1.0 - day_f)
	var night := day_f < 0.35
	for m in lamp_mats:
		(m as StandardMaterial3D).emission_energy_multiplier = 1.6 if night else 0.0

# ── 環境 ──
func _rebuild_env() -> void:
	for ch in env.get_children():
		ch.queue_free()
	lamp_mats.clear()
	var W := cols() * TILE
	var grass := Color(0.42, 0.6, 0.34)
	var asphalt := Color(0.34, 0.34, 0.35)
	# 草地
	M.box(env, Vector3(600, 0.2, 400), Vector3(60, -0.12, 0), grass, false)
	# 海
	var sea := M.box(env, Vector3(600, 0.2, 200), Vector3(60, -0.6, -112), Color(0.25, 0.55, 0.78), false)
	sea.material_override = M.mat(Color(0.28, 0.58, 0.8), 0.0, 0.25)
	M.box(env, Vector3(600, 0.8, 1.0), Vector3(60, -0.3, -12.5), Color(0.62, 0.6, 0.55), false)
	# 道路
	M.box(env, Vector3(600, 0.04, 9.0), Vector3(60, 0.0, ROAD_Z), asphalt, false)
	M.box(env, Vector3(600, 0.05, 1.6), Vector3(60, 0.0, ROAD_Z - 5.3), Color(0.8, 0.78, 0.72), false)
	M.box(env, Vector3(600, 0.05, 1.6), Vector3(60, 0.0, ROAD_Z + 5.3), Color(0.8, 0.78, 0.72), false)
	for i in 60:
		M.box(env, Vector3(3.0, 0.05, 0.25), Vector3(-240 + i * 10.0, 0.01, ROAD_Z), Color(0.95, 0.95, 0.9), false)
	# 停車場（只在自己的地前面）
	M.box(env, Vector3(W + 8.0, 0.045, 15.0), Vector3(W / 2.0, 0.0, FRONT_Z + 8.5), asphalt.lightened(0.05), false)
	for d in docks:
		if d.kind == "truck":
			var x := cell_center(d.cell).x
			for s in [-1.6, 1.6]:
				M.box(env, Vector3(0.15, 0.05, 9.0), Vector3(x + s, 0.012, FRONT_Z + 5.0), Color(0.98, 0.8, 0.2), false)
	# 室內地板
	M.box(env, Vector3(W, 0.1, PD * TILE), Vector3(W / 2.0, 0.0, PD), Color(0.7, 0.66, 0.6), false)
	for c in cols():
		M.box(env, Vector3(0.04, 0.11, PD * TILE), Vector3(c * TILE, 0.0, PD), Color(0.82, 0.78, 0.7), false)
	for r in PD:
		M.box(env, Vector3(W, 0.11, 0.04), Vector3(W / 2.0, 0.0, r * TILE), Color(0.82, 0.78, 0.7), false)
	# 碼頭作業區斑馬紋
	for d in docks:
		var ic: Vector2i = d.inner_cell()
		for cc in [d.cell, ic]:
			var cp := cell_center(cc)
			M.box(env, Vector3(1.9, 0.115, 1.9), cp, Color(0.95, 0.85, 0.35), false)
			for k in 3:
				M.box(env, Vector3(1.9, 0.12, 0.2), cp + Vector3(0, 0, -0.6 + k * 0.6), Color(0.25, 0.25, 0.25), false)
	_build_walls(W)
	_build_extras(W)
	_scatter_trees(W)
	_build_lamps(W)
	update_daylight()

func _build_walls(W: float) -> void:
	var wall := Color(0.62, 0.74, 0.8)
	var trim := Color(0.85, 0.42, 0.28)
	var h := 4.2
	var t := 0.3
	# 後牆（留鐵路／港口門）
	var back_gaps: Array = []
	if G.rail:
		back_gaps.append(cell_center(RAIL_CELL).x)
	if G.harbour:
		back_gaps.append(cell_center(HARBOUR_CELL).x)
	_wall_run(Vector3(0, 0, 0), Vector3(W, 0, 0), back_gaps, h, t, wall, trim)
	_wall_run(Vector3(0, 0, 0), Vector3(0, 0, FRONT_Z), [], h, t, wall, trim)
	_wall_run(Vector3(W, 0, 0), Vector3(W, 0, FRONT_Z), [], h, t, wall, trim)
	# 前牆：每個門位都有門框，未開的拉下鐵捲門
	var gaps: Array = []
	var num := 1
	for p in G.plots:
		for i in 3:
			var x := cell_center(Vector2i(p * PW + DOOR_OFFS[i], 0)).x
			gaps.append(x)
			var open := (p * 3 + i) in G.doors
			var fr := Node3D.new()
			fr.position = Vector3(x, 0, FRONT_Z)
			env.add_child(fr)
			M.box(fr, Vector3(0.25, h, 0.5), Vector3(-1.45, h / 2, 0), Color(0.3, 0.32, 0.36))
			M.box(fr, Vector3(0.25, h, 0.5), Vector3(1.45, h / 2, 0), Color(0.3, 0.32, 0.36))
			M.box(fr, Vector3(3.1, h - 3.2, t), Vector3(0, (h + 3.2) / 2, 0), wall)
			M.box(fr, Vector3(3.15, 0.25, 0.55), Vector3(0, 3.2, 0), Color(0.3, 0.32, 0.36))
			if open:
				M.box(fr, Vector3(2.7, 0.35, 0.3), Vector3(0, 2.95, 0), Color(0.55, 0.6, 0.66))
				M.box(fr, Vector3(2.6, 0.25, 0.9), Vector3(0, 0.12, 0.5), Color(0.4, 0.42, 0.45))
				for s in [-1.25, 1.25]:
					M.box(fr, Vector3(0.18, 1.0, 0.18), Vector3(s, 0.5, 0.8), Color(0.95, 0.8, 0.15))
			else:
				for k in 9:
					M.box(fr, Vector3(2.7, 0.32, 0.12), Vector3(0, 0.18 + k * 0.34, 0.05), Color(0.62, 0.66, 0.7) if k % 2 == 0 else Color(0.55, 0.6, 0.64))
			M.label(fr, str(num), Vector3(0, 3.65, 0.17), 90, Color(0.15, 0.2, 0.3), false).billboard = BaseMaterial3D.BILLBOARD_DISABLED
			num += 1
	_wall_run(Vector3(0, 0, FRONT_Z), Vector3(W, 0, FRONT_Z), gaps, h, t, wall, trim, 1.6)
	# 招牌
	var sign := Node3D.new()
	sign.position = Vector3(3.0, h + 0.9, FRONT_Z + 0.2)
	env.add_child(sign)
	M.box(sign, Vector3(5.6, 1.5, 0.2), Vector3(0, 0, 0), Color(0.15, 0.3, 0.55))
	var lb := M.label(sign, "小柯物流", Vector3(0, 0.05, 0.12), 110, Color(1, 0.92, 0.5), false)
	lb.billboard = BaseMaterial3D.BILLBOARD_DISABLED

func _wall_run(a: Vector3, b: Vector3, gaps: Array, h: float, t: float, col: Color, trim: Color, gap_half := 1.6) -> void:
	var along_x := absf(b.x - a.x) > 0.01
	var length := (b - a).length()
	var cuts: Array = []
	for g in gaps:
		var s: float = (g - (a.x if along_x else a.z))
		cuts.append([s - gap_half, s + gap_half])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var pos := 0.0
	var segs: Array = []
	for c in cuts:
		if c[0] > pos:
			segs.append([pos, c[0]])
		pos = c[1]
	if pos < length:
		segs.append([pos, length])
	for s in segs:
		var l: float = s[1] - s[0]
		if l < 0.05:
			continue
		var mid: float = (s[0] + s[1]) / 2.0
		var center := a + (b - a).normalized() * mid
		var size := Vector3(l, h, t) if along_x else Vector3(t, h, l)
		M.box(env, size, center + Vector3(0, h / 2, 0), col)
		var ts := Vector3(l, 0.3, t + 0.06) if along_x else Vector3(t + 0.06, 0.3, l)
		M.box(env, ts, center + Vector3(0, h - 0.15, 0), trim)
		# 波浪板線條
		var n := int(l / 0.8)
		for k in n:
			var off := -l / 2 + 0.4 + k * 0.8
			var lp := center + ((Vector3(off, h / 2 - 0.1, t / 2 + 0.01)) if along_x else Vector3(t / 2 + 0.01, h / 2 - 0.1, off))
			M.box(env, Vector3(0.05, h - 0.4, 0.02) if along_x else Vector3(0.02, h - 0.4, 0.05), lp, col.darkened(0.08), false)

func _build_extras(W: float) -> void:
	# 鐵道（買了才鋪新軌，沒買是生鏽舊軌）
	var rail_c := Color(0.5, 0.5, 0.52) if G.rail else Color(0.5, 0.36, 0.25)
	M.box(env, Vector3(600, 0.15, 3.2), Vector3(60, 0.0, RAIL_Z), Color(0.55, 0.5, 0.45), false)
	for i in 200:
		M.box(env, Vector3(0.35, 0.12, 2.8), Vector3(-240 + i * 3.0, 0.08, RAIL_Z), Color(0.4, 0.3, 0.22), false)
	for z in [-0.75, 0.75]:
		M.box(env, Vector3(600, 0.14, 0.12), Vector3(60, 0.18, RAIL_Z + z), rail_c, false)
	if G.rail:
		var dp := cell_center(RAIL_CELL)
		M.box(env, Vector3(3.0, 0.9, 3.4), Vector3(dp.x, 0.45, -1.8), Color(0.62, 0.62, 0.6))
	else:
		var s := Node3D.new()
		s.position = Vector3(cell_center(RAIL_CELL).x, 0, -2.2)
		env.add_child(s)
		M.box(s, Vector3(0.12, 1.6, 0.12), Vector3(0, 0.8, 0), Color(0.4, 0.3, 0.2))
		M.box(s, Vector3(2.4, 1.0, 0.08), Vector3(0, 1.6, 0), Color(0.95, 0.95, 0.9))
		M.label(s, "鐵路支線
可擴建", Vector3(0, 1.6, 0.06), 30, Color(0.3, 0.2, 0.15), false).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# 港口
	if G.harbour:
		var hx := cell_center(HARBOUR_CELL).x
		M.box(env, Vector3(30, 1.0, 5.0), Vector3(hx, -0.1, -10.5), Color(0.66, 0.65, 0.62))
		for k in 6:
			M.cyl(env, 0.25, 0.6, Vector3(hx - 12 + k * 4.8, 0.6, -12.6), Color(0.25, 0.25, 0.28))
		# 高架輸送帶：碼頭 → 越過鐵道 → 後牆
		var y := 5.2
		M.box(env, Vector3(1.6, 0.25, 15.0), Vector3(hx, y, -6.5), Color(0.25, 0.27, 0.3))
		for k in 15:
			M.box(env, Vector3(1.5, 0.05, 0.6), Vector3(hx, y + 0.15, -13.5 + k * 1.0), Color(0.15, 0.15, 0.16), false)
		for z in [-12.0, -7.5, -1.5]:
			for s in [-0.7, 0.7]:
				M.box(env, Vector3(0.2, y, 0.2), Vector3(hx + s, y / 2, z), Color(0.95, 0.75, 0.15))
		M.box(env, Vector3(2.4, y + 0.6, 0.3), Vector3(hx, (y + 0.6) / 2, -0.7), Color(0.3, 0.32, 0.36))
		# 起重機
		var cr := Node3D.new()
		cr.position = Vector3(hx + 6.0, 0, -10.5)
		env.add_child(cr)
		for s in [-1.5, 1.5]:
			M.box(cr, Vector3(0.5, 12.0, 0.5), Vector3(s, 6.0, 0), Color(0.9, 0.3, 0.2))
		M.box(cr, Vector3(4.0, 0.8, 16.0), Vector3(0, 12.0, -4.0), Color(0.9, 0.3, 0.2))
	else:
		var s2 := Node3D.new()
		s2.position = Vector3(cell_center(HARBOUR_CELL).x, 0, -9.5)
		env.add_child(s2)
		M.box(s2, Vector3(0.12, 1.6, 0.12), Vector3(0, 0.8, 0), Color(0.4, 0.3, 0.2))
		M.box(s2, Vector3(2.4, 1.0, 0.08), Vector3(0, 1.6, 0), Color(0.95, 0.95, 0.9))
		M.label(s2, "港口
可擴建", Vector3(0, 1.6, 0.06), 30, Color(0.15, 0.25, 0.4), false).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# 未買的地：圍籬與「出售」牌
	_plot_signs.clear()
	if G.plots < G.PLOT_PRICES.size():
		var x0 := W
		var x1 := W + PW * TILE
		for k in int((x1 - x0) / 2.0) + 1:
			M.box(env, Vector3(0.1, 1.2, 0.1), Vector3(x0 + k * 2.0, 0.6, FRONT_Z + 1.0), Color(0.5, 0.5, 0.5))
			M.box(env, Vector3(0.1, 1.2, 0.1), Vector3(x0 + k * 2.0, 0.6, -1.0), Color(0.5, 0.5, 0.5))
		M.box(env, Vector3(x1 - x0, 0.06, 0.06), Vector3((x0 + x1) / 2, 1.1, FRONT_Z + 1.0), Color(0.6, 0.6, 0.6))
		M.box(env, Vector3(x1 - x0, 0.06, 0.06), Vector3((x0 + x1) / 2, 1.1, -1.0), Color(0.6, 0.6, 0.6))
		var sg := Node3D.new()
		sg.position = Vector3((x0 + x1) / 2, 0, FRONT_Z + 1.4)
		env.add_child(sg)
		M.box(sg, Vector3(0.15, 2.2, 0.15), Vector3(-1.2, 1.1, 0), Color(0.4, 0.3, 0.2))
		M.box(sg, Vector3(0.15, 2.2, 0.15), Vector3(1.2, 1.1, 0), Color(0.4, 0.3, 0.2))
		M.box(sg, Vector3(3.2, 1.3, 0.1), Vector3(0, 2.0, 0), Color(0.95, 0.3, 0.25))
		var price: int = G.PLOT_PRICES[G.plots]
		M.label(sg, "出售\n%s" % G.fmt(price), Vector3(0, 2.0, 0.07), 40, Color.WHITE, false).billboard = BaseMaterial3D.BILLBOARD_DISABLED

func _scatter_trees(W: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1015
	var files := ["tree_default", "tree_oak", "tree_pineTallA", "tree_pineRoundC", "tree_fat", "plant_bush", "plant_bushLarge"]
	var scenes: Array = []
	for f in files:
		scenes.append(load("res://assets/nature/%s.glb" % f))
	for i in 140:
		var p := Vector3(rng.randf_range(-90, W + 110), 0, rng.randf_range(-11, 70))
		# 避開道路、停車場、倉庫、未買地塊、鐵道
		if absf(p.z - ROAD_Z) < 7.5:
			continue
		if p.x > -6 and p.x < W + PW * TILE + 4 and p.z > -7.5 and p.z < FRONT_Z + 17:
			continue
		if absf(p.z - RAIL_Z) < 3.0:
			continue
		var k := rng.randi() % scenes.size()
		var t: Node3D = (scenes[k] as PackedScene).instantiate()
		t.position = p
		t.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(2.6, 4.2) if k < 5 else rng.randf_range(2.0, 3.0)
		t.scale = Vector3.ONE * s
		env.add_child(t)

func _build_lamps(W: float) -> void:
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.72, 0.72, 0.7)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.85, 0.55)
	lm.emission_energy_multiplier = 0.0
	lamp_mats.append(lm)
	var xs: Array = []
	var x := -60.0
	while x < W + 80.0:
		xs.append(x)
		x += 16.0
	for lx in xs:
		var p := Vector3(lx, 0, ROAD_Z - 6.4)
		M.box(env, Vector3(0.18, 5.0, 0.18), p + Vector3(0, 2.5, 0), Color(0.3, 0.32, 0.35))
		M.box(env, Vector3(0.15, 0.15, 1.4), p + Vector3(0, 5.0, 0.6), Color(0.3, 0.32, 0.35))
		var head := M.box(env, Vector3(0.6, 0.15, 0.4), p + Vector3(0, 4.9, 1.2), Color(1, 1, 1))
		head.material_override = lm
	# 屋內燈條
	for c in range(1, cols(), 3):
		var b := M.box(env, Vector3(0.12, 0.06, PD * TILE - 3.0), Vector3(c * TILE, 4.3, PD), Color(1, 1, 1), false)
		b.material_override = lm

# ── 擺放貨架 ──
func rack_cells(cell: Vector2i, rot: int) -> Array:
	if rot == 0:
		return [cell, cell + Vector2i(1, 0)]
	return [cell, cell + Vector2i(0, 1)]

func can_place(cell: Vector2i, rot: int) -> bool:
	for c in rack_cells(cell, rot):
		if not in_floor(c) or occ.has(c) or reserved_cell(c):
			return false
	return true

func place_rack(kind: String, cell: Vector2i, rot: int, silent := false) -> Rack:
	var r := Rack.new()
	r.id = _next_rack
	_next_rack += 1
	r.kind = kind
	r.cell = cell
	r.rot = rot
	var n: int = G.BUILD[kind].slots
	for i in n:
		r.slots.append(null)
		r.reserved.append(false)
	r.node = M.rack_model(kind)
	if rot == 0:
		r.node.position = Vector3((cell.x + 1) * TILE, 0, (cell.y + 0.5) * TILE)
	else:
		r.node.position = Vector3((cell.x + 0.5) * TILE, 0, (cell.y + 1) * TILE)
		r.node.rotation.y = -PI / 2
	dyn.add_child(r.node)
	racks.append(r)
	for c in r.cells():
		occ[c] = r
		astar.set_point_solid(c, true)
	for f in forklifts:
		f.unstick()
	if not silent:
		Snd.play("build")
		_pop(r.node)
	return r

func remove_rack(r: Rack) -> bool:
	if r.used() > 0:
		return false
	for x in r.reserved:
		if x:
			return false
	for c in r.cells():
		occ.erase(c)
		astar.set_point_solid(c, false)
	racks.erase(r)
	r.node.queue_free()
	return true

func _pop(n: Node3D) -> void:
	n.scale = Vector3(0.6, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func slot_pos(r: Rack, i: int) -> Vector3:
	return r.node.global_transform * M.slot_local(r.kind, i)

# 取得堆高機要站的位置：{cell, point, yaw, h}
func rack_access(r: Rack, i: int, from: Vector2i) -> Dictionary:
	var cols_n: int = G.BUILD[r.kind].cols
	var col := i % cols_n
	var cc: Vector2i = r.cells()[col]
	var sp := slot_pos(r, i)
	var cands: Array = []
	if r.rot == 0:
		cands = [[cc + Vector2i(0, -1), Vector3(0, 0, 1)], [cc + Vector2i(0, 1), Vector3(0, 0, -1)]]
	else:
		cands = [[cc + Vector2i(-1, 0), Vector3(1, 0, 0)], [cc + Vector2i(1, 0), Vector3(-1, 0, 0)]]
	var best := {}
	var best_len := 1e9
	for cd in cands:
		var ac: Vector2i = cd[0]
		if not in_floor(ac) or astar.is_point_solid(ac):
			continue
		var path := astar.get_id_path(from, ac)
		if path.is_empty() and from != ac:
			continue
		if path.size() < best_len:
			best_len = path.size()
			var face: Vector3 = cd[1]
			best = {"cell": ac, "point": Vector3(sp.x, 0, sp.z) - face * 1.4, "face": face, "h": sp.y}
	return best

func pad_access(d: Dock, i: int) -> Dictionary:
	var pp := d.pad_pos(i)
	return {"cell": d.inner_cell(), "point": pp - d.out_dir * 1.4, "face": d.out_dir, "h": 0.0}

# ── 托盤 ──
func new_pallet(cargo: String, cid: int) -> Pallet:
	var p := Pallet.new()
	p.cargo = cargo
	p.cid = cid
	p.node = M.pallet(cargo)
	dyn.add_child(p.node)
	pallets.append(p)
	return p

func drop_pallet(p: Pallet) -> void:
	pallets.erase(p)
	if is_instance_valid(p.node):
		p.node.queue_free()

func free_capacity() -> Dictionary:
	var out := {"general": 0, "cold": 0, "fragile": 0}
	for r in racks:
		var acc: Array = G.BUILD[r.kind].cargo
		out[acc[0]] += r.free_count()
	return out

func total_capacity() -> Dictionary:
	var out := {"general": 0, "cold": 0, "fragile": 0}
	for r in racks:
		var acc: Array = G.BUILD[r.kind].cargo
		out[acc[0]] += r.slots.size()
	return out

# ── 碼頭分配 ──
func claim_dock(kind: String, v) -> Dock:
	var want := "truck" if kind in ["truck", "van"] else ("rail" if kind == "rail" else "harbour")
	for d in docks:
		if d.kind == want and d.claimed_by == null:
			d.claimed_by = v
			return d
	return null

func release_dock(d: Dock) -> void:
	if d:
		d.claimed_by = null
		d.vehicle = null

# ── 調度 ──
func _process(delta: float) -> void:
	if G.over:
		return
	update_daylight()
	_dispatch_t -= delta
	if _dispatch_t <= 0.0:
		_dispatch_t = 0.15
		_dispatch()

func _idle_forklifts() -> Array:
	var out: Array = []
	for f in forklifts:
		if f.is_idle():
			out.append(f)
	return out

func _dispatch() -> void:
	var idle := _idle_forklifts()
	if idle.is_empty():
		return
	# A) 碼頭上待入庫的托盤
	for d in docks:
		for i in 2:
			var p: Pallet = d.pad[i]
			if p == null or p.claimed or p.state != "pad_in":
				continue
			if idle.is_empty():
				return
			var f = _nearest(idle, d.inner_cell())
			var slot := _find_slot(p.cargo, f.cell())
			if slot.is_empty():
				continue
			var r: Rack = slot.rack
			r.reserved[slot.i] = true
			p.claimed = true
			f.assign({"pallet": p, "from": pad_access(d, i), "to_rack": r, "to_slot": slot.i, "src_dock": d, "src_i": i})
			idle.erase(f)
	# B) 等出貨的車輛
	for d in docks:
		var v = d.vehicle
		if v == null or not v.wants_pallets():
			continue
		var cid: int = v.cid
		var c := G.contract_by_id(cid)
		if c.is_empty():
			continue
		var need: int = int(c.unloaded) - int(c.loaded)
		for p in pallets:
			if p.cid == cid and (p.state == "pad_out" or (p.claimed and p.state == "rack") or p.state == "fork"):
				need -= 1
		while need > 0 and not idle.is_empty():
			var pi: int = d.pad_free_index()
			if pi < 0:
				break
			var src: Pallet = null
			var best := 1e9
			for p in pallets:
				if p.cid == cid and p.state == "rack" and not p.claimed:
					var dist := cell_center(d.inner_cell()).distance_to(p.node.global_position)
					if dist < best:
						best = dist
						src = p
			if src == null:
				break
			var f = _nearest(idle, world_to_cell(src.node.global_position))
			var acc := rack_access(src.rack, src.slot, f.cell())
			if acc.is_empty():
				break
			src.claimed = true
			d.pad_res[pi] = true
			f.assign({"pallet": src, "from": acc, "to_dock": d, "to_pad": pi})
			idle.erase(f)
			need -= 1

func _nearest(list: Array, c: Vector2i):
	var best = list[0]
	var bd := 1e9
	for f in list:
		var dd := Vector2(f.cell() - c).length()
		if dd < bd:
			bd = dd
			best = f
	return best

func _find_slot(cargo: String, from: Vector2i) -> Dictionary:
	var want := cargo
	var best := {}
	var best_d := 1e9
	for r in racks:
		var acc: Array = G.BUILD[r.kind].cargo
		if not (want in acc):
			continue
		for i in r.slots.size():
			if r.slots[i] != null or r.reserved[i]:
				continue
			var a := rack_access(r, i, from)
			if a.is_empty():
				continue
			# 先放低層、離碼頭近
			var d: float = (a.point as Vector3).distance_to(cell_center(from)) + (i / int(G.BUILD[r.kind].cols)) * 3.0
			if d < best_d:
				best_d = d
				best = {"rack": r, "i": i}
	return best

func any_slot_for(cargo: String) -> bool:
	for r in racks:
		if cargo in G.BUILD[r.kind].cargo and r.free_count() > 0:
			return true
	return false

func path_points(from: Vector2i, to: Vector2i) -> Array:
	var ids := astar.get_id_path(from, to)
	var pts: Array = []
	for id in ids:
		pts.append(cell_center(id))
	return pts

func nearest_walkable(c: Vector2i) -> Vector2i:
	if in_floor(c) and not astar.is_point_solid(c):
		return c
	for rad in range(1, 12):
		for dx in range(-rad, rad + 1):
			for dz in range(-rad, rad + 1):
				var n := c + Vector2i(dx, dz)
				if in_floor(n) and not astar.is_point_solid(n):
					return n
	return Vector2i(0, 0)

# ── 存檔 ──
func write_snapshot() -> void:
	var rs: Array = []
	var items: Array = []
	for r in racks:
		var st: Array = []
		for i in r.slots.size():
			var p: Pallet = r.slots[i]
			st.append([p.cid, p.cargo] if p else null)
		rs.append({"k": r.kind, "x": r.cell.x, "y": r.cell.y, "r": r.rot, "s": st})
		items.append(r.kind)
	# 在路上的托盤：入庫中的視為已入庫、出庫中的放回貨架
	var floating: Array = []
	for p in pallets:
		if p.state in ["pad_in", "pad_out", "fork"]:
			floating.append([p.cid, p.cargo])
	G.world_snapshot = {
		"racks": rs, "upkeep_items": items, "forklifts": forklifts.size(),
		"free": free_capacity(), "total": total_capacity(), "floating": floating,
	}

func refresh_capacity() -> void:
	G.world_snapshot["free"] = free_capacity()
	G.world_snapshot["total"] = total_capacity()
	var items: Array = []
	for r in racks:
		items.append(r.kind)
	G.world_snapshot["upkeep_items"] = items
	G.world_snapshot["forklifts"] = forklifts.size()

func restore(snap: Dictionary) -> void:
	for rd in snap.get("racks", []):
		var r := place_rack(rd.k, Vector2i(int(rd.x), int(rd.y)), int(rd.r), true)
		var st: Array = rd.s
		for i in st.size():
			if st[i] != null and i < r.slots.size():
				var p := new_pallet(st[i][1], int(st[i][0]))
				_put_in_rack(p, r, i)
	for fl in snap.get("floating", []):
		var cargo: String = fl[1]
		var slot := _find_slot(cargo, Vector2i(1, 3))
		if slot.is_empty():
			continue
		var p := new_pallet(cargo, int(fl[0]))
		_put_in_rack(p, slot.rack, slot.i)

func _put_in_rack(p: Pallet, r: Rack, i: int) -> void:
	r.slots[i] = p
	p.state = "rack"
	p.rack = r
	p.slot = i
	var t := r.node.global_transform
	p.node.global_transform = Transform3D(t.basis, slot_pos(r, i))
