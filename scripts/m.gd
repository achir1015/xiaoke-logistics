class_name M
extends RefCounted
## 程序化低多邊形模型與材質（全部原創，用方塊／圓柱組成）。

static var _mats: Dictionary = {}
static var _box_cache: Dictionary = {}
static var font: Font = null
static var font_ui: FontVariation = null
static var font_bold: FontVariation = null

static func init_fonts() -> void:
	if font_ui:
		return
	var base: Font = load("res://assets/fonts/NotoSansTC.ttf")
	font_ui = _weight(base, 500)
	font_bold = _weight(base, 800)
	font = font_bold

static func _weight(base: Font, w: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	return fv

static func mat(c: Color, emissive: float = 0.0, rough: float = 0.85) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(), emissive, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func box_mesh(size: Vector3) -> BoxMesh:
	var key := str(size)
	if _box_cache.has(key):
		return _box_cache[key]
	var b := BoxMesh.new()
	b.size = size
	_box_cache[key] = b
	return b

static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.position = pos
	mi.material_override = mat(c)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, axis := "y") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	if axis == "x":
		mi.rotation.z = PI / 2
	elif axis == "z":
		mi.rotation.x = PI / 2
	mi.material_override = mat(c)
	parent.add_child(mi)
	return mi

static func label(parent: Node3D, text: String, pos: Vector3, size: int = 64, c: Color = Color.WHITE, flat := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = c
	l.outline_size = 0
	if font:
		l.font = font
	if flat:
		l.rotation.x = -PI / 2
	else:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	l.no_depth_test = false
	parent.add_child(l)
	return l

# ── 托盤 ──
static func pallet(cargo: String) -> Node3D:
	var n := Node3D.new()
	var wood := Color(0.72, 0.55, 0.34)
	box(n, Vector3(1.2, 0.05, 1.0), Vector3(0, 0.125, 0), wood)
	for x in [-0.5, 0.0, 0.5]:
		box(n, Vector3(0.12, 0.1, 1.0), Vector3(x, 0.05, 0), wood.darkened(0.15))
	var c: Color = G.CARGO[cargo].color
	match cargo:
		"general":
			for i in 4:
				var bx := -0.28 + (i % 2) * 0.56
				var bz := -0.24 + (i / 2) * 0.48
				box(n, Vector3(0.52, 0.42, 0.44), Vector3(bx, 0.36, bz), c.lerp(Color(0.7, 0.5, 0.3), (i % 3) * 0.15))
			box(n, Vector3(0.5, 0.36, 0.42), Vector3(-0.28, 0.75, -0.24), c.lightened(0.08))
			box(n, Vector3(0.5, 0.36, 0.42), Vector3(0.28, 0.75, 0.24), c.darkened(0.06))
		"cold":
			box(n, Vector3(1.1, 0.8, 0.92), Vector3(0, 0.56, 0), c)
			box(n, Vector3(1.12, 0.08, 0.94), Vector3(0, 0.98, 0), Color(0.35, 0.6, 0.9))
			box(n, Vector3(0.3, 0.2, 0.02), Vector3(0, 0.6, 0.47), Color(0.35, 0.6, 0.9))
		"fragile":
			box(n, Vector3(1.1, 0.7, 0.92), Vector3(0, 0.51, 0), c)
			box(n, Vector3(1.12, 0.1, 0.1), Vector3(0, 0.6, 0), Color(0.95, 0.3, 0.3))
			box(n, Vector3(0.1, 0.72, 0.94), Vector3(0, 0.52, 0), Color(0.95, 0.3, 0.3))
		"mystery":
			box(n, Vector3(1.1, 0.75, 0.92), Vector3(0, 0.53, 0), c)
			box(n, Vector3(1.12, 0.06, 0.94), Vector3(0, 0.3, 0), Color(0.1, 0.1, 0.1))
			box(n, Vector3(1.12, 0.06, 0.94), Vector3(0, 0.78, 0), Color(0.1, 0.1, 0.1))
	return n

# ── 貨架 ──
static func rack_model(kind: String) -> Node3D:
	var n := Node3D.new()
	var d: Dictionary = G.BUILD[kind]
	var levels: int = d.levels
	var lv_h := 1.25
	var up := Color(0.18, 0.55, 0.55)
	var beam := Color(0.98, 0.62, 0.16)
	if kind == "cold":
		up = Color(0.88, 0.92, 0.95)
		beam = Color(0.55, 0.75, 0.95)
	elif kind == "fragile":
		up = Color(0.98, 0.82, 0.18)
		beam = Color(0.25, 0.25, 0.28)
	var top := levels * lv_h + 0.2
	for x in [-1.95, 0.0, 1.95]:
		for z in [-0.55, 0.55]:
			box(n, Vector3(0.1, top, 0.1), Vector3(x, top / 2, z), up)
	for l in range(1, levels):
		var y := l * lv_h + 0.1
		for z in [-0.55, 0.55]:
			box(n, Vector3(3.95, 0.12, 0.08), Vector3(0, y - 0.06, z), beam)
		box(n, Vector3(3.9, 0.03, 1.1), Vector3(0, y - 0.015, 0), Color(0.6, 0.62, 0.65))
	box(n, Vector3(3.95, 0.1, 0.08), Vector3(0, top - 0.05, 0.55), beam)
	box(n, Vector3(3.95, 0.1, 0.08), Vector3(0, top - 0.05, -0.55), beam)
	if kind == "cold":
		# 背板與壓縮機
		box(n, Vector3(3.95, top, 0.06), Vector3(0, top / 2, -0.6), Color(0.93, 0.95, 0.97))
		for x in [-1.0, 1.0]:
			box(n, Vector3(0.8, 0.35, 0.8), Vector3(x, top + 0.18, 0), Color(0.85, 0.88, 0.9))
			cyl(n, 0.25, 0.04, Vector3(x, top + 0.37, 0), Color(0.2, 0.22, 0.25))
	elif kind == "fragile":
		box(n, Vector3(3.95, top, 0.04), Vector3(0, top / 2, -0.6), Color(0.3, 0.3, 0.32, 0.45))
	return n

static func slot_local(kind: String, i: int) -> Vector3:
	var cols: int = G.BUILD[kind].cols
	var col := i % cols
	var lvl := i / cols
	return Vector3(-1.0 + col * 2.0, 0.0 if lvl == 0 else lvl * 1.25 + 0.1, 0.0)

# ── 堆高機（司機是小柯機器人）──
static func forklift_model() -> Dictionary:
	var root := Node3D.new()
	var body := Color(0.98, 0.78, 0.15)
	box(root, Vector3(1.0, 0.55, 1.5), Vector3(0, 0.5, -0.1), body)
	box(root, Vector3(1.0, 0.5, 0.45), Vector3(0, 0.75, -0.75), Color(0.25, 0.25, 0.28))   # 配重
	for x in [-0.45, 0.45]:
		box(root, Vector3(0.06, 1.3, 0.06), Vector3(x, 1.4, 0.45), Color(0.2, 0.2, 0.22))
		box(root, Vector3(0.06, 1.3, 0.06), Vector3(x, 1.4, -0.55), Color(0.2, 0.2, 0.22))
	box(root, Vector3(1.0, 0.06, 1.1), Vector3(0, 2.05, -0.05), Color(0.2, 0.2, 0.22))
	for p in [Vector3(-0.5, 0.25, 0.4), Vector3(0.5, 0.25, 0.4), Vector3(-0.5, 0.25, -0.6), Vector3(0.5, 0.25, -0.6)]:
		cyl(root, 0.25, 0.22, p, Color(0.12, 0.12, 0.12), "x")
	# 小柯機器人司機
	var bot := Node3D.new()
	bot.position = Vector3(0, 0.78, -0.2)
	root.add_child(bot)
	box(bot, Vector3(0.42, 0.4, 0.3), Vector3(0, 0.2, 0), Color(0.3, 0.55, 0.95))
	box(bot, Vector3(0.46, 0.38, 0.4), Vector3(0, 0.62, 0), Color(0.95, 0.96, 0.98))
	box(bot, Vector3(0.36, 0.2, 0.02), Vector3(0, 0.62, 0.205), Color(0.1, 0.12, 0.2))
	box(bot, Vector3(0.06, 0.07, 0.01), Vector3(-0.08, 0.64, 0.218), Color(0.4, 0.95, 1.0))
	box(bot, Vector3(0.06, 0.07, 0.01), Vector3(0.08, 0.64, 0.218), Color(0.4, 0.95, 1.0))
	cyl(bot, 0.02, 0.18, Vector3(0, 0.9, 0), Color(0.3, 0.3, 0.3))
	var bulb := box(bot, Vector3(0.08, 0.08, 0.08), Vector3(0, 1.0, 0), Color(1.0, 0.35, 0.3))
	bulb.material_override = mat(Color(1.0, 0.35, 0.3), 2.0)
	# 門架與貨叉
	var mast := Node3D.new()
	mast.position = Vector3(0, 0, 0.72)
	root.add_child(mast)
	for x in [-0.35, 0.35]:
		box(mast, Vector3(0.08, 2.2, 0.1), Vector3(x, 1.15, 0), Color(0.22, 0.22, 0.24))
	var carriage := Node3D.new()
	mast.add_child(carriage)
	box(carriage, Vector3(0.8, 0.7, 0.06), Vector3(0, 0.45, 0.08), Color(0.22, 0.22, 0.24))
	for x in [-0.25, 0.25]:
		box(carriage, Vector3(0.1, 0.05, 1.1), Vector3(x, 0.075, 0.62), Color(0.3, 0.3, 0.32))
	var hold := Node3D.new()
	hold.position = Vector3(0, 0.0, 0.68)
	carriage.add_child(hold)
	return {"root": root, "carriage": carriage, "hold": hold, "bulb": bulb}

# ── 火車與貨輪 ──
static func locomotive() -> Node3D:
	var n := Node3D.new()
	box(n, Vector3(9.0, 1.2, 2.6), Vector3(0, 1.1, 0), Color(0.15, 0.35, 0.3))
	box(n, Vector3(6.5, 1.6, 2.4), Vector3(-1.0, 2.5, 0), Color(0.95, 0.75, 0.15))
	box(n, Vector3(2.0, 1.8, 2.5), Vector3(3.3, 2.6, 0), Color(0.15, 0.35, 0.3))
	box(n, Vector3(0.05, 0.6, 2.0), Vector3(4.31, 2.9, 0), Color(0.6, 0.85, 0.95))
	for x in [-3.2, -2.2, 2.2, 3.2]:
		for z in [-1.0, 1.0]:
			cyl(n, 0.42, 0.25, Vector3(x, 0.45, z), Color(0.12, 0.12, 0.12), "z")
	return n

static func wagon() -> Node3D:
	var n := Node3D.new()
	box(n, Vector3(10.0, 0.4, 2.6), Vector3(0, 0.9, 0), Color(0.3, 0.3, 0.32))
	box(n, Vector3(9.8, 2.2, 2.5), Vector3(0, 2.2, 0), Color(0.62, 0.28, 0.22))
	for x in [-4.6, -2.3, 0.0, 2.3, 4.6]:
		box(n, Vector3(0.08, 2.2, 2.52), Vector3(x, 2.2, 0), Color(0.5, 0.22, 0.18))
	for x in [-3.6, -2.6, 2.6, 3.6]:
		for z in [-1.0, 1.0]:
			cyl(n, 0.4, 0.25, Vector3(x, 0.45, z), Color(0.12, 0.12, 0.12), "z")
	return n

static func ship() -> Node3D:
	var n := Node3D.new()
	box(n, Vector3(7.0, 2.4, 26.0), Vector3(0, 0.6, 0), Color(0.18, 0.3, 0.55))
	box(n, Vector3(7.02, 0.5, 26.02), Vector3(0, -0.2, 0), Color(0.75, 0.2, 0.18))
	box(n, Vector3(6.0, 3.5, 4.0), Vector3(0, 3.5, -10.0), Color(0.95, 0.95, 0.95))
	box(n, Vector3(6.05, 0.5, 0.1), Vector3(0, 4.4, -7.95), Color(0.3, 0.6, 0.85))
	cyl(n, 0.6, 2.0, Vector3(0, 6.0, -10.5), Color(0.85, 0.3, 0.2))
	var cols := [Color(0.85, 0.3, 0.25), Color(0.2, 0.55, 0.75), Color(0.95, 0.7, 0.2), Color(0.3, 0.65, 0.4)]
	var i := 0
	for z in [-5.0, -1.5, 2.0, 5.5, 9.0]:
		for x in [-1.6, 1.6]:
			box(n, Vector3(2.9, 2.4, 3.2), Vector3(x, 3.0, z), cols[i % cols.size()])
			i += 1
	return n

# ── 卡車（Kenney Car Kit，CC0）──
static var _veh: Dictionary = {}

static func vehicle_model(file: String, length: float, tint: Color = Color(0, 0, 0, 0)) -> Node3D:
	if not _veh.has(file):
		_veh[file] = load("res://assets/vehicles/%s.glb" % file)
	var scn: PackedScene = _veh[file]
	var inst: Node3D = scn.instantiate()
	var holder := Node3D.new()
	holder.add_child(inst)
	var aabb := _aabb(inst, Transform3D.IDENTITY)
	var s := length / maxf(aabb.size.z, 0.01)
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	if tint.a > 0.0:
		_tint(inst, tint)
	return holder

static func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		out = a
		first = false
	for ch in n.get_children():
		var b := _aabb(ch, t)
		if b.size != Vector3.ZERO:
			if first:
				out = b
				first = false
			else:
				out = out.merge(b)
	return out

static func _tint(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var m2: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
				m2.albedo_color = c
				mi.set_surface_override_material(s, m2)
	for ch in n.get_children():
		_tint(ch, c)
