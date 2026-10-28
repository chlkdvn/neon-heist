class_name Humanoid
extends CharacterBody3D

## Shared pedestrian / cop / enemy / ally character.

var faction := "ped"
var health := 40.0
var dead := false
var model: Node3D
var anim: AnimationPlayer
var walk_speed := 1.4
var attack_range := 17.0
var fire_delay := 1.4
var accuracy := 0.42
var damage := 7.0
var tint := Color(1, 1, 1)

var path: PackedVector2Array
var total := 0.0
var s := 0.0
var dir_sign := 1.0
var _fire_timer := 1.0
var _bob := 0.0
var _gun: Node3D
var _gun_light: OmniLight3D
var _stuck := 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.3
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.65
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.825
	add_child(col)
	model = load("res://assets/models/character/character.glb").instantiate()
	model.scale = Vector3.ONE * 1.76
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		anim.play("idle")
	_apply_tint()

func configure(kind: String, tint_color: Color) -> void:
	faction = kind
	tint = tint_color
	match kind:
		"ped":
			health = 35.0
			walk_speed = randf_range(1.1, 1.7)
			add_to_group("peds")
		"cop":
			health = 90.0
			walk_speed = 3.4
			attack_range = 20.0
			fire_delay = 1.25
			accuracy = 0.42
			damage = 8.0
			add_to_group("cops")
			_attach_gun()
		"enemy":
			health = 65.0
			walk_speed = 3.0
			attack_range = 18.0
			fire_delay = 1.5
			accuracy = 0.38
			damage = 9.0
			add_to_group("enemies")
			_attach_gun()
		"ally":
			health = 240.0
			walk_speed = 3.2
			attack_range = 22.0
			fire_delay = 1.1
			accuracy = 0.65
			damage = 18.0
			add_to_group("allies")
			_attach_gun()
	if model:
		_apply_tint()

func _apply_tint() -> void:
	if model == null or tint == Color(1, 1, 1):
		return
	var done := false
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = dup.albedo_color * tint
			mi.material_override = dup
			done = true
		if done:
			break
	if done:
		for n: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi2 := n as MeshInstance3D
			if mi2.material_override == null:
				var mat2 := mi2.get_active_material(0)
				if mat2 is StandardMaterial3D:
					var dup2 := (mat2 as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup2.albedo_color = dup2.albedo_color * tint
					mi2.material_override = dup2

func _attach_gun() -> void:
	if model == null:
		return
	var arm: Node3D = model.find_child("arm-right", true, false) as Node3D
	if arm == null:
		return
	_gun = Node3D.new()
	_gun.name = "Gun"
	_gun.position = Vector3(0.05, -0.13, -0.18)
	arm.add_child(_gun)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.055, 0.075, 0.30)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06)
	m.metallic = 0.7
	m.roughness = 0.35
	mi.material_override = m
	_gun.add_child(mi)
	_gun_light = OmniLight3D.new()
	_gun_light.light_color = Color(1.0, 0.75, 0.4)
	_gun_light.light_energy = 0.0
	_gun_light.omni_range = 4.0
	_gun_light.position = Vector3(0, 0, -0.18)
	_gun.add_child(_gun_light)

func set_path(p: PackedVector2Array, length: float, offset: float, direction := 1.0) -> void:
	path = p
	total = length
	s = offset
	dir_sign = direction

func _physics_process(delta: float) -> void:
	if dead:
		gravity_step(delta)
		return
	_fire_timer -= delta
	if faction == "ped":
		_walk_path(delta)
	else:
		_combat(delta)
	if _gun_light and _gun_light.light_energy > 0.0:
		_gun_light.light_energy = maxf(0.0, _gun_light.light_energy - delta * 30.0)

func gravity_step(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	move_and_slide()

func _walk_path(delta: float) -> void:
	if path.is_empty():
		return
	s += walk_speed * dir_sign * delta
	var pos := _sample(s)
	var ahead := _sample(s + 1.5 * dir_sign)
	var d := (ahead - pos).normalized()
	global_position = Vector3(pos.x, 0.16, pos.y)
	if d.length_squared() > 0.001:
		rotation.y = atan2(d.x, d.y)
	if anim:
		var want := "walk"
		if anim.current_animation != want:
			anim.play(want)
		anim.speed_scale = walk_speed / 1.4
	_bob += delta * walk_speed * 4.0

func _sample(v: float) -> Vector2:
	var d := fposmod(v, total)
	for i in path.size():
		var j := (i + 1) % path.size()
		var seg := path[i].distance_to(path[j])
		if d <= seg:
			return path[i].lerp(path[j], d / maxf(seg, 0.001))
		d -= seg
	return path[0]

func _combat(delta: float) -> void:
	var target := _find_target()
	var moving := false
	if target:
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 1.2:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 8.0)
		if dist > attack_range * 0.72:
			var dir := to.normalized()
			var target_vel := dir * walk_speed
			velocity.x = move_toward(velocity.x, target_vel.x, 22.0 * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, 22.0 * delta)
			moving = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if _fire_timer <= 0.0:
				_shoot_at(target)
				_fire_timer = fire_delay * randf_range(0.8, 1.3)
	elif faction == "ally":
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			var to := player.global_position - global_position
			to.y = 0
			if to.length() > 6.0:
				var want := to.normalized() * walk_speed
				velocity.x = move_toward(velocity.x, want.x, 20.0 * delta)
				velocity.z = move_toward(velocity.z, want.z, 20.0 * delta)
				moving = true
				rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 5.0)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()
	_try_step()
	if anim:
		var want2 := "walk" if moving else "idle"
		if anim.current_animation != want2:
			anim.play(want2)
		anim.speed_scale = clampf(walk_speed / 3.0, 0.7, 1.4)

func _find_target() -> Node3D:
	if faction == "ally":
		var best: Node3D = null
		var bd := 60.0
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or (e as Humanoid).dead:
				continue
			var d := global_position.distance_to((e as Node3D).global_position)
			if d < bd:
				bd = d
				best = e as Node3D
		return best
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and not Game.input_locked:
		return p
	return null

func _shoot_at(target: Node3D) -> void:
	if _gun == null:
		return
	_gun_light.light_energy = 3.0
	Audio.gunshot()
	var from := _gun.global_position
	var to := target.global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 8)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit.position
	_spawn_tracer(from, end)
	var can_hit: bool = hit.is_empty() or hit.collider == target
	var acc := accuracy
	if target.is_in_group("player") and player_in_vehicle():
		acc *= 0.55
	if can_hit and randf() < acc:
		if target.is_in_group("player"):
			Game.damage(damage)
			Game.notify_player("HIT", Color(1.0, 0.35, 0.25))
		elif target.has_method("take_damage"):
			target.take_damage(damage, end)

func player_in_vehicle() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and p.get("in_vehicle") != null

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var length := from.distance_to(to)
	bm.size = Vector3(0.025, 0.025, maxf(length, 0.1))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.3)
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	if from.distance_to(to) > 0.1:
		mi.look_at(to, Vector3.UP)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)

func _try_step() -> void:
	if not is_on_floor():
		return
	var horiz := Vector3(velocity.x, 0, velocity.z)
	if horiz.length() < 0.4:
		return
	var dir := horiz.normalized()
	var space := get_world_3d().direct_space_state
	var up_from := global_position + Vector3(0, 0.55, 0) + dir * 0.55
	var q := PhysicsRayQueryParameters3D.create(up_from, up_from + Vector3.DOWN * 0.8, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var rise: float = hit.position.y - global_position.y
		if rise > 0.05 and rise < 0.32:
			global_position.y = hit.position.y + 0.01

func take_damage(amount: float, point := Vector3.ZERO) -> void:
	if dead:
		return
	health -= amount
	if health <= 0.0:
		_die()
	else:
		Audio.play_sfx("hit", -20.0, 1.2)

func hit_by_bullet(amount: float, point: Vector3) -> void:
	take_damage(amount, point)

func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	if anim:
		anim.play("jump")
		anim.speed_scale = 1.0
	model.rotation.z = 1.45
	model.position.y = 0.1
	velocity = Vector3.ZERO
	if faction == "ped":
		Game.add_wanted(1.0)
	elif faction == "cop":
		Game.add_wanted(1.6)
	get_tree().create_timer(7.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)
