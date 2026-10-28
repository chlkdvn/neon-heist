extends Node3D

## Lightweight kinematic traffic on the block loops. Merged car meshes keep draw calls low.

const CAR_PATHS := [
	"res://assets/models/cars/sedan.glb",
	"res://assets/models/cars/sedan-sports.glb",
	"res://assets/models/cars/suv.glb",
	"res://assets/models/cars/hatchback-sports.glb",
	"res://assets/models/cars/taxi.glb",
	"res://assets/models/cars/van.glb",
]

var city: City
var cars: Array[TrafficCar] = []
var _mesh_cache := {}

class TrafficCar extends AnimatableBody3D:
	var path: PackedVector2Array
	var total := 0.0
	var s := 0.0
	var speed := 7.0
	var dir_sign := 1.0
	var cruise := 7.0
	var pause := 0.0

	func _physics_process(delta: float) -> void:
		if path.is_empty():
			return
		if pause > 0.0:
			pause -= delta
			return
		s += speed * dir_sign * delta
		var pos: Vector2 = _sample(s)
		var ahead: Vector2 = _sample(s + 1.2 * dir_sign)
		var d := (ahead - pos).normalized()
		global_position = Vector3(pos.x, 0.02, pos.y)
		if d.length_squared() > 0.001:
			look_at(Vector3(pos.x + d.x, 0.02, pos.y + d.y), Vector3.UP)
		speed = lerpf(speed, cruise, delta * 0.8)

	func _sample(v: float) -> Vector2:
		var d := fposmod(v, total)
		for i in path.size():
			var j := (i + 1) % path.size()
			var seg := path[i].distance_to(path[j])
			if d <= seg:
				return path[i].lerp(path[j], d / maxf(seg, 0.001))
			d -= seg
		return path[0]

	func bump() -> void:
		speed = 0.0
		pause = 2.5

	func can_enter() -> bool:
		return false

func setup(c: City, count := 10) -> void:
	city = c
	var used := {}
	for i in count:
		var bx := randi() % City.BLOCKS
		var bz := randi() % City.BLOCKS
		var key := Vector2i(bx, bz)
		if used.has(key):
			continue
		used[key] = true
		var path := city.block_loop(bx, bz, 33.0, 5.0)
		var path_len := city.path_length(path)
		var car := TrafficCar.new()
		var model: String = CAR_PATHS[randi() % CAR_PATHS.size()]
		car.name = "Traffic_%d_%d" % [bx, bz]
		car.collision_layer = 8
		car.collision_mask = 1
		car.path = path
		car.total = path_len
		car.s = randf() * path_len
		car.dir_sign = 1.0 if randf() < 0.5 else -1.0
		car.cruise = randf_range(6.0, 10.0)
		car.speed = car.cruise
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 1.35, 3.8)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position.y = 0.68
		car.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = _merged(model)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.position.y = 0.02
		car.add_child(mi)
		add_child(car)
		cars.append(car)

func _merged(path: String) -> ArrayMesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var inst: Node3D = load(path).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material = null
	for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mat == null:
			mat = mi.get_active_material(0)
		var xf := _relative(mi, inst)
		xf = xf * Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 1.55), Vector3.ZERO)
		for surf in mi.mesh.get_surface_count():
			st.append_from(mi.mesh, surf, xf)
	var mesh := st.commit()
	if mat:
		mesh.surface_set_material(0, mat)
	inst.free()
	_mesh_cache[path] = mesh
	return mesh

func _relative(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
