extends Node

var main: Node
var shots := "/tmp/opencode/shots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("game_00_menu")

	main._on_new_game()
	await get_tree().create_timer(1.6).timeout
	await _capture("game_01_mission_card")

	# advance the intro dialogue line by line
	for i in 24:
		if main.hud.dialogue_active:
			main.hud._advance_dialogue()
		await get_tree().create_timer(0.28).timeout
	await get_tree().create_timer(0.8).timeout
	await _capture("game_02_pier")
	main.hud.minimap.visible = false
	await _capture("game_02b_nominimap")
	main.hud.vignette.visible = false
	main.hud.minimap.visible = true
	await _capture("game_02c_novignette")
	main.hud.vignette.visible = true

	# walk forward for a moment
	Input.action_press("move_forward")
	await get_tree().create_timer(1.4).timeout
	Input.action_release("move_forward")
	await _capture("game_03_walk")

	# meet Dex
	main.player.global_position = Vector3(343.0, 0.80, -59.2)
	await get_tree().create_timer(1.4).timeout
	await _capture("game_04_dex")
	for i in 16:
		if main.hud.dialogue_active:
			main.hud._advance_dialogue()
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(1.2).timeout

	# get into the spawned car
	var car = main.missions.find_child("DexCar", true, false)
	if car:
		main.player.global_position = car.global_position + Vector3(2.0, 0.2, 0.0)
		await get_tree().create_timer(0.4).timeout
		main.player.enter_vehicle(car)
	await get_tree().create_timer(0.8).timeout
	await _capture("game_05_driving")

	# wanted chase test
	Game.add_wanted(2.0)
	Game.hold_wanted(120.0)
	await get_tree().create_timer(7.0).timeout
	await _capture("game_06_wanted")

	# benchmark
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in 20:
		await get_tree().process_frame
	var start := Time.get_ticks_usec()
	var frames := 240
	for i in frames:
		await get_tree().process_frame
	var secs := float(Time.get_ticks_usec() - start) / 1000000.0
	var fps := float(frames) / maxf(secs, 0.001)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("[game-bench] fps=%.1f draws=%d prims=%d" % [fps, draws, prims])
	get_tree().quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [shots, label])
		print("[shot] ", label, " ", img.get_size())
