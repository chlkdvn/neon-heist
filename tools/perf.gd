extends Node

## Performance probe: measures a busy street scene under different settings.

var main: Node

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.hud.hide_main_menu()
	main.player.global_position = Vector3(144.0, 0.25, 0.0)
	main.player.rotation.y = PI * 0.5
	main.player.camera.current = true
	Game.add_wanted(2.0)
	Game.hold_wanted(600.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await get_tree().create_timer(6.0).timeout

	await _bench("baseline")
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = false
		await _bench("no-sun-shadow")
		sun.shadow_enabled = true
	get_viewport().scaling_3d_scale = 0.55
	await _bench("scale-0.55")
	get_viewport().scaling_3d_scale = 0.70
	for p in main.peds:
		if is_instance_valid(p) and p.model:
			p.model.visible = false
	await _bench("peds-hidden")
	for p in main.peds:
		if is_instance_valid(p) and p.model:
			p.model.visible = true
	if main.traffic:
		main.traffic.visible = false
	await _bench("traffic-hidden")
	if main.traffic:
		main.traffic.visible = true
	if main.player.weapon:
		main.player.weapon.visible = false
	await _bench("weapon-hidden")
	get_tree().quit()

func _bench(label: String) -> void:
	for i in 20:
		await get_tree().process_frame
	var start := Time.get_ticks_usec()
	var frames := 180
	for i in frames:
		await get_tree().process_frame
	var secs := float(Time.get_ticks_usec() - start) / 1000000.0
	var fps := float(frames) / maxf(secs, 0.001)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("[perf] %-14s fps=%.1f draws=%d prims=%d" % [label, fps, draws, prims])
