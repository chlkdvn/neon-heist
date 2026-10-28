extends Node3D

func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var c: Node3D = load("res://assets/models/character/character.glb").instantiate()
	c.scale = Vector3.ONE * 1.78
	c.position = Vector3(0, 0, 0)
	add_child(c)
	var ap := c.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.play("idle")

	var car: Node3D = load("res://assets/models/cars/sedan-sports.glb").instantiate()
	car.scale = Vector3.ONE * 1.55
	car.position = Vector3(4, 0.02, 0)
	add_child(car)

	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.current = true

	await get_tree().create_timer(0.3).timeout
	await _shot(cam, "face_posz", Vector3(0, 1.1, 3.2), Vector3(0, 0.95, 0))
	await _shot(cam, "face_negz", Vector3(0, 1.1, -3.2), Vector3(0, 0.95, 0))
	await _shot(cam, "face_side", Vector3(3.2, 1.1, 0), Vector3(0, 0.95, 0))
	await _shot(cam, "car_posz", Vector3(4, 1.1, 4.5), Vector3(4, 0.8, 0))
	await _shot(cam, "car_negz", Vector3(4, 1.1, -4.5), Vector3(4, 0.8, 0))
	await _shot(cam, "car_side", Vector3(8, 1.1, 0), Vector3(4, 0.8, 0))
	get_tree().quit()

func _shot(cam: Camera3D, label: String, pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/opencode/shots/%s.png" % label)
	print(label)
