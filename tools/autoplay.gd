extends Node

## Automated story smoke test: advances dialogue, teleports to markers,
## presses interaction prompts, clears mission enemies and records frames.
## It is intentionally not a gameplay bot — it validates mission logic.

var main: Node
var shots := "/tmp/opencode/shots/auto"
var start_ms := 0
var last_index := -2
var shot_index := -1
var log_at := 0
var last_obj := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._on_new_game()
	start_ms = Time.get_ticks_msec()
	await get_tree().create_timer(0.8).timeout

	var elapsed := 0.0
	while elapsed < 420.0:
		elapsed = float(Time.get_ticks_msec() - start_ms) / 1000.0
		var m = main.missions
		var hud = main.hud
		Game.set_health(Game.MAX_HEALTH)

		if hud.dialogue_active:
			hud._advance_dialogue()
			await get_tree().create_timer(0.14).timeout
			continue

		if m.active_index != last_index:
			last_index = m.active_index
			print("[auto] mission %d  t=%.1f" % [last_index, elapsed])
			await _capture("m%d_start" % last_index)

		_kill_enemies()

		var mp: Variant = m.get_marker_position()
		if mp != null:
			var target: Vector3 = mp
			await _approach(target, hud)

		# mission-specific nudges
		var obj: String = hud.objective_label.text.to_lower()
		if obj != last_obj:
			last_obj = obj
			if obj != "":
				print("[auto] obj -> %s  (t=%.1f)" % [obj, elapsed])
		if obj.contains("chase down") and m._marker_source is Vehicle:
			var car: Vehicle = m._marker_source
			await _mount_and_move_to(main.player, car.global_position + Vector3(1.6, 0.2, 0.0))
		if obj.contains("destroy") and m._marker_source is Vehicle:
			var target_car: Vehicle = m._marker_source
			target_car.take_damage(9999.0, target_car.global_position)

		if Game.mission_index >= 7:
			print("[auto] story complete at t=%.1f" % elapsed)
			break

		if elapsed > log_at:
			log_at = elapsed + 4.0
			print("[auto] t=%.1f idx=%d obj=%s marker=%s in_car=%s" % [
				elapsed, m.active_index, obj, str(mp), str(main.player.in_vehicle != null)])

		await get_tree().create_timer(0.12).timeout

	print("[auto] done mission_index=%d money=%d" % [Game.mission_index, Game.money])
	await _capture("final")
	get_tree().quit()

func _approach(target: Vector3, hud) -> void:
	var p = main.player
	# get into the mission car if this objective is about driving
	var obj: String = hud.objective_label.text.to_lower()
	var wants_car := obj.contains("steal") or obj.contains("get in") or obj.contains("take the car") or obj.contains("get to the getaway") or obj.contains("run cal down")
	var near_car: Vehicle = null
	if wants_car:
		var bd := 9.0
		for v: Node in get_tree().get_nodes_in_group("vehicles"):
			if not is_instance_valid(v):
				continue
			if not v.has_method("set_driver") or not v.has_method("can_enter"):
				continue
			if not (v as Vehicle).can_enter() or (v as Vehicle).driver != null:
				continue
			if (v as Vehicle).ai_active:
				continue
			var d: float = (v as Node3D).global_position.distance_to(target)
			if d < bd:
				bd = d
				near_car = v
		if near_car and (p.in_vehicle == null or p.in_vehicle != near_car):
			# only swap cars when the marker is actually on a car (mission target),
			# not when we have merely arrived at a destination near parked cars
			var at_destination: bool = p.in_vehicle != null and (p.in_vehicle as Node3D).global_position.distance_to(target) < 4.0
			if not at_destination:
				if p.in_vehicle != null:
					p.exit_vehicle()
					await get_tree().physics_frame
				p.enter_vehicle(near_car)
				await get_tree().create_timer(0.2).timeout

	if p.in_vehicle != null:
		var v: Vehicle = p.in_vehicle
		if v.global_position.distance_to(target) > 3.0:
			v.global_position = target + Vector3(1.4, 0.35, 0.0)
			v.velocity = Vector3.ZERO
		# let the player mirror the car position
		await get_tree().physics_frame
		await get_tree().physics_frame
	else:
		if p.global_position.distance_to(target) > 2.0 or p.global_position.y < target.y - 0.5:
			p.global_position = target + Vector3(1.3, 0.35, 0.0)
			p.velocity = Vector3.ZERO
			await get_tree().physics_frame

	if hud.mission_prompt != "":
		if p.in_vehicle != null:
			p.exit_vehicle()
			await get_tree().physics_frame
		var marker: Vector3 = target
		if p.global_position.distance_to(marker) > 3.0:
			p.global_position = marker + Vector3(1.0, 0.3, 0.0)
		Input.action_press("interact")
		await get_tree().physics_frame
		await get_tree().process_frame
		Input.action_release("interact")
		await get_tree().create_timer(0.18).timeout

func _mount_and_move_to(p, target: Vector3) -> void:
	if p.in_vehicle != null:
		var v: Vehicle = p.in_vehicle
		v.global_position = target
		v.velocity = Vector3.ZERO
		await get_tree().physics_frame
	else:
		p.global_position = target
		p.velocity = Vector3.ZERO

func _kill_enemies() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(150.0, (e as Node3D).global_position)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [shots, label])
		print("[shot] ", label)
