extends Node3D

## Wanted-level police response: foot officers and AI cruisers.

var city: City
var player: PlayerCharacter
var foot: Array[Humanoid] = []
var cruisers: Array = []          # {car: Vehicle, deployed: bool}
var _spawn_timer := 1.0
var _calm_timer := 0.0
var _last_stars := 0
var _siren_on := false

func setup(c: City, p: PlayerCharacter) -> void:
	city = c
	player = p

func _process(delta: float) -> void:
	if player == null or city == null:
		return
	var stars := int(ceil(Game.wanted))
	if stars <= 0:
		_calm_timer += delta
		if _siren_on:
			Audio.set_siren(false)
			_siren_on = false
		if _calm_timer > 3.0:
			_despawn_all()
		return
	_calm_timer = 0.0
	if stars != _last_stars:
		_spawn_timer = 0.35
		_last_stars = stars
	_prune()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(1.6, 4.6 - stars * 0.55)
		if foot.size() < mini(1 + stars, 5):
			_spawn_cop()
		if stars >= 2 and _count_cruisers() < mini(stars - 1, 3):
			_spawn_cruiser()
	_check_cruisers(delta)
	_update_siren()

func _count_cruisers() -> int:
	var n := 0
	for entry: Dictionary in cruisers:
		var c: Vehicle = entry["car"]
		if is_instance_valid(c) and not c.destroyed:
			n += 1
	return n

func _prune() -> void:
	for i in range(foot.size() - 1, -1, -1):
		var h := foot[i]
		if not is_instance_valid(h) or h.dead or h.global_position.distance_to(player.global_position) > 170.0:
			if is_instance_valid(h) and not h.dead and h.global_position.distance_to(player.global_position) > 170.0:
				h.queue_free()
			foot.remove_at(i)
	for i in range(cruisers.size() - 1, -1, -1):
		var entry: Dictionary = cruisers[i]
		var c: Vehicle = entry["car"]
		if not is_instance_valid(c) or c.destroyed or c.global_position.distance_to(player.global_position) > 190.0:
			if is_instance_valid(c) and not c.destroyed and c.global_position.distance_to(player.global_position) > 190.0:
				c.queue_free()
			cruisers.remove_at(i)

func _despawn_all() -> void:
	for h in foot:
		if is_instance_valid(h):
			h.queue_free()
	foot.clear()
	for entry: Dictionary in cruisers:
		var c: Vehicle = entry["car"]
		if is_instance_valid(c):
			c.queue_free()
	cruisers.clear()

func _spawn_cop() -> void:
	var pos := _cop_spawn_pos()
	if pos == Vector3.INF:
		return
	var h := Humanoid.new()
	add_child(h)
	h.global_position = pos
	h.configure("cop", Color(0.46, 0.53, 0.68))
	foot.append(h)

func _cop_spawn_pos() -> Vector3:
	# On the pier, put officers on the deck so they can actually reach the player.
	if player.global_position.x > 232.0 and absf(player.global_position.z + 60.0) < 9.0:
		for attempt in 12:
			var px := clampf(player.global_position.x + randf_range(-34.0, 34.0), 250.0, 360.0)
			var pz := -60.0 + randf_range(-3.2, 3.2)
			var p := Vector3(px, 0.76, pz)
			if p.distance_to(player.global_position) > 13.0:
				return p
		return Vector3(340.0, 0.76, -60.0)
	var space := get_world_3d().direct_space_state
	for attempt in 26:
		var ang := randf() * TAU
		var dist := randf_range(24.0, 44.0)
		var raw := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		raw.x = clampf(raw.x, -210.0, 210.0)
		raw.z = clampf(raw.z, -210.0, 210.0)
		var p := city.nearest_lane_point(raw)
		p.y = 0.04
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.4, 0),
			player.global_position + Vector3(0, 1.3, 0), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return p
	return Vector3.INF

func _spawn_cruiser() -> void:
	var pos := _cruiser_spawn_pos()
	if pos == Vector3.INF:
		return
	var car := Vehicle.new()
	car.configure("res://assets/models/cars/police.glb", Color(1, 1, 1), true)
	add_child(car)
	car.global_position = pos
	var to := player.global_position - pos
	to.y = 0.0
	car.rotation.y = atan2(-to.x, -to.z)
	car.ai_chase(player, 20.0, 18.0)
	cruisers.append({"car": car, "deployed": false})
	Audio.set_engine(false)

func _cruiser_spawn_pos() -> Vector3:
	var space := get_world_3d().direct_space_state
	for attempt in 40:
		var ang := randf() * TAU
		var dist := randf_range(48.0, 78.0)
		var raw := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		raw.x = clampf(raw.x, -205.0, 205.0)
		raw.z = clampf(raw.z, -205.0, 205.0)
		var p := city.nearest_lane_point(raw)
		p.y = 0.05
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.4, 0),
			player.global_position + Vector3(0, 1.3, 0), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return p
	return Vector3.INF

func _check_cruisers(delta: float) -> void:
	for entry: Dictionary in cruisers:
		var car: Vehicle = entry["car"]
		if not is_instance_valid(car) or car.destroyed:
			continue
		if not bool(entry["deployed"]):
			var d := car.global_position.distance_to(player.global_position)
			if d < 26.0:
				entry["deployed"] = true
				car.clear_ai()
				car.ai_stop_distance = 30.0
				car.speed = 0.0
				_deploy_from(car)

func _deploy_from(car: Vehicle) -> void:
	for side in [-2.1, 2.1]:
		var p: Vector3 = car.global_position + car.global_transform.basis.x * side + Vector3(0, 0.1, 0)
		p.y = maxf(0.05, car.global_position.y)
		var h := Humanoid.new()
		add_child(h)
		h.global_position = p
		h.configure("cop", Color(0.46, 0.53, 0.68))
		foot.append(h)

func _update_siren() -> void:
	var near := false
	for entry: Dictionary in cruisers:
		var car: Vehicle = entry["car"]
		if is_instance_valid(car) and not car.destroyed:
			if car.global_position.distance_to(player.global_position) < 110.0:
				near = true
				break
	if near != _siren_on:
		_siren_on = near
		Audio.set_siren(near)
