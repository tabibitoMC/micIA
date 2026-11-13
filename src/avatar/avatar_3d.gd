class_name Avatar3D
extends Avatar
## Avatar 3D con un modelo VRM (por defecto res://assets/models/companion.vrm).
##
## Usa un SubViewport con fondo transparente, así se dibuja encima del fondo
## de la habitación. Las expresiones las maneja VrmExpressionMixer y el
## cuerpo VrmBodyPoser.

const DEFAULT_MODEL_PATH := "res://assets/models/vita.vrm"

## Modelo a cargar (se fija antes de añadir el avatar a la escena).
var model_path := DEFAULT_MODEL_PATH

## Emoción de la app -> {expresión VRM: peso}
const EMOTION_EXPRESSIONS := {
	"neutral": {},
	"feliz": {"happy": 1.0},
	"triste": {"sad": 1.0},
	"enojada": {"angry": 1.0},
	"sorprendida": {"oh": 0.35, "lookUp": 0.3},
	"avergonzada": {"relaxed": 0.6, "lookDown": 0.5},
	"pensativa": {"relaxed": 0.4, "lookUp": 0.6, "lookLeft": 0.4},
	"coqueta": {"happy": 0.35, "relaxed": 0.45, "lookDown": 0.2},
}

## Ajustes de física de resortes según el nombre de los huesos:
## [texto en el nombre, rigidez, arrastre, gravedad]. Menos rigidez y arrastre
## = más rebote. VRoid nombra el busto "J_Sec_*_Bust*".
const SPRING_TUNING := [
	["Bust", 0.45, 0.5, 1.3],
	["Skirt", 0.8, 0.75, 1.1],
	["Hair", 0.9, 0.85, 1.0],
]
## Expresiones que ya cierran los ojos (con ellas no se parpadea).
const EYES_CLOSED_EXPRESSIONS := ["happy", "relaxed"]
const MOUTH_SHAPES := ["aa", "ih", "ou", "ee", "oh"]

var _viewport: SubViewport
var _camera: Camera3D
var _floor_shadow: MeshInstance3D
var _container: SubViewportContainer
var _environment: Environment
var _room: Room3D
var _sleeping := false
var _key_light: DirectionalLight3D
## Encuadre más abierto cuando hay habitación.
var _wide_framing := false
var _camera_awake: Transform3D

## Corrección de color de la imagen 3D (menos "flash"): un poco menos de
## brillo, más contraste y más saturación.
const GRADING_SHADER := """
shader_type canvas_item;
uniform float brightness = 0.97;
uniform float contrast = 1.08;
uniform float saturation = 1.12;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb * brightness;
	col = (col - 0.5) * contrast + 0.5;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	COLOR = vec4(clamp(col, 0.0, 1.0), c.a);
}
"""
var _model: Node3D
var _mixer: VrmExpressionMixer
var _poser: VrmBodyPoser
var _emotion_goals: Dictionary = {}
var _talking := false
var _talk_time := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _action_tween: Tween
var _jump_offset := 0.0
var _model_base_y := 0.0
var _home_x := 0.0
var _base_yaw := 0.0
## Giro extra sobre el eje vertical: hacia dónde camina o darte la espalda.
var _facing_offset := 0.0
var _turned_away := false

## Velocidad al caminar (metros por segundo en el mundo 3D).
const WALK_SPEED := 0.55
## Cuánto gira al caminar de lado (no 90° para que se le siga viendo la cara).
const WALK_TURN := 1.1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_viewport()
	load_model(model_path)


## Devuelve false si el modelo no se pudo cargar (main.gd usa el 2D entonces).
func load_model(path: String) -> bool:
	if _model:
		_model.queue_free()
		_model = null
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("No se pudo cargar el modelo VRM: %s" % path)
		return false
	_model = scene.instantiate() as Node3D
	_tune_springs(_model)
	_cast_shadows(_model)
	_viewport.add_child(_model)

	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty():
		push_warning("El modelo no tiene esqueleto.")
		return false
	_poser = VrmBodyPoser.new(skeletons[0])
	_mixer = VrmExpressionMixer.new(_model, players[0] if not players.is_empty() else null)
	if not _poser.is_valid():
		push_warning("El modelo no tiene huesos humanoides estándar.")
		return false
	# Que el modelo mire a la cámara (la cámara está en +Z).
	if _poser.forward() == Vector3.FORWARD:
		_model.rotate_y(PI)
	_model_base_y = _model.position.y
	_place_floor_shadow.call_deferred()
	_home_x = _model.position.x
	_base_yaw = _model.rotation.y
	_frame_camera.call_deferred()
	return true


## Tiñe la ropa y el pelo según el conjunto (materiales *_CLOTH / *_HAIR de
## VRoid). Se duplican los materiales para no modificar el recurso original.
func apply_tint(cloth: Color, hair: Color) -> void:
	if _model == null:
		return
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(i) as ShaderMaterial
			if source == null:
				continue
			var tint := Color.WHITE
			if source.resource_name.ends_with("_CLOTH"):
				tint = cloth
			elif source.resource_name.contains("_HAIR"):
				tint = hair
			else:
				continue
			var material := source.duplicate() as ShaderMaterial
			for param in ["_Color", "_ShadeColor"]:
				var base: Variant = source.get_shader_parameter(param)
				if base is Color:
					material.set_shader_parameter(param, base * tint)
			mesh.set_surface_override_material(i, material)


func is_ready() -> bool:
	return _poser != null and _poser.is_valid()


func set_emotion(emotion: String) -> void:
	_emotion_goals = EMOTION_EXPRESSIONS.get(emotion, {})


func set_talking(talking: bool) -> void:
	_talking = talking


func play_action(action: String) -> void:
	if _poser == null:
		return
	if _action_tween:
		_action_tween.kill()
	_reset_action_params()
	_action_tween = create_tween()
	var p := _poser
	match action:
		"saludar":
			_action_tween.tween_property(p, "wave", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
			for i in 3:
				_action_tween.tween_property(p, "wave_swing", 1.0, 0.2)
				_action_tween.tween_property(p, "wave_swing", -0.6, 0.2)
			_action_tween.tween_property(p, "wave_swing", 0.0, 0.15)
			_action_tween.tween_property(p, "wave", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		"asentir":
			for i in 2:
				_action_tween.tween_property(p, "head_pitch", 0.3, 0.18)
				_action_tween.tween_property(p, "head_pitch", 0.0, 0.18)
		"negar":
			for i in 2:
				_action_tween.tween_property(p, "head_yaw", 0.35, 0.16)
				_action_tween.tween_property(p, "head_yaw", -0.35, 0.16)
			_action_tween.tween_property(p, "head_yaw", 0.0, 0.14)
		"saltar":
			_action_tween.tween_property(self, "_jump_offset", 0.12, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			_action_tween.tween_property(self, "_jump_offset", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		"cruzar_brazos":
			_action_tween.tween_property(p, "arms_crossed", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
			_action_tween.parallel().tween_property(p, "head_roll", 0.12, 0.45)
			_action_tween.tween_interval(2.2)
			_action_tween.tween_property(p, "arms_crossed", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
			_action_tween.parallel().tween_property(p, "head_roll", 0.0, 0.5)
		"golpear":
			# Echa el brazo atrás y lanza un manotazo hacia la cámara.
			p.point_side = "Right"
			p.point_direction = (Vector3.UP * 0.6 + _poser.forward() * -0.2 + Vector3.LEFT * 0.4).normalized()
			_action_tween.tween_property(p, "point_amount", 1.0, 0.18)
			_action_tween.tween_callback(func():
				p.point_direction = (_poser.forward() + Vector3.UP * 0.15).normalized())
			_action_tween.tween_property(self, "_jump_offset", 0.04, 0.08)
			_action_tween.tween_callback(func(): struck.emit())
			_action_tween.tween_property(self, "_jump_offset", 0.0, 0.15)
			_action_tween.tween_interval(0.35)
			_action_tween.tween_property(p, "point_amount", 0.0, 0.3)
		"llorar":
			# Cabeza gacha, manos a la cara y hombros temblando.
			_action_tween.tween_property(p, "head_pitch", 0.45, 0.4)
			_action_tween.parallel().tween_property(p, "arms_crossed", 0.75, 0.4)
			for i in 8:
				_action_tween.tween_property(p, "body_lean", 0.03, 0.12)
				_action_tween.tween_property(p, "body_lean", -0.03, 0.12)
			_action_tween.tween_property(p, "body_lean", 0.0, 0.1)
			_action_tween.tween_property(p, "head_pitch", 0.0, 0.5)
			_action_tween.parallel().tween_property(p, "arms_crossed", 0.0, 0.5)
		"mirar_otro_lado":
			_action_tween.tween_property(p, "head_yaw", -0.6, 0.3).set_trans(Tween.TRANS_SINE)
			_action_tween.parallel().tween_property(p, "head_roll", -0.08, 0.3)
			_action_tween.tween_interval(1.6)
			_action_tween.tween_property(p, "head_yaw", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			_action_tween.parallel().tween_property(p, "head_roll", 0.0, 0.4)
		_:
			_action_tween.kill()


# --- Lugares (habitaciones 3D) ------------------------------------------------

## Construye la habitación alrededor de ella. time_theme: dia/atardecer/noche.
func set_room(env_id: String, time_theme: String) -> void:
	if _room == null:
		_room = Room3D.new()
		_viewport.add_child(_room)
	_room.build(env_id, time_theme)
	_viewport.transparent_bg = false
	_environment.background_color = Room3D.SKY.get(time_theme, Room3D.SKY["dia"])[0]
	if _floor_shadow:
		_floor_shadow.visible = false
	# Con habitación se aleja un poco la cámara para que se vea el lugar.
	_wide_framing = true
	_frame_camera()
	_apply_time_light(time_theme)


func set_time_of_day(time_theme: String) -> void:
	if _room:
		_room.set_time(time_theme)
		_environment.background_color = Room3D.SKY.get(time_theme, Room3D.SKY["dia"])[0]
	_apply_time_light(time_theme)


func current_room() -> String:
	return _room.env_id if _room else ""


func window_screen_position() -> Variant:
	if _room == null:
		return null
	var window: Variant = Environments.fetch(_room.env_id).get("window")
	return _world_to_screen(window) if window != null else null


## Pantalla a negro y de vuelta (para cambiar de lugar).
func fade(to_black: bool, seconds := 0.35) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.05, 0.02, 0.05) if to_black else Color.WHITE, seconds)
	await tween.finished


## Sale caminando por un lado del cuarto.
func walk_out(to_right: bool) -> void:
	if _poser == null:
		return
	await _walk_to_world_x((Environments.SIDE_X - 0.5) * (1.0 if to_right else -1.0))


## Pone al modelo en el borde izquierdo o derecho del cuarto (para entrar caminando).
func place_at_side(from_left: bool) -> void:
	_model.position.x = -Environments.SIDE_X + 0.6 if from_left else Environments.SIDE_X - 0.6


## Acostarse a dormir en la cama del cuarto (o despertar).
func set_sleeping(sleeping: bool) -> void:
	if sleeping == _sleeping or _model == null:
		return
	if sleeping:
		var bed: Variant = _room.spot("cama") if _room else null
		if bed == null:
			return
		_sleeping = true
		_reset_action_params()
		_camera_awake = _camera.transform
		# Acostada boca arriba, con la cabeza en la almohada (hacia la pared).
		var bed_spot := bed as Vector3
		_model.basis = Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.UP, _base_yaw)
		_model.position = bed_spot
		# Se mueve el cuerpo para que la cabeza quede sobre la almohada,
		# así funciona con modelos de cualquier altura.
		var pillow: Vector3 = _room.spot("almohada") if _room.spot("almohada") != null else bed_spot + Vector3(0, 0.12, -0.25)
		_model.position += pillow - _poser.head_global_position()
		var middle := (_poser.head_global_position() + _poser.hips_global_position()) / 2.0
		_camera.position = middle + Vector3(1.35, 1.45, 1.0)
		_camera.look_at(middle, Vector3.UP)
		if _floor_shadow:
			_floor_shadow.visible = false
		_apply_time_light("noche")
	else:
		_sleeping = false
		_model.basis = Basis(Vector3.UP, _base_yaw)
		_model.position = Vector3(_home_x, _model_base_y, 0.0)
		_camera.transform = _camera_awake
		_apply_time_light(str(Settings.get_value("room_theme")))


func is_sleeping() -> bool:
	return _sleeping


## Luces más cálidas al atardecer y más tenues de noche.
func _apply_time_light(time_theme: String) -> void:
	var key := _key_light
	if key == null:
		return
	match time_theme:
		"atardecer":
			key.light_color = Color(1.0, 0.82, 0.68)
			key.light_energy = 0.42
			_environment.ambient_light_color = Color(1.0, 0.85, 0.85)
		"noche":
			key.light_color = Color(0.75, 0.78, 1.0)
			key.light_energy = 0.28
			_environment.ambient_light_color = Color(0.78, 0.78, 1.0)
		_:
			key.light_color = Color(1.0, 0.96, 0.93)
			key.light_energy = 0.45
			_environment.ambient_light_color = Color(1.0, 0.92, 0.95)


func walk_to_screen_x(x: float) -> void:
	if _poser == null:
		return
	await _walk_to_world_x(_screen_to_world(Vector2(x, global_position.y + size.y * 0.6)).x)


func go_home() -> void:
	if _poser == null:
		return
	await _walk_to_world_x(_home_x)


func point_at_screen(point: Vector2, seconds := 1.0) -> void:
	if _poser == null:
		return
	var target := _screen_to_world(point)
	# Mirando a la cámara, su mano derecha queda a la izquierda de la pantalla.
	var side := "Right" if target.x < _model.global_position.x else "Left"
	var shoulder := _poser.shoulder_global_position(side)
	_poser.point_side = side
	_poser.point_direction = _poser.world_to_skeleton_direction(target - shoulder)
	var tween := create_tween()
	tween.tween_property(_poser, "point_amount", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(seconds)
	tween.tween_property(_poser, "point_amount", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	await tween.finished


func is_head_at(point: Vector2) -> bool:
	if _poser == null:
		return false
	var head := _world_to_screen(_poser.head_global_position() + Vector3.UP * 0.08)
	return point.distance_to(head) < size.y * 0.11


func is_body_at(point: Vector2) -> bool:
	if _poser == null:
		return false
	var head := _world_to_screen(_poser.head_global_position())
	var hips := _world_to_screen(_poser.hips_global_position())
	var half_width := size.x * 0.2
	return point.y > head.y - size.y * 0.12 and absf(point.x - head.x) < half_width and point.y < hips.y + size.y * 0.3


func _world_to_screen(world: Vector3) -> Vector2:
	var viewport_point := _camera.unproject_position(world)
	return global_position + viewport_point * size / Vector2(_viewport.size)


func set_turned_away(away: bool) -> void:
	if away == _turned_away:
		return
	_turned_away = away
	var tween := create_tween()
	tween.tween_property(self, "_facing_offset", PI if away else 0.0, 0.8).set_trans(Tween.TRANS_SINE)


func _walk_to_world_x(target_x: float) -> void:
	var distance := target_x - _model.position.x
	if absf(distance) < 0.03:
		return
	var direction := signf(distance)
	var turn := create_tween()
	turn.tween_property(self, "_facing_offset", WALK_TURN * direction, 0.25)
	turn.parallel().tween_property(_poser, "walk_amount", 1.0, 0.25)
	await turn.finished

	var walk := create_tween()
	walk.tween_property(_model, "position:x", target_x, absf(distance) / WALK_SPEED)
	await walk.finished

	var stop := create_tween()
	stop.tween_property(self, "_facing_offset", PI if _turned_away else 0.0, 0.3)
	stop.parallel().tween_property(_poser, "walk_amount", 0.0, 0.3)
	await stop.finished


## Punto de la pantalla -> punto del mundo 3D a la profundidad del modelo.
func _screen_to_world(screen_point: Vector2) -> Vector3:
	var local := screen_point - global_position
	var viewport_point := local * Vector2(_viewport.size) / size
	var depth := absf(_camera.global_position.z - _model.global_position.z)
	return _camera.project_position(viewport_point, depth)


func _process(delta: float) -> void:
	if _poser == null or _mixer == null:
		return
	_poser.update(delta)
	if _sleeping:
		_update_face(delta)
		return
	_model.position.y = _model_base_y + _jump_offset + _poser.walk_bounce()
	_model.rotation.y = _base_yaw + _facing_offset
	if _floor_shadow:
		_floor_shadow.position.x = _model.position.x
		# La sombra se encoge un poco al saltar.
		var lift := _jump_offset + _poser.walk_bounce()
		_floor_shadow.scale = Vector3.ONE * clampf(1.0 - lift * 3.0, 0.6, 1.0)
	_update_face(delta)


func _update_face(delta: float) -> void:
	# Emoción
	_mixer.clear_goals(MOUTH_SHAPES + ["blink"])
	var eyes_closed := false
	for expression in _emotion_goals:
		_mixer.set_goal(expression, _emotion_goals[expression])
		if expression in EYES_CLOSED_EXPRESSIONS and _emotion_goals[expression] > 0.5:
			eyes_closed = true

	if _sleeping:
		_mixer.set_goal("blink", 1.0)
		_mixer.set_goal("relaxed", 0.4)
		_mixer.update(delta, 4.0)
		return
	# Parpadeo
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.5)
	_blink = maxf(0.0, _blink - delta * 8.0)
	_mixer.set_now("blink", 0.0 if eyes_closed else (1.0 - absf(_blink * 2.0 - 1.0)) * float(_blink > 0.0))

	# Boca: alterna vocales mientras habla
	if _talking:
		_talk_time += delta
		var openness := clampf(0.55 + 0.45 * sin(_talk_time * 17.0) * absf(sin(_talk_time * 4.3)), 0.0, 1.0)
		var vowel_index := int(_talk_time * 6.0) % MOUTH_SHAPES.size()
		for i in MOUTH_SHAPES.size():
			var shape: String = MOUTH_SHAPES[i]
			var weight := openness if i == vowel_index else 0.0
			if shape == "aa":
				weight = maxf(weight, openness * 0.5)
			_mixer.set_goal(shape, weight)
	else:
		for shape in MOUTH_SHAPES:
			_mixer.set_goal(shape, 0.0)
	# Si la emoción usa una vocal (sorprendida -> "oh"), se mantiene.
	for expression in _emotion_goals:
		if expression in MOUTH_SHAPES and not _talking:
			_mixer.set_goal(expression, _emotion_goals[expression])

	_mixer.update(delta, 14.0)


func _reset_action_params() -> void:
	_poser.head_pitch = 0.0
	_poser.head_yaw = 0.0
	_poser.head_roll = 0.0
	_poser.wave = 0.0
	_poser.wave_swing = 0.0
	_poser.arms_crossed = 0.0
	_poser.point_amount = 0.0
	_poser.body_lean = 0.0
	_jump_offset = 0.0


func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grading := Shader.new()
	grading.code = GRADING_SHADER
	var grading_material := ShaderMaterial.new()
	grading_material.shader = grading
	container.material = grading_material
	_container = container
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.fov = 28.0
	_viewport.add_child(_camera)

	# Luz principal cálida con sombras, desde arriba a la derecha.
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38, 28, 0)
	key_light.light_color = Color(1.0, 0.96, 0.93)
	key_light.light_energy = 0.45
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.03
	key_light.shadow_blur = 1.5
	key_light.directional_shadow_max_distance = 8.0
	_viewport.add_child(key_light)
	_key_light = key_light
	# Relleno suave y frío desde la izquierda (suaviza las sombras).
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-15, -55, 0)
	fill_light.light_color = Color(0.85, 0.88, 1.0)
	fill_light.light_energy = 0.06
	_viewport.add_child(fill_light)
	# Contraluz rosado: dibuja el contorno y da sensación de volumen.
	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-20, 160, 0)
	rim_light.light_color = Color(1.0, 0.75, 0.85)
	rim_light.light_energy = 0.15
	_viewport.add_child(rim_light)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.92, 0.95)
	environment.ambient_light_energy = 0.3
	_environment = environment
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	_viewport.add_child(world_env)


## Hace la física de resortes (busto, falda, pelo) más suelta.
func _tune_springs(model: Node) -> void:
	for node in model.find_children("*", "Node3D", true, false):
		var springs: Variant = node.get("spring_bones")
		if typeof(springs) != TYPE_ARRAY:
			continue
		for spring in springs:
			if spring == null:
				continue
			var names := " ".join(spring.joint_nodes)
			for tuning in SPRING_TUNING:
				if names.contains(tuning[0]):
					spring.stiffness_scale = tuning[1]
					spring.drag_force_scale = tuning[2]
					spring.gravity_scale = tuning[3]
					break


func _cast_shadows(model: Node) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Sombra suave y redonda en el piso, bajo sus pies.
func _place_floor_shadow() -> void:
	if _poser == null:
		return
	if _floor_shadow:
		_floor_shadow.queue_free()
	var feet_y := minf(_poser.bone_global_position("LeftFoot").y, _poser.bone_global_position("RightFoot").y)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.35, 0.1, 0.25, 0.45))
	gradient.set_color(1, Color(0.35, 0.1, 0.25, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.55)
	plane.material = material
	_floor_shadow = MeshInstance3D.new()
	_floor_shadow.mesh = plane
	_floor_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_shadow.position = Vector3(_model.position.x, feet_y - 0.03, _model.global_position.z)
	_viewport.add_child(_floor_shadow)


## Encuadre de la cintura para arriba, como en las apps de compañeras.
## wide = true: más abierto y desde un poco más arriba, para ver la habitación.
func _frame_camera() -> void:
	if _poser == null:
		return
	var wide := _wide_framing
	var head := _poser.head_global_position()
	var hips := _poser.hips_global_position()
	var body_height := maxf(0.3, head.y - hips.y)
	if wide:
		_camera.fov = 34.0
		var target := Vector3(0, head.y - body_height * 0.7, 0)
		_camera.position = target + Vector3(0, body_height * 0.55, body_height * 4.8)
		_camera.look_at(target, Vector3.UP)
		return
	# Se apunta un poco por debajo del pecho: la cabeza queda en el tercio
	# superior y la parte baja de la pantalla (donde va el chat) muestra el torso.
	var look_at_point := Vector3(head.x, head.y - body_height * 0.55, head.z)
	_camera.position = look_at_point + Vector3(0, body_height * 0.08, body_height * 5.2)
	_camera.look_at(look_at_point, Vector3.UP)
