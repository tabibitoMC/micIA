class_name AvatarPuppet
extends Avatar
## Avatar 2D estilo VTuber: una marioneta por capas (Puppet) con físicas en
## el pelo, parpadeo, boca al hablar, emociones y gestos.
##
## Se dibuja en un SubViewport transparente con cámara ortográfica, encima
## del fondo de la habitación.

const DEFAULT_MODEL_PATH := "res://assets/puppets/aka.puppet"
## Altura del modelo en el mundo (metros) y encuadre de la cámara.
const MODEL_HEIGHT := 1.6
const VIEW_HEIGHT := 1.55
const VIEW_TOP := 1.72

## Nombres de los parámetros del modelo (los de Inochi2D de ejemplo).
const P_HEAD := "Head:: Yaw-Pitch"
const P_HEAD_ROLL := "Head:: Roll"
const P_BODY := "Body:: Yaw-Pitch"
const P_BODY_ROLL := "Body:: Roll"
const P_MOUTH := "Mouth:: Shape"
const P_BLINK_L := "Eye:: Left:: Blink"
const P_BLINK_R := "Eye:: Right:: Blink"
const P_EYE_L := "Eye:: Left:: Move"
const P_EYE_R := "Eye:: Right:: Move"
const P_BREATH := "Breath"
const P_ARM_L := "Arm:: Left:: Move"
const P_ARM_R := "Arm:: Right:: Move"
const P_BODY_X := "Body:: X:: Move"

## Emoción -> objetivos de la cara y el cuerpo.
##   eyes: cuánto cierra los ojos (0..1) · mouth: [forma, apertura]
##   head: [giro, cabeceo] · roll: inclinación · brow: giro de cejas (rad,
##   positivo = enojada) · brow_y: cejas arriba (-) o abajo (+) en px
const EMOTIONS := {
	"neutral": {"eyes": 0.0, "mouth": [0.5, 0.0], "head": [0.0, 0.0], "roll": 0.0, "brow": 0.0, "brow_y": 0.0},
	"feliz": {"eyes": 0.85, "mouth": [1.0, 0.45], "head": [0.0, 0.1], "roll": 0.12, "brow": -0.05, "brow_y": -6.0},
	"triste": {"eyes": 0.35, "mouth": [0.0, 0.0], "head": [0.0, -0.45], "roll": -0.1, "brow": -0.3, "brow_y": 0.0},
	"enojada": {"eyes": 0.25, "mouth": [0.0, 0.15], "head": [0.0, -0.15], "roll": 0.0, "brow": 0.35, "brow_y": 10.0},
	"sorprendida": {"eyes": 0.0, "mouth": [0.5, 0.9], "head": [0.0, 0.25], "roll": 0.0, "brow": 0.0, "brow_y": -16.0},
	"avergonzada": {"eyes": 0.3, "mouth": [0.3, 0.1], "head": [0.3, -0.3], "roll": 0.15, "brow": -0.15, "brow_y": 0.0, "blush": 1.0},
	"pensativa": {"eyes": 0.15, "mouth": [0.3, 0.0], "head": [-0.35, 0.3], "roll": -0.15, "brow": 0.1, "brow_y": -4.0},
	"coqueta": {"eyes": 0.4, "mouth": [1.0, 0.2], "head": [0.2, -0.1], "roll": 0.25, "brow": 0.0, "brow_y": -4.0, "blush": 0.6},
}

## Modelo a cargar (se fija antes de añadir el avatar a la escena).
var model_path := DEFAULT_MODEL_PATH

## Fondo de la casa (lo pone main.gd): ahí están los lugares y la cama.
var room: RoomBackground

var _viewport: SubViewport
var _foreground: Control
var _night := false
var _in_bed := false
var _container: SubViewportContainer
var _camera: Camera3D
var _puppet: Puppet
var _ready_ok := false

var _goal: Dictionary = EMOTIONS["neutral"]
# Valores actuales (se acercan suavemente al objetivo).
var _eyes := 0.0
var _mouth := Vector2(0.5, 0.0)
var _head := Vector2.ZERO
var _roll := 0.0
var _brow := 0.0
var _brow_y := 0.0
var _blush := 0.0

var _time := 0.0
var _talking := false
var _talk_time := 0.0
var _blink_timer := 2.5
var _blink := 0.0
var _sleeping := false
var _turned_away := false
var _action_tween: Tween

# Lo que suman los gestos (los anima play_action con tweens).
var act_head := Vector2.ZERO
var act_roll := 0.0
var act_body := Vector2.ZERO
var act_arm_l := 0.0
var act_arm_r := 0.0
var act_jump := 0.0
var act_zoom := 0.0
var act_shake := 0.0
var _walk := 0.0
var _home_x := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_viewport()
	var path := model_path if model_path.ends_with(".puppet") else DEFAULT_MODEL_PATH
	_puppet = Puppet.new()
	_viewport.add_child(_puppet)
	_ready_ok = _puppet.load_file(path)
	if not _ready_ok:
		return
	_puppet.fit_height(MODEL_HEIGHT)
	_add_blush()
	_puppet.update(0.0)


func is_ready() -> bool:
	return _ready_ok


func set_emotion(emotion: String) -> void:
	_goal = EMOTIONS.get(emotion, EMOTIONS["neutral"])


func set_talking(talking: bool) -> void:
	_talking = talking


## El conjunto de ropa gira el tono de la ropa (el color de `cloth`).
func apply_tint(cloth: Color, _hair: Color) -> void:
	if not _ready_ok:
		return
	var shift := 0.0 if cloth == Color.WHITE else cloth.h
	_puppet.set_hue(["Skirt", "Ribbon"], shift)


func play_action(action: String) -> void:
	if not _ready_ok:
		return
	if _action_tween:
		_action_tween.kill()
	_reset_actions()
	var t := create_tween()
	_action_tween = t
	match action:
		"saludar":
			t.tween_property(self, "act_arm_l", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", 0.2, 0.3)
			for i in 3:
				t.tween_property(self, "act_arm_l", 0.55, 0.16)
				t.tween_property(self, "act_arm_l", 1.0, 0.16)
			t.tween_property(self, "act_arm_l", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.35)
		"asentir":
			for i in 2:
				t.tween_property(self, "act_head:y", -0.7, 0.16)
				t.tween_property(self, "act_head:y", 0.1, 0.16)
			t.tween_property(self, "act_head:y", 0.0, 0.12)
		"negar":
			for i in 2:
				t.tween_property(self, "act_head:x", 0.7, 0.15)
				t.tween_property(self, "act_head:x", -0.7, 0.15)
			t.tween_property(self, "act_head:x", 0.0, 0.14)
		"saltar":
			t.tween_property(self, "act_jump", 0.14, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			t.tween_property(self, "act_jump", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		"cruzar_brazos":
			t.tween_property(self, "act_body:x", -0.5, 0.4).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_head:x", 0.6, 0.4)
			t.parallel().tween_property(self, "act_roll", -0.25, 0.4)
			t.tween_interval(2.0)
			t.tween_property(self, "act_body:x", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_head:x", 0.0, 0.45)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.45)
		"golpear":
			# Toma impulso y se lanza hacia la pantalla.
			t.tween_property(self, "act_zoom", -0.08, 0.18)
			t.parallel().tween_property(self, "act_arm_r", 1.0, 0.18)
			t.tween_property(self, "act_zoom", 0.35, 0.09)
			t.tween_callback(func(): struck.emit())
			t.tween_interval(0.25)
			t.tween_property(self, "act_zoom", 0.0, 0.3)
			t.parallel().tween_property(self, "act_arm_r", 0.0, 0.3)
		"llorar":
			t.tween_property(self, "act_head:y", -0.8, 0.4)
			for i in 8:
				t.tween_property(self, "act_shake", 1.0, 0.11)
				t.tween_property(self, "act_shake", -1.0, 0.11)
			t.tween_property(self, "act_shake", 0.0, 0.1)
			t.tween_property(self, "act_head:y", 0.0, 0.5)
		"mirar_otro_lado":
			t.tween_property(self, "act_head:x", -0.9, 0.3).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", -0.15, 0.3)
			t.tween_interval(1.6)
			t.tween_property(self, "act_head:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.4)
		_:
			t.kill()


func _reset_actions() -> void:
	act_head = Vector2.ZERO
	act_roll = 0.0
	act_body = Vector2.ZERO
	act_arm_l = 0.0
	act_arm_r = 0.0
	act_jump = 0.0
	act_zoom = 0.0
	act_shake = 0.0


# --- Movimiento por la pantalla ---------------------------------------------------

func walk_to_screen_x(x: float) -> void:
	if not _ready_ok:
		return
	await _walk_to(_screen_to_world_x(x))


func go_home() -> void:
	if _ready_ok:
		await _walk_to(_home_x)


func point_at_screen(point: Vector2, seconds := 1.0) -> void:
	if not _ready_ok:
		return
	var left_side := point.x > _world_to_screen(_puppet.global_position).x
	var arm := "act_arm_l" if left_side else "act_arm_r"
	var t := create_tween()
	t.tween_property(self, arm, 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "act_head:x", 0.6 if left_side else -0.6, 0.3)
	t.tween_interval(seconds)
	t.tween_property(self, arm, 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "act_head:x", 0.0, 0.3)
	await t.finished


func set_turned_away(away: bool) -> void:
	_turned_away = away


# --- Lugares -----------------------------------------------------------------------

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


## Dormir: en el dormitorio se acuesta en la cama, tapada con la cobija.
func set_sleeping(sleeping: bool) -> void:
	if sleeping == _sleeping or not _ready_ok:
		return
	_sleeping = sleeping
	_in_bed = sleeping and room != null and room.place == "dormitorio"
	_reset_actions()
	_puppet.physics_enabled = not _in_bed
	if not _in_bed:
		_puppet.rotation.z = 0.0
		_puppet.position = Vector3(_home_x, 0.0, 0.0)
		_puppet.reset_physics()
	_foreground.queue_redraw()


func is_sleeping() -> bool:
	return _sleeping


func fade(to_black: bool, seconds := 0.35) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.05, 0.02, 0.05) if to_black else Color.WHITE, seconds)
	await tween.finished


func place_at_side(from_left: bool) -> void:
	if _ready_ok:
		_puppet.position.x = _view_half_width() * (-1.3 if from_left else 1.3)
		_puppet.reset_physics()


func walk_out(to_right: bool) -> void:
	if _ready_ok:
		await _walk_to(_view_half_width() * (1.4 if to_right else -1.4))


func is_head_at(point: Vector2) -> bool:
	if not _ready_ok:
		return false
	var head := _world_to_screen(_puppet.node_position("Face"))
	return point.distance_to(head) < size.y * 0.13


func is_body_at(point: Vector2) -> bool:
	if not _ready_ok:
		return false
	var head := _world_to_screen(_puppet.node_position("Face"))
	return point.y > head.y - size.y * 0.2 and absf(point.x - head.x) < size.x * 0.3


func _walk_to(target_x: float) -> void:
	var distance := target_x - _puppet.position.x
	if absf(distance) < 0.02:
		return
	var start := create_tween()
	start.tween_property(self, "_walk", signf(distance), 0.2)
	await start.finished
	var move := create_tween()
	move.tween_property(_puppet, "position:x", target_x, absf(distance) / 0.5)
	await move.finished
	var stop := create_tween()
	stop.tween_property(self, "_walk", 0.0, 0.25)
	await stop.finished


func _view_half_width() -> float:
	return VIEW_HEIGHT * size.x / maxf(1.0, size.y) / 2.0


func _screen_to_world_x(x: float) -> float:
	return ((x - global_position.x) / maxf(1.0, size.x) - 0.5) * 2.0 * _view_half_width()


func _world_to_screen(world: Vector3) -> Vector2:
	var half_w := _view_half_width()
	var u := (world.x / (2.0 * half_w)) + 0.5
	var v := (VIEW_TOP - world.y) / VIEW_HEIGHT
	return global_position + Vector2(u, v) * size


# --- Animación continua --------------------------------------------------------------

func _process(delta: float) -> void:
	if not _ready_ok:
		return
	_time += delta
	var goal := _goal
	var k := 1.0 - exp(-delta * 9.0)
	var eyes_goal: float = goal["eyes"]
	var head_goal := Vector2(goal["head"][0], goal["head"][1])
	var roll_goal: float = goal["roll"]
	var mouth_goal := Vector2(goal["mouth"][0], goal["mouth"][1])
	if _sleeping:
		eyes_goal = 1.0
		head_goal = Vector2(0.2, -0.6)
		roll_goal = 0.35
		mouth_goal = Vector2(0.5, 0.05)
	elif _turned_away:
		eyes_goal = 1.0
		head_goal = Vector2(-1.0, 0.2)
		roll_goal = -0.2
		mouth_goal = Vector2(0.0, 0.0)
	_eyes = lerpf(_eyes, eyes_goal, k)
	_head = _head.lerp(head_goal, k)
	_roll = lerpf(_roll, roll_goal, k)
	_brow = lerpf(_brow, float(goal["brow"]), k)
	_brow_y = lerpf(_brow_y, float(goal["brow_y"]), k)
	_blush = lerpf(_blush, float(goal.get("blush", 0.0)), k)

	# Boca: se abre y cierra al hablar.
	if _talking and not _sleeping:
		_talk_time += delta
		var open := clampf(0.45 + 0.55 * sin(_talk_time * 16.0) * absf(sin(_talk_time * 4.1)), 0.0, 1.0)
		mouth_goal = Vector2(0.5 + 0.4 * sin(_talk_time * 5.3), open)
	_mouth = _mouth.lerp(mouth_goal, 1.0 - exp(-delta * 22.0))

	# Parpadeo
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.5)
	_blink = maxf(0.0, _blink - delta * 7.0)
	var blink_now := (1.0 - absf(_blink * 2.0 - 1.0)) if _blink > 0.0 else 0.0
	var eyes := maxf(_eyes, blink_now)

	# Vida propia: respira y se mece un poco.
	var sway := Vector2(sin(_time * 0.7) * 0.12, sin(_time * 0.53 + 1.0) * 0.1)
	var breath := 0.5 + 0.5 * sin(_time * 1.8)
	var walk_bob := absf(sin(_time * 9.0)) * 0.025 * absf(_walk)
	var p := _puppet
	p.set_param(P_HEAD, _head.x + act_head.x + sway.x + _walk * 0.5, _head.y + act_head.y + sway.y)
	p.set_param(P_HEAD_ROLL, _roll + act_roll + sin(_time * 0.9) * 0.05 + act_shake * 0.08)
	p.set_param(P_BODY, act_body.x + sway.x * 0.5 + _walk * 0.6, act_body.y + sway.y * 0.4)
	p.set_param(P_BODY_ROLL, sin(_time * 9.0) * 0.25 * absf(_walk) + act_shake * 0.15)
	p.set_param(P_BODY_X, act_shake * 0.2)
	p.set_param(P_MOUTH, _mouth.x, _mouth.y)
	p.set_param(P_BLINK_L, eyes)
	p.set_param(P_BLINK_R, eyes)
	p.set_param(P_EYE_L, clampf(_head.x * 0.5, -1.0, 1.0))
	p.set_param(P_EYE_R, clampf(_head.x * 0.5, -1.0, 1.0))
	p.set_param(P_BREATH, breath)
	p.set_param(P_ARM_L, act_arm_l)
	p.set_param(P_ARM_R, act_arm_r)
	p.set_node_offset("Eyebrow:: Left", Vector2(0, _brow_y), -_brow)
	p.set_node_offset("Eyebrow:: Right", Vector2(0, _brow_y), _brow)
	p.set_node_opacity("blush", _blush)
	if _in_bed:
		_lie_in_bed()
	else:
		p.position.y = act_jump + walk_bob
		p.scale = Vector3.ONE * (1.0 + act_zoom)
	p.set_tint(Color(0.6, 0.6, 0.8) if _sleeping else (Color(0.86, 0.84, 0.95) if _night else Color.WHITE))
	p.update(delta)
	if _sleeping:
		_foreground.queue_redraw()


## Acostada de lado sobre la cama: pies a la izquierda, cabeza en la almohada.
func _lie_in_bed() -> void:
	var bed := room.bed_rect()
	var meters_per_pixel := VIEW_HEIGHT / maxf(1.0, size.y)
	# Más larga que la cama: el cuerpo queda bajo la cobija y la cara, que
	# está al 80 % de su altura, justo sobre la almohada.
	var length_px := bed.size.x * 1.45
	var length := length_px * meters_per_pixel
	var feet := Vector2(bed.position.x + bed.size.x * 0.7 - length_px * 0.8, bed.position.y + bed.size.y * 0.2)
	_puppet.scale = Vector3.ONE * (length / MODEL_HEIGHT)
	_puppet.rotation.z = -PI / 2.0
	_puppet.position = Vector3(_screen_to_world_x(global_position.x + feet.x), VIEW_TOP - feet.y * meters_per_pixel, 0.0)


## Lo que va por delante de ella: la cobija y las "Zzz".
func _draw_foreground() -> void:
	if not _sleeping:
		return
	if _in_bed:
		var bed := room.bed_rect()
		var blanket := StyleBoxFlat.new()
		var theme: Dictionary = RoomBackground.THEMES[room.theme_id]
		var color: Color = theme["curtain"].lightened(0.1)
		color.a = 1.0
		blanket.bg_color = color
		blanket.set_corner_radius_all(18)
		_foreground.draw_style_box(blanket, Rect2(bed.position.x - bed.size.x * 0.44, bed.position.y - bed.size.y * 0.45, bed.size.x * 1.0, bed.size.y * 1.3))
		var fold := StyleBoxFlat.new()
		fold.bg_color = Color(1, 1, 1, 0.85)
		fold.set_corner_radius_all(10)
		_foreground.draw_style_box(fold, Rect2(bed.position.x + bed.size.x * 0.5, bed.position.y - bed.size.y * 0.45, bed.size.x * 0.07, bed.size.y * 1.3))
	var head := _world_to_screen(_puppet.node_position("Face")) - global_position
	var font := get_theme_default_font()
	for i in 3:
		var phase := fmod(_time * 0.5 + i * 0.33, 1.0)
		var at := head + Vector2(30 + phase * 46.0, -40 - phase * 70.0)
		_foreground.draw_string(font, at, "z" if i < 2 else "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 + phase * 14.0), Color(1, 1, 1, 1.0 - phase))


# --- Construcción ------------------------------------------------------------------------

func _build_viewport() -> void:
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	resized.connect(_update_render_scale)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_container.add_child(_viewport)

	_foreground = Control.new()
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foreground.draw.connect(_draw_foreground)
	add_child(_foreground)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = VIEW_HEIGHT
	_camera.position = Vector3(0.0, VIEW_TOP - VIEW_HEIGHT / 2.0, 5.0)
	_viewport.add_child(_camera)


## Se dibuja a la resolución real de la pantalla para que se vea nítido.
func _update_render_scale() -> void:
	if _container == null:
		return
	var factor := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 3.0)
	_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_container.size = size * factor
	_container.scale = Vector2.ONE / factor


## Rubor: dos manchas rosadas suaves sobre las mejillas, recortadas a la cara.
func _add_blush() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.35, 0.45, 0.6))
	gradient.set_color(1, Color(1.0, 0.35, 0.45, 0.0))
	var spot := GradientTexture2D.new()
	spot.gradient = gradient
	spot.fill = GradientTexture2D.FILL_RADIAL
	spot.fill_from = Vector2(0.5, 0.5)
	spot.fill_to = Vector2(0.5, 0.0)
	spot.width = 128
	spot.height = 128
	# Una sola capa ancha con las dos mejillas.
	var image := Image.create(512, 128, false, Image.FORMAT_RGBA8)
	var source := spot.get_image()
	if source == null:
		return
	source.convert(Image.FORMAT_RGBA8)
	image.blit_rect(source, Rect2i(0, 0, 128, 128), Vector2i(0, 0))
	image.blit_rect(source, Rect2i(0, 0, 128, 128), Vector2i(384, 0))
	_puppet.add_overlay("blush", "Face", ImageTexture.create_from_image(image), Vector2(10, 190), Vector2(520, 130), -0.05, "Face")
