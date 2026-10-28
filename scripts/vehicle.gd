class_name Vehicle
extends CharacterBody3D

## Arcade car: stable on the flat city, readable handling, damage and explosions.

const MAX_SPEED := 30.0
const MAX_REVERSE := 9.0
const ENGINE_ACCEL := 11.5
const BRAKE := 20.0
const DRAG := 1.2
const STEER_RATE := 1.85
const GRAVITY := 24.0

var driver: Node = null
var visual: Node3D
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var wheel_spin := 0.0
var steer_visual := 0.0
var speed := 0.0
var health := 220.0
var destroyed := false
var is_police := false

# --- lightweight AI driving (cops, escorts, race rivals)
var ai_target: Node3D = null
var ai_path: PackedVector3Array = []
var ai_index := 0
var ai_cruise := 17.0
var ai_stop_distance := 16.0
var ai_active := false

var camera: Camera3D
var cam_yaw := 0.0
var cam_pitch := 0.28
var _cam_idle := 0.0
var _siren_time := 0.0
var _siren_mats: Array[StandardMaterial3D] = []
var _headlight_mats: Array[StandardMaterial3D] = []
var _brake_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("vehicles")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(45.0)
	var box := BoxShape3D.new()
	box.size = Vector3(2.15, 1.05, 4.0)
	var col := CollisionShape3D.new()
	col.shape = box
	col.position.y = 0.55
	add_child(col)

	camera = Camera3D.new()
	camera.top_level = true
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 1600.0
	add_child(camera)

	_build_lights()

func configure(path: String, tint := Color(1, 1, 1), police := false) -> void:
	is_police = police
	visual = load(path).instantiate()
	visual.scale = Vector3.ONE * 1.55
	visual.rotation.y = PI
	visual.position.y = 0.02
	add_child(visual)
	for n: Node in visual.find_children("*", "MeshInstance3D", true, false):
		if n.name.begins_with("wheel"):
			wheels.append(n as Node3D)
			if n.name.contains("front"):
				front_wheels.append(n as Node3D)
	if tint != Color(1, 1, 1):
		_tint(tint)
	if police:
		_build_siren()

func _tint(tint: Color) -> void:
	for n: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = dup.albedo_color * tint
			mi.material_override = dup

func _build_lights() -> void:
	# headlights
	for sx in [-0.62, 0.62]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.26, 0.10, 0.05)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.93, 0.75)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.92, 0.7)
		m.emission_energy_multiplier = 2.4
		mi.material_override = m
		mi.position = Vector3(sx, 0.62, -2.0)
		add_child(mi)
		_headlight_mats.append(m)
	# taillights
	for sx in [-0.62, 0.62]:
		var mi2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.26, 0.09, 0.05)
		mi2.mesh = bm2
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0.8, 0.05, 0.04)
		m2.emission_enabled = true
		m2.emission = Color(1.0, 0.06, 0.03)
		m2.emission_energy_multiplier = 0.8
		mi2.material_override = m2
		mi2.position = Vector3(sx, 0.66, 2.0)
		add_child(mi2)
		_brake_mats.append(m2)

func _build_siren() -> void:
	for item in [[-0.32, Color(1.0, 0.05, 0.03)], [0.32, Color(0.05, 0.2, 1.0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.34, 0.10, 0.18)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = item[1]
		m.emission_enabled = true
		m.emission = item[1]
		m.emission_energy_multiplier = 0.4
		mi.material_override = m
		mi.position = Vector3(item[0], 1.62, 0.1)
		add_child(mi)
		_siren_mats.append(m)

func can_enter() -> bool:
	return not destroyed and driver == null

func set_driver(p: Node) -> void:
	driver = p
	if p == null:
		camera.current = false
		speed = 0.0
		Audio.set_engine(false)
		Game.set_mouse_captured(true)
		return
	camera.current = true
	cam_yaw = 0.0
	cam_pitch = 0.28
	Game.current_vehicle = self
	Audio.set_engine(true, 0.0)
	if is_police:
		Game.add_wanted(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if driver == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.0025, -0.15, 0.85)
		_cam_idle = 0.0
	if event.is_action_pressed("interact"):
		if driver and driver.has_method("exit_vehicle"):
			driver.exit_vehicle()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("radio_next"):
		Audio.click()
		Game.say("", "WAVE 99.1 — SUNSET FM", 1.6)

func _physics_process(delta: float) -> void:
	if destroyed:
		return
	var throttle := 0.0
	var steer := 0.0
	ai_active = driver == null and (ai_target != null or ai_path.size() > 0) and not destroyed
	if ai_active:
		var c := _ai_controls()
		steer = c.x
		throttle = c.y
	elif driver and not Game.input_locked:
		throttle = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("move_right", "move_left")
		if Input.is_action_just_pressed("horn"):
			Audio.play_sfx("click", -10.0, 0.6)

	# longitudinal speed
	if driver or ai_active:
		if throttle > 0.0:
			if speed < -0.5:
				speed = move_toward(speed, 0.0, BRAKE * delta)
			else:
				var cap := ai_cruise if ai_active else MAX_SPEED
				speed = minf(cap, speed + ENGINE_ACCEL * throttle * delta)
		elif throttle < 0.0:
			if speed > 0.5:
				speed = move_toward(speed, 0.0, BRAKE * delta)
			else:
				speed = maxf(-MAX_REVERSE, speed + ENGINE_ACCEL * throttle * 0.7 * delta)
		else:
			speed = move_toward(speed, 0.0, DRAG * delta)
	else:
		speed = move_toward(speed, 0.0, BRAKE * 0.6 * delta)

	if absf(speed) < 0.02:
		speed = 0.0

	# steering only while rolling
	var steer_factor := clampf(absf(speed) / 7.0, 0.0, 1.0)
	var target_steer := steer * STEER_RATE * steer_factor * signf(speed)
	rotation.y += target_steer * delta * clampf(absf(speed) * 0.10, 0.25, 1.2)
	steer_visual = lerpf(steer_visual, steer * 0.42, delta * 8.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0
	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	var before := global_position
	move_and_slide()
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_collider() and c.get_collider() != driver:
				if absf(speed) > 8.0:
					speed *= 0.55
					Audio.play_sfx("hit", -12.0, 0.7)
					var dmg := absf(speed) * 1.2
					if dmg > 3.0:
						take_damage(dmg, c.get_position())
				break
	if global_position.y < -6.0:
		global_position = before

	# Keep the hidden player attached to the car so missions, police and the
	# minimap all use one consistent world position while driving.
	if driver and driver is Node3D:
		(driver as Node3D).global_position = global_position

	if driver:
		Audio.set_engine(true, clampf(absf(speed) / MAX_SPEED, 0.0, 1.0))
		_update_camera(delta)
	elif not ai_active:
		Audio.set_engine(false)
	_update_wheels(delta)
	_update_lights(delta)

func _ai_controls() -> Vector2:
	var aim := Vector3.ZERO
	if ai_target != null and is_instance_valid(ai_target):
		aim = ai_target.global_position
	elif ai_path.size() > 0:
		if global_position.distance_to(ai_path[ai_index]) < 8.0:
			ai_index = (ai_index + 1) % ai_path.size()
		aim = ai_path[ai_index]
	else:
		return Vector2.ZERO
	var to := aim - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < ai_stop_distance:
		return Vector2.ZERO
	var desired := atan2(-to.x, -to.z)
	var diff := wrapf(desired - rotation.y, -PI, PI)
	var steer := clampf(diff * 1.7, -1.0, 1.0)
	var throttle := 1.0
	if absf(diff) > 0.9:
		throttle = 0.32
	elif absf(diff) > 0.45:
		throttle = 0.66
	if dist < 24.0:
		throttle *= 0.55
	return Vector2(steer, throttle)

func ai_follow(points: PackedVector3Array, cruise := 17.0) -> void:
	ai_path = points
	ai_index = 0
	ai_target = null
	ai_cruise = cruise
	ai_stop_distance = 0.0

func ai_chase(target: Node3D, cruise := 20.0, stop_dist := 14.0) -> void:
	ai_target = target
	ai_path = PackedVector3Array()
	ai_cruise = cruise
	ai_stop_distance = stop_dist

func clear_ai() -> void:
	ai_target = null
	ai_path = PackedVector3Array()
	ai_active = false

func _update_camera(delta: float) -> void:
	if driver == null:
		return
	_cam_idle += delta
	if _cam_idle > 1.4 and absf(speed) > 2.0:
		cam_yaw = lerpf(cam_yaw, 0.0, delta * 1.8)
	var back := global_transform.basis.z
	var yaw_basis := Basis(Vector3.UP, cam_yaw)
	var offset := yaw_basis * (back * 7.2 + Vector3(0, 2.4 + sin(cam_pitch) * 2.2, 0))
	var origin := global_position + Vector3(0, 1.3, 0)
	var desired := origin + offset
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, desired, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		desired = hit.position + (origin - desired).normalized() * 0.4
	camera.global_position = camera.global_position.lerp(desired, delta * 12.0)
	camera.look_at(origin + back * -4.0, Vector3.UP)
	camera.rotation.z = 0.0
	camera.fov = lerpf(camera.fov, 70.0 + clampf(absf(speed) * 0.35, 0.0, 8.0), delta * 6.0)

func _update_wheels(delta: float) -> void:
	var spin := speed * delta / 0.46
	wheel_spin += spin
	for w: Node3D in wheels:
		if w.name.contains("front"):
			w.rotation.y = steer_visual
		w.rotation.x = -wheel_spin

func _update_lights(delta: float) -> void:
	for m: StandardMaterial3D in _headlight_mats:
		m.emission_energy_multiplier = 2.4 if (driver != null or ai_active) else 0.35
	var braking := driver != null and Input.get_axis("move_back", "move_forward") < -0.1 and speed > 0.2
	for m2: StandardMaterial3D in _brake_mats:
		m2.emission_energy_multiplier = 3.2 if braking else 0.8
	if is_police:
		_siren_time += delta
		var phase := int(_siren_time * 7.0) % 2
		for i in _siren_mats.size():
			_siren_mats[i].emission_energy_multiplier = 4.0 if i == phase else 0.25

func take_damage(amount: float, point := Vector3.ZERO) -> void:
	if destroyed:
		return
	health -= amount
	if health <= 0.0:
		_explode()
	elif amount > 2.0:
		Audio.play_sfx("hit", -16.0, 0.9)

func hit_by_bullet(amount: float, point: Vector3) -> void:
	take_damage(amount * 0.55, point)

func _explode() -> void:
	destroyed = true
	collision_layer = 0
	collision_mask = 0
	Audio.explosion()
	Audio.set_engine(false)
	var fire := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	fire.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.45, 0.08, 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.4, 0.05)
	fm.emission_energy_multiplier = 4.0
	fire.material_override = fm
	fire.position = global_position + Vector3(0, 1.0, 0)
	get_tree().current_scene.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.1)
	light.light_energy = 6.0
	light.omni_range = 18.0
	light.position = global_position + Vector3(0, 2.0, 0)
	get_tree().current_scene.add_child(light)
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if is_instance_valid(light): light.light_energy = 3.0
	)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(fire): fire.queue_free()
		if is_instance_valid(light): light.queue_free()
	)
	if driver and driver.has_method("exit_vehicle"):
		Game.damage(45.0)
		driver.exit_vehicle()
	visual.visible = false
	Game.notify_player("VEHICLE DESTROYED", Color(1.0, 0.3, 0.2))
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(self): queue_free()
	)
