class_name Avatar3D
extends Avatar
## Avatar 3D con un modelo VRM (por defecto res://assets/models/companion.vrm).
##
## Usa un SubViewport con fondo transparente, así se dibuja encima del fondo
## de la habitación. Las expresiones las maneja VrmExpressionMixer y el
## cuerpo VrmBodyPoser.

const DEFAULT_MODEL_PATH := "res://assets/models/companion.vrm"

## Emoción de la app -> {expresión VRM: peso}
const EMOTION_EXPRESSIONS := {
	"neutral": {},
	"feliz": {"happy": 1.0},
	"triste": {"sad": 1.0},
	"enojada": {"angry": 1.0},
	"sorprendida": {"oh": 0.35, "lookUp": 0.3},
	"avergonzada": {"relaxed": 0.6, "lookDown": 0.5},
	"pensativa": {"relaxed": 0.4, "lookUp": 0.6, "lookLeft": 0.4},
}
## Expresiones que ya cierran los ojos (con ellas no se parpadea).
const EYES_CLOSED_EXPRESSIONS := ["happy", "relaxed"]
const MOUTH_SHAPES := ["aa", "ih", "ou", "ee", "oh"]

var _viewport: SubViewport
var _camera: Camera3D
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
	load_model(DEFAULT_MODEL_PATH)


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
	_home_x = _model.position.x
	_base_yaw = _model.rotation.y
	_frame_camera.call_deferred()
	return true


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
		"mirar_otro_lado":
			_action_tween.tween_property(p, "head_yaw", -0.6, 0.3).set_trans(Tween.TRANS_SINE)
			_action_tween.parallel().tween_property(p, "head_roll", -0.08, 0.3)
			_action_tween.tween_interval(1.6)
			_action_tween.tween_property(p, "head_yaw", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			_action_tween.parallel().tween_property(p, "head_roll", 0.0, 0.4)
		_:
			_action_tween.kill()


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
	_model.position.y = _model_base_y + _jump_offset + _poser.walk_bounce()
	_model.rotation.y = _base_yaw + _facing_offset
	_update_face(delta)


func _update_face(delta: float) -> void:
	# Emoción
	_mixer.clear_goals(MOUTH_SHAPES + ["blink"])
	var eyes_closed := false
	for expression in _emotion_goals:
		_mixer.set_goal(expression, _emotion_goals[expression])
		if expression in EYES_CLOSED_EXPRESSIONS and _emotion_goals[expression] > 0.5:
			eyes_closed = true

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
	_jump_offset = 0.0


func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.fov = 28.0
	_viewport.add_child(_camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, 25, 0)
	key_light.light_energy = 1.0
	_viewport.add_child(key_light)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.94, 0.95)
	environment.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	_viewport.add_child(world_env)


## Encuadre de la cintura para arriba, como en las apps de compañeras.
func _frame_camera() -> void:
	if _poser == null:
		return
	var head := _poser.head_global_position()
	var hips := _poser.hips_global_position()
	var body_height := maxf(0.3, head.y - hips.y)
	# Se apunta un poco por debajo del pecho: la cabeza queda en el tercio
	# superior y la parte baja de la pantalla (donde va el chat) muestra el torso.
	var look_at_point := Vector3(head.x, head.y - body_height * 0.55, head.z)
	_camera.position = look_at_point + Vector3(0, body_height * 0.08, body_height * 5.2)
	_camera.look_at(look_at_point, Vector3.UP)
