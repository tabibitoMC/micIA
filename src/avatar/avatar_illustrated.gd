class_name AvatarIllustrated
extends Avatar
## Avatar hecho con UNA ilustración de cuerpo entero (sin capas separadas).
##
## Se anima como los "warp deformers" de Live2D: la imagen va sobre una malla
## y un shader mueve sus vértices por zonas (cabeza alrededor del cuello,
## moño con inercia, respiración en el pecho, falda y estola que se mecen).
## La cara se completa dibujando encima, siguiendo la cabeza: párpados
## (parpadeo, ojos felices, enojo, guiño), boca que se abre al hablar (con
## colmillos), rubor y lágrimas.
##
## Todo lo que depende del dibujo (dónde están los ojos, el cuello...) va en
## el "rig" del personaje (ver Characters.DATA["mireya"]).

## Encuadre igual al de la marioneta: la parte de arriba de la cabeza queda
## al 7.7 % de la altura y los pies un poco por debajo del borde.
const TOP_RATIO := 0.077
const FEET_RATIO := 1.11
const GRID := Vector2i(32, 80)

## Emoción -> cara y postura.
##   lid: cuánto bajan los párpados (0 abiertos, 1 cerrados)
##   slope: inclinación del párpado (+ = lado de la nariz más bajo: enojo;
##          - = lado de afuera más bajo: tristeza)
##   arc: ojos cerrados curvos (1 = felices "^ ^")
##   wink: guiña un ojo · mouth: boca abierta · blush: rubor
##   head: [giro, cabeceo] · roll: inclinación · lean: inclina el cuerpo
const EMOTIONS := {
	"neutral": {"lid": 0.08, "slope": 0.0, "arc": 0.0, "mouth": 0.0, "blush": 0.0, "head": [0.0, 0.0], "roll": 0.0, "lean": 0.0},
	"feliz": {"lid": 1.0, "slope": 0.0, "arc": 1.0, "mouth": 0.28, "blush": 0.3, "head": [0.0, 0.25], "roll": 0.06, "lean": 0.01},
	"triste": {"lid": 0.42, "slope": -0.35, "arc": 0.0, "mouth": 0.0, "blush": 0.0, "head": [0.1, -0.7], "roll": -0.05, "lean": -0.01},
	"enojada": {"lid": 0.4, "slope": 0.45, "arc": 0.0, "mouth": 0.12, "blush": 0.0, "head": [0.0, -0.35], "roll": 0.0, "lean": -0.015},
	"sorprendida": {"lid": 0.0, "slope": 0.0, "arc": 0.0, "mouth": 0.5, "blush": 0.0, "head": [0.0, 0.45], "roll": 0.0, "lean": -0.02},
	"avergonzada": {"lid": 0.38, "slope": -0.15, "arc": 0.0, "mouth": 0.0, "blush": 1.0, "head": [0.55, -0.55], "roll": 0.07, "lean": 0.0},
	"pensativa": {"lid": 0.3, "slope": 0.0, "arc": 0.0, "mouth": 0.0, "blush": 0.0, "head": [-0.6, 0.45], "roll": -0.06, "lean": 0.0},
	"coqueta": {"lid": 0.3, "slope": 0.1, "arc": 0.0, "wink": 1.0, "mouth": 0.08, "blush": 0.55, "head": [0.35, -0.15], "roll": 0.08, "lean": 0.012},
}

const SHADER := """
shader_type canvas_item;
uniform vec2 neck;
uniform vec2 face_center;
uniform float face_radius = 170.0;
uniform float hair_line = 650.0;
uniform float top_y = 27.0;
uniform float center_x = 608.0;
uniform float feet_y = 3024.0;
uniform float head_rot = 0.0;
uniform vec2 face_shift = vec2(0.0);
uniform float lag_rot = 0.0;
uniform float breath = 0.0;
uniform float skirt = 0.0;
uniform float fur = 0.0;
uniform vec4 fur_box = vec4(760.0, 1150.0, 1150.0, 2550.0);
uniform float skirt_top = 1700.0;
uniform float chest_top = 870.0;
uniform float chest_bottom = 1400.0;

vec2 rot(vec2 v, float a) {
	float c = cos(a); float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void vertex() {
	vec2 v = VERTEX;
	vec2 p = v;
	// Cabeza: todo lo que está sobre el cuello (con transición suave).
	float w_head = 1.0 - smoothstep(neck.y - 10.0, neck.y + 45.0, v.y);
	// Volumen falso: la cara se corre hacia donde gira y el pelo de atrás al revés.
	float w_face = 1.0 - smoothstep(face_radius * 0.55, face_radius, distance(v, face_center));
	p += face_shift * w_face * w_head;
	p -= face_shift * 0.35 * (1.0 - w_face) * w_head;
	// El moño va con retraso (inercia) respecto a la cabeza.
	float w_lag = 1.0 - smoothstep(top_y, hair_line, v.y);
	p = neck + rot(p - neck, head_rot * w_head + lag_rot * w_lag * w_head);
	// Respiración: el pecho y los hombros suben un poco.
	float w_chest = smoothstep(neck.y + 10.0, chest_top + 60.0, v.y) * (1.0 - smoothstep(chest_top + 300.0, chest_bottom, v.y));
	p.y -= breath * 7.0 * w_chest;
	p.x = mix(p.x, center_x + (p.x - center_x) * (1.0 + breath * 0.01), w_chest);
	// Falda: se mece más cuanto más abajo.
	float w_skirt = smoothstep(skirt_top, feet_y, v.y);
	p.x += skirt * w_skirt * w_skirt * 45.0;
	// Estola de piel.
	float w_fur = smoothstep(fur_box.x, fur_box.x + 100.0, v.x) * smoothstep(fur_box.y, fur_box.y + 250.0, v.y) * (1.0 - smoothstep(fur_box.w - 200.0, fur_box.w, v.y));
	p.x += fur * w_fur * clamp((v.y - fur_box.y) / (fur_box.w - fur_box.y), 0.0, 1.0) * 34.0;
	VERTEX = p;
}
"""

## Datos del personaje (los pone main.gd antes de añadirlo a la escena).
var character: Dictionary = {}
## Fondo de la casa (lo pone main.gd).
var room: RoomBackground

var _rig: Dictionary = {}
var _image: Image
var _texture: ImageTexture
var _material: ShaderMaterial
var _body: Node2D
var _local: Node2D
var _mesh: MeshInstance2D
var _face: Node2D
var _foreground: Control
var _ready_ok := false

var _goal: Dictionary = EMOTIONS["neutral"]
var _lid := 0.08
var _slope := 0.0
var _arc := 0.0
var _wink := 0.0
var _mouth_emotion := 0.0
var _blush := 0.0
var _head := Vector2.ZERO
var _roll := 0.0
var _lean := 0.0

var _time := 0.0
var _talking := false
var _talk_time := 0.0
var _voice_level := -1.0
var _voice_level_time := 0.0
var _mouth := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _sleeping := false
var _in_bed := false
var _night := false
var _turned_away := false
var _action_tween: Tween
var _idle_tween: Tween
var _idle_timer := 2.5

## Posición horizontal (fracción del ancho) y la de "casa".
var _x := 0.5
var _home := 0.5
var _walk := 0.0

# Gestos (los animan los tweens de play_action).
var act_head := Vector2.ZERO
var act_roll := 0.0
var act_lean := 0.0
var act_jump := 0.0
var act_zoom := 0.0
var act_shake := 0.0
var act_tears := 0.0
var act_lid := 0.0
var idle_head := Vector2.ZERO
var idle_roll := 0.0

# Inercias (resortes) del moño, la falda y la estola.
var _lag := 0.0
var _lag_speed := 0.0
var _skirt := 0.0
var _skirt_speed := 0.0
var _last_head_rot := 0.0
var _last_x := 0.5
var _last_lean := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rig = character.get("rig", {})
	var path := str(character.get("illustration", ""))
	var bytes := FileAccess.get_file_as_bytes(path)
	_image = Image.new()
	if bytes.is_empty() or _image.load_webp_from_buffer(bytes) != OK:
		push_warning("AvatarIllustrated: no se pudo cargar " + path)
		return
	_image.generate_mipmaps()
	_texture = ImageTexture.create_from_image(_image)
	_build()
	resized.connect(_layout)
	_ready_ok = true
	_layout()


func is_ready() -> bool:
	return _ready_ok


func _v(key: String, fallback: Variant) -> Variant:
	return _rig.get(key, fallback)


func _build() -> void:
	var w := float(_image.get_width())
	var h := float(_image.get_height())
	_body = Node2D.new()
	add_child(_body)
	_local = Node2D.new()
	_body.add_child(_local)

	# Malla en píxeles de la imagen.
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in GRID.y + 1:
		for i in GRID.x + 1:
			var uv := Vector2(float(i) / GRID.x, float(j) / GRID.y)
			uvs.append(uv)
			vertices.append(uv * Vector2(w, h))
	for j in GRID.y:
		for i in GRID.x:
			var a := j * (GRID.x + 1) + i
			indices.append_array([a, a + 1, a + GRID.x + 1, a + 1, a + GRID.x + 2, a + GRID.x + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("neck", _v("neck", Vector2(w * 0.5, h * 0.28)))
	_material.set_shader_parameter("face_center", _v("face", Vector2(w * 0.5, h * 0.24)))
	_material.set_shader_parameter("face_radius", float(_v("face_radius", 170.0)))
	_material.set_shader_parameter("hair_line", float(_v("hair_line", h * 0.21)))
	_material.set_shader_parameter("top_y", float(_v("top", 0.0)))
	_material.set_shader_parameter("feet_y", float(_v("feet", h)))
	_material.set_shader_parameter("center_x", float(_v("neck", Vector2(w * 0.5, 0)).x))
	_material.set_shader_parameter("fur_box", _v("fur_box", Vector4(w, h, w, h)))
	_material.set_shader_parameter("skirt_top", float(_v("skirt_top", h * 0.56)))
	_material.set_shader_parameter("chest_top", float(_v("chest_top", h * 0.29)))
	_material.set_shader_parameter("chest_bottom", float(_v("chest_bottom", h * 0.46)))

	_mesh = MeshInstance2D.new()
	_mesh.mesh = mesh
	_mesh.texture = _texture
	_mesh.material = _material
	_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_local.add_child(_mesh)

	_face = Node2D.new()
	_face.draw.connect(_draw_face)
	_local.add_child(_face)

	_foreground = Control.new()
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foreground.draw.connect(_draw_foreground)
	add_child(_foreground)


## Escala: la altura de la cabeza a los pies ocupa lo mismo que Aka.
func _scale() -> float:
	var top := float(_v("top", 0.0))
	var feet := float(_v("feet", _image.get_height()))
	return size.y * (_feet_ratio() - TOP_RATIO) / maxf(1.0, feet - top)


## Imagen cortada a medio cuerpo: su borde de abajo va al borde de la pantalla.
func _feet_ratio() -> float:
	return 1.0 if _v("cut", false) else FEET_RATIO


func _layout() -> void:
	if not _ready_ok:
		return
	if not _in_bed:
		_place_standing()


func _place_standing() -> void:
	var feet := Vector2(float(_v("neck", Vector2.ZERO).x), float(_v("feet", _image.get_height())))
	var s := _scale() * (1.0 + act_zoom)
	_local.position = -feet
	_body.position = Vector2(_x * size.x + act_shake * size.x * 0.02, size.y * _feet_ratio() - act_jump * size.y)
	_body.rotation = _lean + act_lean * 0.08
	_body.scale = Vector2(s, s)


# --- Interfaz de Avatar -------------------------------------------------------------

func set_emotion(emotion: String) -> void:
	_goal = EMOTIONS.get(emotion, EMOTIONS["neutral"])


func set_talking(talking: bool) -> void:
	_talking = talking
	if not talking:
		_voice_level = -1.0


func set_mouth_level(level: float) -> void:
	_voice_level = clampf(level, 0.0, 1.0)
	_voice_level_time = _time


func apply_tint(_cloth: Color, _hair: Color) -> void:
	pass


func play_action(action: String) -> void:
	if not _ready_ok or _in_bed:
		return
	if _action_tween:
		_action_tween.kill()
	_reset_actions()
	var t := create_tween()
	_action_tween = t
	match action:
		"saludar":
			t.tween_property(self, "act_roll", 0.16, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "act_lean", 0.25, 0.3)
			t.parallel().tween_property(self, "act_jump", 0.015, 0.3)
			for i in 2:
				t.tween_property(self, "act_roll", 0.24, 0.18).set_trans(Tween.TRANS_SINE)
				t.tween_property(self, "act_roll", 0.08, 0.18).set_trans(Tween.TRANS_SINE)
			t.tween_property(self, "act_roll", 0.0, 0.4)
			t.parallel().tween_property(self, "act_lean", 0.0, 0.4)
			t.parallel().tween_property(self, "act_jump", 0.0, 0.4)
		"asentir":
			for i in 2:
				t.tween_property(self, "act_head:y", -0.9, 0.16)
				t.tween_property(self, "act_head:y", 0.2, 0.16)
			t.tween_property(self, "act_head:y", 0.0, 0.12)
		"negar":
			for i in 2:
				t.tween_property(self, "act_head:x", 0.8, 0.15)
				t.tween_property(self, "act_head:x", -0.8, 0.15)
			t.tween_property(self, "act_head:x", 0.0, 0.12)
		"saltar", "celebrar":
			var times := 2 if action == "celebrar" else 1
			for i in times:
				t.tween_property(self, "act_jump", 0.06, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t.parallel().tween_property(self, "act_lid", -0.2, 0.2)
				t.tween_property(self, "act_jump", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(self, "act_lid", 0.0, 0.2)
		"cruzar_brazos":
			# Se echa hacia atrás, barbilla arriba y mirada de reojo.
			t.tween_property(self, "act_lean", -0.3, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "act_head", Vector2(-0.6, 0.35), 0.35)
			t.parallel().tween_property(self, "act_lid", 0.25, 0.35)
			t.tween_interval(1.6)
			t.tween_property(self, "act_lean", 0.0, 0.5)
			t.parallel().tween_property(self, "act_head", Vector2.ZERO, 0.5)
			t.parallel().tween_property(self, "act_lid", 0.0, 0.5)
		"abrazar":
			# Se acerca a la pantalla.
			t.tween_property(self, "act_zoom", 0.12, 0.4).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_lean", 0.2, 0.4)
			t.parallel().tween_property(self, "act_lid", 0.5, 0.4)
			t.parallel().tween_property(self, "act_roll", 0.1, 0.4)
			t.tween_interval(1.2)
			t.tween_property(self, "act_zoom", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_lean", 0.0, 0.5)
			t.parallel().tween_property(self, "act_lid", 0.0, 0.5)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.5)
		"golpear":
			t.tween_property(self, "act_lean", -0.35, 0.18)
			t.parallel().tween_property(self, "act_head:x", 0.5, 0.18)
			t.tween_property(self, "act_lean", 0.6, 0.09).set_trans(Tween.TRANS_EXPO)
			t.parallel().tween_property(self, "act_zoom", 0.08, 0.09)
			t.parallel().tween_property(self, "act_head:x", -0.8, 0.09)
			t.tween_callback(func(): struck.emit())
			t.tween_property(self, "act_lean", 0.0, 0.4)
			t.parallel().tween_property(self, "act_zoom", 0.0, 0.4)
			t.parallel().tween_property(self, "act_head:x", 0.0, 0.4)
		"llorar":
			t.tween_property(self, "act_tears", 1.0, 0.5)
			t.parallel().tween_property(self, "act_head:y", -0.6, 0.5)
			t.tween_interval(3.0)
			t.tween_property(self, "act_tears", 0.0, 1.0)
			t.parallel().tween_property(self, "act_head:y", 0.0, 1.0)
		"mirar_otro_lado":
			t.tween_property(self, "act_head", Vector2(-0.9, 0.2), 0.3)
			t.parallel().tween_property(self, "act_roll", -0.08, 0.3)
			t.tween_interval(1.4)
			t.tween_property(self, "act_head", Vector2.ZERO, 0.4)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.4)
		_:
			t.tween_interval(0.01)


func _reset_actions() -> void:
	act_head = Vector2.ZERO
	act_roll = 0.0
	act_lean = 0.0
	act_jump = 0.0
	act_zoom = 0.0
	act_shake = 0.0
	act_lid = 0.0


func walk_to_screen_x(x: float) -> void:
	if _ready_ok and not _in_bed:
		await _walk_to((x - global_position.x) / maxf(1.0, size.x))


func go_home() -> void:
	if _ready_ok and not _in_bed:
		await _walk_to(_home)


func point_at_screen(point: Vector2, seconds := 1.0) -> void:
	if not _ready_ok or _in_bed:
		return
	var right_side := point.x > global_position.x + _x * size.x
	var t := create_tween()
	t.tween_property(self, "act_head", Vector2(0.9 if right_side else -0.9, 0.3), 0.3)
	t.parallel().tween_property(self, "act_lean", 0.45 if right_side else -0.45, 0.3)
	t.tween_interval(seconds)
	t.tween_property(self, "act_head", Vector2.ZERO, 0.3)
	t.parallel().tween_property(self, "act_lean", 0.0, 0.3)
	await t.finished


func set_turned_away(away: bool) -> void:
	_turned_away = away


func fade(to_black: bool, seconds := 0.35) -> void:
	var targets: Array = [self]
	if room:
		targets.append(room)
	var tween := create_tween().set_parallel()
	for target in targets:
		tween.tween_property(target, "modulate", Color(0.05, 0.02, 0.05) if to_black else Color.WHITE, seconds)
	await tween.finished


func place_at_side(from_left: bool) -> void:
	_x = -0.3 if from_left else 1.3


func walk_out(to_right: bool) -> void:
	if _ready_ok and not _in_bed:
		await _walk_to(1.4 if to_right else -0.4)


func is_head_at(point: Vector2) -> bool:
	if not _ready_ok:
		return false
	var face := _face_to_screen(_v("face", Vector2.ZERO))
	return point.distance_to(face) < size.y * (0.12 if _in_bed else 0.09)


## Toque sobre ella: se mira el píxel de la ilustración (no un rectángulo).
func is_body_at(point: Vector2) -> bool:
	if not _ready_ok:
		return false
	var local := (_local.get_global_transform()).affine_inverse() * point
	var x := int(local.x)
	var y := int(local.y)
	for d in [Vector2i.ZERO, Vector2i(20, 0), Vector2i(-20, 0), Vector2i(0, 20), Vector2i(0, -20)]:
		var px: int = x + d.x
		var py: int = y + d.y
		if px >= 0 and py >= 0 and px < _image.get_width() and py < _image.get_height():
			if _image.get_pixel(px, py).a > 0.3:
				return true
	return false


func _walk_to(target: float) -> void:
	var distance := target - _x
	if absf(distance) < 0.005:
		return
	var start := create_tween()
	start.tween_property(self, "_walk", signf(distance), 0.2)
	await start.finished
	var move := create_tween()
	move.tween_property(self, "_x", target, absf(distance) * size.x / maxf(1.0, size.y) / 0.32)
	await move.finished
	var stop := create_tween()
	stop.tween_property(self, "_walk", 0.0, 0.25)
	await stop.finished


# --- Lugares y dormir -------------------------------------------------------------

func set_room(env_id: String, time_theme: String) -> void:
	if room:
		room.set_place(env_id)
		room.set_room_theme(time_theme)
	set_time_of_day(time_theme)


func set_time_of_day(time_theme: String) -> void:
	_night = time_theme == "noche"


func current_room() -> String:
	return room.place if room else ""


func window_screen_position() -> Variant:
	if room == null or room.place == "patio":
		return null
	return room.window_global_center()


func set_sleeping(sleeping: bool) -> void:
	if sleeping == _sleeping or not _ready_ok:
		return
	_sleeping = sleeping
	_in_bed = sleeping and room != null and room.place == "dormitorio"
	if _action_tween:
		_action_tween.kill()
	_reset_actions()
	if room:
		room.set_sleep_view(_in_bed)
	if not _in_bed:
		_x = _home
		_place_standing()
	_foreground.queue_redraw()


func is_sleeping() -> bool:
	return _sleeping


## Acostada en la cama: los pies bajo la cobija y la cara en la almohada.
func _lie_in_bed() -> void:
	var spot := room.sleep_spot()
	var head: Vector2 = spot["head"]
	var length_px: float = spot["length"]
	var feet_screen: Vector2 = spot.get("feet", Vector2(head.x - length_px * 0.8, head.y))
	var feet := Vector2(float(_v("neck", Vector2.ZERO).x), float(_v("feet", _image.get_height())))
	var face: Vector2 = _v("face", Vector2.ZERO)
	var along := head - feet_screen
	_local.position = -feet
	_body.position = feet_screen
	_body.rotation = atan2(along.y, along.x) + PI / 2.0
	var s := along.length() / maxf(1.0, feet.y - face.y)
	_body.scale = Vector2(s, s)


# --- Animación -------------------------------------------------------------

func _process(delta: float) -> void:
	if not _ready_ok:
		return
	_time += delta
	var goal := _goal
	var k := 1.0 - exp(-delta * 8.0)
	var lid_goal: float = goal["lid"]
	var head_goal := Vector2(goal["head"][0], goal["head"][1])
	var roll_goal: float = goal["roll"]
	var arc_goal: float = goal["arc"]
	var wink_goal: float = goal.get("wink", 0.0)
	if _sleeping:
		lid_goal = 1.0
		arc_goal = 0.0
		wink_goal = 0.0
		head_goal = Vector2(0.2, -0.3) if _in_bed else Vector2(0.25, -0.9)
		roll_goal = 0.05
	if _turned_away and not _sleeping:
		head_goal = Vector2(-1.0, -0.2)
		lid_goal = maxf(lid_goal, 0.35)
	_lid = lerpf(_lid, clampf(lid_goal + act_lid, 0.0, 1.0), k)
	_slope = lerpf(_slope, goal["slope"], k)
	_arc = lerpf(_arc, arc_goal, k)
	_wink = lerpf(_wink, wink_goal, k)
	_mouth_emotion = lerpf(_mouth_emotion, goal["mouth"], k)
	_blush = lerpf(_blush, goal["blush"], k * 0.5)
	_head = _head.lerp(head_goal, k)
	_roll = lerpf(_roll, roll_goal, k)
	_lean = lerpf(_lean, goal["lean"], k)

	# Parpadeo.
	_blink_timer -= delta
	if _blink_timer <= 0.0 and not _sleeping:
		_blink_timer = randf_range(2.2, 5.5)
		var blink := create_tween()
		blink.tween_property(self, "_blink", 1.0, 0.07)
		blink.tween_property(self, "_blink", 0.0, 0.11)

	# Boca: con la voz real si llega; si no, simulada.
	var mouth_goal := _mouth_emotion
	if _talking and not _sleeping:
		_talk_time += delta
		if _voice_level >= 0.0 and _time - _voice_level_time < 0.3:
			mouth_goal = maxf(mouth_goal, _voice_level)
		else:
			mouth_goal = maxf(mouth_goal, absf(sin(_talk_time * 11.0)) * 0.7 * (0.6 + 0.4 * sin(_talk_time * 3.1)))
	_mouth = lerpf(_mouth, mouth_goal, 1.0 - exp(-delta * 18.0))

	_update_idle(delta)

	# Postura total de la cabeza.
	var head := _head + act_head + idle_head
	var roll := _roll + act_roll + idle_roll
	if _talking and not _sleeping:
		head.y += sin(_talk_time * 4.3) * 0.12
		roll += sin(_talk_time * 2.1) * 0.015
	if _walk != 0.0:
		roll += sin(_time * 8.0) * 0.02
	var head_rot := roll * 0.9 + head.x * 0.03
	var face_shift := Vector2(head.x * 16.0, -head.y * 10.0)

	# Inercia del moño: se queda atrás cuando la cabeza gira o el cuerpo se mueve.
	var head_speed := (head_rot - _last_head_rot) / maxf(delta, 0.001)
	_last_head_rot = head_rot
	var move_speed := (_x - _last_x) / maxf(delta, 0.001)
	_last_x = _x
	var lean_now := _lean + act_lean * 0.08
	var lean_speed := (lean_now - _last_lean) / maxf(delta, 0.001)
	_last_lean = lean_now
	_lag_speed += (-_lag * 90.0 - _lag_speed * 7.0 - head_speed * 0.9 - lean_speed * 0.6 - move_speed * 0.4) * delta
	_lag = clampf(_lag + _lag_speed * delta, -0.12, 0.12)
	_skirt_speed += (-_skirt * 40.0 - _skirt_speed * 3.5 - move_speed * 4.0 - lean_speed * 3.0) * delta
	_skirt = clampf(_skirt + _skirt_speed * delta, -1.0, 1.0)
	var idle_sway := sin(_time * 1.3) * 0.08 + sin(_time * 0.7) * 0.05

	var breath := (sin(_time * 1.6) * 0.5 + 0.5) * (0.6 if _sleeping else 1.0)
	_material.set_shader_parameter("head_rot", head_rot)
	_material.set_shader_parameter("face_shift", face_shift)
	_material.set_shader_parameter("lag_rot", _lag)
	_material.set_shader_parameter("breath", breath)
	_material.set_shader_parameter("skirt", _skirt + idle_sway)
	_material.set_shader_parameter("fur", _skirt * 0.8 + sin(_time * 1.1 + 1.0) * 0.12)
	_face_rot = head_rot
	_face_shift = face_shift

	if _in_bed and room:
		_lie_in_bed()
	else:
		_place_standing()
		if _walk != 0.0:
			_body.position.y -= absf(sin(_time * 7.0)) * size.y * 0.006
			_body.rotation += _walk * 0.03
		# Balanceo suave de cadera al estar de pie.
		_body.rotation += sin(_time * 0.9) * 0.006
	_face.queue_redraw()
	if _sleeping:
		_foreground.queue_redraw()


var _face_rot := 0.0
var _face_shift := Vector2.ZERO


## Pequeños movimientos propios mientras está quieta.
func _update_idle(delta: float) -> void:
	if _sleeping:
		return
	_idle_timer -= delta
	if _idle_timer > 0.0:
		return
	_idle_timer = randf_range(2.5, 6.0) if not _talking else randf_range(1.2, 2.5)
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween()
	var target := Vector2(randf_range(-0.35, 0.35), randf_range(-0.2, 0.25))
	_idle_tween.tween_property(self, "idle_head", target, randf_range(0.6, 1.2)).set_trans(Tween.TRANS_SINE)
	_idle_tween.parallel().tween_property(self, "idle_roll", randf_range(-0.035, 0.035), 1.0).set_trans(Tween.TRANS_SINE)


## Lleva un punto de la cara (píxeles de la imagen) a como se ve tras mover la cabeza.
func _face_point(p: Vector2) -> Vector2:
	var neck: Vector2 = _v("neck", Vector2.ZERO)
	return neck + (p + _face_shift - neck).rotated(_face_rot)


func _face_to_screen(p: Vector2) -> Vector2:
	return _local.get_global_transform() * _face_point(p)


# --- Cara dibujada encima -------------------------------------------------------------

func _draw_face() -> void:
	var neck: Vector2 = _v("neck", Vector2.ZERO)
	# Mismo movimiento que la cabeza en el shader.
	_face.draw_set_transform_matrix(Transform2D(_face_rot, neck) * Transform2D(0.0, _face_shift - neck))
	var skin: Color = _v("skin", Color8(250, 214, 205))
	var lash: Color = _v("lash", Color8(30, 16, 22))
	var eyes: Array = _v("eyes", [])
	var halves: Array = _v("eye_half", [])
	var face: Vector2 = _v("face", Vector2.ZERO)

	# Rubor.
	if _blush > 0.02:
		for cheek in _v("cheeks", []):
			_soft_ellipse(cheek, Vector2(62, 26), Color(1.0, 0.35, 0.45, 0.42 * _blush))

	for i in eyes.size():
		var center: Vector2 = eyes[i]
		var half: Vector2 = halves[i]
		# Lado de la nariz: +1 si queda a la derecha del ojo.
		var inner := 1.0 if face.x > center.x else -1.0
		var lid := maxf(_lid, _blink)
		var arc := _arc
		# Guiño: el ojo de la derecha de la pantalla se cierra feliz.
		if _wink > 0.01 and inner < 0.0:
			lid = maxf(lid, _wink)
			arc = maxf(arc, _wink)
		_draw_lid(center, half, clampf(lid, 0.0, 1.0), _slope * inner, arc, inner, skin, lash)

	if act_tears > 0.01:
		for i in eyes.size():
			var center: Vector2 = eyes[i]
			var half: Vector2 = halves[i]
			var outer := -1.0 if face.x > center.x else 1.0
			for d in 2:
				var phase := fmod(_time * 0.6 + d * 0.5, 1.0)
				var at := center + Vector2(outer * half.x * 0.6, half.y + phase * 90.0)
				_face.draw_circle(at, 7.0 * (1.0 - phase * 0.4), Color(0.6, 0.85, 1.0, 0.75 * act_tears * (1.0 - phase)))
			_face.draw_line(center + Vector2(outer * half.x * 0.6, half.y), center + Vector2(outer * half.x * 0.6, half.y + 70.0), Color(0.7, 0.9, 1.0, 0.35 * act_tears), 5.0)

	_draw_mouth()


## Párpado: cubre el ojo desde arriba hasta "lid". Cerrado del todo dibuja
## la línea de pestañas (curva hacia abajo, o hacia arriba si está feliz).
## La piel va en degradado (sombra de ojos arriba, rubor abajo) y con borde
## difuminado para que no se note el parche.
func _draw_lid(center: Vector2, half: Vector2, lid: float, slope: float, arc: float, inner: float, skin: Color, lash: Color) -> void:
	if lid < 0.03:
		return
	var lid_top: Color = _v("lid_top", skin)
	var lid_bottom: Color = _v("lid_bottom", skin)
	var top := half.y + 15.0
	var bottom := half.y + 4.0
	var a := half.x + 6.0
	var steps := 18
	var closed := lid > 0.93
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for s in steps + 1:
		var f := float(s) / steps
		var dx := (f * 2.0 - 1.0) * a
		var curve_r := sqrt(maxf(0.0, 1.0 - pow(dx / a, 2.0)))
		var y_top := -top * curve_r
		var y_bottom := bottom * curve_r
		var y_edge := y_bottom if closed else clampf(-top + lid * (top + bottom) + slope * dx * 0.9 + (1.0 - curve_r) * 4.0, y_top, y_bottom)
		upper.append(center + Vector2(dx, y_top))
		lower.append(center + Vector2(dx, y_edge))
	var span := top + bottom
	var color_at := func(p: Vector2) -> Color:
		return lid_top.lerp(lid_bottom, clampf((p.y - (center.y - top)) / span, 0.0, 1.0))
	# Relleno por columnas (draw_primitive no necesita triangular).
	for s in steps:
		var quad := PackedVector2Array([upper[s], upper[s + 1], lower[s + 1], lower[s]])
		_face.draw_primitive(quad, PackedColorArray([color_at.call(quad[0]), color_at.call(quad[1]), color_at.call(quad[2]), color_at.call(quad[3])]), PackedVector2Array())
	# Borde difuminado por arriba (y por abajo si está cerrado).
	var feather := 9.0
	var outlines: Array = [upper]
	if closed:
		outlines.append(lower)
	for outline in outlines:
		for s in steps:
			var p0: Vector2 = outline[s]
			var p1: Vector2 = outline[s + 1]
			var n0 := (p0 - center).normalized() * feather
			var n1 := (p1 - center).normalized() * feather
			var c0: Color = color_at.call(p0)
			var c1: Color = color_at.call(p1)
			_face.draw_primitive(PackedVector2Array([p0, p1, p1 + n1, p0 + n0]),
				PackedColorArray([c0, c1, Color(c1, 0.0), Color(c0, 0.0)]), PackedVector2Array())
	if closed:
		var line := PackedVector2Array()
		for s in steps + 1:
			var f := float(s) / steps
			var dx := (f * 2.0 - 1.0) * half.x * 1.05
			var curve := 1.0 - pow(dx / (half.x * 1.05), 2.0)
			# arc 0: "‿" (dormida/parpadeo) · arc 1: "^" (feliz)
			var y := lerpf(half.y * 0.15 + curve * half.y * 0.3, half.y * 0.3 - curve * half.y * 0.85, arc)
			line.append(center + Vector2(dx, y))
		_face.draw_polyline(line, Color(lash, 0.35), 10.0, true)
		_face.draw_polyline(line, lash, 5.5, true)
		# Pestañas en la esquina de afuera.
		var outer := -inner
		var corner := line[steps if outer > 0.0 else 0]
		_face.draw_line(corner, corner + Vector2(outer * 16.0, -8.0 if arc < 0.5 else 2.0), lash, 4.5, true)
		_face.draw_line(corner + Vector2(-outer * 8.0, 1.0), corner + Vector2(outer * 8.0, 9.0 if arc < 0.5 else -9.0), lash, 3.5, true)
		return
	# Sombra bajo el párpado y pestañas en su borde.
	var shadow := PackedVector2Array()
	for p in lower:
		shadow.append(p + Vector2(0, 5))
	_face.draw_polyline(shadow, Color(lash.r, lash.g, lash.b, 0.25), 6.0, true)
	_face.draw_polyline(lower, lash, 7.0, true)


## Boca abierta al hablar o por la emoción, con colmillos de vampira.
func _draw_mouth() -> void:
	var open := clampf(_mouth, 0.0, 1.0)
	if open < 0.05 or _sleeping:
		return
	var mouth: Vector2 = _v("mouth", Vector2.ZERO)
	var width := float(_v("mouth_width", 40.0))
	var lips: Color = _v("lips", Color8(170, 30, 45))
	var w := width * (0.55 + 0.25 * open)
	var h := 4.0 + 26.0 * open
	var c := mouth + Vector2(0, h * 0.35)
	var inside := PackedVector2Array()
	for s in 24:
		var a := TAU * s / 24.0
		inside.append(c + Vector2(cos(a) * w, sin(a) * h * 0.5))
	# Labios alrededor y el hueco de la boca.
	var rim := PackedVector2Array()
	for p in inside:
		rim.append(c + (p - c) * Vector2(1.12, 1.25))
	_face.draw_colored_polygon(rim, lips)
	_face.draw_colored_polygon(inside, Color8(70, 14, 24))
	# Lengua.
	if open > 0.3:
		_soft_ellipse(c + Vector2(0, h * 0.28), Vector2(w * 0.55, h * 0.22), Color8(196, 86, 98))
	# Colmillos.
	var fang := minf(open * 2.0, 1.0) * 9.0
	for side in [-1.0, 1.0]:
		var x: float = c.x + side * w * 0.45
		var y := c.y - h * 0.45
		_face.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, y), Vector2(x + 4, y), Vector2(x + side * 0.5, y + fang)]), Color(1, 1, 1, 0.95))


func _soft_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	for i in 5:
		var f := 1.0 - i / 5.0
		var pts := PackedVector2Array()
		for s in 20:
			var a := TAU * s / 20.0
			pts.append(center + Vector2(cos(a) * radius.x * f, sin(a) * radius.y * f))
		_face.draw_colored_polygon(pts, Color(color.r, color.g, color.b, color.a / 5.0 * 1.6))


## Cobija y "Zzz" por delante de ella cuando duerme.
func _draw_foreground() -> void:
	if not _sleeping:
		return
	var canvas := _foreground
	if _in_bed and room:
		var overlay: Dictionary = room.blanket_overlay()
		if not overlay.is_empty():
			canvas.draw_polygon(overlay["points"], PackedColorArray([Color.WHITE]), overlay["uvs"], overlay["texture"])
		else:
			canvas.draw_rect(room.blanket_rect(), room.blanket_color().darkened(0.25 if _night else 0.0))
	var head := _face_to_screen(_v("face", Vector2.ZERO)) - global_position
	var font := get_theme_default_font()
	for i in 3:
		var phase := fmod(_time * 0.45 + i * 0.33, 1.0)
		var direction := -1.0 if head.x > size.x * 0.6 else 1.0
		var at := head + Vector2(direction * (size.x * 0.04 + phase * 50.0) - (30.0 if direction < 0.0 else 0.0), -size.y * 0.09 - phase * 80.0)
		canvas.draw_string(font, at, "z" if i < 2 else "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 + phase * 18.0), Color(1, 1, 1, sin(phase * PI)))
