class_name Missions
extends Node3D

## Seven-mission story director, mission markers and repeatable free-roam jobs.

const TITLES := [
	"Last Call",
	"Repo Man",
	"Debt Collection",
	"The Inside Man",
	"Ocean Drive",
	"The Heist",
	"Sunset",
]
const REWARDS := [500, 800, 1200, 1500, 2000, 3000, 5000]
const PLACES := ["SUNSET PIER", "THE MARINA", "THE STRIP", "SUNSET PIER", "OCEAN DRIVE", "NEON PALMS", "SUNSET PIER"]

var city: City
var player: PlayerCharacter
var hud: CanvasLayer

var running := false
var in_mission := false
var active_index := -1
var _gen := 0
var _props: Array[Node] = []
var _marker: Node3D
var _marker_beam: MeshInstance3D
var _marker_cone: MeshInstance3D
var _marker_pos := Vector3.ZERO
var _marker_live := false
var _marker_source: Node3D = null
var _marker_time := 0.0
var _last_objective := ""

func setup(c: City, p: PlayerCharacter, h: CanvasLayer) -> void:
	city = c
	player = p
	hud = h

func _ready() -> void:
	Game.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	if _marker_live:
		_marker_time += delta
		if _marker:
			_marker.rotate_y(delta * 0.7)
			_marker.position.y = _marker_pos.y + 0.03 + sin(_marker_time * 2.2) * 0.035
		if _marker_cone:
			_marker_cone.position.y = _marker_pos.y + 2.55 + sin(_marker_time * 2.4) * 0.08
			_marker_cone.rotate_y(delta * 1.5)
		if _marker_source and is_instance_valid(_marker_source):
			_marker_pos = _marker_source.global_position
			if _marker:
				_marker.global_position = Vector3(_marker_pos.x, _marker_pos.y + 0.05, _marker_pos.z)
			if _marker_beam:
				_marker_beam.global_position = Vector3(_marker_pos.x, _marker_pos.y + 3.5, _marker_pos.z)
			if _marker_cone:
				_marker_cone.global_position = Vector3(_marker_pos.x, _marker_pos.y + 2.55, _marker_pos.z)

# ------------------------------------------------------------------ entry

func begin_story() -> void:
	if running:
		return
	running = true
	await _wait(1.0)
	while running:
		if Game.mission_index >= TITLES.size():
			await _free_roam()
			return
		var idx: int = clampi(Game.mission_index, 0, TITLES.size() - 1)
		active_index = idx
		in_mission = true
		_gen += 1
		var gen := _gen
		_clear_props()
		_clear_marker()
		Game.start_mission(idx, TITLES[idx])
		player.set_vehicle_entry_enabled(true)
		Game.set_objective("")
		hud.set_action_prompt("")
		hud.show_location(PLACES[idx], _time_of_day(idx), 4.5)
		await _wait(1.1)
		if gen != _gen:
			continue
		await _intro(idx)
		if gen != _gen:
			_clear_props()
			await _wait(3.0)
			continue
		var ok := false
		match idx:
			0: ok = await _mission_1()
			1: ok = await _mission_2()
			2: ok = await _mission_3()
			3: ok = await _mission_4()
			4: ok = await _mission_5()
			5: ok = await _mission_6()
			6: ok = await _mission_7()
		if gen != _gen:
			# the player died; wait for respawn then run the mission again
			_clear_props()
			_clear_marker()
			hud.set_action_prompt("")
			await _wait(3.4)
			continue
		_clear_marker()
		hud.set_action_prompt("")
		if not ok:
			_clear_props()
			await _wait(3.0)
			continue
		await _outro(idx)
		if gen != _gen:
			_clear_props()
			await _wait(3.0)
			continue
		Game.add_money(REWARDS[idx])
		Audio.mission_done()
		in_mission = false
		Game.complete_mission(idx)
		if idx == 6:
			await _finale()
			Game.mission_index = 7
			Game.save_game()
			running = false
			await _free_roam()
			return
		await _wait(3.6)
		_clear_props()
		await _wait(1.2)
	in_mission = false

func _time_of_day(idx: int) -> String:
	return ["MORNING — 9:12 AM", "AFTERNOON — 2:40 PM", "DUSK — 6:05 PM", "NIGHT — 12:20 AM",
		"DUSK — 7:30 PM", "NIGHT — 11:45 PM", "SUNSET — 8:10 PM"][clampi(idx, 0, 6)]

func _on_player_died() -> void:
	if in_mission:
		_gen += 1
		_clear_marker()
		hud.set_action_prompt("")

# ------------------------------------------------------------------ missions

func _mission_1() -> bool:
	var gen := _gen
	var dex_pos := Vector3(344.0, 0.76, -59.0)
	var dex := _spawn_humanoid("ped", dex_pos, Color(0.78, 0.85, 0.72))
	_dex_tag(dex, "DEX")
	if not await _goto(dex_pos, 3.2, "Meet Dex at the end of the pier"):
		return false
	if not await _dialogue([
		{"speaker": "DEX", "text": "Look at you. Bigger, meaner, still late."},
		{"speaker": "MARA", "text": "I'm not late. The ferry was."},
		{"speaker": "DEX", "text": "I got us a room at the Sunset Motel. Green door. Working lock and everything."},
		{"speaker": "MARA", "text": "And the forty grand you owe Cal?"},
		{"speaker": "DEX", "text": "...We'll talk about that after breakfast."},
	]):
		return false
	var car := _spawn_vehicle("res://assets/models/cars/hatchback-sports.glb",
		Vector3(326.0, 0.78, -62.2), PI * 0.5, Color(0.92, 0.98, 0.92))
	car.name = "DexCar"
	if not await _await_enter(car, "Get in the green car"):
		return false
	Game.say("DEX", "Okay. Easy on the paint. It's borrowed.", 3.2)
	if not await _goto(Vector3(180.0, 0.05, 69.2), 12.0, "Drive to the Sunset Motel"):
		return false
	if not await _dialogue([
		{"speaker": "DEX", "text": "Home sweet home. For tonight, anyway."},
		{"speaker": "MARA", "text": "Who turned the room over?"},
		{"speaker": "DEX", "text": "Cal's people. It's a long story."},
		{"speaker": "MARA", "text": "We've got all night."},
	]):
		return false
	Audio.pickup()
	return true

func _mission_2() -> bool:
	var gen := _gen
	if not await _dialogue([
		{"speaker": "CAL", "text": "Dexter tells me you're a good driver. I need a car brought home."},
		{"speaker": "MARA", "text": "And if I say no?"},
		{"speaker": "CAL", "text": "Then your brother learns what the bottom of the bay looks like."},
		{"speaker": "NADIA", "text": "The car's at the marina. Candy red. Try not to scratch it."},
	]):
		return false
	if not await _goto(Vector3(222.0, 0.05, -44.0), 14.0, "Get to the marina"):
		return false
	Game.say("NADIA", "Park whatever you're driving. The red car is waiting.", 2.8)
	var car := _spawn_vehicle("res://assets/models/cars/sedan-sports.glb",
		Vector3(218.8, 0.04, -44.0), 0.0, Color(0.94, 0.94, 0.91))
	car.name = "JobCar"
	car.health = 260.0
	if not await _await_enter(car, "Steal the red sports car at the marina"):
		return false
	Game.add_wanted(2.0)
	Game.hold_wanted(150.0)
	Game.say("NADIA", "That's the owner calling the cops. Drive.", 3.0)
	Audio.set_siren(true)
	if not await _goto(Vector3(-69.2, 0.05, -24.0), 12.0, "Deliver the car to the Neon Palms garage"):
		return false
	if not await _dialogue([
		{"speaker": "NADIA", "text": "Not bad. Cal's got another job for you."},
		{"speaker": "MARA", "text": "Of course he does."},
		{"speaker": "NADIA", "text": "Three businesses. Three debts. Try to leave the paint on the cars."},
	]):
		return false
	Game.clear_wanted()
	Audio.set_siren(false)
	return true

func _mission_3() -> bool:
	var gen := _gen
	if not await _dialogue([
		{"speaker": "CAL", "text": "Three businesses owe me. You're the new collections department."},
		{"speaker": "MARA", "text": "I don't do kneecaps."},
		{"speaker": "CAL", "text": "Start with reminders. The kneecaps come later."},
	]):
		return false
	var stops := [
		{"pos": Vector3(-108.0, 0.05, -69.2), "name": "pawn shop", "tag": "PAWN"},
		{"pos": Vector3(36.0, 0.05, 69.2), "name": "tattoo parlor", "tag": "TATTOO"},
		{"pos": Vector3(108.0, 0.05, -69.2), "name": "club", "tag": "CLUB"},
	]
	for stop: Dictionary in stops:
		var pos: Vector3 = stop["pos"]
		if not await _goto(pos, 10.0, "Collect from the %s" % stop["name"]):
			return false
		var muscle := _spawn_wave(3, 12.0, 26.0)
		if muscle.is_empty():
			return false
		if not await _kill_all(muscle):
			return false
		Audio.pickup()
		Game.say("", "Payment collected — %s" % stop["tag"], 2.0)
		if not await _wait(1.1):
			return false

	# the club owner runs
	var debtor := _spawn_vehicle("res://assets/models/cars/sedan.glb",
		Vector3(108.0, 0.04, -72.0), -PI * 0.5, Color(0.30, 0.26, 0.22))
	debtor.name = "DebtorCar"
	debtor.health = 120.0
	var route := PackedVector3Array([
		Vector3(146.8, 0.04, -72.0), Vector3(146.8, 0.04, -144.0),
		Vector3(72.0, 0.04, -144.0), Vector3(72.0, 0.04, -72.0),
		Vector3(0.0, 0.04, -72.0), Vector3(0.0, 0.04, -144.0),
		Vector3(-72.0, 0.04, -144.0), Vector3(-72.0, 0.04, -72.0),
		Vector3(-144.0, 0.04, -72.0), Vector3(-144.0, 0.04, -144.0),
	])
	debtor.ai_follow(route, 14.5)
	Game.add_wanted(2.0)
	Game.hold_wanted(160.0)
	Game.set_objective("Chase down the debtor")
	_marker_source = debtor
	_set_marker(debtor.global_position)
	var result := await _chase_car(debtor, 3.0)
	_marker_source = null
	if result == 0:
		return false
	if result == 2:
		Game.say("MARA", "He's not going anywhere. Neither is the debt.", 2.6)
	else:
		debtor.clear_ai()
		debtor.speed = 0.0
		var runner := _spawn_humanoid("ped", debtor.global_position + Vector3(2.2, 0.05, 0.0), Color(0.55, 0.48, 0.4))
		_dex_tag(runner, "DEBTOR")
		if not await _interact(debtor.global_position, 4.5, "E   CUFF THE DEBTOR", "Cuff the debtor"):
			return false
		Game.say("", "The debtor is in the car. Cal gets his money.", 2.4)

	Audio.click()
	Game.say("MARA", "Now we lose the cops.", 2.0)
	if not await _goto(Vector3(250.0, 0.76, -60.0), 18.0, "Lose the heat — get to the marina"):
		return false
	Game.clear_wanted()
	Audio.set_siren(false)
	Game.notify_player("HEAT LOST", Color(0.42, 0.86, 0.79))
	await _wait(1.2)
	return true

func _mission_4() -> bool:
	var gen := _gen
	if not await _goto(Vector3(344.0, 0.76, -59.0), 4.0, "Meet Nadia at the containers"):
		return false
	if not await _dialogue([
		{"speaker": "NADIA", "text": "You came. I wasn't sure you would."},
		{"speaker": "MARA", "text": "You said you had something on Cal."},
		{"speaker": "NADIA", "text": "I have a way out. But first—"},
	]):
		return false
	var nadia := _spawn_humanoid("ally", player.global_position + Vector3(2.0, 0.0, 1.0), Color(0.72, 0.30, 0.26))
	_dex_tag(nadia, "NADIA")
	nadia.health = 400.0
	hud.show_location("THE CONTAINERS", "SUNSET PIER — 12:20 AM", 3.0)
	Game.say("", "—we have company.", 2.0)
	await _wait(1.4)
	for wave in 3:
		var enemies := _spawn_pier_wave(2 + wave)
		if enemies.is_empty():
			return false
		Game.set_objective("Survive the ambush — wave %d / 3" % (wave + 1))
		if not await _kill_all(enemies):
			return false
		if not await _wait(1.0):
			return false
	if not await _dialogue([
		{"speaker": "NADIA", "text": "Cal keeps a ledger. Every bribe, every body, since '89."},
		{"speaker": "MARA", "text": "And my brother?"},
		{"speaker": "NADIA", "text": "Dex has been photographing pages for weeks. He's been trying to buy your way out."},
		{"speaker": "MARA", "text": "Then we finish what he started."},
	]):
		return false
	return true

func _mission_5() -> bool:
	var gen := _gen
	if not await _dialogue([
		{"speaker": "NADIA", "text": "Cal watches the Ocean Drive run every year. Win it and he'll want to meet you."},
		{"speaker": "MARA", "text": "And the safe code?"},
		{"speaker": "NADIA", "text": "He keeps it in his head. Get close enough and I'll do the rest."},
	]):
		return false
	var car := _spawn_vehicle("res://assets/models/cars/sedan-sports.glb",
		Vector3(218.8, 0.04, -62.0), 0.0, Color(0.66, 0.13, 0.11))
	car.name = "RaceCar"
	car.health = 300.0
	if not await _await_enter(car, "Take the car to the Ocean Drive starting line"):
		return false
	if not await _goto(Vector3(146.8, 0.05, -38.0), 12.0, "Drive to the starting line"):
		return false
	var nadia_car := _spawn_vehicle("res://assets/models/cars/sedan-sports.glb",
		Vector3(140.0, 0.04, -38.0), 0.0, Color(0.16, 0.20, 0.24))
	nadia_car.name = "NadiaCar"
	nadia_car.health = 300.0
	Game.set_objective("Beat Nadia to the finish line")
	Game.say("NADIA", "Five checkpoints. No shortcuts. Try to keep up.", 3.0)
	await _wait(2.0)
	var checkpoints := [
		Vector3(146.8, 0.05, -144.0),
		Vector3(0.0, 0.05, -141.2),
		Vector3(0.0, 0.05, 141.2),
		Vector3(146.8, 0.05, 144.0),
		Vector3(146.8, 0.05, -38.0),
	]
	var nadia_route := PackedVector3Array([
		Vector3(140.0, 0.04, -38.0), Vector3(144.0, 0.04, -72.0), Vector3(144.0, 0.04, -144.0),
		Vector3(72.0, 0.04, -144.0), Vector3(0.0, 0.04, -144.0),
		Vector3(0.0, 0.04, -72.0), Vector3(0.0, 0.04, 0.0),
		Vector3(0.0, 0.04, 72.0), Vector3(0.0, 0.04, 144.0),
		Vector3(72.0, 0.04, 144.0), Vector3(144.0, 0.04, 144.0),
		Vector3(144.0, 0.04, 72.0), Vector3(144.0, 0.04, 0.0),
		Vector3(144.0, 0.04, -38.0),
	])
	Game.input_locked = true
	Game.say("", "3", 0.75)
	await _wait(1.0)
	Game.say("", "2", 0.75)
	await _wait(1.0)
	Game.say("", "1", 0.75)
	await _wait(1.0)
	Game.say("", "GO", 1.0)
	Game.input_locked = false
	nadia_car.ai_follow(nadia_route, 17.5)
	var finish: Vector3 = checkpoints[checkpoints.size() - 1]
	for i in checkpoints.size():
		var cp: Vector3 = checkpoints[i]
		if i == checkpoints.size() - 1:
			Game.set_objective("FINISH — Ocean Drive")
		else:
			Game.set_objective("Checkpoint %d / 4" % (i + 1))
		_set_marker(cp)
		var passed := false
		while _gen == gen:
			if player.global_position.distance_to(cp) < 16.0:
				passed = true
				break
			if nadia_car.ai_index >= nadia_route.size() - 1 and nadia_car.global_position.distance_to(finish) < 16.0:
				break
			await get_tree().physics_frame
		if not passed:
			_clear_marker()
			Game.say("NADIA", "Too slow, Velez. Try again.", 2.4)
			return false
		Audio.click()
		if not await _wait(0.35):
			return false
	_clear_marker()
	if not await _dialogue([
		{"speaker": "NADIA", "text": "That was almost impressive. Cal's watching."},
		{"speaker": "MARA", "text": "Good. Let him watch."},
		{"speaker": "NADIA", "text": "He'll want to see you at the casino. Tomorrow night. The code goes in the safe at midnight."},
	]):
		return false
	return true

func _mission_6() -> bool:
	var gen := _gen
	if not await _dialogue([
		{"speaker": "NADIA", "text": "Three charges. One safe. Then we disappear."},
		{"speaker": "MARA", "text": "Dex is inside."},
		{"speaker": "NADIA", "text": "I know. That's why we're doing it tonight."},
	]):
		return false
	var getaway := _spawn_vehicle("res://assets/models/cars/sedan.glb",
		Vector3(-69.2, 0.04, -18.0), PI * 0.5, Color(0.14, 0.15, 0.17))
	getaway.name = "GetawayCar"
	var charges := [
		{"pos": Vector3(-58.5, 0.16, -20.0), "name": "loading dock"},
		{"pos": Vector3(-13.5, 0.16, -30.0), "name": "security door"},
		{"pos": Vector3(-36.0, 0.16, -8.5), "name": "service hatch"},
	]
	for charge: Dictionary in charges:
		var cp: Vector3 = charge["pos"]
		if not await _goto(cp, 4.0, "Plant a charge at the %s" % charge["name"]):
			return false
		if not await _interact(cp, 4.0, "E   PLANT CHARGE", "Plant a charge at the %s" % charge["name"]):
			return false
		Audio.play_sfx("click", -4.0, 1.8)
		_spark(cp + Vector3(0, 0.4, 0))
		if not await _wait(0.7):
			return false
	if not await _goto(Vector3(-36.0, 0.16, -8.5), 4.0, "Crack Cal's office safe"):
		return false
	if not await _interact(Vector3(-36.0, 0.16, -8.5), 4.0, "E   CRACK THE SAFE", "Crack Cal's office safe"):
		return false
	Audio.explosion()
	_blast(Vector3(-45.0, 0.6, -18.0))
	if not await _dialogue([
		{"speaker": "CAL", "text": "Mara. You should have stayed on the ferry."},
		{"speaker": "MARA", "text": "And miss all this?"},
		{"speaker": "NADIA", "text": "The Ledger's in your hand. Now run."},
	]):
		return false
	Game.add_wanted(3.0)
	Game.hold_wanted(200.0)
	Audio.set_siren(true)
	if player.in_vehicle == null:
		if not await _await_enter(getaway, "Get to the getaway car"):
			return false
	if not await _goto(Vector3(250.0, 0.76, -60.0), 18.0, "Escape to the marina with the Ledger"):
		return false
	Game.clear_wanted()
	Audio.set_siren(false)
	Game.notify_player("LEDGER SECURED — HEAT LOST", Color(0.42, 0.86, 0.79))
	if not await _dialogue([
		{"speaker": "NADIA", "text": "One more night. Then we're ghosts."},
		{"speaker": "MARA", "text": "Cal won't let this go."},
		{"speaker": "NADIA", "text": "No. He won't."},
	]):
		return false
	return true

func _mission_7() -> bool:
	var gen := _gen
	var dex_pos := Vector3(352.0, 0.76, -56.5)
	var dex := _spawn_humanoid("ped", dex_pos, Color(0.78, 0.85, 0.72))
	_dex_tag(dex, "DEX")
	var cal := _spawn_humanoid("ped", Vector3(340.0, 0.76, -62.0), Color(0.16, 0.14, 0.15))
	_dex_tag(cal, "CAL")
	var backup := _spawn_vehicle("res://assets/models/cars/sedan.glb",
		Vector3(256.0, 0.78, -57.5), PI * 0.5, Color(0.12, 0.13, 0.16))
	backup.name = "PierCar"
	if not await _goto(Vector3(340.0, 0.76, -59.0), 5.0, "Get to the pier — Dex is in trouble"):
		return false
	if not await _dialogue([
		{"speaker": "CAL", "text": "You brought a gun to a business meeting. I'm insulted."},
		{"speaker": "MARA", "text": "Where's Dex?"},
		{"speaker": "CAL", "text": "Somewhere with a view. Bring me the Ledger and he keeps breathing."},
		{"speaker": "DEX", "text": "Mara—don't!"},
	]):
		return false
	# Cal bolts for his car
	cal.queue_free()
	var cal_car := _spawn_vehicle("res://assets/models/cars/sedan-sports.glb",
		Vector3(304.0, 0.78, -62.4), PI * 0.5, Color(0.09, 0.09, 0.11))
	cal_car.name = "CalCar"
	cal_car.health = 170.0
	cal_car.ai_follow(PackedVector3Array([
		Vector3(240.0, 0.76, -60.0), Vector3(218.8, 0.04, -60.0),
		Vector3(218.8, 0.04, -144.0), Vector3(144.0, 0.04, -144.0),
		Vector3(144.0, 0.04, -72.0), Vector3(216.0, 0.04, -72.0),
		Vector3(216.0, 0.04, 0.0), Vector3(144.0, 0.04, 0.0),
		Vector3(144.0, 0.04, 72.0), Vector3(72.0, 0.04, 72.0),
		Vector3(72.0, 0.04, 0.0), Vector3(0.0, 0.04, 0.0),
		Vector3(0.0, 0.04, -72.0), Vector3(-72.0, 0.04, -72.0),
	]), 19.0)
	Audio.explosion()
	_spark(Vector3(304.0, 1.2, -62.4))
	Game.say("CAL", "You want the Ledger? Come and take it!", 3.0)
	var guards := _spawn_pier_wave(4)
	if guards.is_empty():
		return false
	Game.set_objective("Fight through Cal's men")
	if not await _kill_all(guards):
		return false
	_marker_source = cal_car
	_set_marker(cal_car.global_position)
	if player.in_vehicle == null:
		Game.set_objective("Take the car and run Cal down")
		if not await _await_enter_any(backup):
			return false
	Game.set_objective("Destroy Cal's car")
	var wrecked := await _destroy_car(cal_car)
	_marker_source = null
	if not wrecked:
		return false
	Audio.explosion()
	_blast(cal_car.global_position)
	await _wait(2.2)
	Game.say("MARA", "That was for Dex.", 3.0)
	await _wait(3.0)
	_clear_marker()
	if not await _dialogue([
		{"speaker": "DEX", "text": "You actually did it. You burned Cal Rourke."},
		{"speaker": "MARA", "text": "I burned everything he touched."},
		{"speaker": "DEX", "text": "The Ledger. All of it?"},
		{"speaker": "MARA", "text": "Every page."},
	]):
		return false
	Game.clear_wanted()
	return true

# ------------------------------------------------------------------ finale / free roam

func _finale() -> void:
	hud.show_location("SUNSET BEACH", "THE LAST NIGHT OF SUMMER", 6.0)
	await _dialogue([
		{"speaker": "", "text": "The sun went down on Sunset City like it always did."},
		{"speaker": "DEX", "text": "So what happens now?"},
		{"speaker": "MARA", "text": "We get out."},
		{"speaker": "", "text": "Somewhere behind them, a radio played."},
	])
	if hud.has_method("show_ending"):
		hud.show_ending("SUNSET", "SUNSET CITY WILL REMEMBER")
	await get_tree().create_timer(9.0).timeout

func _free_roam() -> void:
	in_mission = false
	running = true
	active_index = -1
	Game.set_objective("Free roam — the city is yours")
	hud.set_action_prompt("")
	await _wait(9.0)
	while running:
		var pickup_pos: Vector3 = [Vector3(-108.0, 0.05, -69.2), Vector3(36.0, 0.05, 69.2),
			Vector3(108.0, 0.05, -69.2), Vector3(-36.0, 0.05, 69.2)][randi() % 4]
		if not await _goto(pickup_pos, 9.0, "Delivery job — pick up the package"):
			return
		Audio.pickup()
		Game.say("", "Package secured. Delivery marked on your map.", 2.4)
		var drop_pos: Vector3 = [Vector3(250.0, 0.76, -60.0), Vector3(180.0, 0.05, 69.2),
			Vector3(-69.2, 0.05, -36.0), Vector3(146.8, 0.05, 144.0)][randi() % 4]
		if not await _goto(drop_pos, 10.0, "Deliver the package — $250"):
			return
		Game.add_money(250)
		Audio.mission_done()
		Game.notify_player("+$250  DELIVERY COMPLETE", Color(0.96, 0.72, 0.30))
		await _wait(5.0)
		Game.set_objective("Free roam — the city is yours")

# ------------------------------------------------------------------ mission helpers

func _intro(idx: int) -> void:
	match idx:
		0: await _dialogue([
			{"speaker": "", "text": "SUNSET CITY. The year is 1999. The ferry runs once a day."},
			{"speaker": "MARA", "text": "Five years. The pier still smells like diesel and bad decisions."},
			{"speaker": "DEX", "text": "Mara! Over here! You look like you just got out of prison."},
			{"speaker": "MARA", "text": "I did."},
		])
		1: await _dialogue([
			{"speaker": "CAL", "text": "Dexter's debt is forty thousand dollars, Mara. I'm told you can make it disappear."},
			{"speaker": "MARA", "text": "I'm listening."},
		])
		2: await _dialogue([
			{"speaker": "NADIA", "text": "The pawn shop, the tattoo parlor, the club. They all stopped paying this month."},
			{"speaker": "MARA", "text": "And Cal wants his money."},
			{"speaker": "NADIA", "text": "Cal wants his money."},
		])
		3: await _dialogue([
			{"speaker": "", "text": "MIDNIGHT. The containers at the end of the pier."},
			{"speaker": "NADIA", "text": "Don't bring anyone. Trust me."},
		])
		4: await _dialogue([
			{"speaker": "", "text": "The Ocean Drive run. Every street racer on the island, and one very public exit."},
			{"speaker": "MARA", "text": "Five checkpoints. How hard can it be?"},
		])
		5: await _dialogue([
			{"speaker": "", "text": "MIDNIGHT. The Neon Palms Casino. Cal is upstairs. Dex is inside."},
			{"speaker": "MARA", "text": "Three charges. One ledger. No mistakes."},
		])
		6: await _dialogue([
			{"speaker": "", "text": "Cal took Dex to the pier. He wants the Ledger back."},
			{"speaker": "DEX", "text": "Mara— don't come alone."},
		])

func _outro(idx: int) -> void:
	match idx:
		0: await _dialogue([
			{"speaker": "DEX", "text": "Told you. Everything's gonna be different."},
			{"speaker": "MARA", "text": "That's what scares me."},
		])
		1: await _dialogue([
			{"speaker": "NADIA", "text": "Cal's got another job for you. Try not to enjoy it."},
			{"speaker": "MARA", "text": "I never do."},
		])
		2: await _dialogue([
			{"speaker": "CAL", "text": "Three payments. My faith in you is almost restored."},
			{"speaker": "MARA", "text": "Keep the faith. Keep my brother breathing."},
		])
		3: await _dialogue([
			{"speaker": "NADIA", "text": "The Ledger is real. And it's going to set us both free."},
			{"speaker": "MARA", "text": "Then we take it."},
		])
		4: await _dialogue([
			{"speaker": "NADIA", "text": "Cal's watching. Tomorrow night, the casino. Midnight."},
			{"speaker": "MARA", "text": "I'll be there."},
		])
		5: await _dialogue([
			{"speaker": "NADIA", "text": "One more night. Then we're ghosts."},
			{"speaker": "MARA", "text": "Cal won't let this go."},
		])
		_: await _wait(0.1)

func _dialogue(lines: Array) -> bool:
	var gen := _gen
	Game.input_locked = true
	Game.dialogue_requested.emit(lines)
	await Game.dialogue_finished
	return gen == _gen

func _wait(seconds: float) -> bool:
	var gen := _gen
	await get_tree().create_timer(seconds).timeout
	return gen == _gen

func _goto(pos: Vector3, radius: float, objective: String) -> bool:
	var gen := _gen
	_set_marker(pos)
	Game.set_objective(objective)
	while gen == _gen:
		if player.global_position.distance_to(pos) < radius:
			_clear_marker()
			return true
		await get_tree().physics_frame
	_clear_marker()
	return false

func _await_enter(v: Vehicle, objective: String) -> bool:
	var gen := _gen
	player.set_vehicle_entry_enabled(true)
	Game.set_objective(objective)
	_set_marker(v.global_position)
	while gen == _gen:
		if not is_instance_valid(v) or v.destroyed:
			hud.set_action_prompt("")
			_clear_marker()
			return false
		_marker_pos = v.global_position
		if player.in_vehicle == v:
			hud.set_action_prompt("")
			_clear_marker()
			return true
		if player.in_vehicle != null:
			hud.set_action_prompt("E   GET OUT — THEN ENTER THE MARKED CAR")
		elif player.global_position.distance_to(v.global_position) < 6.0:
			hud.set_action_prompt("E   ENTER THE MARKED CAR")
		else:
			hud.set_action_prompt("")
		await get_tree().physics_frame
	hud.set_action_prompt("")
	_clear_marker()
	return false

func _await_enter_any(v: Vehicle) -> bool:
	var gen := _gen
	_set_marker(v.global_position)
	while gen == _gen:
		if player.in_vehicle != null:
			_clear_marker()
			return true
		if not is_instance_valid(v):
			return false
		await get_tree().physics_frame
	return false

func _interact(pos: Vector3, radius: float, prompt: String, objective: String) -> bool:
	var gen := _gen
	player.set_vehicle_entry_enabled(false)
	_set_marker(pos)
	Game.set_objective(objective)
	hud.set_action_prompt(prompt)
	while gen == _gen:
		if player.in_vehicle == null and player.global_position.distance_to(pos) < radius:
			if Input.is_action_just_pressed("interact"):
				hud.set_action_prompt("")
				_clear_marker()
				player.set_vehicle_entry_enabled(true)
				Audio.click()
				return true
		await get_tree().physics_frame
	hud.set_action_prompt("")
	_clear_marker()
	player.set_vehicle_entry_enabled(true)
	return false

func _kill_all(enemies: Array) -> bool:
	var gen := _gen
	while gen == _gen:
		var alive := 0
		for e: Node in enemies:
			if is_instance_valid(e) and not (e as Humanoid).dead:
				alive += 1
		if alive == 0:
			return true
		await get_tree().create_timer(0.35).timeout
	return false

func _chase_car(car: Vehicle, hold_time: float) -> int:
	var gen := _gen
	var close := 0.0
	while gen == _gen:
		if not is_instance_valid(car) or car.destroyed:
			return 2
		_marker_pos = car.global_position
		var d := player.global_position.distance_to(car.global_position)
		if d < 16.0:
			close += get_physics_process_delta_time() + 0.016
		else:
			close = 0.0
		if close >= hold_time:
			return 1
		await get_tree().physics_frame
	return 0

func _destroy_car(car: Vehicle) -> bool:
	var gen := _gen
	while gen == _gen:
		if not is_instance_valid(car) or car.destroyed:
			return true
		await get_tree().physics_frame
	return false

# ------------------------------------------------------------------ spawning

func _spawn_humanoid(kind: String, pos: Vector3, tint: Color) -> Humanoid:
	var h := Humanoid.new()
	add_child(h)
	h.global_position = pos
	h.configure(kind, tint)
	_props.append(h)
	return h

func _spawn_vehicle(path: String, pos: Vector3, yaw: float, tint: Color, police := false) -> Vehicle:
	var v := Vehicle.new()
	v.configure(path, tint, police)
	add_child(v)
	v.global_position = pos
	v.rotation.y = yaw
	_props.append(v)
	return v

func _spawn_wave(count: int, min_d: float, max_d: float) -> Array:
	var out: Array = []
	for i in count:
		var p := _find_spawn(min_d, max_d)
		if p == Vector3.INF:
			continue
		var e := _spawn_humanoid("enemy", p, Color(0.40, 0.34, 0.33))
		out.append(e)
	return out

func _spawn_pier_wave(count: int) -> Array:
	var out: Array = []
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var along := 10.0 + i * 5.5
		var p := Vector3(clampf(player.global_position.x - along, 260.0, 358.0), 0.76,
			-60.0 + side * 2.4)
		if p.distance_to(player.global_position) < 5.0:
			p.x -= 9.0
		var e := _spawn_humanoid("enemy", p, Color(0.40, 0.34, 0.33))
		out.append(e)
	return out

func pier_center() -> Vector3:
	if player and player.global_position.x > 238.0 and absf(player.global_position.z + 60.0) < 8.0:
		return Vector3(clampf(player.global_position.x, 260.0, 350.0), 0.76, -60.0)
	return Vector3(320.0, 0.76, -60.0)

func _find_spawn(min_d: float, max_d: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	for attempt in 24:
		var ang := randf() * TAU
		var dist := randf_range(min_d, max_d)
		var p := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		p.x = clampf(p.x, -214.0, 214.0)
		p.z = clampf(p.z, -214.0, 214.0)
		if absf(p.x) > 218.0 or absf(p.z) > 218.0:
			continue
		p.y = _ground_y(p) + 0.02
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.3, 0),
			player.global_position + Vector3(0, 1.3, 0), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return p
	return Vector3.INF

func _ground_y(p: Vector3) -> float:
	if p.x > 238.0 and p.x < 370.0 and absf(p.z + 60.0) < 5.0:
		return 0.75
	if p.x > 224.0 and p.x <= 238.0 and absf(p.z + 60.0) < 5.0:
		return 0.45
	for c in city.block_centers:
		if absf(p.x - c.x) < City.BLOCK_SIZE * 0.5 and absf(p.z - c.y) < City.BLOCK_SIZE * 0.5:
			return City.WALK_Y
	if absf(p.x) <= City.CITY_EDGE and absf(p.z) <= City.CITY_EDGE:
		return City.ROAD_Y
	return City.SAND_Y

# ------------------------------------------------------------------ markers and fx

func set_external_marker(pos: Vector3) -> void:
	_set_marker(pos)

func _set_marker(pos: Vector3) -> void:
	_marker_pos = pos
	_marker_live = true
	_marker_source = null
	if _marker == null:
		_marker = Node3D.new()
		_marker.name = "MissionMarker"
		add_child(_marker)
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.7
		cm.bottom_radius = 1.7
		cm.height = 0.08
		ring.mesh = cm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(1.0, 0.78, 0.30)
		rm.emission_enabled = true
		rm.emission = Color(1.0, 0.62, 0.16)
		rm.emission_energy_multiplier = 2.0
		ring.material_override = rm
		_marker.add_child(ring)
		_marker_beam = MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.11
		bm.bottom_radius = 0.21
		bm.height = 7.0
		_marker_beam.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = Color(1.0, 0.68, 0.24, 0.05)
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		bmat.emission_enabled = true
		bmat.emission = Color(1.0, 0.55, 0.15)
		bmat.emission_energy_multiplier = 0.22
		_marker_beam.material_override = bmat
		_marker_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker_beam)
		_marker_cone = MeshInstance3D.new()
		var km := CylinderMesh.new()
		km.top_radius = 0.0
		km.bottom_radius = 0.42
		km.height = 0.85
		_marker_cone.mesh = km
		var kmat := StandardMaterial3D.new()
		kmat.albedo_color = Color(1.0, 0.80, 0.36)
		kmat.emission_enabled = true
		kmat.emission = Color(1.0, 0.62, 0.18)
		kmat.emission_energy_multiplier = 1.5
		_marker_cone.material_override = kmat
		_marker_cone.rotation.z = PI
		_marker_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker_cone)
	_marker.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	if _marker_beam:
		_marker_beam.global_position = Vector3(pos.x, pos.y + 3.5, pos.z)
		_marker_beam.visible = true
	if _marker_cone:
		_marker_cone.global_position = Vector3(pos.x, pos.y + 2.55, pos.z)
		_marker_cone.visible = true
	if _marker:
		_marker.visible = true

func _clear_marker() -> void:
	_marker_live = false
	_marker_source = null
	if _marker:
		_marker.visible = false
	if _marker_beam:
		_marker_beam.visible = false
	if _marker_cone:
		_marker_cone.visible = false

func get_marker_position() -> Variant:
	if not _marker_live:
		return null
	return _marker_pos

func _clear_props() -> void:
	for p in _props:
		if is_instance_valid(p):
			if player and player.in_vehicle == p:
				continue
			p.queue_free()
	_props.clear()

func _blast(pos: Vector3) -> void:
	var fire := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 3.2
	fire.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.42, 0.08, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.35, 0.05)
	fm.emission_energy_multiplier = 5.0
	fire.material_override = fm
	fire.position = pos + Vector3(0, 0.8, 0)
	get_tree().current_scene.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.42, 0.1)
	light.light_energy = 8.0
	light.omni_range = 22.0
	light.position = pos + Vector3(0, 2.0, 0)
	get_tree().current_scene.add_child(light)
	var tw := create_tween()
	tw.tween_property(fire, "scale", Vector3.ONE * 2.4, 0.25)
	tw.parallel().tween_property(fm, "albedo_color:a", 0.0, 0.7)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fire): fire.queue_free()
		if is_instance_valid(light): light.queue_free()
	)

func _spark(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	mi.position = pos
	get_tree().current_scene.add_child(mi)
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(mi): mi.queue_free()
	)

func _dex_tag(h: Humanoid, label: String) -> void:
	h.name = label.capitalize().replace(" ", "")
	var tag := Label3D.new()
	tag.text = label
	tag.font = load("res://assets/fonts/BebasNeue-Regular.ttf")
	tag.font_size = 48
	tag.modulate = Color(1.0, 0.85, 0.5, 0.9)
	tag.outline_modulate = Color(0, 0, 0, 0.8)
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.3, 0)
	tag.pixel_size = 0.004
	h.add_child(tag)
