class_name IsoCam
extends Node3D
## 等角正交攝影機：滾輪／雙指縮放、右鍵／中鍵／單指拖曳平移、Q/E 旋轉。

var cam: Camera3D
var zoom := 34.0
var zoom_target := 34.0
var yaw := deg_to_rad(35.0)
var yaw_target := deg_to_rad(35.0)
var pitch := deg_to_rad(-38.0)
var bounds := Rect2(-30, -20, 120, 60)
var drag_pan := false
var touches: Dictionary = {}
var _pinch_d := 0.0
var _last_mouse := Vector2.ZERO
var touch_pan_enabled := true
var focus_tween: Tween

func _ready() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.near = 1.0
	cam.far = 500.0
	add_child(cam)
	_apply()

func _apply() -> void:
	rotation = Vector3(0, yaw, 0)
	cam.position = Vector3(0, sin(-pitch) * 120.0, cos(pitch) * 120.0)
	cam.rotation = Vector3(pitch, 0, 0)
	cam.size = zoom

func _process(delta: float) -> void:
	zoom = lerpf(zoom, zoom_target, minf(1.0, delta * 10.0))
	yaw = lerp_angle(yaw, yaw_target, minf(1.0, delta * 8.0))
	var k := Vector2.ZERO
	if not _typing():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			k.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			k.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			k.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			k.y += 1
	if k != Vector2.ZERO:
		_pan_world(k.normalized() * zoom * 0.9 * delta)
	_apply()

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func _pan_world(v: Vector2) -> void:
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
	position += right * v.x + fwd * v.y
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)

func pan_pixels(rel: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var wpp := zoom / vp.y
	_pan_world(Vector2(-rel.x * wpp, -rel.y * wpp / sin(-pitch)))

func zoom_by(f: float) -> void:
	zoom_target = clampf(zoom_target * f, 9.0, 90.0)

func rotate_step(d: int) -> void:
	yaw_target += d * PI / 2.0

func focus(p: Vector3, z := -1.0) -> void:
	if focus_tween:
		focus_tween.kill()
	focus_tween = create_tween()
	focus_tween.tween_property(self, "position", Vector3(p.x, 0, p.z), 0.6).set_trans(Tween.TRANS_SINE)
	if z > 0.0:
		zoom_target = z

func ground_point(screen: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen)
	var n := cam.project_ray_normal(screen)
	var pl := Plane(Vector3.UP, 0.0)
	return pl.intersects_ray(o, n)

# 由主場景轉送未被介面吃掉的輸入
func handle_input(e: InputEvent) -> bool:
	if (e is InputEventMouseButton or e is InputEventMouseMotion) and e.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(0.88)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(1.13)
			return true
		if mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			drag_pan = mb.pressed
			return false
	elif e is InputEventMouseMotion:
		if drag_pan:
			pan_pixels((e as InputEventMouseMotion).relative)
			return true
	elif e is InputEventMagnifyGesture:
		zoom_by(1.0 / (e as InputEventMagnifyGesture).factor)
		return true
	elif e is InputEventPanGesture:
		pan_pixels((e as InputEventPanGesture).delta * 8.0)
		return true
	elif e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			touches[st.index] = st.position
		else:
			touches.erase(st.index)
		_pinch_d = _pinch_dist()
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		touches[sd.index] = sd.position
		if touches.size() >= 2:
			var d := _pinch_dist()
			if _pinch_d > 0.0 and d > 0.0:
				zoom_by(_pinch_d / d)
			_pinch_d = d
			pan_pixels(sd.relative * 0.5)
			return true
		elif touch_pan_enabled:
			pan_pixels(sd.relative)
			return true
	elif e is InputEventKey and e.pressed and not e.echo:
		var kk := e as InputEventKey
		if kk.keycode == KEY_Q:
			rotate_step(-1)
			return true
		if kk.keycode == KEY_E:
			rotate_step(1)
			return true
		if kk.keycode in [KEY_EQUAL, KEY_KP_ADD]:
			zoom_by(0.85)
			return true
		if kk.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			zoom_by(1.18)
			return true
	return false

func _pinch_dist() -> float:
	if touches.size() < 2:
		return 0.0
	var ks := touches.keys()
	return (touches[ks[0]] as Vector2).distance_to(touches[ks[1]])
