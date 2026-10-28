extends Control

## Five wanted stars drawn as polygons.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.wanted_changed.connect(func(_l: int) -> void: queue_redraw())

func _process(_delta: float) -> void:
	queue_redraw()

func _star(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * float(i) / 5.0
		var rr := radius if i % 2 == 0 else radius * 0.44
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts

func _draw() -> void:
	var active := int(ceil(Game.wanted))
	for i in 5:
		var c := Vector2(18 + i * 36, 20)
		var lit := i < active
		var col := Color(1.0, 0.80, 0.30) if lit else Color(0.12, 0.13, 0.15, 0.75)
		var pts := _star(c, 12.0)
		draw_colored_polygon(pts, col)
		var outline := Color(1.0, 0.9, 0.6, 0.9) if lit else Color(0.55, 0.56, 0.55, 0.5)
		for k in 10:
			draw_line(pts[k], pts[(k + 1) % 10], outline, 1.0)
