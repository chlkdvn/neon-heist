extends Control

## Compact rectangular city map. All drawing is clamped to the panel so it
## never needs a mask texture or expensive shader.

const FONT := preload("res://assets/fonts/BebasNeue-Regular.ttf")
const BG := Color(0.012, 0.028, 0.038, 0.94)
const WATER := Color(0.025, 0.075, 0.095)
const SAND := Color(0.40, 0.35, 0.25)
const BLOCK := Color(0.145, 0.155, 0.17)
const ROAD := Color(0.29, 0.30, 0.315)
const EDGE := Color(0.96, 0.90, 0.80, 0.22)

var player: Node3D
var city: City
var mission: Node
var zoom := 0.42
var _clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 0.08:
		_clock = 0.0
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BG)

	if player == null or city == null:
		_draw_frame(rect)
		return

	var c := size * 0.5
	var p := player.global_position
	var sand_rect := Rect2(c + Vector2(-City.SAND_HALF - p.x, -City.SAND_HALF - p.z) * zoom,
		Vector2(City.SAND_HALF, City.SAND_HALF) * 2.0 * zoom)
	_fill_clipped(sand_rect, rect, SAND, WATER)

	var city_rect := Rect2(c + Vector2(-City.CITY_EDGE - p.x, -City.CITY_EDGE - p.z) * zoom,
		Vector2(City.CITY_EDGE, City.CITY_EDGE) * 2.0 * zoom)
	_fill_clipped(city_rect, rect, Color(0.16, 0.17, 0.185), Color(0.16, 0.17, 0.185))

	# blocks
	for bz in City.BLOCKS:
		for bx in City.BLOCKS:
			var bc: Vector2 = city.block_centers[bz * City.BLOCKS + bx]
			var d := bc - Vector2(p.x, p.z)
			if absf(d.x) * zoom > size.x * 0.8 or absf(d.y) * zoom > size.y * 0.8:
				continue
			var special: String = city.block_specials.get(Vector2i(bx, bz), "")
			var col := BLOCK
			if special == "park":
				col = Color(0.14, 0.24, 0.15)
			elif special == "casino":
				col = Color(0.27, 0.20, 0.10)
			elif special == "motel":
				col = Color(0.22, 0.14, 0.16)
			var r := Rect2(c + d * zoom - Vector2.ONE * City.BLOCK_SIZE * 0.5 * zoom,
				Vector2.ONE * City.BLOCK_SIZE * zoom)
			_fill_clipped(r, rect, col, Color(0.16, 0.17, 0.185))
			if special == "park" and rect.has_point(c + d * zoom):
				draw_circle(c + d * zoom, 4.0, Color(0.22, 0.38, 0.22))

	# roads (axis-aligned, so clamp to the panel)
	for line in city.road_lines:
		var sx := c.x + (line - p.x) * zoom
		if sx > 2.0 and sx < size.x - 2.0:
			draw_line(Vector2(sx, 2), Vector2(sx, size.y - 2), ROAD, 5.0)
		var sy := c.y + (line - p.z) * zoom
		if sy > 2.0 and sy < size.y - 2.0:
			draw_line(Vector2(2, sy), Vector2(size.x - 2, sy), ROAD, 5.0)

	# pier
	var pier := Rect2(c + Vector2(238.0 - p.x, -65.0 - p.z) * zoom, Vector2(132.0, 10.0) * zoom)
	_fill_clipped(pier, rect, Color(0.33, 0.26, 0.17), Color(0.33, 0.26, 0.17))

	# traffic (white) and police cruisers (red)
	for v: Node in get_tree().get_nodes_in_group("vehicles"):
		if not is_instance_valid(v):
			continue
		var vp: Vector3 = (v as Node3D).global_position
		var d2 := Vector2(vp.x - p.x, vp.z - p.z) * zoom
		if d2.length() > minf(size.x, size.y) * 0.52:
			continue
		var cp := c + d2
		if not rect.grow(-4).has_point(cp):
			continue
		var police: bool = v.get("is_police") == true
		draw_circle(cp, 2.2, Color(0.95, 0.28, 0.2) if police else Color(0.86, 0.87, 0.84, 0.9))

	for cop: Node in get_tree().get_nodes_in_group("cops"):
		if not is_instance_valid(cop):
			continue
		var cp3: Vector3 = (cop as Node3D).global_position
		var d3 := Vector2(cp3.x - p.x, cp3.z - p.z) * zoom
		if d3.length() < minf(size.x, size.y) * 0.52 and rect.grow(-4).has_point(c + d3):
			draw_circle(c + d3, 2.4, Color(0.98, 0.30, 0.22))

	for en: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(en):
			continue
		var ep: Vector3 = (en as Node3D).global_position
		var d4 := Vector2(ep.x - p.x, ep.z - p.z) * zoom
		if d4.length() < minf(size.x, size.y) * 0.52 and rect.grow(-4).has_point(c + d4):
			draw_circle(c + d4, 2.0, Color(1.0, 0.55, 0.15))

	# mission marker, clamped to the panel edge
	if mission and mission.has_method("get_marker_position"):
		var mp: Variant = mission.get_marker_position()
		if mp != null:
			var dv := Vector2((mp as Vector3).x - p.x, (mp as Vector3).z - p.z) * zoom
			var limit := Vector2(size.x * 0.5 - 14.0, size.y * 0.5 - 14.0)
			dv.x = clampf(dv.x, -limit.x, limit.x)
			dv.y = clampf(dv.y, -limit.y, limit.y)
			var pulse := 2.4 + sin(Time.get_ticks_msec() * 0.006) * 1.0
			draw_circle(c + dv, 5.0 + pulse, Color(0.95, 0.72, 0.18, 0.22))
			draw_circle(c + dv, 4.0, Color(1.0, 0.82, 0.28))

	# player arrow
	draw_set_transform(c, -player.rotation.y, Vector2.ONE)
	var tri := PackedVector2Array([Vector2(0, -9), Vector2(-6.5, 7), Vector2(0, 3.5), Vector2(6.5, 7)])
	draw_colored_polygon(tri, Color(0.96, 0.97, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# frame + north
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), EDGE, false, 1.0)
	draw_rect(Rect2(0, 0, size.x, 2), Color(0.96, 0.72, 0.30, 0.75))
	draw_string(FONT, Vector2(7, 15), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.95, 0.93, 0.86, 0.7))

func _fill_clipped(r: Rect2, bounds: Rect2, color: Color, _clear: Color) -> void:
	var i := r.intersection(bounds)
	if i.size.x > 0.0 and i.size.y > 0.0:
		draw_rect(i, color)

func _draw_frame(rect: Rect2) -> void:
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), EDGE, false, 1.0)
	draw_rect(Rect2(0, 0, size.x, 2), Color(0.96, 0.72, 0.30, 0.75))
