extends Node

## Real-input check for entering and exiting a vehicle with E.

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._on_new_game()
	await get_tree().create_timer(1.4).timeout

	var car := Vehicle.new()
	car.configure("res://assets/models/cars/sedan.glb", Color(0.35, 0.55, 0.75))
	main.add_child(car)
	car.global_position = main.player.global_position + Vector3(2.0, 0.1, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[enter] prompt=%s near=%s" % [main.player.prompt_text, str(main.player.nearby_vehicle != null)])

	await _key(KEY_E)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[enter] after E: in_car=%s driver_ok=%s" % [
		main.player.in_vehicle != null, car.driver == main.player])
	if main.player.in_vehicle:
		await _key(KEY_E)
		await get_tree().physics_frame
		await get_tree().physics_frame
		print("[enter] after E again: in_car=%s" % [main.player.in_vehicle != null])
	get_tree().quit()
