class_name Forklift
extends Node3D
## 堆高機：沿網格路徑移動、叉起托盤、放進貨架或碼頭。

const SPEED := 4.5
const TURN := 5.0
const LIFT_SPEED := 1.6
const CARRY_H := 0.25

var world: World
var parts: Dictionary
var job: Dictionary = {}
var phase := ""
var waypoints: Array = []
var target_yaw := 0.0
var face_after := Vector3.ZERO
var lift_target := 0.0
var carrying = null
var _wait := 0.0
var _blink := 0.0

func setup(w: World, c: Vector2i) -> void:
	world = w
	parts = M.forklift_model()
	add_child(parts.root)
	position = w.cell_center(c)

func cell() -> Vector2i:
	return world.world_to_cell(position)

func is_idle() -> bool:
	return job.is_empty()

func unstick() -> void:
	var c := cell()
	if not world.in_floor(c) or world.astar.is_point_solid(c):
		position = world.cell_center(world.nearest_walkable(c))
		waypoints.clear()
		if not job.is_empty():
			_route_to(job.get("cur", {}))

func assign(j: Dictionary) -> void:
	job = j
	phase = "go_from"
	job["cur"] = j.from
	_route_to(j.from)

func _route_to(acc: Dictionary) -> void:
	waypoints.clear()
	if acc.is_empty():
		return
	var pts := world.path_points(cell(), acc.cell)
	if pts.size() > 0:
		pts.remove_at(0)
	waypoints = pts
	waypoints.append(acc.point)
	face_after = acc.face

func _process(delta: float) -> void:
	var dt := delta * G.speed
	if dt <= 0.0:
		return
	_blink += dt
	if parts.has("bulb"):
		(parts.bulb as Node3D).visible = job.is_empty() or fmod(_blink, 0.8) < 0.4
	var carriage: Node3D = parts.carriage
	if absf(carriage.position.y - lift_target) > 0.001:
		carriage.position.y = move_toward(carriage.position.y, lift_target, LIFT_SPEED * dt)
	if job.is_empty():
		return
	if _wait > 0.0:
		_wait -= dt
		return
	match phase:
		"go_from", "go_to":
			if _drive(dt):
				if _turn_to(face_after, dt):
					if phase == "go_from":
						phase = "lift_pick"
						lift_target = float(job.cur.h)
					else:
						phase = "lift_drop"
						lift_target = float(job.cur.h) + 0.03
		"lift_pick":
			if absf(carriage.position.y - lift_target) < 0.005:
				_attach()
				lift_target = maxf(lift_target + 0.08, CARRY_H) if lift_target > 0.3 else CARRY_H
				phase = "settle_pick"
		"settle_pick":
			if absf(carriage.position.y - lift_target) < 0.005:
				lift_target = CARRY_H
				_plan_dest()
		"wait_dest":
			_plan_dest()
		"lift_drop":
			if absf(carriage.position.y - lift_target) < 0.005:
				_detach()
				lift_target = 0.0
				phase = "lower"
		"lower":
			if absf(carriage.position.y) < 0.01:
				job = {}
				phase = ""

func _drive(dt: float) -> bool:
	if waypoints.is_empty():
		return true
	var tgt: Vector3 = waypoints[0]
	var to := tgt - position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.05:
		waypoints.remove_at(0)
		return waypoints.is_empty()
	var dir := to / dist
	var yaw := atan2(dir.x, dir.z)
	var diff := wrapf(yaw - rotation.y, -PI, PI)
	rotation.y += clampf(diff, -TURN * dt, TURN * dt)
	var sp := SPEED * (0.35 if absf(diff) > 0.8 else 1.0)
	if waypoints.size() == 1:
		sp *= 0.6
	position += dir * minf(sp * dt, dist)
	return false

func _turn_to(face: Vector3, dt: float) -> bool:
	if face == Vector3.ZERO:
		return true
	var yaw := atan2(face.x, face.z)
	var diff := wrapf(yaw - rotation.y, -PI, PI)
	if absf(diff) < 0.02:
		rotation.y = yaw
		return true
	rotation.y += clampf(diff, -TURN * dt, TURN * dt)
	return false

func _attach() -> void:
	var p = job.pallet
	if job.has("src_dock"):
		var d = job.src_dock
		d.pad[job.src_i] = null
	elif p.rack != null:
		p.rack.slots[p.slot] = null
		p.rack = null
		p.slot = -1
	p.state = "fork"
	carrying = p
	var hold: Node3D = parts.hold
	var gt: Transform3D = p.node.global_transform
	p.node.get_parent().remove_child(p.node)
	hold.add_child(p.node)
	p.node.transform = Transform3D.IDENTITY
	if randf() < 0.25:
		Snd.play_at("beep", global_position, 0.35)

func _plan_dest() -> void:
	var p = job.pallet
	if job.has("to_rack"):
		var r = job.to_rack
		if not (r in world.racks):
			job.erase("to_rack")
			var slot: Dictionary = world._find_slot(p.cargo, cell())
			if slot.is_empty():
				phase = "wait_dest"
				_wait = 3.0
				return
			slot.rack.reserved[slot.i] = true
			job.to_rack = slot.rack
			job.to_slot = slot.i
			r = slot.rack
		var acc: Dictionary = world.rack_access(r, job.to_slot, cell())
		if acc.is_empty():
			r.reserved[job.to_slot] = false
			var slot2: Dictionary = world._find_slot(p.cargo, cell())
			if slot2.is_empty():
				job.erase("to_rack")
				job["to_rack"] = r
				r.reserved[job.to_slot] = true
				phase = "wait_dest"
				_wait = 3.0
				return
			slot2.rack.reserved[slot2.i] = true
			job.to_rack = slot2.rack
			job.to_slot = slot2.i
			acc = world.rack_access(slot2.rack, slot2.i, cell())
		job.cur = acc
	else:
		job.cur = world.pad_access(job.to_dock, job.to_pad)
	phase = "go_to"
	_route_to(job.cur)

func _detach() -> void:
	var p = carrying
	carrying = null
	if p == null:
		return
	var gpos: Vector3 = p.node.global_position
	var gb: Basis = p.node.global_transform.basis
	p.node.get_parent().remove_child(p.node)
	world.dyn.add_child(p.node)
	p.claimed = false
	if job.has("to_rack"):
		var r = job.to_rack
		r.reserved[job.to_slot] = false
		r.slots[job.to_slot] = p
		p.rack = r
		p.slot = job.to_slot
		p.state = "rack"
		p.node.global_transform = Transform3D(r.node.global_transform.basis, world.slot_pos(r, job.to_slot))
		G.stats.pallets += 1
		world.refresh_capacity()
	else:
		var d = job.to_dock
		d.pad_res[job.to_pad] = false
		d.pad[job.to_pad] = p
		p.dock = d
		p.pad_i = job.to_pad
		p.state = "pad_out"
		p.node.global_transform = Transform3D(Basis(), d.pad_pos(job.to_pad))
		world.refresh_capacity()
