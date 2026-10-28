extends Node3D

## NEON HEIST — game boot: city, player, traffic, pedestrians, police, HUD and story.

var city: City
var player: PlayerCharacter
var hud: CanvasLayer
var missions: Node3D
var cops: Node3D
var traffic: Node3D
var peds: Array[Humanoid] = []
var menu_cam: Camera3D

func _ready() -> void:
	add_to_group("main")
	randomize()
	_setup_environment()

	city = City.new()
	city.name = "SunsetCity"
	add_child(city)
	city.build()

	menu_cam = Camera3D.new()
	menu_cam.name = "MenuCamera"
	menu_cam.fov = 52.0
	menu_cam.near = 0.1
	menu_cam.far = 1600.0
	add_child(menu_cam)
	menu_cam.global_position = Vector3(344.0, 4.6, -60.0)
	menu_cam.look_at(Vector3(-70.0, 20.0, -48.0), Vector3.UP)
	menu_cam.current = true

	traffic = Node3D.new()
	traffic.name = "Traffic"
	traffic.set_script(load("res://scripts/traffic.gd"))
	add_child(traffic)
	traffic.setup(city, 7)

	_spawn_pedestrians(6)

	player = PlayerCharacter.new()
	add_child(player)
	player.global_position = city.spawn_point + Vector3(0, 0.05, 0)
	player.rotation.y = PI * 0.5
	player.camera.current = false

	missions = Node3D.new()
	missions.name = "Missions"
	missions.set_script(load("res://scripts/missions.gd"))
	add_child(missions)

	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)
	hud.player = player
	hud.city = city
	hud.missions = missions

	missions.setup(city, player, hud)

	cops = Node3D.new()
	cops.name = "Police"
	cops.set_script(load("res://scripts/cops.gd"))
	add_child(cops)
	cops.setup(city, player)

	hud.new_game_requested.connect(_on_new_game)
	hud.continue_requested.connect(_on_continue)
	hud.quit_requested.connect(_on_quit)
	Game.player_died.connect(_on_player_died)

	hud.show_main_menu(Game.has_save())
	Game.set_mouse_captured(false)
	print("[main] ready — city built, player at pier")

func _setup_environment() -> void:
	var grade := CanvasLayer.new()
	grade.name = "Grade"
	grade.layer = 5
	add_child(grade)
	var grade_rect := ColorRect.new()
	grade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade_mat := ShaderMaterial.new()
	grade_mat.shader = load("res://assets/shaders/grade.gdshader")
	grade_rect.material = grade_mat
	grade.add_child(grade_rect)

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
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-22, 55, 0)
	sun.light_color = Color(1.0, 0.83, 0.68)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 2.0
	add_child(sun)

func _spawn_pedestrians(count: int) -> void:
	for i in count:
		var bx := randi() % City.BLOCKS
		var bz := randi() % City.BLOCKS
		var loop := city.block_loop(bx, bz, 28.5, 5.0)
		var h := Humanoid.new()
		h.name = "Ped_%d" % i
		add_child(h)
		h.global_position = Vector3(loop[0].x, 0.16, loop[0].y)
		h.configure("ped", Color(1, 1, 1))
		h.model.scale = Vector3.ONE * randf_range(1.66, 1.84)
		var total := city.path_length(loop)
		h.set_path(loop, total, randf() * total, 1.0 if randf() < 0.5 else -1.0)
		h.walk_speed = randf_range(1.0, 1.5)
		peds.append(h)

# ------------------------------------------------------------------ session

func _on_new_game() -> void:
	Game.new_game()
	player.global_position = city.spawn_point + Vector3(0, 0.05, 0)
	player.rotation.y = PI * 0.5
	player.velocity = Vector3.ZERO
	player.camera.current = true
	hud.hide_main_menu()
	hud.show_location("SUNSET CITY", "SUNSET PIER — 9:12 AM", 5.0)
	missions.begin_story()

func _on_continue() -> void:
	var data := Game.read_save()
	if data.is_empty():
		return
	Game.apply_save(data)
	player.global_position = city.spawn_point + Vector3(0, 0.05, 0)
	player.rotation.y = PI * 0.5
	player.velocity = Vector3.ZERO
	Game.set_health(Game.MAX_HEALTH)
	player.camera.current = true
	hud.hide_main_menu()
	hud.show_location("SUNSET CITY", "WELCOME BACK", 5.0)
	missions.begin_story()

func _on_quit() -> void:
	get_tree().quit()

func _on_player_died() -> void:
	Game.hold_wanted(0.0)

func respawn_player() -> void:
	if player.in_vehicle != null:
		player.exit_vehicle()
	player.global_position = Vector3(180.0, 0.30, 75.0)
	player.velocity = Vector3.ZERO
	player.rotation.y = -PI * 0.5
	Game.set_health(Game.MAX_HEALTH)
	Game.clear_wanted()
	Audio.set_siren(false)
	Game.set_mouse_captured(true)
