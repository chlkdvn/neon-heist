extends Node

## Session integration check: pause menu, save/continue, death respawn and
## wanted-level police spawning. Not part of normal gameplay.

var main: Node

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._on_new_game()
	await get_tree().create_timer(1.3).timeout

	# --- pause via real Escape key event
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[test] pause: tree=%s hud=%s visible=%s" % [
		get_tree().paused, main.hud.state, main.hud.pause_root.visible])
	main.hud._resume()
	await get_tree().process_frame
	print("[test] resume: tree=%s hud=%s" % [get_tree().paused, main.hud.state])

	# --- save + continue
	Game.mission_index = 3
	Game.money = 1234
	Game.save_game()
	var data: Dictionary = Game.read_save()
	print("[test] save: mission=%s money=%s present=%s" % [
		data.get("mission"), data.get("money"), not data.is_empty()])
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Game.new_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._on_continue()
	await get_tree().create_timer(2.2).timeout
	print("[test] continue: mission_index=%d active=%d money=%d state=%s" % [
		Game.mission_index, main.missions.active_index, Game.money, main.hud.state])

	# --- wanted police
	Game.add_wanted(3.0)
	Game.hold_wanted(90.0)
	await get_tree().create_timer(3.0).timeout
	var cop_count := get_tree().get_nodes_in_group("cops").size()
	Game.set_health(Game.MAX_HEALTH)
	print("[test] wanted: stars=%d cops=%d" % [Game.wanted, cop_count])

	# --- death + respawn
	Game.damage(999.0)
	await get_tree().create_timer(3.4).timeout
	print("[test] respawn: health=%.0f pos=%s state=%s" % [
		Game.health, str(main.player.global_position), main.hud.state])

	Game.clear_wanted()
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()
