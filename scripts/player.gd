class_name PlayerCharacter
extends CharacterBody3D

## First-person / third-person on-foot controller with a hitscan pistol.

const WALK_SPEED := 4.3
const RUN_SPEED := 7.4
const ACCEL := 38.0
const AIR_ACCEL := 8.0
const FRICTION := 14.0
const GRAVITY := 22.0
const JUMP_VELOCITY := 5.6
const MOUSE_SENS := 0.0024
const CAM_DIST := 3.6

var camera: Camera3D
var head: Node3D
var model: Node3D
var anim: AnimationPlayer
var weapon: Node3D
var muzzle: Node3D
var muzzle_light: OmniLight3D
var prompt_text := ""
var nearby_vehicle: Node = null

var third_person := false
var controls_enabled := true
var vehicle_entry_enabled := true
var in_vehicle: Node = null
var pitch := -0.03
var bob := 0.0
var ammo := 12
var reserve := 72
var reloading := 0.0
var fire_cooldown := 0.0
var aiming := false
var _step_timer := 0.0
var _death := false

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.72
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.86
	add_child(col)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.62
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 76.0
	camera.near = 0.05
	camera.far = 1600.0
	camera.top_level = true
	add_child(camera)
	camera.current = true

	model = load("res://assets/models/character/character.glb").instantiate()
	model.scale = Vector3.ONE * 1.78
	model.position.y = 0.02
	model.rotation.y = PI
	model.visible = false
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		anim.play("idle")

	_build_weapon()

	Game.player_died.connect(_on_died)
	Game.health_changed.connect(func(_v: float, _m: float) -> void: pass)

const WEAPON_BASE := Vector3(0.32, -0.27, -0.56)
const WEAPON_AIM := Vector3(0.0, -0.085, -0.44)

func _build_weapon() -> void:
	weapon = Node3D.new()
	weapon.name = "Pistol"
	weapon.position = WEAPON_BASE
	weapon.rotation = Vector3(deg_to_rad(-1.5), deg_to_rad(-4.0), deg_to_rad(2.2))
	weapon.scale = Vector3.ONE * 0.9
	camera.add_child(weapon)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.30, 0.31, 0.34)
	steel.metallic = 0.38
	steel.roughness = 0.42
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.15, 0.16, 0.18)
	frame_mat.metallic = 0.30
	frame_mat.roughness = 0.52
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.16, 0.125, 0.10)
	grip_mat.roughness = 0.86
	var glove_mat := StandardMaterial3D.new()
	glove_mat.albedo_color = Color(0.145, 0.12, 0.10)
	glove_mat.roughness = 0.92
	var sleeve_mat := StandardMaterial3D.new()
	sleeve_mat.albedo_color = Color(0.115, 0.125, 0.15)
	sleeve_mat.roughness = 0.94

	var slide := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.032, 0.044, 0.205)
	slide.mesh = sm
	slide.material_override = steel
	slide.position = Vector3(0, 0.028, -0.028)
	weapon.add_child(slide)

	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.029, 0.026, 0.145)
	frame.mesh = fm
	frame.material_override = frame_mat
	frame.position = Vector3(0, 0.0, 0.032)
	weapon.add_child(frame)

	var grip_mi := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.034, 0.115, 0.060)
	grip_mi.mesh = gm
	grip_mi.material_override = grip_mat
	grip_mi.position = Vector3(0, -0.070, 0.092)
	grip_mi.rotation.x = -0.22
	weapon.add_child(grip_mi)

	# trigger guard: three thin pieces under the frame
	var guard_mat := frame_mat
	for piece in [
		[Vector3(0.0, -0.030, -0.012), Vector3(0.006, 0.030, 0.008)],
		[Vector3(0.0, -0.046, 0.010), Vector3(0.006, 0.008, 0.052)],
		[Vector3(0.0, -0.030, 0.032), Vector3(0.006, 0.030, 0.008)],
	]:
		var g := MeshInstance3D.new()
		var gb := BoxMesh.new()
		gb.size = piece[1]
		g.mesh = gb
		g.material_override = guard_mat
		g.position = piece[0]
		weapon.add_child(g)

	# sights
	var front_sight := MeshInstance3D.new()
	var fs := BoxMesh.new()
	fs.size = Vector3(0.005, 0.007, 0.010)
	front_sight.mesh = fs
	front_sight.material_override = frame_mat
	front_sight.position = Vector3(0, 0.053, -0.118)
	weapon.add_child(front_sight)
	var rear_sight := MeshInstance3D.new()
	var rs := BoxMesh.new()
	rs.size = Vector3(0.024, 0.006, 0.008)
	rear_sight.mesh = rs
	rear_sight.material_override = frame_mat
	rear_sight.position = Vector3(0, 0.053, 0.058)
	weapon.add_child(rear_sight)

	# gloved hand and jacket sleeve
	var hand := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.056, 0.095, 0.072)
	hand.mesh = hm
	hand.material_override = glove_mat
	hand.position = Vector3(0.002, -0.088, 0.086)
	hand.rotation.x = -0.18
	weapon.add_child(hand)

	var thumb := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.024, 0.046, 0.030)
	thumb.mesh = tm
	thumb.material_override = glove_mat
	thumb.position = Vector3(-0.030, -0.058, 0.062)
	thumb.rotation = Vector3(-0.3, 0.0, 0.25)
	weapon.add_child(thumb)

	var sleeve := MeshInstance3D.new()
	var slm := BoxMesh.new()
	slm.size = Vector3(0.068, 0.072, 0.18)
	sleeve.mesh = slm
	sleeve.material_override = sleeve_mat
	sleeve.position = Vector3(0.010, -0.135, 0.205)
	sleeve.rotation = Vector3(0.22, 0.0, -0.08)
	weapon.add_child(sleeve)

	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.030, -0.132)
	weapon.add_child(muzzle)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.35)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 6.0
	muzzle.add_child(muzzle_light)

func _unhandled_input(event: InputEvent) -> void:
	if _death or not controls_enabled or in_vehicle:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.35, 1.15)
		if third_person:
			pitch = clampf(pitch, -0.8, 0.55)
	if vehicle_entry_enabled and event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Game.input_locked:
		_update_prompt()
		if nearby_vehicle and is_instance_valid(nearby_vehicle):
			enter_vehicle(nearby_vehicle)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("camera_toggle") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		third_person = not third_person
		model.visible = third_person and in_vehicle == null
		weapon.visible = not third_person
		Audio.click()

func _physics_process(delta: float) -> void:
	if in_vehicle or _death or Game.input_locked:
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	reloading = maxf(0.0, reloading - delta)
	aiming = Input.is_action_pressed("aim") and not third_person
	if reloading <= 0.0 and Input.is_action_just_pressed("reload") and ammo < 12 and reserve > 0:
		reloading = 1.15
		Game.say("", "Reloading", 1.0)
	if reloading > 0.0 and reloading <= 0.02:
		var need := 12 - ammo
		var take := mini(need, reserve)
		ammo += take
		reserve -= take
	if Input.is_action_pressed("fire") and fire_cooldown <= 0.0 and reloading <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_shoot()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if aiming:
		speed *= 0.62
	var target := dir * speed
	var a := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, a * delta)
	velocity.z = move_toward(velocity.z, target.z, a * delta)
	if dir.length_squared() < 0.01 and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta * 4.0)

	move_and_slide()
	_try_step_up()

	var planar := Vector2(velocity.x, velocity.z).length()
	bob += delta * planar * 1.9
	_update_camera(delta, planar)
	_update_anim(planar)
	_update_prompt()
	_update_weapon(delta)
	if is_on_floor() and planar > 1.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.42 if planar < 5.5 else 0.33
			Audio.play_sfx("hit", -26.0, 1.65)

func _try_step_up() -> void:
	if not is_on_floor():
		return
	var horiz := Vector3(velocity.x, 0, velocity.z)
	if horiz.length() < 0.6:
		return
	var dir := horiz.normalized()
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var probe_from := feet + Vector3(0, 0.28, 0)
	var q := PhysicsRayQueryParameters3D.create(probe_from, probe_from + dir * 0.55, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var up_from := feet + Vector3(0, 0.55, 0) + dir * 0.62
	var q2 := PhysicsRayQueryParameters3D.create(up_from, up_from + Vector3.DOWN * 0.8, 1)
	q2.exclude = [get_rid()]
	var fhit := space.intersect_ray(q2)
	if fhit.is_empty():
		return
	var rise: float = fhit.position.y - feet.y
	if rise > 0.05 and rise < 0.34:
		global_position.y = fhit.position.y + 0.01

func _update_camera(delta: float, planar: float) -> void:
	var cp := Vector3(0.0, 1.62 + sin(bob * 2.0) * 0.022, 0.0)
	var target_fov := 62.0 if aiming else 76.0
	camera.fov = lerpf(camera.fov, target_fov, delta * 10.0)
	if third_person:
		var back := transform.basis.z
		var dist := CAM_DIST + (0.7 if aiming else 0.0)
		var origin := global_position + Vector3(0, 1.55, 0)
		var desired := origin + back * dist + Vector3(0, 0.55 + sin(pitch) * dist, 0)
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(origin, desired, 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			desired = hit.position + (origin - desired).normalized() * 0.35
		camera.global_position = camera.global_position.lerp(desired, delta * 14.0)
		var look := origin + Vector3(0, 0.05, 0) + back * -2.5
		camera.look_at(look, Vector3.UP)
		camera.rotation.z = 0.0
	else:
		camera.global_position = head.global_position + Vector3(0, cp.y - 1.62, 0)
		camera.rotation = Vector3(pitch, rotation.y, 0.0)
		if planar > 4.8:
			camera.rotation.z = sin(bob) * 0.006
		else:
			camera.rotation.z = 0.0

func _update_anim(planar: float) -> void:
	if third_person and anim and not in_vehicle:
		var want := "walk" if planar > 0.5 else "idle"
		if anim.current_animation != want:
			anim.play(want)
			anim.speed_scale = clampf(planar / 4.0, 0.7, 1.8)
	elif anim:
		anim.speed_scale = 1.0

func _update_weapon(delta: float) -> void:
	if not weapon:
		return
	weapon.visible = not third_person and in_vehicle == null and not _death
	var target_pos := WEAPON_BASE
	if aiming:
		target_pos = WEAPON_AIM
	weapon.position = weapon.position.lerp(target_pos, delta * 12.0)
	if muzzle_light.light_energy > 0.0:
		muzzle_light.light_energy = maxf(0.0, muzzle_light.light_energy - delta * 40.0)

func _update_prompt() -> void:
	prompt_text = ""
	nearby_vehicle = null
	if in_vehicle:
		return
	var best: Node = null
	var bd := 4.2
	for v: Node in get_tree().get_nodes_in_group("vehicles"):
		if not is_instance_valid(v):
			continue
		if not v.has_method("set_driver"):
			continue
		if v.has_method("can_enter") and not v.can_enter():
			continue
		var d: float = global_position.distance_to((v as Node3D).global_position)
		if d < bd:
			bd = d
			best = v
	if best:
		nearby_vehicle = best
		prompt_text = "E   ENTER VEHICLE"

func _shoot() -> void:
	if ammo <= 0:
		if reserve > 0:
			Audio.click()
			Game.say("", "Out of ammo — press R", 1.2)
		return
	ammo -= 1
	fire_cooldown = 0.19
	Audio.gunshot()
	muzzle_light.light_energy = 4.0
	pitch = clampf(pitch + 0.012, -1.3, 1.1)

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var spread := 0.006 if aiming else 0.026
	if not aiming:
		dir += cam.global_transform.basis.x * randf_range(-spread, spread)
		dir += cam.global_transform.basis.y * randf_range(-spread, spread)
	dir = dir.normalized()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 220.0, 1 | 4 | 8 | 16)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	var point: Vector3 = hit.position
	_spawn_impact(point)
	Game.add_wanted(0.12)
	if col and col.has_method("take_damage"):
		col.take_damage(34.0, point)
	elif col and col.has_method("hit_by_bullet"):
		col.hit_by_bullet(34.0, point)

func _spawn_impact(point: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.82, 0.45)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.65, 0.25)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.position = point
	get_tree().current_scene.add_child(mi)
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)

func enter_vehicle(v: Node) -> void:
	if in_vehicle or v == null:
		return
	in_vehicle = v
	Game.current_vehicle = v
	model.visible = false
	weapon.visible = false
	camera.current = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	set_physics_process(false)
	if v.has_method("set_driver"):
		v.set_driver(self)
	Game.set_mouse_captured(true)
	Game.say("", "Q  radio    E  get out    V  camera", 2.6)
	Audio.click()

func exit_vehicle() -> void:
	if in_vehicle == null:
		return
	var v := in_vehicle
	in_vehicle = null
	Game.current_vehicle = null
	if v.has_method("set_driver"):
		v.set_driver(null)
	global_position = v.global_position + v.global_transform.basis.x * 2.6 + Vector3(0, 0.4, 0)
	velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	set_physics_process(true)
	camera.current = true
	model.visible = third_person
	weapon.visible = not third_person
	Game.set_mouse_captured(true)
	Audio.click()

func set_controls(enabled: bool) -> void:
	controls_enabled = enabled

func set_vehicle_entry_enabled(enabled: bool) -> void:
	vehicle_entry_enabled = enabled

func _on_died() -> void:
	if _death:
		return
	_death = true
	velocity = Vector3.ZERO
	model.visible = true
	weapon.visible = false
	model.rotation.z = 1.4
	Game.say("", "You died.", 1.0)
	await get_tree().create_timer(2.4).timeout
	_death = false
	model.rotation.z = 0.0
	Game.set_health(Game.MAX_HEALTH)
	Game.clear_wanted()
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("respawn_player"):
		main.respawn_player()
	model.visible = third_person
	weapon.visible = not third_person
