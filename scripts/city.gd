class_name City
extends Node3D

## Sunset City — procedural neon island.
## 6x6 city blocks, 72 m block pitch, beach ring and a pier on the east side.

const TILE := 12.0
const BLOCK_TILES := 6
const BLOCKS := 6
const GRID := BLOCKS * BLOCK_TILES + 1          # 37 tiles
const CITY_HALF := (GRID - 1) * TILE * 0.5      # 216 m
const BLOCK_HALF := (BLOCK_TILES - 1) * TILE * 0.5  # 30 m
const SAND_HALF := 310.0
const WATER_Y := -0.32
const LANE_OFFSET := 2.8
const SIDEWALK_OFFSET := 28.0
const ROAD_Y := 0.0
const WALK_Y := 0.15
const PAINT_Y := 0.018
const SAND_Y := -0.02
const BLOCK_SIZE := 60.0
const CITY_EDGE := 222.0

const FONT_SIGN: Font = preload("res://assets/fonts/BebasNeue-Regular.ttf")

const SHOP_SIGNS := ["HOTEL", "MOTEL", "CAFE", "PIZZA", "LIQUOR", "TATTOO", "PAWN", "ARCADE",
	"CLUB", "VICE", "SUNSET", "OCEAN", "RADIO", "24/7", "SURF", "DINER", "MUSIC", "VIDEO", "GYM", "NEON"]

const NEON_COLORS := [
	Color(1.0, 0.22, 0.62), Color(0.15, 0.87, 1.0), Color(1.0, 0.78, 0.30),
	Color(0.72, 0.32, 1.0), Color(0.30, 1.0, 0.66), Color(1.0, 0.34, 0.30),
]

var rng := RandomNumberGenerator.new()
var road_lines: Array[float] = []
var block_centers: Array[Vector2] = []
var block_specials := {}
var palm_entries: Array[Transform3D] = []
var lamp_entries: Array[Transform3D] = []
var building_count := 0
var tower_count := 0
var sign_count := 0
var parking_spots: Array[Vector3] = []

var water_mesh: MeshInstance3D
var _water_mat: StandardMaterial3D
var _protos := {}
var _collider: StaticBody3D
var _sign_candidates: Array[Dictionary] = []
var _glow_tex: GradientTexture2D
var _dark_mat: StandardMaterial3D
var _additive_mat: StandardMaterial3D

# Story / gameplay landmarks
var pier_point := Vector3(344.0, 0.85, -60.0)
var pier_root := Vector3(246.0, 0.85, -60.0)
var spawn_point := Vector3(356.0, 0.75, -60.0)
var motel_point := Vector3(180.0, WALK_Y, 36.0)
var casino_point := Vector3(-36.0, WALK_Y, -36.0)
var park_point := Vector3(36.0, WALK_Y, -36.0)
var pawn_point := Vector3(-108.0, WALK_Y, -108.0)
var tattoo_point := Vector3(36.0, WALK_Y, 108.0)
var club_point := Vector3(108.0, WALK_Y, -36.0)
var tower_a_point := Vector3(108.0, WALK_Y, -108.0)
var tower_b_point := Vector3(-108.0, WALK_Y, 108.0)
var tower_c_point := Vector3(108.0, WALK_Y, 108.0)

func build(seed_value: int = 1999) -> void:
	rng.seed = seed_value
	_setup_materials()
	_build_index()
	_build_ground()
	_build_streets()
	_build_blocks()
	_build_specials()
	_build_palms()
	_build_pier()
	_build_lamps()
	_build_bounds()
	print("[city] buildings=", building_count, " towers=", tower_count, " signs=", sign_count,
		" palms=", palm_entries.size(), " lamps=", lamp_entries.size())

func _process(delta: float) -> void:
	if _water_mat:
		var o := _water_mat.uv1_offset
		o.x = fmod(o.x + delta * 0.006, 1.0)
		o.y = fmod(o.y + delta * 0.003, 1.0)
		_water_mat.uv1_offset = o

# ---------------------------------------------------------------- indexing

func _build_index() -> void:
	for i in GRID:
		if i % BLOCK_TILES == 0:
			road_lines.append(tile_world(i))
	for bz in BLOCKS:
		for bx in BLOCKS:
			block_centers.append(Vector2(tile_world(bx * BLOCK_TILES + BLOCK_TILES / 2),
				tile_world(bz * BLOCK_TILES + BLOCK_TILES / 2)))
	# special blocks, keyed "bx,bz"
	block_specials[Vector2i(2, 2)] = "casino"
	block_specials[Vector2i(3, 2)] = "park"
	block_specials[Vector2i(5, 3)] = "motel"
	block_specials[Vector2i(4, 1)] = "tower_a"
	block_specials[Vector2i(1, 4)] = "tower_b"
	block_specials[Vector2i(4, 4)] = "tower_c"

func tile_world(index: int) -> float:
	return (float(index) - float(GRID - 1) * 0.5) * TILE

func block_center(bx: int, bz: int) -> Vector3:
	var c := block_centers[bz * BLOCKS + bx]
	return Vector3(c.x, WALK_Y, c.y)

# ---------------------------------------------------------------- resources

func _setup_materials() -> void:
	_dark_mat = StandardMaterial3D.new()
	_dark_mat.albedo_color = Color(0.035, 0.025, 0.055)
	_dark_mat.roughness = 0.9

	_additive_mat = StandardMaterial3D.new()
	_additive_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_additive_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_additive_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_additive_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_additive_mat.albedo_color = Color(1, 1, 1, 1)

	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0.0))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.width = 128
	_glow_tex.height = 64
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)

func _building_material(base: Material) -> ShaderMaterial:
	var sh := ShaderMaterial.new()
	sh.shader = load("res://assets/shaders/building.gdshader")
	if base is StandardMaterial3D:
		sh.set_shader_parameter("albedo_tex", base.albedo_texture)
	return sh

func _proto(path: String) -> Dictionary:
	if _protos.has(path):
		return _protos[path]
	var inst: Node = load(path).instantiate()
	var mi := _first_mesh(inst)
	var d := {
		"mesh": mi.mesh,
		"mat": mi.get_active_material(0),
		"aabb": mi.get_aabb(),
	}
	inst.free()
	_protos[path] = d
	return d

func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh(c)
		if r:
			return r
	return null

func _mesh_instance(name: String, mesh: Mesh, mat: Material, pos: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)
	return mi

func _add_multimesh(name: String, entries: Array, mesh: Mesh, mat: Material,
		shadows := false) -> void:
	if entries.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = entries.size()
	for i in entries.size():
		mm.set_instance_transform(i, entries[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _add_collision_box(size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	shape.rotation.y = rot_y
	_collider.add_child(shape)

# ---------------------------------------------------------------- ground

func _pbr_material(folder: String, uv_scale: float, tint: Color, normal_scale := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s/color.png" % folder)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/%s/normal.png" % folder)
	m.normal_scale = normal_scale
	m.roughness_texture = load("res://assets/textures/%s/roughness.png" % folder)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.albedo_color = tint
	m.roughness = 1.0
	m.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _box_with_uv(size: Vector3, meters_per_tile: float) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var n := norms[i]
		var uv: Vector2
		if absf(n.y) > 0.5:
			uv = Vector2(v.x, v.z)
		elif absf(n.x) > 0.5:
			uv = Vector2(v.z, v.y)
		else:
			uv = Vector2(v.x, v.y)
		uvs[i] = uv / meters_per_tile
	var out := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

func _build_ground() -> void:
	var water := MeshInstance3D.new()
	water.name = "Ocean"
	var wm := PlaneMesh.new()
	wm.size = Vector2(5000, 5000)
	water.mesh = wm
	water.position.y = WATER_Y
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.010, 0.065, 0.090)
	wmat.metallic = 0.52
	wmat.roughness = 0.12
	wmat.metallic_specular = 0.8
	wmat.normal_enabled = true
	wmat.normal_texture = load("res://assets/textures/water/normal.png")
	wmat.normal_scale = 0.30
	wmat.uv1_scale = Vector3(560, 560, 1)
	wmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	water.material_override = wmat
	_water_mat = wmat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	water_mesh = water

	var sand := MeshInstance3D.new()
	sand.name = "Beach"
	var bm := BoxMesh.new()
	bm.size = Vector3(SAND_HALF * 2.0, 0.45, SAND_HALF * 2.0)
	sand.mesh = bm
	sand.position.y = SAND_Y - 0.225
	var smat := _pbr_material("sand", 150.0, Color(0.98, 0.92, 0.82), 0.35)
	sand.material_override = smat
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sand)

	# one big walkable slab under the island (road level)
	_collider = StaticBody3D.new()
	_collider.name = "CitySolid"
	_collider.collision_layer = 1
	_collider.collision_mask = 0
	add_child(_collider)
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(SAND_HALF * 2.0, 1.0, SAND_HALF * 2.0)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0, ROAD_Y - 0.5, 0)
	_collider.add_child(ground_shape)

func _build_streets() -> void:
	# ---- asphalt carpet under the whole island
	var road_mat := _pbr_material("asphalt", 89.0, Color(0.90, 0.91, 0.95), 1.0)
	var road := MeshInstance3D.new()
	road.name = "Asphalt"
	var pm := PlaneMesh.new()
	pm.size = Vector2(CITY_EDGE * 2.0, CITY_EDGE * 2.0)
	road.mesh = pm
	road.position.y = ROAD_Y
	road.material_override = road_mat
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)

	# ---- raised concrete blocks with a lip curb
	var walk_mat := _pbr_material("concrete", 1.0, Color(0.72, 0.70, 0.67), 0.55)
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.58, 0.57, 0.54)
	curb_mat.roughness = 0.9
	var slab := _box_with_uv(Vector3(BLOCK_SIZE, WALK_Y, BLOCK_SIZE), 3.2)
	var curb_h := BoxMesh.new()
	curb_h.size = Vector3(BLOCK_SIZE - 0.4, 0.02, 0.4)
	var curb_v := BoxMesh.new()
	curb_v.size = Vector3(0.4, 0.02, BLOCK_SIZE - 0.4)
	var slabs: Array[Transform3D] = []
	var curbs_h: Array[Transform3D] = []
	var curbs_v: Array[Transform3D] = []
	for bz in BLOCKS:
		for bx in BLOCKS:
			var c := block_centers[bz * BLOCKS + bx]
			slabs.append(Transform3D(Basis(), Vector3(c.x, WALK_Y * 0.5, c.y)))
			_add_collision_box(Vector3(BLOCK_SIZE, WALK_Y, BLOCK_SIZE),
				Vector3(c.x, WALK_Y * 0.5, c.y))
			curbs_h.append(Transform3D(Basis(), Vector3(c.x, WALK_Y + 0.01, c.y - 29.8)))
			curbs_h.append(Transform3D(Basis(), Vector3(c.x, WALK_Y + 0.01, c.y + 29.8)))
			curbs_v.append(Transform3D(Basis(), Vector3(c.x - 29.8, WALK_Y + 0.01, c.y)))
			curbs_v.append(Transform3D(Basis(), Vector3(c.x + 29.8, WALK_Y + 0.01, c.y)))
	_add_multimesh("Sidewalks", slabs, slab, walk_mat, false)
	_add_multimesh("CurbsH", curbs_h, curb_h, curb_mat, false)
	_add_multimesh("CurbsV", curbs_v, curb_v, curb_mat, false)

	_build_road_paint()

func _paint_vertex(st: SurfaceTool, x: float, z: float) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3(x, PAINT_Y, z))

func _paint_quad(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float) -> void:
	# clockwise winding when viewed from above (Godot front faces are CW)
	_paint_vertex(st, x0, z0)
	_paint_vertex(st, x1, z1)
	_paint_vertex(st, x0, z1)
	_paint_vertex(st, x0, z0)
	_paint_vertex(st, x1, z0)
	_paint_vertex(st, x1, z1)

func _build_road_paint() -> void:
	var white := SurfaceTool.new()
	white.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yellow := SurfaceTool.new()
	yellow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gap := 6.4

	# center double-yellow and white edge lines, split at each intersection
	for i in range(road_lines.size() - 1):
		var a: float = road_lines[i] + gap
		var b: float = road_lines[i + 1] - gap
		for line in road_lines:
			# north-south street at x = line
			_paint_quad(yellow, line - 0.21, a, line - 0.09, b)
			_paint_quad(yellow, line + 0.09, a, line + 0.21, b)
			_paint_quad(white, line - 5.42, a, line - 5.26, b)
			_paint_quad(white, line + 5.26, a, line + 5.42, b)
			# east-west street at z = line
			_paint_quad(yellow, a, line - 0.21, b, line - 0.09)
			_paint_quad(yellow, a, line + 0.09, b, line + 0.21)
			_paint_quad(white, a, line - 5.42, b, line - 5.26)
			_paint_quad(white, a, line + 5.26, b, line + 5.42)

	# crosswalks + stop bars at every intersection
	for rz in road_lines:
		for rx in road_lines:
			for side in [-1.0, 1.0]:
				var cz: float = rz + side * 7.9
				var x := rx - 5.1
				while x < rx + 5.0:
					_paint_quad(white, x, cz - 1.5, minf(x + 0.55, rx + 5.1), cz + 1.5)
					x += 1.15
				var cx: float = rx + side * 7.9
				var z := rz - 5.1
				while z < rz + 5.0:
					_paint_quad(white, cx - 1.5, z, cx + 1.5, minf(z + 0.55, rz + 5.1))
					z += 1.15
			# stop bars (right-hand traffic)
			_paint_quad(white, rx + 0.35, rz + 9.9, rx + 5.1, rz + 10.4)
			_paint_quad(white, rx - 5.1, rz - 10.4, rx - 0.35, rz - 9.9)
			_paint_quad(white, rx - 10.4, rz + 0.35, rx - 9.9, rz + 5.1)
			_paint_quad(white, rx + 9.9, rz - 5.1, rx + 10.4, rz - 0.35)

	var mesh := ArrayMesh.new()
	white.commit(mesh)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.68, 0.68, 0.65)
	wmat.roughness = 0.62
	mesh.surface_set_material(0, wmat)
	yellow.commit(mesh)
	var ymat := StandardMaterial3D.new()
	ymat.albedo_color = Color(0.66, 0.47, 0.10)
	ymat.roughness = 0.64
	mesh.surface_set_material(1, ymat)

	var paint := MeshInstance3D.new()
	paint.name = "RoadPaint"
	paint.mesh = mesh
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paint)

# ---------------------------------------------------------------- blocks

func _build_blocks() -> void:
	var paths := [
		"res://assets/models/city/building-small-a.glb",
		"res://assets/models/city/building-small-b.glb",
		"res://assets/models/city/building-small-c.glb",
		"res://assets/models/city/building-small-d.glb",
		"res://assets/models/city/building-garage.glb",
	]
	var weights := [0.28, 0.24, 0.16, 0.22, 0.10]
	var meshes := {}
	for p in paths:
		meshes[p] = _proto(p)
	var building_entries := {}
	for p in paths:
		building_entries[p] = []
	for bz in BLOCKS:
		for bx in BLOCKS:
			if block_specials.has(Vector2i(bx, bz)):
				continue
			var center := block_center(bx, bz)
			var layout := rng.randi_range(0, 2)
			var spots: Array[Vector2] = []
			var base_scale := 1.5
			if layout == 0:
				spots.append(Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)))
				base_scale = 2.15
			elif layout == 1:
				base_scale = 1.72
				if rng.randf() < 0.5:
					spots.append(Vector2(-2.5, -13.5))
					spots.append(Vector2(2.0, 13.5))
				else:
					spots.append(Vector2(-13.5, -2.5))
					spots.append(Vector2(13.5, 2.0))
			else:
				base_scale = 1.48
				spots.append(Vector2(-13.0, -13.0))
				spots.append(Vector2(13.0, -13.0))
				spots.append(Vector2(-13.0, 13.0))
				spots.append(Vector2(13.0, 13.0))

			for spot in spots:
				var path := _weighted_path(paths, weights)
				var proto: Dictionary = meshes[path]
				var aabb: AABB = proto["aabb"]
				var y_scale := rng.randf_range(0.9, 1.32)
				if layout == 0:
					y_scale = rng.randf_range(1.15, 1.9)
				var footprint := 13.1 * base_scale * rng.randf_range(0.92, 1.08)
				var height := aabb.size.y * 13.1 * y_scale
				var pos := Vector3(center.x + spot.x + rng.randf_range(-1, 1), WALK_Y + 0.005,
					center.z + spot.y + rng.randf_range(-1, 1))
				var yaw := _nearest_street_yaw(center, Vector2(pos.x, pos.z))
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3(footprint, 13.1 * y_scale, footprint))
				building_entries[path].append(Transform3D(basis, pos))
				building_count += 1
				_add_collision_box(Vector3(footprint, height, footprint),
					pos + Vector3(0, height * 0.5, 0), yaw)
				if rng.randf() < 0.30 and sign_count < 16:
					_sign_candidates.append({
						"pos": pos, "yaw": yaw, "height": height,
						"front": footprint * 0.5, "scale": clampf(height / 16.0, 0.75, 1.6),
					})

	for p in paths:
		var d: Dictionary = meshes[p]
		_add_multimesh("Buildings_" + p.get_file().get_basename(), building_entries[p],
			d["mesh"], _building_material(d["mat"]), true)
	# rooftop / facade neon signs
	_sign_candidates.shuffle()
	var count := mini(14, _sign_candidates.size())
	for i in count:
		var s: Dictionary = _sign_candidates[i]
		var col: Color = NEON_COLORS[i % NEON_COLORS.size()]
		var txt: String = SHOP_SIGNS[(i * 7 + 3) % SHOP_SIGNS.size()]
		var dir := Vector3(sin(s.yaw), 0, cos(s.yaw))
		var base: Vector3 = s.pos + dir * (float(s.front) + 0.35)
		base.y = s.pos.y + clampf(float(s.height) * 0.45, 3.2, 8.5)
		_add_neon_sign(txt, base, dir, col, float(s.scale))

func _weighted_path(paths: Array, weights: Array) -> String:
	var r := rng.randf()
	var acc := 0.0
	for i in paths.size():
		acc += weights[i]
		if r <= acc:
			return str(paths[i])
	return str(paths[-1])

func _nearest_street_yaw(center: Vector3, p: Vector2) -> float:
	var dx := p.x - center.x
	var dz := p.y - center.z
	var dir: Vector3
	if absf(dx) > absf(dz):
		dir = Vector3(signf(dx), 0, 0)
	else:
		dir = Vector3(0, 0, signf(dz))
	return atan2(dir.x, dir.z)

# ---------------------------------------------------------------- landmarks

func _build_specials() -> void:
	_build_casino()
	_build_motel()
	_build_park()
	_build_tower(tower_a_point, Vector3(24, 58, 22), Color(0.10, 0.07, 0.17), Color(1.0, 0.66, 0.34), Color(1.0, 0.2, 0.6), 4.0)
	_build_tower(tower_b_point, Vector3(20, 46, 26), Color(0.08, 0.10, 0.18), Color(0.8, 0.86, 1.0), Color(0.1, 1.0, 0.85), 9.0)
	_build_tower(tower_c_point, Vector3(22, 72, 22), Color(0.13, 0.08, 0.15), Color(1.0, 0.72, 0.4), Color(0.45, 0.55, 1.0), 14.0)

func _build_casino() -> void:
	var c := casino_point
	# plaza
	var plaza := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(56, 0.05, 54)
	plaza.mesh = pm
	plaza.position = Vector3(c.x, WALK_Y + 0.025, c.z)
	plaza.material_override = _pbr_material("concrete", 12.0, Color(0.55, 0.50, 0.45), 0.5)
	add_child(plaza)

	var base_y := WALK_Y
	var podium := Vector3(40, 16, 32)
	_tower_box(podium, Vector3(c.x, base_y + podium.y * 0.5, c.z + 7), Color(0.13, 0.06, 0.18),
		Color(1.0, 0.7, 0.35), Color(1.0, 0.18, 0.62), 2.0, 1.0)
	var tower_size := Vector3(22, 54, 20)
	_tower_box(tower_size, Vector3(c.x - 4, base_y + podium.y + tower_size.y * 0.5, c.z + 10),
		Color(0.11, 0.06, 0.16), Color(1.0, 0.75, 0.4), Color(1.0, 0.18, 0.62), 2.0, 1.0)
	# neon crown
	var crown := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(23, 0.35, 21)
	crown.mesh = cm
	crown.position = Vector3(c.x - 4, base_y + podium.y + tower_size.y, c.z + 10)
	crown.material_override = _emissive(Color(1.0, 0.2, 0.66), 3.0)
	add_child(crown)
	# porte-cochere
	var canopy := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(18, 1.0, 10)
	canopy.mesh = km
	canopy.position = Vector3(c.x + 2, base_y + 6.2, c.z - 20)
	canopy.material_override = _dark_mat
	add_child(canopy)
	for sx in [-7.0, 8.0]:
		var pillar := MeshInstance3D.new()
		var pmm := BoxMesh.new()
		pmm.size = Vector3(1.0, 6.2, 1.0)
		pillar.mesh = pmm
		pillar.position = Vector3(c.x + sx + 2, base_y + 3.1, c.z - 22)
		pillar.material_override = _dark_mat
		add_child(pillar)
	_add_collision_box(Vector3(40, 16, 32), Vector3(c.x, base_y + 8, c.z + 7))
	_add_collision_box(Vector3(22, 54, 20), Vector3(c.x - 4, base_y + 16 + 27, c.z + 10))
	_add_neon_sign("NEON PALMS", Vector3(c.x, base_y + 9.5, c.z - 9.4), Vector3(0, 0, -1),
		Color(1.0, 0.2, 0.66), 2.1)
	_add_neon_sign("CASINO", Vector3(c.x + 20.3, base_y + 13.0, c.z + 7), Vector3(1, 0, 0),
		Color(1.0, 0.8, 0.3), 1.2)
	casino_point = Vector3(c.x, WALK_Y, c.z)

func _build_motel() -> void:
	var c := motel_point
	# low L-shaped motel using one wide building
	var proto := _proto("res://assets/models/city/building-small-a.glb")
	var entries: Array[Transform3D] = []
	var footprint := 26.0
	var basis := Basis(Vector3.UP, PI).scaled(Vector3(footprint, 13.1 * 0.78, 18.0))
	var pos := Vector3(c.x - 3, WALK_Y + 0.005, c.z - 8)
	entries.append(Transform3D(basis, pos))
	_add_multimesh("Motel", entries, proto.mesh, _building_material(proto.mat), true)
	var motel_aabb: AABB = proto["aabb"]
	var h: float = motel_aabb.size.y * 13.1 * 0.78
	_add_collision_box(Vector3(footprint, h, 18.0), pos + Vector3(0, h * 0.5, 0), PI)
	_add_neon_sign("SUNSET MOTEL", Vector3(c.x - 3, WALK_Y + 8.0, c.z + 1.2), Vector3(0, 0, 1),
		Color(0.2, 0.92, 1.0), 1.7)
	# a few parking spots out front
	for i in 3:
		parking_spots.append(Vector3(c.x - 15 + i * 6.0, WALK_Y, c.z + 24))

func _build_park() -> void:
	var c := park_point
	var plaza := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(44, 0.05, 44)
	plaza.mesh = pm
	plaza.position = Vector3(c.x, WALK_Y + 0.025, c.z)
	plaza.material_override = _pbr_material("concrete", 10.0, Color(0.68, 0.64, 0.57), 0.45)
	add_child(plaza)
	var fountain := _proto("res://assets/models/city/pavement-fountain.glb")
	var fe: Array[Transform3D] = [Transform3D(
		Basis().scaled(Vector3(11, 11, 11)), Vector3(c.x, WALK_Y + 0.02, c.z))]
	_add_multimesh("Fountain", fe, fountain.mesh, fountain.mat, true)
	# trees around the plaza
	var tree := _proto("res://assets/models/city/grass-trees-tall.glb")
	var te: Array[Transform3D] = []
	for i in 10:
		var a := TAU * float(i) / 10.0
		te.append(Transform3D(Basis().scaled(Vector3(5.5, 5.5, 5.5)),
			Vector3(c.x + cos(a) * 24.0, WALK_Y, c.z + sin(a) * 24.0)))
	_add_multimesh("ParkTrees", te, tree.mesh, tree.mat, true)
	# palms in the corners
	for p in [Vector2(-18, -18), Vector2(18, -18), Vector2(-18, 18), Vector2(18, 18)]:
		palm_entries.append(Transform3D(Basis().scaled(Vector3(1.0, 1.05, 1.0)),
			Vector3(c.x + p.x, WALK_Y, c.z + p.y)))

func _build_tower(center: Vector3, size: Vector3, wall: Color, lit: Color, accent: Color, seed_value: float) -> void:
	var plaza := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(48, 0.05, 48)
	plaza.mesh = pm
	plaza.position = Vector3(center.x, WALK_Y + 0.025, center.z)
	plaza.material_override = _pbr_material("concrete", 11.0, Color(0.58, 0.55, 0.51), 0.5)
	add_child(plaza)

	var h1 := size.y * 0.34
	var h2 := size.y * 0.30
	var h3 := size.y * 0.36
	var w1 := size.x
	var d1 := size.z
	var w2 := size.x * 0.82
	var d2 := size.z * 0.82
	var w3 := size.x * 0.6
	var d3 := size.z * 0.6
	var base_y := WALK_Y
	_tower_box(Vector3(w1, h1, d1), Vector3(center.x, base_y + h1 * 0.5, center.z), wall, lit, accent, seed_value, 1.0)
	_tower_box(Vector3(w2, h2, d2), Vector3(center.x + 1.5, base_y + h1 + h2 * 0.5, center.z - 1.0), wall, lit, accent, seed_value, 0.9)
	_tower_box(Vector3(w3, h3, d3), Vector3(center.x + 0.6, base_y + h1 + h2 + h3 * 0.5, center.z), wall, lit, accent, seed_value, 0.8)
	# crown
	var crown := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(w3 + 0.8, 0.35, d3 + 0.8)
	crown.mesh = cm
	crown.position = Vector3(center.x + 0.6, base_y + h1 + h2 + h3, center.z)
	crown.material_override = _emissive(accent, 3.2)
	add_child(crown)
	# antenna
	var ant := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.09
	am.bottom_radius = 0.2
	am.height = 9.0
	ant.mesh = am
	ant.position = Vector3(center.x + 0.6, base_y + h1 + h2 + h3 + 5.0, center.z)
	ant.material_override = _dark_mat
	add_child(ant)
	var beacon := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.32
	bm.height = 0.64
	beacon.mesh = bm
	beacon.position = Vector3(center.x + 0.6, base_y + h1 + h2 + h3 + 9.3, center.z)
	beacon.material_override = _emissive(Color(1.0, 0.1, 0.15), 4.0)
	add_child(beacon)

	_add_collision_box(Vector3(w1, h1 + h2 + h3, d1),
		Vector3(center.x, base_y + (h1 + h2 + h3) * 0.5, center.z))
	tower_count += 1

func _tower_box(size: Vector3, pos: Vector3, wall: Color, lit: Color, accent: Color,
		seed_value: float, brightness: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var sh := ShaderMaterial.new()
	sh.shader = load("res://assets/shaders/tower.gdshader")
	sh.set_shader_parameter("wall_color", wall * brightness)
	sh.set_shader_parameter("lit_color", lit)
	sh.set_shader_parameter("accent_color", accent)
	sh.set_shader_parameter("seed", seed_value)
	sh.set_shader_parameter("tower_height", size.y)
	sh.set_shader_parameter("half_x", size.x * 0.5)
	sh.set_shader_parameter("half_z", size.z * 0.5)
	sh.set_shader_parameter("lit_ratio", 0.34 + fmod(seed_value, 5.0) * 0.035)
	mi.material_override = sh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

# ---------------------------------------------------------------- neon

func _add_neon_sign(text: String, pos: Vector3, fwd: Vector3, color: Color, size := 1.0) -> void:
	var yaw := atan2(fwd.x, fwd.z)
	var label := Label3D.new()
	label.text = text
	label.font = FONT_SIGN
	label.font_size = 96
	label.pixel_size = 0.012 * size
	label.modulate = color
	label.outline_size = 18
	label.outline_modulate = Color(0.02, 0.01, 0.04, 0.95)
	label.position = pos + fwd * 0.28
	label.rotation.y = yaw
	label.shaded = false
	label.double_sided = false
	label.no_depth_test = false
	add_child(label)

	var w := maxf(2.4, float(text.length()) * 0.46 * 96.0 * 0.012 * size)
	var h := 1.55 * size
	var quad := QuadMesh.new()
	quad.size = Vector2(w * 1.12, h * 1.25)
	var back := MeshInstance3D.new()
	back.mesh = quad
	back.material_override = _dark_mat
	back.position = pos + fwd * 0.10
	back.rotation.y = yaw
	add_child(back)

	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(w * 2.6, h * 3.6)
	glow.mesh = gq
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	gmat.albedo_texture = _glow_tex
	gmat.albedo_color = Color(color.r, color.g, color.b, 0.62)
	glow.material_override = gmat
	glow.position = pos + fwd * 0.04
	glow.rotation.y = yaw
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	sign_count += 1

# ---------------------------------------------------------------- nature

func _build_palms() -> void:
	# beach ring
	for i in 90:
		var side := rng.randi_range(0, 3)
		var a := rng.randf_range(234.0, 292.0)
		var b := rng.randf_range(-292.0, 292.0)
		var p: Vector3
		match side:
			0: p = Vector3(a, 0.06, b)
			1: p = Vector3(-a, 0.06, b)
			2: p = Vector3(b, 0.06, a)
			_: p = Vector3(b, 0.06, -a)
		# keep the pier corridor clear
		if p.x > 220.0 and absf(p.z + 60.0) < 14.0:
			continue
		palm_entries.append(_palm_transform(p))
	# inner-city palms
	for i in 26:
		var bz := rng.randi_range(0, BLOCKS - 1)
		var bx := rng.randi_range(0, BLOCKS - 1)
		var c := block_center(bx, bz)
		var side := rng.randi_range(0, 3)
		var along := rng.randf_range(-25.0, 25.0)
		var off := 27.2
		var p2: Vector3
		match side:
			0: p2 = Vector3(c.x + along, WALK_Y, c.z - off)
			1: p2 = Vector3(c.x + along, WALK_Y, c.z + off)
			2: p2 = Vector3(c.x - off, WALK_Y, c.z + along)
			_: p2 = Vector3(c.x + off, WALK_Y, c.z + along)
		palm_entries.append(_palm_transform(p2))

	var palm := _make_palm_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = palm
	mm.instance_count = palm_entries.size()
	for i in palm_entries.size():
		mm.set_instance_transform(i, palm_entries[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Palms"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _palm_transform(p: Vector3) -> Transform3D:
	var s := rng.randf_range(0.85, 1.25)
	return Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s, s)), p)

func _make_palm_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var frng := RandomNumberGenerator.new()
	frng.seed = 4242

	# trunk
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var seg := 7
	var height := 6.6
	var pts: Array[PackedVector3Array] = []
	for i in rings:
		var t := float(i) / float(rings - 1)
		var y := t * height
		var lean := 0.95 * t * t
		var r := lerpf(0.26, 0.12, t)
		var ring: PackedVector3Array = []
		for j in seg:
			var a := TAU * float(j) / float(seg)
			ring.append(Vector3(cos(a) * r + lean, y, sin(a) * r))
		pts.append(ring)
	for i in rings - 1:
		for j in seg:
			var j2 := (j + 1) % seg
			var a0 := pts[i][j]
			var a1 := pts[i][j2]
			var b0 := pts[i + 1][j]
			var b1 := pts[i + 1][j2]
			st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(a1)
			st.add_vertex(a1); st.add_vertex(b0); st.add_vertex(b1)
	st.generate_normals()
	st.commit(mesh)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.36, 0.25, 0.17)
	trunk_mat.roughness = 0.96
	mesh.surface_set_material(0, trunk_mat)

	# fronds
	var ft := SurfaceTool.new()
	ft.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.95, height, 0.0)
	for k in 9:
		var ang := TAU * float(k) / 9.0 + frng.randf_range(-0.08, 0.08)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var length := frng.randf_range(3.0, 3.9)
		var widths: Array[float] = []
		var centers: Array[Vector3] = []
		for i in 5:
			var t := float(i) / 4.0
			var c := top + dir * (t * length)
			c.y = top.y + 0.35 * sin(t * PI * 0.7) - 2.4 * t * t
			c += dir * 0.0
			centers.append(c)
			widths.append(lerpf(0.34, 0.04, t))
		for i in 4:
			var a := centers[i] - side * widths[i]
			var b := centers[i] + side * widths[i]
			var c2 := centers[i + 1] - side * widths[i + 1]
			var d := centers[i + 1] + side * widths[i + 1]
			ft.add_vertex(a); ft.add_vertex(c2); ft.add_vertex(b)
			ft.add_vertex(b); ft.add_vertex(c2); ft.add_vertex(d)
	ft.generate_normals()
	ft.commit(mesh)
	var frond_mat := StandardMaterial3D.new()
	frond_mat.albedo_color = Color(0.10, 0.34, 0.19)
	frond_mat.roughness = 0.9
	frond_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, frond_mat)
	return mesh

# ---------------------------------------------------------------- lamps / pier / bounds

func _build_lamps() -> void:
	# intersection corners
	for bz in BLOCKS + 1:
		for bx in BLOCKS + 1:
			if (bx + bz) % 2 != 0:
				continue
			var cx := tile_world(bx * BLOCK_TILES)
			var cz := tile_world(bz * BLOCK_TILES)
			for sx in [-1.0, 1.0]:
				var p := Vector3(cx + sx * 7.6, WALK_Y, cz + 7.6)
				var yaw := atan2(-sx, -1.0)
				lamp_entries.append(Transform3D(Basis(Vector3.UP, yaw), p))
	var lm := _make_lamp_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lm
	mm.instance_count = lamp_entries.size()
	for i in lamp_entries.size():
		mm.set_instance_transform(i, lamp_entries[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "StreetLamps"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _make_lamp_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st, Vector3(0, 2.5, 0), Vector3(0.12, 5.0, 0.12))
	_append_box(st, Vector3(0, 4.95, 0), Vector3(1.3, 0.12, 0.12))
	_append_box(st, Vector3(0.6, 4.85, 0), Vector3(0.5, 0.16, 0.28))
	st.generate_normals()
	st.commit(mesh)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.17, 0.22)
	metal.metallic = 0.6
	metal.roughness = 0.45
	mesh.surface_set_material(0, metal)

	var e := SurfaceTool.new()
	e.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(e, Vector3(0.6, 4.77, 0), Vector3(0.4, 0.06, 0.2))
	e.generate_normals()
	e.commit(mesh)
	mesh.surface_set_material(1, _emissive(Color(1.0, 0.78, 0.45), 2.6))
	return mesh

func _append_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var c := [
		center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
		center + Vector3(h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, h.z),
		center + Vector3(-h.x, h.y, -h.z), center + Vector3(h.x, h.y, -h.z),
		center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
	]
	var faces := [
		[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1],
		[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0],
	]
	for f in faces:
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var cc: Vector3 = c[f[2]]
		var d: Vector3 = c[f[3]]
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(cc)
		st.add_vertex(a); st.add_vertex(cc); st.add_vertex(d)

func _wood_material() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var tone := 0.82 + 0.18 * sin(float(y) * 0.7)
		for x in 64:
			var seam := 0.72 if (y % 8) == 0 else 1.0
			var grain := 0.92 + 0.08 * sin(float(x) * 0.35 + float(y) * 1.7)
			var v := tone * seam * grain
			img.set_pixel(x, y, Color(0.34 * v, 0.23 * v, 0.15 * v))
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(1, 8, 1)
	m.roughness = 0.88
	return m

func _build_pier() -> void:
	var z := -60.0
	var deck_y := 0.75
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(132, 0.35, 10)
	deck.mesh = dm
	deck.position = Vector3(304, deck_y - 0.175, z)
	var wood := _wood_material()
	deck.material_override = wood
	add_child(deck)
	_add_collision_box(Vector3(132, 0.35, 10), Vector3(304, deck_y - 0.175, z))

	# ramp from beach to pier
	var ramp := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(15, 0.3, 10)
	ramp.mesh = rm
	ramp.position = Vector3(232.5, 0.4, z)
	ramp.rotation.z = -0.045
	ramp.material_override = wood
	add_child(ramp)
	var ramp_shape := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(15, 0.3, 10)
	ramp_shape.shape = rb
	ramp_shape.position = ramp.position
	ramp_shape.rotation.z = -0.045
	_collider.add_child(ramp_shape)

	# railing posts + rails
	var posts: Array[Transform3D] = []
	for i in 23:
		var x := 240.0 + i * 5.6
		for side in [-1.0, 1.0]:
			posts.append(Transform3D(Basis(), Vector3(x, deck_y + 0.55, z + side * 4.9)))
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.12, 1.1, 0.12)
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.mesh = post_mesh
	pm.instance_count = posts.size()
	for i in posts.size():
		pm.set_instance_transform(i, posts[i])
	var pmm := MultiMeshInstance3D.new()
	pmm.multimesh = pm
	pmm.material_override = wood
	pmm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmm)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rmm := BoxMesh.new()
		rmm.size = Vector3(126, 0.09, 0.09)
		rail.mesh = rmm
		rail.position = Vector3(303, deck_y + 1.05, z + side * 4.9)
		rail.material_override = wood
		add_child(rail)

	# pilings
	var pilings: Array[Transform3D] = []
	for i in 7:
		var px := 318.0 + i * 8.0
		for side in [-1.0, 1.0]:
			pilings.append(Transform3D(Basis().scaled(Vector3(1, 1, 1)),
				Vector3(px, -0.4, z + side * 4.2)))
	var pile_mesh := CylinderMesh.new()
	pile_mesh.top_radius = 0.22
	pile_mesh.bottom_radius = 0.26
	pile_mesh.height = 2.4
	var pile_mm := MultiMesh.new()
	pile_mm.transform_format = MultiMesh.TRANSFORM_3D
	pile_mm.mesh = pile_mesh
	pile_mm.instance_count = pilings.size()
	for i in pilings.size():
		pile_mm.set_instance_transform(i, pilings[i])
	var pile_mi := MultiMeshInstance3D.new()
	pile_mi.multimesh = pile_mm
	pile_mi.material_override = wood
	pile_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pile_mi)

	# pier arch
	var arch_mat := _dark_mat
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pbm := BoxMesh.new()
		pbm.size = Vector3(0.6, 7.0, 0.6)
		post.mesh = pbm
		post.position = Vector3(246, 3.5 + 0.8, z + side * 5.2)
		post.material_override = arch_mat
		add_child(post)
	var beam := MeshInstance3D.new()
	var bbm := BoxMesh.new()
	bbm.size = Vector3(0.7, 0.7, 12)
	beam.mesh = bbm
	beam.position = Vector3(246, 7.2, z)
	beam.material_override = arch_mat
	add_child(beam)
	_add_neon_sign("SUNSET PIER", Vector3(246.5, 7.2, -60.0), Vector3(1, 0, 0),
		Color(1.0, 0.55, 0.3), 1.3)
	# pier lamps
	for i in 5:
		var x := 252.0 + i * 24.0
		for side in [-1.0, 1.0]:
			lamp_entries.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x, deck_y, z + side * 4.6)))

func _build_bounds() -> void:
	# invisible walls just past the beach so the player can't drive into the void
	for sx in [-1.0, 1.0]:
		if sx > 0.0:
			# leave a gap for the pier
			for seg in [Vector2(-306.0, -78.0), Vector2(-42.0, 306.0)]:
				var w := CollisionShape3D.new()
				var b := BoxShape3D.new()
				b.size = Vector3(1, 8, seg.y - seg.x)
				w.shape = b
				w.position = Vector3(sx * 306.0, 2.0, (seg.x + seg.y) * 0.5)
				_collider.add_child(w)
		else:
			var w := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(1, 8, 640)
			w.shape = b
			w.position = Vector3(sx * 306.0, 2.0, 0)
			_collider.add_child(w)
	for sz in [-1.0, 1.0]:
		var w2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(640, 8, 1)
		w2.shape = b2
		w2.position = Vector3(0, 2.0, sz * 306.0)
		_collider.add_child(w2)

# ---------------------------------------------------------------- helpers

func get_sidewalk_offset() -> float:
	return SIDEWALK_OFFSET

func get_lane_offset() -> float:
	return LANE_OFFSET

func block_loop(bx: int, bz: int, half_size: float, corner_radius := 7.0) -> PackedVector2Array:
	var c := block_centers[bz * BLOCKS + bx]
	var pts := PackedVector2Array()
	var r := minf(corner_radius, half_size * 0.5)
	# north straight (heading east)
	pts.append(Vector2(c.x - half_size + r, c.y - half_size))
	pts.append(Vector2(c.x + half_size - r, c.y - half_size))
	_arc(pts, Vector2(c.x + half_size - r, c.y - half_size + r), r, -PI * 0.5, 0.0)
	pts.append(Vector2(c.x + half_size, c.y + half_size - r))
	_arc(pts, Vector2(c.x + half_size - r, c.y + half_size - r), r, 0.0, PI * 0.5)
	pts.append(Vector2(c.x - half_size + r, c.y + half_size))
	_arc(pts, Vector2(c.x - half_size + r, c.y + half_size - r), r, PI * 0.5, PI)
	pts.append(Vector2(c.x - half_size, c.y - half_size + r))
	_arc(pts, Vector2(c.x - half_size + r, c.y - half_size + r), r, PI, PI * 1.5)
	return pts

func _arc(pts: PackedVector2Array, center: Vector2, radius: float, a0: float, a1: float) -> void:
	for i in range(1, 6):
		var a := lerpf(a0, a1, float(i) / 5.0)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)

func path_length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in pts.size():
		total += pts[i].distance_to(pts[(i + 1) % pts.size()])
	return total

func sample_path(pts: PackedVector2Array, total: float, s: float) -> Dictionary:
	var d := fposmod(s, total)
	for i in pts.size():
		var j := (i + 1) % pts.size()
		var seg := pts[i].distance_to(pts[j])
		if d <= seg:
			var t := d / maxf(seg, 0.001)
			var p := pts[i].lerp(pts[j], t)
			var dir := (pts[j] - pts[i]).normalized()
			return {"pos": Vector2(p.x, p.y), "dir": dir}
		d -= seg
	return {"pos": pts[0], "dir": Vector2(1, 0)}

func nearest_lane_point(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := 1e9
	for z in road_lines:
		var d := absf(p.z - z)
		if d < bd:
			bd = d
			best = Vector3(p.x, ROAD_Y + 0.02, z + LANE_OFFSET)
	for x in road_lines:
		var d2 := absf(p.x - x)
		if d2 < bd:
			bd = d2
			best = Vector3(x + LANE_OFFSET, ROAD_Y + 0.02, p.z)
	return best
