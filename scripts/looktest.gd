extends Node3D

## Visual / performance test for the city. Run normally, then it auto-quits.

var city: City
var cam: Camera3D
var shots_dir := "/tmp/opencode/shots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	print("[gpu] ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_video_adapter_vendor())
	_setup_environment()
	city = City.new()
	city.name = "SunsetCity"
	add_child(city)
	city.build()

	var car: Node3D = load("res://assets/models/cars/sedan-sports.glb").instantiate()
	car.scale = Vector3.ONE * 1.55
	car.position = Vector3(150, 0.06, -2.2)
	car.rotation.y = PI * 0.5
	add_child(car)
	var car2: Node3D = load("res://assets/models/cars/police.glb").instantiate()
	car2.scale = Vector3.ONE * 1.55
	car2.position = Vector3(150, 0.06, 2.2)
	car2.rotation.y = PI * 0.5
	add_child(car2)
	var dude: Node3D = load("res://assets/models/character/character.glb").instantiate()
	dude.scale = Vector3.ONE * 2.1
	dude.position = Vector3(152, 0.06, 5.2)
	add_child(dude)
	var ap := dude.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.play("idle")

	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 1500.0
	add_child(cam)
	cam.current = true

	await get_tree().create_timer(0.4).timeout

	await _shot("01_pier_arrival", Vector3(350, 2.2, -60), Vector3(60, 10, -55))
	await _shot("02_street", Vector3(168, 3.2, 3.0), Vector3(60, 4.0, -4.0))
	await _shot("03_aerial", Vector3(20, 130, 210), Vector3(0, 0, -10))
	await _shot("04_beach", Vector3(288, 6.5, -18), Vector3(80, 12, -55))
	await _shot("05_cars", Vector3(156, 1.8, 8.5), Vector3(149, 1.0, 0))
	await _shot("06_park", Vector3(36, 2.2, 8), Vector3(36, 6, -36))
	await _shot("07_casino", Vector3(-4, 4.5, 8), Vector3(-36, 16, -36))
	await _shot("08_intersection", Vector3(148, 12, 18), Vector3(144, 0, 0))
	await _shot("09_sidewalk", Vector3(163, 1.65, 22), Vector3(180, 1.2, 4))

	await _bench()
	get_tree().quit()

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/sky/venice_sunset_1k.hdr")
	pano.energy_multiplier = 0.55
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.50, 0.64)
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.78, 0.68)
	env.fog_light_energy = 0.55
	env.fog_density = 0.0010
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.95
	env.adjustment_brightness = 1.0
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 55, 0)
	sun.light_color = Color(1.0, 0.83, 0.68)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 2.0
	add_child(sun)

func _shot(label: String, pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [shots_dir, label])
		print("[shot] ", label, " ", img.get_size())

func _bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	cam.global_position = Vector3(168, 3.2, 3.0)
	cam.look_at(Vector3(60, 4.0, -4.0), Vector3.UP)
	for i in 30:
		await get_tree().process_frame
	var start := Time.get_ticks_usec()
	var frames := 300
	for i in frames:
		await get_tree().process_frame
	var secs := float(Time.get_ticks_usec() - start) / 1000000.0
	var fps := float(frames) / maxf(secs, 0.001)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	print("[bench] fps=%.1f frames=%d secs=%.2f draws=%d prims=%d objects=%d" % [fps, frames, secs, draws, prims, objs])
