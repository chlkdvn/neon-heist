extends CanvasLayer

## Heads-up display, letterboxed dialogue, mission cards, pause and main menu.

signal new_game_requested
signal continue_requested
signal quit_requested

const FONT_TITLE: Font = preload("res://assets/fonts/BebasNeue-Regular.ttf")
const FONT_BODY: Font = preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const CREAM := Color(0.94, 0.91, 0.85)
const AMBER := Color(0.96, 0.72, 0.30)
const TEAL := Color(0.42, 0.86, 0.79)
const RED := Color(0.90, 0.30, 0.22)
const INK := Color(0.035, 0.045, 0.06, 0.88)

var player: PlayerCharacter
var city: City
var missions: Node

var hud_root: Control
var minimap: Control
var wanted: Control
var crosshair: Control

var health_fill: ColorRect
var health_bg: ColorRect
var health_ticks: Array[ColorRect] = []
var money_label: Label
var ammo_label: Label
var speed_label: Label
var speed_unit: Label
var radio_label: Label
var prompt_label: Label
var objective_panel: PanelContainer
var objective_label: Label
var distance_label: Label
var subtitle_label: Label
var subtitle_name: Label
var notification_box: VBoxContainer
var location_label: Label
var location_sub: Label
var location_timer := 0.0

var vignette: TextureRect
var damage_flash := 0.0
var low_health_pulse := 0.0
var displayed_health := 100.0

var dialogue_root: Control
var bar_top: ColorRect
var bar_bottom: ColorRect
var dialogue_name: Label
var dialogue_text: Label
var dialogue_hint: Label
var dialogue_lines: Array = []
var dialogue_index := -1
var dialogue_chars := 0.0
var dialogue_active := false

var card_root: Control
var card_kicker: Label
var card_title: Label
var card_sub: Label

var wasted_root: Control
var wasted_title: Label
var wasted_sub: Label

var menu_root: Control
var menu_continue: Button
var menu_buttons: VBoxContainer
var pause_root: Control
var pause_panel: PanelContainer
var pause_buttons: VBoxContainer

var state := "game"
var mission_prompt := ""
var _subtitle_timer := 0.0
var _hud_time := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_dialogue()
	_build_cards()
	_build_wasted()
	_build_menu()
	_build_pause()
	_connect_game()
	Game.input_locked = false

func _connect_game() -> void:
	Game.money_changed.connect(_on_money)
	Game.health_changed.connect(_on_health)
	Game.notify.connect(_on_notify)
	Game.objective_changed.connect(_on_objective)
	Game.subtitle_requested.connect(_on_subtitle)
	Game.mission_started.connect(_on_mission_started)
	Game.mission_completed.connect(_on_mission_completed)
	Game.dialogue_requested.connect(_on_dialogue)
	Game.player_died.connect(_on_player_died)

# ------------------------------------------------------------------ build

func _mk_label(text: String, size: int, color: Color, font: Font = FONT_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _mk_panel(bg: Color, border := Color(1, 1, 1, 0.10), radius := 3) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hud_root = root

	vignette = TextureRect.new()
	vignette.texture = load("res://assets/ui/vignette.png")
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.modulate = Color(1, 1, 1, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	# minimap bottom left
	minimap = Control.new()
	minimap.set_script(load("res://scripts/minimap.gd"))
	minimap.anchor_left = 0.0
	minimap.anchor_top = 1.0
	minimap.anchor_right = 0.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = 22.0
	minimap.offset_top = -246.0
	minimap.offset_right = 238.0
	minimap.offset_bottom = -30.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)

	# health
	var health_group := Control.new()
	health_group.anchor_left = 0.0
	health_group.anchor_top = 1.0
	health_group.anchor_right = 0.0
	health_group.anchor_bottom = 1.0
	health_group.offset_left = 24.0
	health_group.offset_top = -274.0
	health_group.offset_right = 240.0
	health_group.offset_bottom = -252.0
	health_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(health_group)

	health_bg = ColorRect.new()
	health_bg.color = Color(0.04, 0.05, 0.06, 0.72)
	health_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_group.add_child(health_bg)

	health_fill = ColorRect.new()
	health_fill.color = CREAM
	health_fill.position = Vector2(2, 2)
	health_fill.size = Vector2(212, 18)
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_group.add_child(health_fill)

	for i in range(1, 10):
		var tick := ColorRect.new()
		tick.color = Color(0.04, 0.05, 0.06, 0.55)
		tick.position = Vector2(2 + 21.2 * i, 2)
		tick.size = Vector2(1.2, 18)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_group.add_child(tick)
		health_ticks.append(tick)

	var hp_name := _mk_label("CONDITION", 12, Color(0.88, 0.86, 0.80, 0.72))
	hp_name.position = Vector2(2, -16)
	health_group.add_child(hp_name)

	# wanted stars top right
	wanted = Control.new()
	wanted.set_script(load("res://scripts/wanted_stars.gd"))
	wanted.anchor_left = 1.0
	wanted.anchor_top = 0.0
	wanted.anchor_right = 1.0
	wanted.anchor_bottom = 0.0
	wanted.offset_left = -228.0
	wanted.offset_top = 44.0
	wanted.offset_right = -24.0
	wanted.offset_bottom = 88.0
	wanted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wanted)

	money_label = _mk_label("$0", 38, CREAM, FONT_TITLE)
	money_label.anchor_left = 1.0
	money_label.anchor_right = 1.0
	money_label.offset_left = -320.0
	money_label.offset_top = 6.0
	money_label.offset_right = -24.0
	money_label.offset_bottom = 46.0
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(money_label)

	# objective
	objective_panel = _mk_panel(Color(0.03, 0.045, 0.06, 0.62), Color(0.96, 0.72, 0.30, 0.20), 3)
	objective_panel.anchor_left = 0.5
	objective_panel.anchor_right = 0.5
	objective_panel.offset_left = -230.0
	objective_panel.offset_top = 14.0
	objective_panel.offset_right = 230.0
	objective_panel.offset_bottom = 84.0
	objective_panel.visible = false
	root.add_child(objective_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", -2)
	objective_panel.add_child(ov)
	var otop := HBoxContainer.new()
	otop.add_theme_constant_override("separation", 10)
	ov.add_child(otop)
	var kicker := _mk_label("OBJECTIVE", 12, AMBER, FONT_TITLE)
	kicker.add_theme_constant_override("outline_size", 0)
	otop.add_child(kicker)
	distance_label = _mk_label("", 14, Color(0.84, 0.83, 0.78, 0.82), FONT_BODY)
	distance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	otop.add_child(distance_label)
	objective_label = _mk_label("", 20, CREAM, FONT_BODY)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(420, 0)
	ov.add_child(objective_label)

	# subtitles
	subtitle_name = _mk_label("", 15, AMBER, FONT_TITLE)
	subtitle_name.anchor_left = 0.5
	subtitle_name.anchor_right = 0.5
	subtitle_name.offset_left = -430.0
	subtitle_name.offset_right = 430.0
	subtitle_name.offset_top = 560.0
	subtitle_name.offset_bottom = 584.0
	subtitle_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_name.visible = false
	root.add_child(subtitle_name)

	subtitle_label = _mk_label("", 22, CREAM, FONT_BODY)
	subtitle_label.anchor_left = 0.5
	subtitle_label.anchor_right = 0.5
	subtitle_label.offset_left = -440.0
	subtitle_label.offset_right = 440.0
	subtitle_label.offset_top = 584.0
	subtitle_label.offset_bottom = 628.0
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.visible = false
	root.add_child(subtitle_label)

	prompt_label = _mk_label("", 18, CREAM, FONT_BODY)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.offset_left = -300.0
	prompt_label.offset_right = 300.0
	prompt_label.offset_top = 636.0
	prompt_label.offset_bottom = 662.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	root.add_child(prompt_label)

	# ammo / speed bottom right
	ammo_label = _mk_label("", 26, CREAM, FONT_TITLE)
	ammo_label.anchor_left = 1.0
	ammo_label.anchor_top = 1.0
	ammo_label.anchor_right = 1.0
	ammo_label.anchor_bottom = 1.0
	ammo_label.offset_left = -250.0
	ammo_label.offset_top = -92.0
	ammo_label.offset_right = -24.0
	ammo_label.offset_bottom = -56.0
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(ammo_label)

	speed_label = _mk_label("0", 54, CREAM, FONT_TITLE)
	speed_label.anchor_left = 1.0
	speed_label.anchor_top = 1.0
	speed_label.anchor_right = 1.0
	speed_label.anchor_bottom = 1.0
	speed_label.offset_left = -200.0
	speed_label.offset_top = -152.0
	speed_label.offset_right = -24.0
	speed_label.offset_bottom = -92.0
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.visible = false
	root.add_child(speed_label)
	speed_unit = _mk_label("MPH", 13, Color(0.9, 0.88, 0.82, 0.6), FONT_TITLE)
	speed_unit.anchor_left = 1.0
	speed_unit.anchor_top = 1.0
	speed_unit.anchor_right = 1.0
	speed_unit.anchor_bottom = 1.0
	speed_unit.offset_left = -190.0
	speed_unit.offset_top = -96.0
	speed_unit.offset_right = -24.0
	speed_unit.offset_bottom = -78.0
	speed_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_unit.visible = false
	root.add_child(speed_unit)

	radio_label = _mk_label(Game.radio_station, 13, Color(0.86, 0.84, 0.78, 0.58), FONT_BODY)
	radio_label.anchor_left = 1.0
	radio_label.anchor_top = 1.0
	radio_label.anchor_right = 1.0
	radio_label.anchor_bottom = 1.0
	radio_label.offset_left = -360.0
	radio_label.offset_top = -30.0
	radio_label.offset_right = -24.0
	radio_label.offset_bottom = -10.0
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(radio_label)

	# notifications top-left
	notification_box = VBoxContainer.new()
	notification_box.position = Vector2(24, 96)
	notification_box.add_theme_constant_override("separation", 4)
	notification_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notification_box)

	# location title (top-left, fades)
	location_label = _mk_label("SUNSET CITY", 30, CREAM, FONT_TITLE)
	location_label.position = Vector2(24, 22)
	location_label.visible = false
	root.add_child(location_label)
	location_sub = _mk_label("FLORIDA • 1999", 13, AMBER, FONT_BODY)
	location_sub.position = Vector2(26, 52)
	location_sub.visible = false
	root.add_child(location_sub)

	crosshair = Control.new()
	crosshair.set_script(load("res://scripts/crosshair.gd"))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-24, -24)
	crosshair.size = Vector2(48, 48)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

func _build_dialogue() -> void:
	dialogue_root = Control.new()
	dialogue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_root.visible = false
	add_child(dialogue_root)

	bar_top = ColorRect.new()
	bar_top.color = Color(0.01, 0.012, 0.016, 1.0)
	bar_top.anchor_right = 1.0
	bar_top.offset_bottom = 0.0
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_root.add_child(bar_top)

	bar_bottom = ColorRect.new()
	bar_bottom.color = Color(0.01, 0.012, 0.016, 1.0)
	bar_bottom.anchor_top = 1.0
	bar_bottom.anchor_right = 1.0
	bar_bottom.anchor_bottom = 1.0
	bar_bottom.offset_top = 0.0
	bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_root.add_child(bar_bottom)

	dialogue_name = _mk_label("", 20, AMBER, FONT_TITLE)
	dialogue_name.anchor_left = 0.5
	dialogue_name.anchor_right = 0.5
	dialogue_name.offset_left = -450.0
	dialogue_name.offset_right = 450.0
	dialogue_name.offset_top = 494.0
	dialogue_name.offset_bottom = 522.0
	dialogue_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_root.add_child(dialogue_name)

	dialogue_text = _mk_label("", 25, CREAM, FONT_BODY)
	dialogue_text.anchor_left = 0.5
	dialogue_text.anchor_right = 0.5
	dialogue_text.offset_left = -470.0
	dialogue_text.offset_right = 470.0
	dialogue_text.offset_top = 530.0
	dialogue_text.offset_bottom = 608.0
	dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_root.add_child(dialogue_text)

	dialogue_hint = _mk_label("[SPACE]  CONTINUE", 13, Color(0.85, 0.83, 0.76, 0.5), FONT_BODY)
	dialogue_hint.anchor_left = 0.5
	dialogue_hint.anchor_right = 0.5
	dialogue_hint.offset_left = -200.0
	dialogue_hint.offset_right = 200.0
	dialogue_hint.offset_top = 626.0
	dialogue_hint.offset_bottom = 648.0
	dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_root.add_child(dialogue_hint)

func _build_cards() -> void:
	card_root = Control.new()
	card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.modulate = Color(1, 1, 1, 0)
	card_root.visible = false
	add_child(card_root)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.02, 0.34)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(shade)

	card_kicker = _mk_label("MISSION 01", 18, AMBER, FONT_TITLE)
	card_kicker.anchor_left = 0.5
	card_kicker.anchor_right = 0.5
	card_kicker.offset_left = -400.0
	card_kicker.offset_right = 400.0
	card_kicker.offset_top = 292.0
	card_kicker.offset_bottom = 320.0
	card_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_root.add_child(card_kicker)

	card_title = _mk_label("", 76, CREAM, FONT_TITLE)
	card_title.anchor_left = 0.5
	card_title.anchor_right = 0.5
	card_title.offset_left = -560.0
	card_title.offset_right = 560.0
	card_title.offset_top = 314.0
	card_title.offset_bottom = 396.0
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_root.add_child(card_title)

	card_sub = _mk_label("", 18, Color(0.88, 0.85, 0.78, 0.85), FONT_BODY)
	card_sub.anchor_left = 0.5
	card_sub.anchor_right = 0.5
	card_sub.offset_left = -480.0
	card_sub.offset_right = 480.0
	card_sub.offset_top = 404.0
	card_sub.offset_bottom = 434.0
	card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_root.add_child(card_sub)

func _build_wasted() -> void:
	wasted_root = Control.new()
	wasted_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wasted_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wasted_root.visible = false
	add_child(wasted_root)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wasted_root.add_child(bg)

	wasted_title = _mk_label("WASTED", 132, Color(0.74, 0.10, 0.08), FONT_TITLE)
	wasted_title.anchor_left = 0.5
	wasted_title.anchor_right = 0.5
	wasted_title.offset_left = -500.0
	wasted_title.offset_right = 500.0
	wasted_title.offset_top = 286.0
	wasted_title.offset_bottom = 396.0
	wasted_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wasted_root.add_child(wasted_title)

	wasted_sub = _mk_label("THE CITY ALWAYS TAKES SOMETHING", 17, Color(0.9, 0.85, 0.8, 0.75), FONT_BODY)
	wasted_sub.anchor_left = 0.5
	wasted_sub.anchor_right = 0.5
	wasted_sub.offset_left = -400.0
	wasted_sub.offset_right = 400.0
	wasted_sub.offset_top = 400.0
	wasted_sub.offset_bottom = 430.0
	wasted_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wasted_root.add_child(wasted_sub)

func _style_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(300, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.04, 0.72)
	normal.border_color = Color(0.95, 0.90, 0.80, 0.16)
	normal.set_border_width_all(1)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.96, 0.72, 0.30, 0.92)
	hover.border_color = Color(1, 0.86, 0.55, 0.9)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.86, 0.6, 0.2, 1.0)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = AMBER
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	b.add_theme_color_override("font_focus_color", CREAM)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.58, 0.35))
	b.mouse_entered.connect(func() -> void: Audio.click())

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.52)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(shade)

	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.015, 0.02, 0.92))
	grad.set_color(1, Color(0.01, 0.015, 0.02, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 512
	gt.height = 8
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var left_shade := TextureRect.new()
	left_shade.texture = gt
	left_shade.anchor_bottom = 1.0
	left_shade.anchor_right = 0.72
	left_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_shade.stretch_mode = TextureRect.STRETCH_SCALE
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(left_shade)

	var kicker := _mk_label("A SUNSET CITY STORY", 15, AMBER, FONT_BODY)
	kicker.position = Vector2(84, 74)
	kicker.add_theme_constant_override("outline_size", 0)
	menu_root.add_child(kicker)

	var title := _mk_label("NEON\nHEIST", 100, CREAM, FONT_TITLE)
	title.position = Vector2(78, 90)
	title.add_theme_constant_override("line_spacing", -22)
	menu_root.add_child(title)

	var rule := ColorRect.new()
	rule.color = AMBER
	rule.position = Vector2(84, 318)
	rule.size = Vector2(96, 3)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(rule)

	var tag := _mk_label("SUNSET CITY  •  1999", 20, Color(0.88, 0.85, 0.78, 0.86), FONT_BODY)
	tag.position = Vector2(84, 330)
	menu_root.add_child(tag)

	menu_buttons = VBoxContainer.new()
	menu_buttons.position = Vector2(84, 382)
	menu_buttons.add_theme_constant_override("separation", 10)
	menu_root.add_child(menu_buttons)

	var new_b := Button.new()
	new_b.text = "NEW GAME"
	_style_button(new_b)
	new_b.pressed.connect(func() -> void:
		Audio.click()
		new_game_requested.emit()
	)
	menu_buttons.add_child(new_b)

	menu_continue = Button.new()
	menu_continue.text = "CONTINUE"
	_style_button(menu_continue)
	menu_continue.pressed.connect(func() -> void:
		Audio.click()
		continue_requested.emit()
	)
	menu_buttons.add_child(menu_continue)

	var quit_b := Button.new()
	quit_b.text = "QUIT"
	_style_button(quit_b)
	quit_b.pressed.connect(func() -> void:
		Audio.click()
		quit_requested.emit()
	)
	menu_buttons.add_child(quit_b)

	var controls := _mk_label(
		"WASD  MOVE     MOUSE  LOOK     SHIFT  SPRINT     SPACE  JUMP\n" +
		"E  INTERACT / ENTER CAR     V  CAMERA     LMB  FIRE     R  RELOAD\n" +
		"Q  RADIO     E  EXIT CAR     ESC  PAUSE",
		14, Color(0.86, 0.84, 0.78, 0.6), FONT_BODY)
	controls.anchor_left = 0.0
	controls.anchor_top = 1.0
	controls.offset_left = 84.0
	controls.offset_top = -112.0
	controls.offset_right = 900.0
	controls.offset_bottom = -38.0
	menu_root.add_child(controls)

	var legal := _mk_label("AN ORIGINAL WORK OF FICTION  •  BUILT IN GODOT", 12, Color(0.7, 0.68, 0.62, 0.45), FONT_BODY)
	legal.anchor_left = 1.0
	legal.anchor_top = 1.0
	legal.anchor_right = 1.0
	legal.anchor_bottom = 1.0
	legal.offset_left = -520.0
	legal.offset_top = -34.0
	legal.offset_right = -24.0
	legal.offset_bottom = -14.0
	legal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu_root.add_child(legal)

func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	add_child(pause_root)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02, 0.62)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(bg)

	pause_panel = _mk_panel(Color(0.025, 0.035, 0.045, 0.97), Color(0.95, 0.9, 0.8, 0.18), 4)
	pause_panel.anchor_left = 0.5
	pause_panel.anchor_top = 0.5
	pause_panel.anchor_right = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left = -220.0
	pause_panel.offset_top = -230.0
	pause_panel.offset_right = 220.0
	pause_panel.offset_bottom = 230.0
	pause_root.add_child(pause_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pause_panel.add_child(box)

	var kicker := _mk_label("SUNSET CITY", 13, AMBER, FONT_BODY)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var paused := _mk_label("PAUSED", 58, CREAM, FONT_TITLE)
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(paused)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	pause_buttons = VBoxContainer.new()
	pause_buttons.add_theme_constant_override("separation", 8)
	box.add_child(pause_buttons)

	var resume := Button.new()
	resume.text = "RESUME"
	_style_button(resume)
	resume.custom_minimum_size = Vector2(360, 44)
	resume.pressed.connect(_resume)
	pause_buttons.add_child(resume)

	var save := Button.new()
	save.text = "SAVE GAME"
	_style_button(save)
	save.custom_minimum_size = Vector2(360, 44)
	save.pressed.connect(func() -> void:
		Audio.click()
		Game.save_game()
		_toast("GAME SAVED", AMBER)
	)
	pause_buttons.add_child(save)

	var to_menu := Button.new()
	to_menu.text = "MAIN MENU"
	_style_button(to_menu)
	to_menu.custom_minimum_size = Vector2(360, 44)
	to_menu.pressed.connect(func() -> void:
		Audio.click()
		_pause_off()
		get_tree().reload_current_scene()
	)
	pause_buttons.add_child(to_menu)

	var quit := Button.new()
	quit.text = "QUIT DESKTOP"
	_style_button(quit)
	quit.custom_minimum_size = Vector2(360, 44)
	quit.pressed.connect(func() -> void:
		Audio.click()
		get_tree().quit()
	)
	pause_buttons.add_child(quit)

	var stats := _mk_label("", 13, Color(0.85, 0.83, 0.76, 0.55), FONT_BODY)
	stats.name = "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)

func _pause_off() -> void:
	pause_root.visible = false
	state = "game"
	get_tree().paused = false
	Game.set_mouse_captured(true)

# ------------------------------------------------------------------ wiring

func _on_money(value: int) -> void:
	money_label.text = "$%s" % _thousands(value)

func _thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out

func _on_health(value: float, _max_value: float) -> void:
	if value < displayed_health:
		damage_flash = minf(1.0, damage_flash + (displayed_health - value) / 30.0)
	if value < 26.0:
		low_health_pulse = 1.0

func _on_notify(text: String, color: Color) -> void:
	if text == "+":
		return
	var l := _mk_label(text, 18, color, FONT_BODY)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	notification_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(l):
			l.queue_free()
	)

func _toast(text: String, color := AMBER) -> void:
	_on_notify(text, color)

func _on_objective(text: String) -> void:
	objective_label.text = text
	objective_panel.visible = text != ""
	if text != "":
		objective_panel.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(objective_panel, "modulate:a", 1.0, 0.25)

func _on_subtitle(speaker: String, text: String, seconds: float) -> void:
	subtitle_name.text = speaker
	subtitle_name.visible = speaker != ""
	subtitle_label.text = text
	subtitle_label.visible = true
	_subtitle_timer = seconds

func _on_mission_started(index: int, title: String) -> void:
	card_kicker.text = "MISSION %02d  /  07" % (index + 1)
	card_title.text = title.to_upper()
	card_sub.text = "SUNSET CITY — %s" % ["MORNING", "AFTERNOON", "DUSK", "NIGHT", "DUSK", "NIGHT", "SUNSET"][clampi(index, 0, 6)]
	_show_card(3.4)

func _on_mission_completed(index: int) -> void:
	var rewards := [500, 800, 1200, 1500, 2000, 3000, 5000]
	card_kicker.text = "MISSION COMPLETE"
	card_title.text = "PAID"
	card_sub.text = "+$%s   •   %s" % [_thousands(rewards[clampi(index, 0, 6)]), "THE CITY NOTICES"]
	_show_card(3.0)

func _show_card(seconds: float) -> void:
	card_root.visible = true
	card_root.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(card_root, "modulate:a", 1.0, 0.35)
	tw.tween_interval(seconds)
	tw.tween_property(card_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: card_root.visible = false)

func _on_player_died() -> void:
	wasted_root.visible = true
	wasted_root.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(wasted_root, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(2.8).timeout
	var tw := create_tween()
	tw.tween_property(wasted_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: wasted_root.visible = false)

# ------------------------------------------------------------------ dialogue

func _on_dialogue(lines: Array) -> void:
	if lines.is_empty():
		Game.dialogue_finished.emit()
		return
	dialogue_lines = lines.duplicate()
	dialogue_index = -1
	dialogue_active = true
	state = "dialogue"
	Game.input_locked = true
	Game.set_mouse_captured(true)
	dialogue_root.visible = true
	bar_top.offset_bottom = 0.0
	bar_bottom.offset_top = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bar_top, "offset_bottom", 78.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar_bottom, "offset_top", -78.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_next_dialogue_line()

func _next_dialogue_line() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		_end_dialogue()
		return
	var entry: Variant = dialogue_lines[dialogue_index]
	var speaker := ""
	var text := ""
	var pause := 0.0
	if entry is Dictionary:
		speaker = str(entry.get("speaker", ""))
		text = str(entry.get("text", ""))
		pause = float(entry.get("pause", 0.0))
	elif entry is Array and (entry as Array).size() >= 2:
		speaker = str(entry[0])
		text = str(entry[1])
	else:
		text = str(entry)
	dialogue_name.text = speaker.to_upper()
	dialogue_name.visible = speaker != ""
	dialogue_text.text = text
	dialogue_text.visible_characters = 0
	dialogue_chars = 0.0
	dialogue_hint.text = "[SPACE]  CONTINUE"
	dialogue_hint.visible = false
	if pause > 0.0:
		await get_tree().create_timer(pause).timeout
		if not dialogue_active:
			return

func _advance_dialogue() -> void:
	if not dialogue_active:
		return
	var full: String = dialogue_text.text
	if dialogue_text.visible_characters < full.length():
		dialogue_text.visible_characters = -1
		dialogue_hint.visible = true
		return
	_next_dialogue_line()

func _end_dialogue() -> void:
	dialogue_active = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bar_top, "offset_bottom", 0.0, 0.3)
	tw.tween_property(bar_bottom, "offset_top", 0.0, 0.3)
	tw.tween_property(dialogue_name, "modulate:a", 0.0, 0.2)
	tw.tween_property(dialogue_text, "modulate:a", 0.0, 0.2)
	await tw.finished
	dialogue_root.visible = false
	dialogue_name.modulate.a = 1.0
	dialogue_text.modulate.a = 1.0
	dialogue_hint.visible = false
	state = "game"
	Game.input_locked = false
	Game.dialogue_finished.emit()

# ------------------------------------------------------------------ menus

func show_main_menu(has_save: bool) -> void:
	state = "menu"
	if hud_root:
		hud_root.visible = false
	menu_root.visible = true
	menu_continue.disabled = not has_save
	get_tree().paused = true
	Game.set_mouse_captured(false)
	await get_tree().process_frame
	for b: Node in menu_buttons.get_children():
		if b is Button and not (b as Button).disabled:
			(b as Button).grab_focus()
			break

func hide_main_menu() -> void:
	menu_root.visible = false
	if hud_root:
		hud_root.visible = true
	state = "game"
	get_tree().paused = false
	Game.set_mouse_captured(true)

func _pause_on() -> void:
	if state != "game":
		return
	state = "pause"
	pause_root.visible = true
	get_tree().paused = true
	Game.set_mouse_captured(false)
	var stats := pause_panel.find_child("Stats", true, false) as Label
	if stats:
		var mins := int(Game.play_time) / 60
		var secs := int(Game.play_time) % 60
		stats.text = "TIME  %02d:%02d     CASH  $%s     DEATHS  %d" % [mins, secs, _thousands(Game.money), Game.deaths]
	await get_tree().process_frame
	for b: Node in pause_buttons.get_children():
		if b is Button:
			(b as Button).grab_focus()
			break

func _resume() -> void:
	Audio.click()
	_pause_off()

func _unhandled_input(event: InputEvent) -> void:
	if state == "dialogue":
		var advance := false
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
				advance = true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			advance = true
		if advance:
			get_viewport().set_input_as_handled()
			_advance_dialogue()
		return

	if state == "menu" or state == "pause":
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			if state == "pause":
				_resume()
		return

	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause_on()

# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	_hud_time += delta
	if minimap:
		var mm = minimap
		mm.player = player
		mm.city = city
		mm.mission = missions
	if state == "game" and not get_tree().paused:
		_tick_hud(delta)
	_tick_dialogue(delta)
	_tick_location(delta)

func _tick_hud(delta: float) -> void:
	if player == null:
		return
	displayed_health = lerpf(displayed_health, Game.health, delta * 7.0)
	var ratio := clampf(displayed_health / Game.MAX_HEALTH, 0.0, 1.0)
	health_fill.size.x = 212.0 * ratio
	health_fill.color = CREAM if ratio > 0.28 else Color(0.95, 0.32, 0.22)
	for tick in health_ticks:
		tick.modulate.a = 1.0 if ratio > 0.28 else 0.5

	damage_flash = maxf(0.0, damage_flash - delta * 1.8)
	var low := 0.0
	if Game.health < 28.0:
		low = (0.5 + sin(_hud_time * 5.0) * 0.5) * (1.0 - Game.health / 40.0) * 0.5
	vignette.modulate = Color(1, 1, 1, clampf(damage_flash * 0.9 + low, 0.0, 0.9))

	if player.in_vehicle:
		ammo_label.visible = false
		speed_label.visible = true
		speed_unit.visible = true
		var v: Node = player.in_vehicle
		var mph := 0
		if v.get("speed") != null:
			mph = int(absf(float(v.get("speed"))) * 2.237)
		speed_label.text = str(mph)
		if v.get("is_police") == true:
			radio_label.text = "SUNSET CITY POLICE — CH. 4"
		else:
			radio_label.text = Game.radio_station
	else:
		speed_label.visible = false
		speed_unit.visible = false
		ammo_label.visible = true
		ammo_label.text = "%d  /  %d" % [player.ammo, player.reserve]
		radio_label.text = Game.radio_station

	if mission_prompt != "":
		prompt_label.visible = true
		prompt_label.text = mission_prompt
	else:
		prompt_label.visible = player.prompt_text != ""
		prompt_label.text = player.prompt_text

	if missions and missions.has_method("get_marker_position"):
		var mp: Variant = missions.get_marker_position()
		if mp != null and not Game.input_locked:
			var d: float = player.global_position.distance_to(mp as Vector3)
			distance_label.text = "%d M" % int(d)
		else:
			distance_label.text = ""
	else:
		distance_label.text = ""

	if _subtitle_timer > 0.0:
		_subtitle_timer -= delta
		if _subtitle_timer <= 0.0:
			subtitle_label.visible = false
			subtitle_name.visible = false
	if crosshair:
		crosshair.player = player

func _tick_dialogue(delta: float) -> void:
	if not dialogue_active:
		return
	var full: String = dialogue_text.text
	if dialogue_text.visible_characters < full.length():
		dialogue_chars += delta * 46.0
		dialogue_text.visible_characters = mini(int(dialogue_chars), full.length())
		if dialogue_text.visible_characters >= full.length():
			dialogue_hint.visible = true
	elif not dialogue_hint.visible:
		dialogue_hint.visible = true

func _tick_location(delta: float) -> void:
	if location_timer > 0.0:
		location_timer -= delta
		var a := clampf(location_timer / 0.6, 0.0, 1.0)
		location_label.modulate.a = a
		location_sub.modulate.a = a
		if location_timer <= 0.0:
			location_label.visible = false
			location_sub.visible = false

func set_action_prompt(text: String) -> void:
	mission_prompt = text

func show_location(title: String, sub: String, seconds := 4.0) -> void:
	location_label.text = title.to_upper()
	location_sub.text = sub.to_upper()
	location_label.visible = true
	location_sub.visible = true
	location_label.modulate.a = 0.0
	location_sub.modulate.a = 0.0
	location_timer = seconds
	var tw := create_tween().set_parallel(true)
	tw.tween_property(location_label, "modulate:a", 1.0, 0.6)
	tw.tween_property(location_sub, "modulate:a", 1.0, 0.6)
