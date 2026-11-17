class_name Puppet
extends Node3D
## Marioneta 2D por capas (estilo VTuber / Live2D).
##
## Carga un archivo .puppet (hecho con tools/bake_puppet.py a partir de un
## modelo de Inochi2D) y lo dibuja: cada capa es una malla con su textura,
## los parámetros la deforman (blend shapes en la GPU) o mueven sus nodos, y
## las físicas hacen que el pelo, la ropa y la cola se muevan solos.
##
## Todo se dibuja en un mismo plano (X derecha, Y arriba, en metros); el
## orden de las capas se fija con sorting_offset y las máscaras con stencil.
##
## Uso:
##   var puppet := Puppet.new()
##   puppet.load_file("res://assets/puppets/aka.puppet")
##   puppet.set_param("Head:: Yaw-Pitch", 0.5, 0.0)
##   puppet.update(delta)   # una vez por frame

const MAGIC := "MICPUP1"
## Separación (en "metros de orden") entre capas consecutivas.
const SORT_STEP := 2.0

const SHADER_TEMPLATE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, %s;
%s
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float hue_shift = 0.0;
uniform float threshold = 0.5;

vec3 shift_hue(vec3 color, float amount) {
	const vec3 k = vec3(0.57735);
	float c = cos(amount * 6.2831853);
	float s = sin(amount * 6.2831853);
	return color * c + cross(k, color) * s + k * dot(k, color) * (1.0 - c);
}

void fragment() {
	vec4 c = texture(tex, UV);
%s
}
"""
const FRAGMENT_MIX := """
	vec3 rgb = hue_shift != 0.0 ? clamp(shift_hue(c.rgb, hue_shift), 0.0, 1.0) : c.rgb;
	ALBEDO = rgb * tint;
	ALPHA = c.a * opacity;
"""
const FRAGMENT_MUL := """
	ALBEDO = mix(vec3(1.0), c.rgb, c.a * opacity);
	ALPHA = 1.0;
"""
const FRAGMENT_WRITER := """
	if (c.a < threshold) discard;
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
"""

enum Target { TX, TY, RX, RY, RZ, SX, SY, Z, OPACITY }
const TARGET_NAMES := {
	"t.x": Target.TX, "t.y": Target.TY, "r.x": Target.RX, "r.y": Target.RY, "r.z": Target.RZ,
	"s.x": Target.SX, "s.y": Target.SY, "zSort": Target.Z, "opacity": Target.OPACITY,
}


class PNode:
	var name := ""
	var type := "node"
	var parent := -1
	var composite := -1
	var enabled := true
	var base_t := Vector2.ZERO
	var base_r := Vector3.ZERO
	var base_s := Vector2.ONE
	var base_z := 0.0
	var base_opacity := 1.0
	# Lo que suman los parámetros este frame.
	var off_t := Vector2.ZERO
	var off_r := Vector3.ZERO
	var off_s := Vector2.ONE
	var off_z := 0.0
	var off_opacity := 1.0
	# Ajustes extra puestos por código (cejas, etc.).
	var user_t := Vector2.ZERO
	var user_rz := 0.0
	var user_s := Vector2.ONE
	var user_opacity := 1.0
	var world := Transform3D.IDENTITY
	var z := 0.0
	var instance: MeshInstance3D
	var material: ShaderMaterial
	## Copias invisibles que escriben la máscara (stencil) de otras capas.
	var writers: Array[MeshInstance3D] = []
	var mask_writers: Array[MeshInstance3D] = []
	var blend := "Normal"
	var last_opacity := -1.0


class PParam:
	var name := ""
	var low := Vector2.ZERO
	var high := Vector2.ONE
	var defaults := Vector2.ZERO
	var value := Vector2.ZERO
	var applied := Vector2(INF, INF)
	var axis_x := PackedFloat32Array()
	var axis_y := PackedFloat32Array()
	var deforms: Array = []  # [node, PackedInt32Array shape por celda, activos]
	var values: Array = []   # [node, target, PackedFloat32Array, actual]
	var driven := false      # lo mueve una física


class PPhysics:
	var node := -1
	var param := -1
	var gravity := 1.0
	var length := 100.0
	var frequency := 1.0
	var angle_damping := 0.5
	var length_damping := 0.5
	var output_scale := Vector2.ONE
	var spring := true
	var bob := Vector2.ZERO
	var velocity := Vector2.ZERO
	var started := false


## Metros por píxel del modelo (lo fija fit_height()).
var unit := 0.001
## Rectángulo que ocupa el modelo en reposo, en píxeles del modelo (Y abajo).
var rest_bounds := Rect2()
## Punto del modelo (px) que queda en el origen del nodo: entre los pies.
var pivot := Vector2.ZERO
## Créditos del modelo (artista, licencia).
var meta := {}
## Movimiento del mundo que deben notar las físicas (metros).
var physics_enabled := true

var _nodes: Array[PNode] = []
var _params: Array[PParam] = []
var _physics: Array[PPhysics] = []
var _node_index := {}
var _param_index := {}
var _textures: Array[Texture2D] = []
var _shaders := {}
var _pixels_per_meter := 1000.0
var _gravity := 9.8
var _order_dirty := true
var _last_z_sum := INF
var _next_reference := 1
var _hue := 0.0
var _hue_nodes := {}
var _tint := Color.WHITE
var _last_origin := Vector3(INF, INF, INF)


# --- Carga ----------------------------------------------------------------------

func load_file(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 16 or bytes.slice(0, 7).get_string_from_ascii() != MAGIC:
		push_warning("No se pudo leer la marioneta: %s" % path)
		return false
	var pos := 8
	var header_size := bytes.decode_u32(pos)
	pos += 4
	var header: Variant = JSON.parse_string(bytes.slice(pos, pos + header_size).get_string_from_utf8())
	pos += header_size
	if typeof(header) != TYPE_DICTIONARY:
		return false
	var blob_size := bytes.decode_u32(pos)
	pos += 4
	var blob := bytes.slice(pos, pos + blob_size)
	pos += blob_size
	var texture_count := bytes.decode_u32(pos)
	pos += 4
	for i in texture_count:
		var size := bytes.decode_u32(pos)
		pos += 4
		var image := Image.new()
		image.load_webp_from_buffer(bytes.slice(pos, pos + size))
		pos += size
		image.generate_mipmaps()
		_textures.append(ImageTexture.create_from_image(image))

	meta = header.get("meta", {})
	_pixels_per_meter = float(header.get("pixels_per_meter", 1000.0))
	_gravity = float(header.get("gravity", 9.8))
	_read_nodes(header["nodes"])
	_read_params(header["params"], blob)
	_build_instances(header["nodes"], blob)
	_measure_rest()
	return true


func _read_nodes(source: Array) -> void:
	for data in source:
		var node := PNode.new()
		node.name = data["name"]
		node.type = data["type"]
		node.parent = int(data["parent"])
		node.composite = int(data["composite"])
		node.enabled = bool(data["enabled"])
		node.base_t = Vector2(data["t"][0], data["t"][1])
		node.base_r = Vector3(data["r"][0], data["r"][1], data["r"][2])
		node.base_s = Vector2(data["s"][0], data["s"][1])
		node.base_z = float(data["z"])
		node.base_opacity = float(data.get("opacity", 1.0))
		node.blend = str(data.get("blend", "Normal"))
		_node_index[node.name] = _nodes.size()
		_nodes.append(node)
		if node.type == "physics":
			var p: Dictionary = data["physics"]
			var physics := PPhysics.new()
			physics.node = _nodes.size() - 1
			physics.param = int(p["param"])
			physics.gravity = float(p["gravity"])
			physics.length = maxf(1.0, float(p["length"]))
			physics.frequency = float(p["frequency"])
			physics.angle_damping = float(p["angle_damping"])
			physics.length_damping = float(p["length_damping"])
			physics.output_scale = Vector2(p["output_scale"][0], p["output_scale"][1])
			physics.spring = str(p["model"]) == "SpringPendulum"
			if physics.param >= 0:
				_physics.append(physics)


## Lista temporal: por nodo, {clave "param:x:y" -> índice de blend shape}.
var _shape_names: Array = []


func _read_params(source: Array, blob: PackedByteArray) -> void:
	_shape_names.resize(_nodes.size())
	for i in _nodes.size():
		_shape_names[i] = []
	for data in source:
		var param := PParam.new()
		param.name = data["name"]
		param.low = Vector2(data["min"][0], data["min"][1])
		param.high = Vector2(data["max"][0], data["max"][1])
		param.defaults = Vector2(data["defaults"][0], data["defaults"][1])
		param.value = param.defaults
		param.axis_x = PackedFloat32Array(data["axes"][0])
		param.axis_y = PackedFloat32Array(data["axes"][1])
		var ny := param.axis_y.size()
		for binding in data["bindings"]:
			var node_id := int(binding["node"])
			if binding["target"] == "deform":
				var shapes := PackedInt32Array()
				shapes.resize(param.axis_x.size() * ny)
				for x in param.axis_x.size():
					for y in ny:
						var offset := int(binding["offsets"][x][y])
						if offset < 0:
							shapes[x * ny + y] = -1
						else:
							shapes[x * ny + y] = _shape_names[node_id].size()
							_shape_names[node_id].append(offset)
				param.deforms.append([node_id, shapes, PackedInt32Array()])
			elif TARGET_NAMES.has(binding["target"]):
				var values := PackedFloat32Array()
				values.resize(param.axis_x.size() * ny)
				for x in param.axis_x.size():
					for y in ny:
						values[x * ny + y] = float(binding["values"][x][y])
				param.values.append([node_id, TARGET_NAMES[binding["target"]], values, 0.0])
		_param_index[param.name] = _params.size()
		_params.append(param)
	for physics in _physics:
		_params[physics.param].driven = true


func _build_instances(source: Array, blob: PackedByteArray) -> void:
	for i in _nodes.size():
		var node := _nodes[i]
		var data: Dictionary = source[i]
		if node.type != "part":
			continue
		var raw_verts: Array = data["verts"]
		var count := raw_verts.size() / 2
		var verts := PackedVector3Array()
		verts.resize(count)
		for v in count:
			verts[v] = Vector3(raw_verts[v * 2], raw_verts[v * 2 + 1], 0.0)
		var raw_uvs: Array = data["uvs"]
		var uvs := PackedVector2Array()
		uvs.resize(count)
		for v in count:
			uvs[v] = Vector2(raw_uvs[v * 2], raw_uvs[v * 2 + 1])
		# Una forma (blend shape) por cada punto clave que deforma esta capa.
		var shapes: Array = []
		for offset in _shape_names[i]:
			var deltas := blob.slice(offset, offset + count * 8).to_float32_array()
			var shape := PackedVector3Array()
			shape.resize(count)
			for v in count:
				shape[v] = Vector3(deltas[v * 2], deltas[v * 2 + 1], 0.0)
			shapes.append(shape)
		var mesh := _make_mesh(verts, uvs, PackedInt32Array(data["indices"]), shapes)
		var masks: Array = data.get("masks", [])
		var reference := 0
		var dodge := false
		if not masks.is_empty():
			reference = _next_reference
			_next_reference += 1
			dodge = bool(masks[0]["dodge"])
		node.material = _make_material(node.blend, reference, dodge, _textures[int(data["tex"])])
		node.instance = _make_instance(mesh, node.material)
		node.instance.name = "part_%d" % i
		for mask in masks:
			var source_node := _nodes[int(mask["node"])]
			var source_data: Dictionary = source[int(mask["node"])]
			var writer_material := _make_material("Writer", reference, false, _textures[int(source_data["tex"])])
			writer_material.set_shader_parameter("threshold", float(source_data.get("mask_threshold", 0.5)))
			# La malla de la fuente todavía puede no existir: se crea después.
			var writer := _make_instance(null, writer_material)
			writer.set_meta("source", int(mask["node"]))
			node.mask_writers.append(writer)
			source_node.writers.append(writer)
	# Ahora sí: cada escritor comparte la malla de su capa fuente.
	for node in _nodes:
		for writer in node.writers:
			writer.mesh = node.instance.mesh
	_shape_names.clear()


func _make_mesh(verts: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, shapes: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var shape_arrays := []
	for s in shapes.size():
		mesh.add_blend_shape("s%d" % s)
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = shapes[s]
		shape_arrays.append(shape)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shape_arrays)
	return mesh


func _make_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 2.0
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(instance)
	return instance


func _make_material(blend: String, reference: int, dodge: bool, texture: Texture2D) -> ShaderMaterial:
	var key := "%s:%d:%s" % [blend, reference, dodge]
	if not _shaders.has(key):
		var stencil := ""
		if blend == "Writer":
			stencil = "stencil_mode write, compare_always, %d;" % reference
		elif reference > 0:
			stencil = "stencil_mode read, %s, %d;" % ["compare_not_equal" if dodge else "compare_equal", reference]
		var shader := Shader.new()
		match blend:
			"Writer":
				shader.code = SHADER_TEMPLATE % ["blend_mix", stencil, FRAGMENT_WRITER]
			"Multiply":
				shader.code = SHADER_TEMPLATE % ["blend_mul", stencil, FRAGMENT_MUL]
			_:
				shader.code = SHADER_TEMPLATE % ["blend_mix", stencil, FRAGMENT_MIX]
		_shaders[key] = shader
	var material := ShaderMaterial.new()
	material.shader = _shaders[key]
	material.set_shader_parameter("tex", texture)
	return material


func _measure_rest() -> void:
	_apply_params(true)
	_update_transforms()
	var bounds := Rect2()
	var first := true
	for node in _nodes:
		if node.type != "part" or node.instance == null:
			continue
		var aabb := node.instance.mesh.get_aabb()
		for corner in [aabb.position, aabb.position + Vector3(aabb.size.x, 0, 0), aabb.position + Vector3(0, aabb.size.y, 0), aabb.end]:
			var p: Vector3 = node.world * corner
			var point := Vector2(p.x, p.y)
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	rest_bounds = bounds
	pivot = Vector2(bounds.get_center().x, bounds.end.y)


# --- API ------------------------------------------------------------------------

## Escala la marioneta para que mida `meters` de alto (pivote en los pies).
func fit_height(meters: float) -> void:
	unit = meters / maxf(1.0, rest_bounds.size.y)


func has_param(param_name: String) -> bool:
	return _param_index.has(param_name)


func set_param(param_name: String, x: float, y := 0.0) -> void:
	var index: int = _param_index.get(param_name, -1)
	if index >= 0:
		var param := _params[index]
		param.value = Vector2(clampf(x, param.low.x, param.high.x), clampf(y, param.low.y, param.high.y))


func get_param(param_name: String) -> Vector2:
	var index: int = _param_index.get(param_name, -1)
	return _params[index].value if index >= 0 else Vector2.ZERO


func param_names() -> Array:
	return _param_index.keys()


func has_node_named(node_name: String) -> bool:
	return _node_index.has(node_name)


## Desplaza / gira / escala un nodo además de lo que digan los parámetros.
func set_node_offset(node_name: String, translation := Vector2.ZERO, rotation := 0.0, scale_by := Vector2.ONE) -> void:
	var index: int = _node_index.get(node_name, -1)
	if index >= 0:
		_nodes[index].user_t = translation
		_nodes[index].user_rz = rotation
		_nodes[index].user_s = scale_by


func set_node_opacity(node_name: String, value: float) -> void:
	var index: int = _node_index.get(node_name, -1)
	if index >= 0:
		_nodes[index].user_opacity = value


## Posición de un nodo en el mundo 3D (usa la última actualización).
func node_position(node_name: String, offset_px := Vector2.ZERO) -> Vector3:
	var index: int = _node_index.get(node_name, -1)
	if index < 0:
		return global_position
	var p: Vector3 = _nodes[index].world * Vector3(offset_px.x, offset_px.y, 0.0)
	return to_global(Vector3((p.x - pivot.x) * unit, -(p.y - pivot.y) * unit, 0.0))


## Añade una capa propia (rubor, lágrimas...) pegada a un nodo del modelo.
## position y size van en píxeles del modelo, relativos al nodo padre.
## z_offset negativo = por delante del padre. mask_node recorta la capa.
func add_overlay(overlay_name: String, parent_name: String, texture: Texture2D, position_px: Vector2, size_px: Vector2, z_offset := -0.01, mask_node := "", blend := "Normal") -> void:
	var parent_index: int = _node_index.get(parent_name, -1)
	if parent_index < 0 or _node_index.has(overlay_name):
		return
	var node := PNode.new()
	node.name = overlay_name
	node.type = "part"
	node.parent = parent_index
	node.composite = -1
	node.base_t = position_px
	node.base_z = z_offset
	node.blend = blend
	node.user_opacity = 0.0
	var half := size_px / 2.0
	var verts := PackedVector3Array([Vector3(-half.x, -half.y, 0), Vector3(half.x, -half.y, 0), Vector3(half.x, half.y, 0), Vector3(-half.x, half.y, 0)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var mesh := _make_mesh(verts, uvs, PackedInt32Array([0, 1, 2, 0, 2, 3]), [])
	var reference := 0
	var mask_index: int = _node_index.get(mask_node, -1)
	if mask_index >= 0:
		reference = _next_reference
		_next_reference += 1
	node.material = _make_material(blend, reference, false, texture)
	node.instance = _make_instance(mesh, node.material)
	if mask_index >= 0:
		var source_node := _nodes[mask_index]
		var writer_material := _make_material("Writer", reference, false, source_node.material.get_shader_parameter("tex"))
		var writer := _make_instance(source_node.instance.mesh, writer_material)
		node.mask_writers.append(writer)
		source_node.writers.append(writer)
		_copy_blend_shapes(source_node.instance, writer)
	_node_index[overlay_name] = _nodes.size()
	_nodes.append(node)
	_order_dirty = true


## Gira el tono (0..1) de las capas cuyos nombres empiezan por alguno de `prefixes`.
func set_hue(prefixes: Array, amount: float) -> void:
	for node in _nodes:
		if node.material == null or node.blend != "Normal":
			continue
		var shift := 0.0
		for prefix in prefixes:
			if node.name.begins_with(prefix):
				shift = amount
				break
		node.material.set_shader_parameter("hue_shift", shift)


## Color que multiplica a todo el modelo (p. ej. más oscuro de noche).
func set_tint(color: Color) -> void:
	if color == _tint:
		return
	_tint = color
	for node in _nodes:
		if node.material and node.blend == "Normal":
			node.material.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))


## Avanza un frame: parámetros -> transformaciones -> capas -> físicas.
func update(delta: float) -> void:
	_apply_params(false)
	_update_transforms()
	_update_instances()
	if physics_enabled:
		_update_physics(delta)


## Deja las físicas quietas en su sitio (tras teletransportar el modelo).
func reset_physics() -> void:
	for physics in _physics:
		physics.started = false


# --- Parámetros -----------------------------------------------------------------

func _apply_params(force: bool) -> void:
	for node in _nodes:
		node.off_t = Vector2.ZERO
		node.off_r = Vector3.ZERO
		node.off_s = Vector2.ONE
		node.off_z = 0.0
		node.off_opacity = 1.0
	for param in _params:
		if force or param.value != param.applied:
			_evaluate(param)
			param.applied = param.value
		for binding in param.values:
			var node := _nodes[binding[0]]
			var value: float = binding[3]
			match binding[1]:
				Target.TX: node.off_t.x += value
				Target.TY: node.off_t.y += value
				Target.RX: node.off_r.x += value
				Target.RY: node.off_r.y += value
				Target.RZ: node.off_r.z += value
				Target.SX: node.off_s.x *= value
				Target.SY: node.off_s.y *= value
				Target.Z: node.off_z += value
				Target.OPACITY: node.off_opacity *= value


## Interpola el parámetro en su rejilla de puntos clave (bilineal).
func _evaluate(param: PParam) -> void:
	var span := param.high - param.low
	var nx := 0.0 if span.x == 0.0 else (param.value.x - param.low.x) / span.x
	var ny := 0.0 if span.y == 0.0 else (param.value.y - param.low.y) / span.y
	var cell_x := _find_cell(param.axis_x, nx)
	var cell_y := _find_cell(param.axis_y, ny)
	var x0 := int(cell_x.x)
	var y0 := int(cell_y.x)
	var x1 := mini(x0 + 1, param.axis_x.size() - 1)
	var y1 := mini(y0 + 1, param.axis_y.size() - 1)
	var tx: float = cell_x.y
	var ty: float = cell_y.y
	var rows := param.axis_y.size()
	var corners := [x0 * rows + y0, x1 * rows + y0, x0 * rows + y1, x1 * rows + y1]
	var weights := [(1.0 - tx) * (1.0 - ty), tx * (1.0 - ty), (1.0 - tx) * ty, tx * ty]
	for binding in param.values:
		var values: PackedFloat32Array = binding[2]
		binding[3] = values[corners[0]] * weights[0] + values[corners[1]] * weights[1] + values[corners[2]] * weights[2] + values[corners[3]] * weights[3]
	for binding in param.deforms:
		var node := _nodes[binding[0]]
		var shapes: PackedInt32Array = binding[1]
		var active: PackedInt32Array = binding[2]
		for shape in active:
			_set_shape(node, shape, 0.0)
		active.clear()
		var totals := {}
		for c in 4:
			var shape := shapes[corners[c]]
			if shape >= 0 and weights[c] > 0.0:
				totals[shape] = totals.get(shape, 0.0) + weights[c]
		for shape in totals:
			_set_shape(node, shape, totals[shape])
			active.append(shape)
		binding[2] = active


func _set_shape(node: PNode, shape: int, weight: float) -> void:
	node.instance.set_blend_shape_value(shape, weight)
	for writer in node.writers:
		writer.set_blend_shape_value(shape, weight)


func _copy_blend_shapes(from: MeshInstance3D, to: MeshInstance3D) -> void:
	for shape in from.get_blend_shape_count():
		to.set_blend_shape_value(shape, from.get_blend_shape_value(shape))


## Devuelve (índice del punto clave izquierdo, fracción hasta el siguiente).
static func _find_cell(axis: PackedFloat32Array, value: float) -> Vector2:
	var last := axis.size() - 1
	if last <= 0 or value <= axis[0]:
		return Vector2(0, 0)
	if value >= axis[last]:
		return Vector2(last, 0)
	for i in last:
		if value < axis[i + 1]:
			return Vector2(i, (value - axis[i]) / (axis[i + 1] - axis[i]))
	return Vector2(last, 0)


# --- Transformaciones y dibujo --------------------------------------------------

func _update_transforms() -> void:
	# Los nodos están en orden padre -> hijos, así que basta un recorrido.
	var z_sum := 0.0
	for node in _nodes:
		var rotation := node.base_r + node.off_r
		rotation.z += node.user_rz
		var basis := Basis.from_euler(rotation, EULER_ORDER_ZYX) if rotation != Vector3.ZERO else Basis.IDENTITY
		var scale_by := node.base_s * node.off_s * node.user_s
		if scale_by != Vector2.ONE:
			basis = basis.scaled_local(Vector3(scale_by.x, scale_by.y, 1.0))
		var translation := node.base_t + node.off_t + node.user_t
		var local := Transform3D(basis, Vector3(translation.x, translation.y, 0.0))
		if node.parent >= 0:
			var parent := _nodes[node.parent]
			node.world = parent.world * local
			node.z = parent.z + node.base_z + node.off_z
		else:
			node.world = local
			node.z = node.base_z + node.off_z
		z_sum += node.z
	if not is_equal_approx(z_sum, _last_z_sum):
		_last_z_sum = z_sum
		_order_dirty = true


func _update_instances() -> void:
	if _order_dirty:
		_sort_layers()
	var u := unit
	for node in _nodes:
		if node.instance == null:
			continue
		var w := node.world
		var flat := Transform3D(
			Basis(Vector3(w.basis.x.x, -w.basis.x.y, 0.0) * u, Vector3(w.basis.y.x, -w.basis.y.y, 0.0) * u, Vector3(0, 0, 1)),
			Vector3((w.origin.x - pivot.x) * u, -(w.origin.y - pivot.y) * u, 0.0))
		node.instance.transform = flat
		for writer in node.writers:
			writer.transform = flat
		var alpha := node.base_opacity * node.off_opacity * node.user_opacity
		if alpha != node.last_opacity:
			node.last_opacity = alpha
			node.material.set_shader_parameter("opacity", alpha)
			var shown := alpha > 0.003 and node.enabled
			node.instance.visible = shown
			for writer in node.mask_writers:
				writer.visible = shown


## Orden de dibujo: mayor z = más al fondo. Los hijos de un composite se
## ordenan entre sí y ocupan el lugar del composite.
func _sort_layers() -> void:
	_order_dirty = false
	var entries := []
	for i in _nodes.size():
		var node := _nodes[i]
		if node.instance == null:
			continue
		var top := node.z if node.composite < 0 else _nodes[node.composite].z
		entries.append([top, node.z, i])
	entries.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[2] < b[2])
	for rank in entries.size():
		var node := _nodes[entries[rank][2]]
		var offset := (rank + 1) * SORT_STEP
		node.instance.sorting_offset = offset
		for writer in node.mask_writers:
			writer.sorting_offset = offset - SORT_STEP * 0.5


# --- Físicas ---------------------------------------------------------------------

func _update_physics(delta: float) -> void:
	# El movimiento del nodo entero por el mundo también agita el pelo.
	var origin := global_position
	var world_shift := Vector2.ZERO
	if _last_origin.x != INF:
		world_shift = Vector2(origin.x - _last_origin.x, -(origin.y - _last_origin.y)) / unit
	_last_origin = origin
	if world_shift.length() > 600.0:
		world_shift = Vector2.ZERO
	var step_total := clampf(delta, 0.0, 0.05)
	var steps := maxi(1, int(ceil(step_total / 0.006)))
	var h := step_total / steps
	var g_base := _gravity * _pixels_per_meter
	for physics in _physics:
		var node := _nodes[physics.node]
		var anchor := Vector2(node.world.origin.x, node.world.origin.y)
		if not physics.started:
			physics.started = true
			physics.bob = anchor + Vector2(0, physics.length)
			physics.velocity = Vector2.ZERO
		# Si el mundo se movió, el péndulo "se queda atrás".
		physics.bob -= world_shift
		var g := physics.gravity * g_base
		for s in steps:
			if physics.spring:
				_step_spring(physics, anchor, g, h)
			else:
				_step_pendulum(physics, anchor, g, h)
		var local3: Vector3 = node.world.affine_inverse() * Vector3(physics.bob.x, physics.bob.y, 0.0)
		var out := Vector2(local3.x, local3.y) / physics.length - Vector2(0, 1)
		out.y = -out.y
		var param := _params[physics.param]
		param.value = Vector2(
			clampf(out.x * physics.output_scale.x, param.low.x, param.high.x),
			clampf(out.y * physics.output_scale.y, param.low.y, param.high.y))


func _step_spring(physics: PPhysics, anchor: Vector2, g: float, h: float) -> void:
	var spring_sqrt := physics.frequency * TAU
	var spring_k := spring_sqrt * spring_sqrt
	var rest_length := physics.length - g / spring_k
	var offset := physics.bob - anchor
	var distance := offset.length()
	if distance < 0.001 or distance > physics.length * 6.0:
		physics.bob = anchor + Vector2(0, physics.length)
		physics.velocity = Vector2.ZERO
		return
	var direction := offset / distance
	var crit_angle := 2.0 * sqrt(g / physics.length)
	var crit_length := 2.0 * spring_sqrt
	var force := Vector2(0, g) - direction * (distance - rest_length) * spring_k
	var v := physics.velocity
	var rotated := Vector2(v.x * direction.y + v.y * direction.x, v.y * direction.y - v.x * direction.x)
	var damp_x := -rotated.x * physics.angle_damping * crit_angle
	var damp_y := -rotated.y * physics.length_damping * crit_length
	force += Vector2(damp_x * direction.y - damp_y * direction.x, damp_y * direction.y + damp_x * direction.x)
	physics.velocity += force * h
	physics.bob += physics.velocity * h


func _step_pendulum(physics: PPhysics, anchor: Vector2, g: float, h: float) -> void:
	var offset := physics.bob - anchor
	var angle := atan2(-offset.x, offset.y)
	var ratio := g / physics.length
	var acceleration := -ratio * sin(angle) - physics.velocity.x * physics.angle_damping * 2.0 * sqrt(ratio)
	physics.velocity.x += acceleration * h
	angle += physics.velocity.x * h
	physics.bob = anchor + Vector2(-sin(angle), cos(angle)) * physics.length
