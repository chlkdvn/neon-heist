extends Control

## Dynamic crosshair.

var player: PlayerCharacter

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	position = Vector2(-24, -24)
	size = Vector2(48, 48)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if player == null or Game.input_locked or player.in_vehicle:
		return
	var c := size * 0.5
	var gap := 5.0 if player.aiming else 8.0
	var ln := 5.0
	var alpha := 0.85 if player.aiming else 0.6
	var col := Color(0.96, 0.97, 0.95, alpha)
	draw_line(c + Vector2(-gap - ln, 0), c + Vector2(-gap, 0), col, 1.4)
	draw_line(c + Vector2(gap, 0), c + Vector2(gap + ln, 0), col, 1.4)
	draw_line(c + Vector2(0, -gap - ln), c + Vector2(0, -gap), col, 1.4)
	draw_line(c + Vector2(0, gap), c + Vector2(0, gap + ln), col, 1.4)
	draw_circle(c, 1.2, Color(0.96, 0.97, 0.95, 0.9))
