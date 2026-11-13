class_name Room3D
extends Node3D
## Construye un lugar en 3D (paredes, piso, ventana, muebles, piscina) a
## partir de Environments, y ajusta el color según la hora (día/atardecer/noche).

const SKY := {
	"dia": [Color("9fd2f5"), Color("e4f3fb")],
	"atardecer": [Color("f39a6b"), Color("ffd6a5")],
	"noche": [Color("1c1f4a"), Color("3b3f7a")],
}

var env_id := ""
var _window_material: StandardMaterial3D
var _pool_material: ShaderMaterial
var _sky_material: StandardMaterial3D


func build(id: String, time_theme: String) -> void:
	env_id = id
	for child in get_children():
		child.queue_free()
	var data := Environments.fetch(id)
	var outdoor := bool(data.get("outdoor", false))

	_add_floor(data, outdoor)
	if outdoor:
		_add_outdoor_backdrop()
	else:
		_add_walls(data)
		if data.has("window"):
			_add_window(data["window"])
	if data.get("pool", false):
		_add_pool()
	for prop in data["props"]:
		_add_prop(prop)
	set_time(time_theme)


func spot(name: String) -> Variant:
	return Environments.fetch(env_id)["spots"].get(name)


## Cambia el cielo de la ventana / fondo según la hora.
func set_time(time_theme: String) -> void:
	var colors: Array = SKY.get(time_theme, SKY["dia"])
	if _window_material:
		_window_material.albedo_color = colors[1].lerp(colors[0], 0.5)
		_window_material.emission = colors[0]
	if _sky_material:
		_sky_material.albedo_color = colors[0]
	if _pool_material:
		_pool_material.set_shader_parameter("deep", Color("2f8fc9") if time_theme != "noche" else Color("1b3d6b"))


func _add_floor(data: Dictionary, outdoor: bool) -> void:
	var size := Vector2(Environments.SIDE_X * 2.0 + (8.0 if outdoor else 0.4), 8.0)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = data["floor"]
	material.roughness = 0.9
	if data.get("tiles", false):
		material.albedo_texture = _checker_texture(Color(data["floor"]), Color(data["floor"]).darkened(0.08))
		material.uv1_scale = Vector3(6, 6, 1)
	elif not outdoor:
		material.albedo_texture = _plank_texture(Color(data["floor"]))
		material.uv1_scale = Vector3(4, 4, 1)
	floor_mesh.material = material
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3(0, 0, Environments.BACK_Z + size.y / 2.0)
	add_child(floor_node)


func _add_walls(data: Dictionary) -> void:
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = data["wall"]
	wall_material.roughness = 0.95
	var height := 3.0
	var back := _box(Vector3(Environments.SIDE_X * 2.0, height, 0.1), Vector3(0, height / 2.0, Environments.BACK_Z - 0.05), wall_material)
	back.name = "BackWall"
	for side in [-1.0, 1.0]:
		_box(Vector3(0.1, height, 5.0), Vector3(Environments.SIDE_X * side, height / 2.0, Environments.BACK_Z + 2.5), wall_material)
	# Zócalo
	var trim := StandardMaterial3D.new()
	trim.albedo_color = data["wall_trim"]
	_box(Vector3(Environments.SIDE_X * 2.0, 0.12, 0.04), Vector3(0, 0.06, Environments.BACK_Z + 0.02), trim)


func _add_window(position_on_wall: Vector3) -> void:
	_window_material = StandardMaterial3D.new()
	_window_material.emission_enabled = true
	_window_material.emission_energy_multiplier = 0.6
	_box(Vector3(1.3, 1.0, 0.02), position_on_wall + Vector3(0, 0, 0.02), _window_material)
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color.WHITE
	for offset in [Vector3(0, 0.52, 0), Vector3(0, -0.52, 0), Vector3(0, 0, 0)]:
		_box(Vector3(1.4, 0.06, 0.06), position_on_wall + offset + Vector3(0, 0, 0.04), frame)
	for offset in [Vector3(-0.67, 0, 0), Vector3(0.67, 0, 0), Vector3(0, 0, 0)]:
		_box(Vector3(0.06, 1.1, 0.06), position_on_wall + offset + Vector3(0, 0, 0.04), frame)
	# Cortinas
	var curtain := StandardMaterial3D.new()
	curtain.albedo_color = Color(1.0, 0.78, 0.86)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.28, 1.35, 0.05), position_on_wall + Vector3(0.8 * side, -0.05, 0.1), curtain)


func _add_outdoor_backdrop() -> void:
	# Cielo de fondo
	_sky_material = StandardMaterial3D.new()
	_sky_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(Vector3(30, 14, 0.1), Vector3(0, 6, Environments.BACK_Z - 6.0), _sky_material)
	# Cerca blanca
	var fence := StandardMaterial3D.new()
	fence.albedo_color = Color("fbf7f2")
	for i in range(-14, 15):
		_box(Vector3(0.12, 1.0, 0.06), Vector3(i * 0.42, 0.5, Environments.BACK_Z - 0.6), fence)
	_box(Vector3(12.0, 0.08, 0.05), Vector3(0, 0.85, Environments.BACK_Z - 0.58), fence)
	_box(Vector3(12.0, 0.08, 0.05), Vector3(0, 0.35, Environments.BACK_Z - 0.58), fence)
	# Arbustos
	var bush := StandardMaterial3D.new()
	bush.albedo_color = Color("5fa65a")
	for x in [-3.2, -2.4, 2.6, 3.3]:
		var sphere := SphereMesh.new()
		sphere.radius = 0.55
		sphere.height = 0.9
		sphere.material = bush
		var mesh := MeshInstance3D.new()
		mesh.mesh = sphere
		mesh.position = Vector3(x, 0.35, Environments.BACK_Z - 0.3)
		add_child(mesh)


## Piscina detrás de ella, con agua animada por shader.
func _add_pool() -> void:
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("f1ece4")
	var center := Vector3(0, 0, Environments.BACK_Z + 0.75)
	var size := Vector2(3.6, 1.5)
	_box(Vector3(size.x + 0.3, 0.08, 0.15), center + Vector3(0, 0.04, -size.y / 2), edge)
	_box(Vector3(size.x + 0.3, 0.08, 0.15), center + Vector3(0, 0.04, size.y / 2), edge)
	_box(Vector3(0.15, 0.08, size.y), center + Vector3(-size.x / 2, 0.04, 0), edge)
	_box(Vector3(0.15, 0.08, size.y), center + Vector3(size.x / 2, 0.04, 0), edge)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform vec4 deep : source_color = vec4(0.18, 0.56, 0.79, 1.0);
uniform vec4 light : source_color = vec4(0.65, 0.9, 1.0, 1.0);
void fragment() {
	vec2 uv = UV * vec2(6.0, 2.5);
	float w = sin(uv.x * 3.0 + TIME * 1.6) * 0.5 + sin(uv.y * 5.0 - TIME * 1.2 + uv.x) * 0.5;
	float caustic = smoothstep(0.55, 1.0, w);
	ALBEDO = mix(deep.rgb, light.rgb, caustic * 0.55);
}
"""
	_pool_material = ShaderMaterial.new()
	_pool_material.shader = shader
	var water := PlaneMesh.new()
	water.size = size
	water.material = _pool_material
	var water_mesh := MeshInstance3D.new()
	water_mesh.mesh = water
	water_mesh.position = center + Vector3(0, 0.02, 0)
	add_child(water_mesh)


func _add_prop(prop: Array) -> void:
	var scene := load(prop[0]) as PackedScene
	if scene == null:
		push_warning("No se pudo cargar " + str(prop[0]))
		return
	var node := scene.instantiate() as Node3D
	var extra_scale: float = prop[3] if prop.size() > 3 else 1.0
	node.scale = Vector3.ONE * Environments.FURNITURE_SCALE * extra_scale
	node.position = prop[1]
	node.rotation_degrees.y = prop[2]
	add_child(node)
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = pos
	add_child(mesh)
	return mesh


static func _plank_texture(base: Color) -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var row_shade := 0.94 + 0.06 * float((y / 8) % 2)
		for x in 64:
			var c := base * row_shade
			if y % 8 == 0 or (x + (y / 8) * 23) % 64 == 0:
				c = base.darkened(0.18)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


static func _checker_texture(a: Color, b: Color) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var c := a if ((x / 16) + (y / 16)) % 2 == 0 else b
			if x % 16 == 0 or y % 16 == 0:
				c = c.darkened(0.12)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)
