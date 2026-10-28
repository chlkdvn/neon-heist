extends Node

## Global game state, input map, signal bus and save handling.

signal money_changed(value: int)
signal health_changed(value: float, max_value: float)
signal wanted_changed(level: int)
signal notify(text: String, color: Color)
signal objective_changed(text: String)
signal mission_started(index: int, title: String)
signal mission_completed(index: int)
signal dialogue_requested(lines: Array)
signal dialogue_finished()
signal subtitle_requested(speaker: String, text: String, seconds: float)
signal player_died()
signal vehicle_changed(vehicle: Node)
signal radio_changed(station: String)
signal game_loaded()
signal toast(text: String)

const MAX_HEALTH := 100.0
const MAX_WANTED := 5

var money := 0
var health := MAX_HEALTH
var wanted := 0.0
var mission_index := 0          # number of completed story missions
var story_started := false
var play_time := 0.0
var deaths := 0
var current_vehicle: Node = null
var radio_station := "WAVE 99.1 — SUNSET FM"
var input_locked := false

var _heat_timer := 0.0
var _last_stars := 0
var _save_path := "user://neon_heist_save.json"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()

func _process(delta: float) -> void:
	play_time += delta
	if wanted > 0.0:
		_heat_timer -= delta
		if _heat_timer <= 0.0:
			wanted = maxf(0.0, wanted - delta * 0.22)
			_emit_wanted()

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
		"reload": [KEY_R],
		"camera_toggle": [KEY_V],
		"pause": [KEY_ESCAPE],
		"map": [KEY_M],
		"radio_next": [KEY_Q],
		"horn": [KEY_H],
		"confirm": [KEY_ENTER, KEY_KP_ENTER],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	for action in ["fire", "aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mb)
	var mb2 := InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("aim", mb2)

func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)

func set_health(value: float) -> void:
	health = clampf(value, 0.0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)

func damage(amount: float) -> void:
	if health <= 0.0:
		return
	set_health(health - amount)
	if health <= 0.0:
		deaths += 1
		player_died.emit()

func heal(amount: float) -> void:
	set_health(health + amount)

func add_wanted(amount: float) -> void:
	wanted = clampf(wanted + amount, 0.0, MAX_WANTED)
	_heat_timer = 28.0 + wanted * 6.0
	_emit_wanted()

func hold_wanted(seconds: float) -> void:
	if wanted > 0.0:
		_heat_timer = maxf(_heat_timer, seconds)

func clear_wanted() -> void:
	wanted = 0.0
	_heat_timer = 0.0
	_emit_wanted()

func _emit_wanted() -> void:
	var stars := int(ceil(wanted))
	if stars != _last_stars:
		_last_stars = stars
		wanted_changed.emit(stars)

func set_objective(text: String) -> void:
	objective_changed.emit(text)

func say(speaker: String, text: String, seconds := 4.5) -> void:
	subtitle_requested.emit(speaker, text, seconds)

func notify_player(text: String, color := Color(1, 0.86, 0.55)) -> void:
	notify.emit(text, color)

func start_mission(index: int, title: String) -> void:
	mission_index = index
	story_started = true
	mission_started.emit(index, title)

func complete_mission(index: int) -> void:
	mission_index = maxi(mission_index, index + 1)
	mission_completed.emit(index)
	save_game({})

func save_game(extra := {}) -> void:
	var data := {
		"money": money,
		"health": health,
		"wanted": wanted,
		"mission": mission_index,
		"story_started": story_started,
		"play_time": play_time,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	for k: String in extra:
		data[k] = extra[k]
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func read_save() -> Dictionary:
	if not FileAccess.file_exists(_save_path):
		return {}
	var f := FileAccess.open(_save_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}

func has_save() -> bool:
	return FileAccess.file_exists(_save_path)

func new_game() -> void:
	money = 0
	health = MAX_HEALTH
	wanted = 0.0
	mission_index = 0
	story_started = false
	play_time = 0.0
	deaths = 0
	current_vehicle = null
	_last_stars = 0
	_heat_timer = 0.0
	money_changed.emit(money)
	health_changed.emit(health, MAX_HEALTH)
	wanted_changed.emit(0)
	radio_station = "WAVE 99.1 — SUNSET FM"

func apply_save(data: Dictionary) -> void:
	money = int(data.get("money", 0))
	health = float(data.get("health", MAX_HEALTH))
	wanted = float(data.get("wanted", 0.0))
	mission_index = int(data.get("mission", 0))
	story_started = bool(data.get("story_started", mission_index > 0))
	play_time = float(data.get("play_time", 0.0))
	_last_stars = 0
	_emit_wanted()
	money_changed.emit(money)
	health_changed.emit(health, MAX_HEALTH)
	game_loaded.emit()

func set_mouse_captured(enabled: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
