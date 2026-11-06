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
	l.double_sided = false
	l.no_depth_test = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
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
	if kind == "inspect":
		return inspect_table()
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
	if kind == "inspect":
		return Vector3(-1.0 + (i % 2) * 2.0, 0.62, 0.0)
	var cols: int = G.BUILD[kind].cols
	var col := i % cols
	var lvl := i / cols
	return Vector3(-1.0 + col * 2.0, 0.0 if lvl == 0 else lvl * 1.25 + 0.1, 0.0)

# ── 海關查驗台與海關人員 ──
static func inspect_table() -> Node3D:
	var n := Node3D.new()
	var steel := Color(0.72, 0.75, 0.78)
	M.box(n, Vector3(3.9, 0.08, 1.3), Vector3(0, 0.58, 0), steel)
	for x in [-1.85, 1.85]:
		for z in [-0.55, 0.55]:
			M.box(n, Vector3(0.1, 0.58, 0.1), Vector3(x, 0.29, z), Color(0.3, 0.32, 0.35))
	# 黃黑警示邊
	for k in 10:
		M.box(n, Vector3(0.39, 0.1, 0.06), Vector3(-1.75 + k * 0.39, 0.6, 0.66), Color(0.98, 0.8, 0.1) if k % 2 == 0 else Color(0.1, 0.1, 0.1))
	# 告示牌
	M.box(n, Vector3(0.08, 1.6, 0.08), Vector3(-2.0, 0.8, -0.6), Color(0.3, 0.3, 0.3))
	M.box(n, Vector3(1.3, 0.55, 0.06), Vector3(-2.0, 1.75, -0.6), Color(0.12, 0.3, 0.6))
	var l := M.label(n, "海關查驗", Vector3(-2.0, 1.75, -0.56), 34, Color(1, 1, 1), false)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var off := officer()
	off.name = "Officer"
	off.position = Vector3(0, 0, -1.1)
	off.visible = false
	n.add_child(off)
	return n

static func officer() -> Node3D:
	var n := Node3D.new()
	var navy := Color(0.12, 0.2, 0.38)
	M.box(n, Vector3(0.2, 0.8, 0.22), Vector3(-0.13, 0.4, 0), Color(0.15, 0.17, 0.22))
	M.box(n, Vector3(0.2, 0.8, 0.22), Vector3(0.13, 0.4, 0), Color(0.15, 0.17, 0.22))
	M.box(n, Vector3(0.6, 0.75, 0.32), Vector3(0, 1.17, 0), navy)
	M.box(n, Vector3(0.14, 0.12, 0.02), Vector3(0.15, 1.35, 0.17), Color(0.95, 0.8, 0.2))
	M.box(n, Vector3(0.36, 0.38, 0.34), Vector3(0, 1.75, 0), Color(0.93, 0.78, 0.65))
	M.box(n, Vector3(0.42, 0.12, 0.42), Vector3(0, 1.98, 0.02), navy)
	M.box(n, Vector3(0.42, 0.04, 0.2), Vector3(0, 1.93, 0.25), Color(0.08, 0.08, 0.1))
	# 手上的文件板
	M.box(n, Vector3(0.3, 0.4, 0.04), Vector3(0.3, 1.15, 0.25), Color(0.95, 0.95, 0.9))
	return n

# ── 貨機（機頭朝 +Z，雙引擎廣體貨機）──
# 梯形翼面：根部弦長 rc、翼尖弦長 tc、展長 span（沿 +X）、後掠角 sweep（度）、厚度 th
static func panel_mesh(rc: float, tc: float, span: float, sweep: float, th: float, mirror := false) -> ArrayMesh:
	var off := span * tan(deg_to_rad(sweep))
	var pts := [Vector2(0, rc / 2), Vector2(0, -rc / 2), Vector2(span, -off - tc / 2), Vector2(span, -off + tc / 2)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Array = []
	var bot: Array = []
	for i in 4:
		var q: Vector2 = pts[i]
		var t := th * (1.0 - 0.6 * q.x / maxf(span, 0.01))
		var qx := -q.x if mirror else q.x
		top.append(Vector3(qx, t / 2, q.y))
		bot.append(Vector3(qx, -t / 2, q.y))
	var quads := [[top[0], top[3], top[2], top[1]], [bot[0], bot[1], bot[2], bot[3]],
		[top[0], bot[0], bot[3], top[3]], [top[1], top[2], bot[2], bot[1]], [top[2], top[3], bot[3], bot[2]], [top[0], top[1], bot[1], bot[0]]]
	for qd0 in quads:
		var qd: Array = qd0
		if mirror:
			qd = [qd0[0], qd0[3], qd0[2], qd0[1]]
		var n: Vector3 = ((qd[1] as Vector3) - (qd[0] as Vector3)).cross((qd[2] as Vector3) - (qd[0] as Vector3)).normalized()
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(qd[idx])
	return st.commit()

static func panel(parent: Node3D, rc: float, tc: float, span: float, sweep: float, th: float, c: Color, mirror := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = panel_mesh(rc, tc, span, sweep, th, mirror)
	var m: StandardMaterial3D = mat(c, 0.0, 0.5).duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	parent.add_child(mi)
	return mi

static func _cone(parent: Node3D, r0: float, r1: float, h: float, pos: Vector3, c: Color, rot_x: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.position = pos
	mi.rotation.x = rot_x
	mi.material_override = mat(c, 0.0, 0.5)
	parent.add_child(mi)
	return mi

static func plane() -> Node3D:
	var n := Node3D.new()
	var white := Color(0.96, 0.97, 0.98)
	var teal := Color(0.1, 0.52, 0.62)
	var gray := Color(0.62, 0.66, 0.7)
	var dark := Color(0.12, 0.14, 0.18)
	var R := 2.05
	var y := 3.4
	# 機身
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = R
	cm.bottom_radius = R
	cm.height = 22.0
	cm.radial_segments = 24
	body.mesh = cm
	body.rotation.x = PI / 2
	body.position = Vector3(0, y, 0)
	body.material_override = mat(white, 0.0, 0.45)
	n.add_child(body)
	# 圓滑機頭
	var nose := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	nose.mesh = sm
	nose.scale = Vector3(R, R * 0.97, 4.2)
	nose.position = Vector3(0, y - 0.05, 11.0)
	nose.material_override = mat(white, 0.0, 0.45)
	n.add_child(nose)
	# 上翹機尾錐
	_cone(n, R, 0.35, 9.0, Vector3(0, y + 0.75, -15.2), white, -PI / 2 - 0.16)
	# 腹部深色塗裝與側線
	for sx in [-1.0, 1.0]:
		box(n, Vector3(0.06, 0.32, 21.0), Vector3(sx * (R + 0.01), y + 0.15, 0.5), teal, false)
		box(n, Vector3(0.06, 0.1, 21.0), Vector3(sx * (R + 0.01), y - 0.3, 0.5), Color(0.95, 0.72, 0.2), false)
	# 駕駛艙窗（斜面上的一排深色窗）
	for k in 4:
		var w := box(n, Vector3(0.55, 0.32, 0.06), Vector3(-0.95 + k * 0.63, y + 1.05, 13.25), dark, false)
		w.rotation.x = -0.75
	for sx in [-1.0, 1.0]:
		var sw := box(n, Vector3(0.06, 0.3, 0.6), Vector3(sx * 1.55, y + 0.95, 12.7), dark, false)
		sw.rotation.y = sx * 0.5
	# 貨艙門（右側，打開往上掀）
	box(n, Vector3(0.08, 2.4, 3.4), Vector3(R + 0.04, y - 0.1, 8.2), gray, false)
	var door := box(n, Vector3(0.12, 0.25, 3.4), Vector3(R + 0.6, y + 1.35, 8.2), white)
	door.rotation.z = -0.9
	# 主翼（後掠＋上反角）
	for sx in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(sx * (R - 0.3), y - 1.05, 2.4)
		wing.rotation.z = sx * deg_to_rad(5.0)
		n.add_child(wing)
		var mir: bool = sx < 0
		panel(wing, 7.6, 2.0, 16.5, 31.0, 0.55, white, mir)
		# 翼尖小翼
		var wl := Node3D.new()
		wl.position = Vector3(sx * 16.4, 0.1, -16.5 * tan(deg_to_rad(31.0)) - 0.2)
		wl.rotation.z = sx * (PI / 2 - 0.15)
		wing.add_child(wl)
		panel(wl, 1.8, 0.8, 2.2, 38.0, 0.12, teal, mir)
		# 引擎：吊架、短艙、進氣口
		var ex: float = 6.2 * sx
		var ez := 2.2 - absf(ex) * tan(deg_to_rad(31.0))
		box(wing, Vector3(0.35, 1.0, 3.0), Vector3(ex, -0.55, ez + 0.6), gray)
		var nac := cyl(wing, 1.15, 4.6, Vector3(ex, -1.45, ez + 1.4), gray, "z")
		nac.material_override = mat(Color(0.82, 0.85, 0.88), 0.0, 0.35)
		cyl(wing, 1.2, 0.35, Vector3(ex, -1.45, ez + 3.6), teal, "z")
		cyl(wing, 0.95, 0.06, Vector3(ex, -1.45, ez + 3.8), dark, "z")
		cyl(wing, 0.55, 0.9, Vector3(ex, -1.45, ez - 1.2), Color(0.35, 0.36, 0.38), "z")
	# 水平尾翼
	for sx in [-1.0, 1.0]:
		var hs := Node3D.new()
		hs.position = Vector3(sx * 0.6, y + 1.35, -15.3)
		hs.rotation.z = sx * deg_to_rad(7.0)
		n.add_child(hs)
		panel(hs, 3.8, 1.5, 6.6, 34.0, 0.3, white, sx < 0)
	# 垂直尾翼（塗裝＋小柯字樣）
	var vs := Node3D.new()
	vs.position = Vector3(0, y + 1.6, -14.0)
	vs.rotation.z = PI / 2
	n.add_child(vs)
	panel(vs, 6.0, 2.2, 7.0, 40.0, 0.35, teal)
	for sx in [-1.0, 1.0]:
		var lb := label(n, "小柯", Vector3(sx * 0.22, y + 5.0, -17.3), 150, Color(1, 1, 1), false)
		lb.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lb.rotation.y = sx * PI / 2
		var side := label(n, "小柯航空貨運", Vector3(sx * (R + 0.03), y + 0.95, 1.0), 110, teal.darkened(0.25), false)
		side.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		side.rotation.y = sx * PI / 2
	# 起落架：鼻輪＋兩組主輪車架
	box(n, Vector3(0.2, y - 1.4, 0.2), Vector3(0, (y - 1.4) / 2 + 0.45, 10.5), gray)
	for sx in [-0.25, 0.25]:
		cyl(n, 0.45, 0.32, Vector3(sx, 0.45, 10.5), dark, "x")
	for sx in [-1.0, 1.0]:
		box(n, Vector3(0.28, y - 1.6, 0.28), Vector3(sx * 1.6, (y - 1.6) / 2 + 0.55, 1.2), gray)
		box(n, Vector3(0.3, 0.18, 2.2), Vector3(sx * 1.6, 0.6, 1.2), gray)
		for dz in [0.4, 2.0]:
			for dx in [-0.35, 0.35]:
				cyl(n, 0.55, 0.36, Vector3(sx * 1.6 + dx, 0.55, dz), dark, "x")
	# 防撞燈
	var bl := box(n, Vector3(0.25, 0.12, 0.25), Vector3(0, y + R + 0.05, 0), Color(1, 0.2, 0.2))
	bl.material_override = mat(Color(1, 0.2, 0.2), 3.0)
	return n

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

# 船殼放樣：sections = [[z, 上半寬, 下半寬], ...]，由船尾到船首
static func loft(sections: Array, y_top: float, y_bot: float, c: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector3, b: Vector3, cc: Vector3, d: Vector3):
		var nn := (b - a).cross(cc - a).normalized()
		if nn.length() < 0.01:
			nn = (cc - a).cross(d - a).normalized()
		for v in [a, b, cc, a, cc, d]:
			st.set_normal(nn)
			st.add_vertex(v)
	for i in sections.size() - 1:
		var s0: Array = sections[i]
		var s1: Array = sections[i + 1]
		var z0: float = s0[0]
		var z1: float = s1[0]
		# 右舷、左舷、甲板、船底
		quad.call(Vector3(s0[1], y_top, z0), Vector3(s0[2], y_bot, z0), Vector3(s1[2], y_bot, z1), Vector3(s1[1], y_top, z1))
		quad.call(Vector3(-s0[1], y_top, z0), Vector3(-s1[1], y_top, z1), Vector3(-s1[2], y_bot, z1), Vector3(-s0[2], y_bot, z0))
		quad.call(Vector3(-s0[1], y_top, z0), Vector3(s0[1], y_top, z0), Vector3(s1[1], y_top, z1), Vector3(-s1[1], y_top, z1))
		quad.call(Vector3(-s0[2], y_bot, z0), Vector3(-s1[2], y_bot, z1), Vector3(s1[2], y_bot, z1), Vector3(s0[2], y_bot, z0))
	var f: Array = sections[0]
	quad.call(Vector3(-f[1], y_top, f[0]), Vector3(-f[2], y_bot, f[0]), Vector3(f[2], y_bot, f[0]), Vector3(f[1], y_top, f[0]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m: StandardMaterial3D = mat(c, 0.0, 0.6).duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi

static func ship() -> Node3D:
	var n := Node3D.new()
	var hull_sec := [[-19.0, 3.2, 2.6], [-15.0, 3.5, 3.0], [11.0, 3.5, 3.0], [14.5, 3.0, 2.2], [17.0, 2.0, 1.0], [18.8, 0.9, 0.2], [19.8, 0.1, 0.05]]
	var low_sec := [[-18.6, 2.6, 2.0], [-15.0, 3.0, 2.4], [11.0, 3.0, 2.4], [14.5, 2.2, 1.4], [17.0, 1.0, 0.5], [18.6, 0.2, 0.05]]
	n.add_child(loft(hull_sec, 2.6, 0.35, Color(0.13, 0.22, 0.4)))
	n.add_child(loft(low_sec, 0.35, -1.6, Color(0.72, 0.16, 0.14)))
	box(n, Vector3(7.02, 0.12, 30.0), Vector3(0, 0.38, -1.5), Color(0.95, 0.95, 0.95), false)
	# 甲板
	box(n, Vector3(6.6, 0.1, 30.5), Vector3(0, 2.62, -1.5), Color(0.45, 0.47, 0.5), false)
	# 船首樓與舷牆
	box(n, Vector3(4.6, 0.9, 3.2), Vector3(0, 3.05, 15.6), Color(0.13, 0.22, 0.4))
	box(n, Vector3(0.12, 2.4, 0.12), Vector3(0, 4.7, 16.4), Color(0.9, 0.9, 0.9))
	# 貨櫃（20 呎，沿船身擺放）
	var pal := [Color(0.82, 0.22, 0.18), Color(0.16, 0.42, 0.72), Color(0.2, 0.58, 0.36), Color(0.95, 0.6, 0.15),
		Color(0.55, 0.57, 0.6), Color(0.1, 0.55, 0.6), Color(0.92, 0.82, 0.25), Color(0.9, 0.9, 0.88), Color(0.45, 0.25, 0.55)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var bay_z := -9.8
	while bay_z < 13.0:
		var tiers := rng.randi_range(2, 4)
		var rows := 5 if bay_z < 10.5 else 3
		for r in rows:
			var x := (r - (rows - 1) / 2.0) * 1.22
			var t_here := tiers if absf(x) < 2.0 else maxi(1, tiers - 1)
			for t in t_here:
				var c: Color = pal[rng.randi() % pal.size()]
				box(n, Vector3(1.16, 1.18, 2.95), Vector3(x, 3.27 + t * 1.2, bay_z), c)
				box(n, Vector3(1.18, 0.06, 2.97), Vector3(x, 3.85 + t * 1.2, bay_z), c.darkened(0.25), false)
		# 綁紮橋
		box(n, Vector3(6.4, 0.12, 0.12), Vector3(0, 2.75, bay_z + 1.55), Color(0.85, 0.75, 0.2), false)
		bay_z += 3.1
	# 船尾艦橋（多層白色上層建築）
	var sup := Node3D.new()
	sup.position = Vector3(0, 2.6, -15.0)
	n.add_child(sup)
	var white := Color(0.94, 0.95, 0.96)
	for k in 4:
		box(sup, Vector3(6.2 - k * 0.3, 1.5, 4.2 - k * 0.2), Vector3(0, 0.75 + k * 1.5, 0), white)
		box(sup, Vector3(6.25 - k * 0.3, 0.32, 4.25 - k * 0.2), Vector3(0, 0.95 + k * 1.5, 0), Color(0.15, 0.2, 0.28), false)
	box(sup, Vector3(8.6, 0.9, 2.2), Vector3(0, 6.45, 0.9), white)
	box(sup, Vector3(8.65, 0.4, 2.25), Vector3(0, 6.55, 0.9), Color(0.15, 0.2, 0.28), false)
	box(sup, Vector3(5.0, 0.15, 3.6), Vector3(0, 6.95, 0.3), Color(0.8, 0.8, 0.8), false)
	# 雷達桅與煙囪
	box(sup, Vector3(0.14, 2.6, 0.14), Vector3(0, 8.2, 0.3), Color(0.9, 0.9, 0.9))
	box(sup, Vector3(1.8, 0.12, 0.3), Vector3(0, 9.2, 0.3), Color(0.25, 0.25, 0.28))
	var fun := Node3D.new()
	fun.position = Vector3(0, 6.0, -2.6)
	sup.add_child(fun)
	box(fun, Vector3(2.0, 3.4, 2.4), Vector3(0, 1.7, 0), Color(0.85, 0.32, 0.2))
	box(fun, Vector3(2.04, 0.6, 2.44), Vector3(0, 3.1, 0), Color(0.1, 0.1, 0.12))
	box(fun, Vector3(2.06, 0.8, 0.9), Vector3(0, 1.8, 0), Color(1.0, 0.85, 0.3), false)
	# 船名
	for sx in [-1.0, 1.0]:
		var nm := label(n, "小柯號", Vector3(sx * 3.34, 1.8, 14.0), 110, Color(1, 1, 1), false)
		nm.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		nm.rotation.y = sx * PI / 2
		var ln := label(n, "小柯海運", Vector3(sx * 3.52, 1.55, -2.0), 200, Color(1, 1, 1), false)
		ln.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		ln.rotation.y = sx * PI / 2
	var lt := box(n, Vector3(0.25, 0.25, 0.25), Vector3(0, 6.0, 16.4), Color(1, 1, 0.8))
	lt.material_override = mat(Color(1, 0.95, 0.7), 3.0)
	return n

# 拖船（港口裝飾）
static func tug() -> Node3D:
	var n := Node3D.new()
	var sec := [[-3.5, 1.4, 1.0], [2.0, 1.5, 1.1], [3.4, 0.9, 0.4], [4.2, 0.1, 0.05]]
	n.add_child(loft(sec, 1.2, -0.6, Color(0.15, 0.3, 0.55)))
	n.add_child(loft([[-3.4, 1.0, 0.8], [3.3, 0.7, 0.3]], -0.6, -1.0, Color(0.7, 0.18, 0.15)))
	box(n, Vector3(2.0, 1.4, 2.6), Vector3(0, 1.9, 0.3), Color(0.95, 0.95, 0.95))
	box(n, Vector3(2.05, 0.4, 2.65), Vector3(0, 2.2, 0.3), Color(0.15, 0.2, 0.28), false)
	box(n, Vector3(0.7, 1.4, 0.7), Vector3(0, 2.9, -1.0), Color(0.95, 0.75, 0.2))
	for z in [-3.0, -1.0, 1.0, 3.0]:
		cyl(n, 0.28, 0.5, Vector3(1.45, 0.9, z), Color(0.1, 0.1, 0.1), "z")
		cyl(n, 0.28, 0.5, Vector3(-1.45, 0.9, z), Color(0.1, 0.1, 0.1), "z")
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
