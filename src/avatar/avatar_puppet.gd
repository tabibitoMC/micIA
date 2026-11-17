class_name AvatarPuppet
extends Avatar
## Avatar 2D estilo VTuber: una marioneta por capas (Puppet) con físicas en
## el pelo, parpadeo, boca al hablar, emociones y gestos con los brazos.
##
## Se dibuja en un SubViewport transparente con cámara ortográfica, encima
## del fondo de la casa (RoomBackground).

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
const P_BODY_X := "Body:: X:: Move"

## Brazos: nodo y hombro (pivote en píxeles del nodo). El brazo "Left" del
## modelo queda a la derecha de la pantalla. Los ángulos de abajo son para
## el izquierdo; el derecho usa el signo contrario (ver _apply_arms).
const ARM_L := "Arm:: Left"
const ARM_R := "Arm:: Right"
const ARM_L_PIVOT := Vector2(-215, -1075)
const ARM_R_PIVOT := Vector2(203, -1117)
## Codos (a medio camino entre hombro y muñeca) y manos.
const ARM_L_ELBOW := Vector2(115, -486)
const ARM_R_ELBOW := Vector2(-64, -433)
## Cola: base (cadera), curva del medio y física propia con resorte.
const TAIL := "Tail"
const TAIL_BASE := Vector2(-920, -830)
const TAIL_MIDDLE := Vector2(-145, 570)
## Emoción -> [amplitud del meneo, velocidad, caída (positivo = baja)]
const TAIL_MOOD := {
	"feliz": [0.16, 3.2, -0.04], "coqueta": [0.12, 2.0, -0.05], "sorprendida": [0.04, 1.0, -0.12],
	"enojada": [0.05, 4.5, -0.1], "triste": [0.03, 0.7, 0.14], "avergonzada": [0.07, 2.4, 0.04],
	"pensativa": [0.05, 0.9, 0.0], "neutral": [0.07, 1.3, 0.0],
}
const HAND_L := "Hand:: Left"
const HAND_R := "Hand:: Right"
## Poses de brazo: [hombro, codo] en radianes. Hombro: negativo = abre el
## brazo hacia afuera. Codo: positivo = flexiona hacia el cuerpo.
##
## Este modelo tiene UN solo dibujo de cada brazo (colgando). Los riggers de
## Live2D, para levantar los brazos, dibujan brazos aparte y los intercambian;
## doblar el mismo dibujo mucho se ve deforme. Por eso aquí los brazos solo
## se mueven en ángulos pequeños (ARM_LIMITS) y los gestos grandes se hacen
## con el cuerpo, la cabeza y la cara.
const POSE_REST := Vector2(0.0, 0.04)
const POSE_CROSSED := Vector2(0.06, 0.18)
const POSE_WAVE := Vector2(-0.22, 0.38)
const POSE_UP := Vector2(-0.26, -0.04)
const POSE_SIDE := Vector2(-0.24, 0.0)
const POSE_WINDUP := Vector2(-0.28, 0.1)
const POSE_SLAP := Vector2(0.18, 0.4)
const POSE_PALM_UP := Vector2(-0.12, 0.2)
## [mín, máx] del hombro y del codo: dentro de esto el dibujo no se deforma.
const ARM_LIMITS := [Vector2(-0.3, 0.2), Vector2(-0.05, 0.45)]
## Muñecas (dónde empieza la tela que cuelga).
const WRIST_L := Vector2(446, 102)
const WRIST_R := Vector2(-332, 250)
## Compatibilidad con mods viejos que usan estos nombres.
const ARM_CROSSED := 0.8
const ARM_SIDE := -1.3
const ARM_UP := -2.2
## Capas por delante del cuerpo cuando cruza los brazos.
const ARM_FRONT_Z := -0.5

## Emoción -> objetivos de la cara y el cuerpo.
##   eyes: cuánto cierra los ojos (0..1) · mouth: [forma, apertura]
##   head: [giro, cabeceo] · roll: inclinación · brow: giro de cejas (rad,
##   positivo = enojada) · brow_y: cejas arriba (-) o abajo (+) en px
##   arms: cuánto recoge los brazos hacia el cuerpo (-1 abiertos .. 1 cruzados)
const EMOTIONS := {
	"neutral": {"eyes": 0.0, "mouth": [0.5, 0.0], "head": [0.0, 0.0], "roll": 0.0, "brow": 0.0, "brow_y": 0.0, "arms": 0.0},
	"feliz": {"eyes": 0.85, "mouth": [1.0, 0.45], "head": [0.0, 0.1], "roll": 0.12, "brow": -0.05, "brow_y": -6.0, "arms": -0.12},
	"triste": {"eyes": 0.35, "mouth": [0.0, 0.0], "head": [0.0, -0.45], "roll": -0.1, "brow": -0.3, "brow_y": 0.0, "arms": 0.1},
	"enojada": {"eyes": 0.25, "mouth": [0.0, 0.15], "head": [0.0, -0.15], "roll": 0.0, "brow": 0.35, "brow_y": 10.0, "arms": 0.22},
	"sorprendida": {"eyes": 0.0, "mouth": [0.5, 0.9], "head": [0.0, 0.25], "roll": 0.0, "brow": 0.0, "brow_y": -16.0, "arms": -0.3},
	"avergonzada": {"eyes": 0.3, "mouth": [0.3, 0.1], "head": [0.3, -0.3], "roll": 0.15, "brow": -0.15, "brow_y": 0.0, "blush": 1.0, "arms": 0.22},
	"pensativa": {"eyes": 0.15, "mouth": [0.3, 0.0], "head": [-0.35, 0.3], "roll": -0.15, "brow": 0.1, "brow_y": -4.0, "arms": 0.15},
	"coqueta": {"eyes": 0.4, "mouth": [1.0, 0.2], "head": [0.2, -0.1], "roll": 0.25, "brow": 0.0, "brow_y": -4.0, "blush": 0.6, "arms": 0.2},
}

## Modelo a cargar (se fija antes de añadir el avatar a la escena).
var model_path := DEFAULT_MODEL_PATH
## Fondo de la casa (lo pone main.gd): ahí están los lugares y la cama.
var room: RoomBackground

var _viewport: SubViewport
var _container: SubViewportContainer
var _foreground: Control
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
var _arms := 0.0

var _time := 0.0
var _talking := false
var _talk_time := 0.0
var _blink_timer := 2.5
var _blink := 0.0
var _sleeping := false
var _in_bed := false
var _night := false
var _turned_away := false
var _action_tween: Tween

# Lo que suman los gestos (los anima play_action con tweens).
var act_head := Vector2.ZERO
var act_roll := 0.0
var act_body := Vector2.ZERO
## Pose de cada brazo: x = hombro, y = codo (convención del brazo izquierdo;
## el derecho se refleja solo).
var act_arm_l := Vector2.ZERO
var act_arm_r := Vector2.ZERO
## 1 = brazos por delante del cuerpo.
var act_front := 0.0
var act_jump := 0.0
var act_zoom := 0.0
var act_shake := 0.0
var act_lean := 0.0
var act_tears := 0.0
var _walk := 0.0
var _home_x := 0.0

# Vida propia: pequeños gestos cuando está quieta o hablando. Van aparte de
# los gestos grandes para no pisarse.
var idle_head := Vector2.ZERO
var idle_roll := 0.0
var idle_lean := 0.0
var idle_arm_l := Vector2.ZERO
var idle_arm_r := Vector2.ZERO
var _idle_timer := 2.0
var _idle_tween: Tween
var _eye_target := 0.0
var _eye := 0.0
var _eye_timer := 1.0
var _arm_lag_l := Vector2.ZERO
var _arm_lag_r := Vector2.ZERO
var _arm_lag_speed_l := Vector2.ZERO
var _arm_lag_speed_r := Vector2.ZERO
var _arm_last_pos := Vector2.ZERO
var _arm_last_lean := 0.0
var _tail_angle := 0.0
var _tail_speed := 0.0
var _tail_mood: Array = TAIL_MOOD["neutral"]
var _last_x := 0.0
var _ear_timer := 3.0
var _voice_level := -1.0
var _voice_level_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_viewport()
	var path := model_path if model_path.ends_with(".puppet") else DEFAULT_MODEL_PATH
	# Calidad normal: versión con menos vértices (nombre_normal.puppet).
	if not bool(Settings.get_value("avatar_high_quality")):
		var lighter := path.trim_suffix(".puppet") + "_normal.puppet"
		if FileAccess.file_exists(lighter):
			path = lighter
	_puppet = Puppet.new()
	_viewport.add_child(_puppet)
	_ready_ok = _puppet.load_file(path)
	if not _ready_ok:
		return
	_puppet.fit_height(MODEL_HEIGHT)
	# Física más suelta y con más rebote en pelo, orejas, falda y mangas.
	_puppet.physics_gain = 1.7
	_puppet.damping_scale = 0.6
	_add_sways()
	_add_blush()
	_add_tears()
	_puppet.update(0.0)


func is_ready() -> bool:
	return _ready_ok


func set_emotion(emotion: String) -> void:
	_goal = EMOTIONS.get(emotion, EMOTIONS["neutral"])
	_tail_mood = TAIL_MOOD.get(emotion, TAIL_MOOD["neutral"])
	# Un cambio de emoción sacude un poco las orejas.
	_twitch_ears(1.0)


func set_talking(talking: bool) -> void:
	_talking = talking
	if talking:
		_idle_timer = 0.3
	else:
		_voice_level = -1.0


func set_mouth_level(level: float) -> void:
	_voice_level = level
	_voice_level_time = _time


## El conjunto de ropa gira el tono de la ropa (hacia el color de `cloth`).
func apply_tint(cloth: Color, _hair: Color) -> void:
	if not _ready_ok:
		return
	var shift := 0.0 if cloth == Color.WHITE else cloth.h
	_puppet.set_hue(["Skirt", "Ribbon"], shift)


# --- Gestos -------------------------------------------------------------------------

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
			t.tween_property(self, "act_arm_l", POSE_WAVE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "act_roll", 0.18, 0.35)
			t.parallel().tween_property(self, "act_lean", 0.25, 0.35)
			t.parallel().tween_property(self, "act_jump", 0.02, 0.35)
			for i in 3:
				t.tween_property(self, "act_arm_l", POSE_WAVE + Vector2(-0.07, 0.06), 0.16).set_trans(Tween.TRANS_SINE)
				t.parallel().tween_property(self, "act_roll", 0.26, 0.16)
				t.tween_property(self, "act_arm_l", POSE_WAVE + Vector2(0.07, -0.06), 0.16).set_trans(Tween.TRANS_SINE)
				t.parallel().tween_property(self, "act_roll", 0.12, 0.16)
			t.tween_property(self, "act_arm_l", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.45)
			t.parallel().tween_property(self, "act_lean", 0.0, 0.45)
			t.parallel().tween_property(self, "act_jump", 0.0, 0.45)
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
			t.parallel().tween_property(self, "act_arm_l", Vector2(-0.6, -0.5), 0.18)
			t.parallel().tween_property(self, "act_arm_r", Vector2(-0.6, -0.5), 0.18)
			t.tween_property(self, "act_jump", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
			t.parallel().tween_property(self, "act_arm_l", Vector2.ZERO, 0.4)
			t.parallel().tween_property(self, "act_arm_r", Vector2.ZERO, 0.4)
		"celebrar":
			t.tween_property(self, "act_arm_l", POSE_UP, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "act_arm_r", POSE_UP, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for i in 3:
				t.tween_property(self, "act_jump", 0.12, 0.16).set_ease(Tween.EASE_OUT)
				t.parallel().tween_property(self, "act_arm_l", POSE_UP + Vector2(0.12, -0.25), 0.16)
				t.parallel().tween_property(self, "act_arm_r", POSE_UP + Vector2(0.12, -0.25), 0.16)
				t.tween_property(self, "act_jump", 0.0, 0.2).set_ease(Tween.EASE_IN)
				t.parallel().tween_property(self, "act_arm_l", POSE_UP, 0.2)
				t.parallel().tween_property(self, "act_arm_r", POSE_UP, 0.2)
			t.tween_property(self, "act_arm_l", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_arm_r", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_SINE)
		"cruzar_brazos":
			t.tween_property(self, "act_arm_l", POSE_CROSSED, 0.4).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_arm_r", POSE_CROSSED + Vector2(0.0, 0.1), 0.4).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_head:x", 0.6, 0.4)
			t.parallel().tween_property(self, "act_roll", -0.22, 0.4)
			t.parallel().tween_property(self, "act_lean", -0.3, 0.4)
			t.parallel().tween_property(self, "act_head:y", 0.15, 0.4)
			t.tween_interval(2.4)
			t.tween_property(self, "act_arm_l", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_arm_r", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_head:x", 0.0, 0.5)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.5)
			t.parallel().tween_property(self, "act_lean", 0.0, 0.5)
			t.parallel().tween_property(self, "act_head:y", 0.0, 0.5)
		"abrazar":
			# Abre los brazos para recibirte y se acerca a la pantalla.
			t.tween_property(self, "act_arm_l", POSE_SIDE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "act_arm_r", POSE_SIDE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "act_zoom", 0.2, 0.5).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", 0.18, 0.5)
			t.parallel().tween_property(self, "act_head:y", -0.25, 0.5)
			t.tween_interval(1.4)
			t.tween_property(self, "act_arm_l", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_arm_r", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_zoom", 0.0, 0.5)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.5)
			t.parallel().tween_property(self, "act_head:y", 0.0, 0.5)
		"golpear":
			# Cachetada: toma impulso con el codo arriba y suelta el golpe.
			t.tween_property(self, "act_arm_r", POSE_WINDUP, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "act_lean", 0.5, 0.24)
			t.parallel().tween_property(self, "act_zoom", -0.06, 0.24)
			t.tween_callback(func(): act_front = 1.0)
			t.tween_property(self, "act_arm_r", POSE_SLAP, 0.09)
			t.parallel().tween_property(self, "act_zoom", 0.4, 0.09)
			t.parallel().tween_property(self, "act_lean", -0.6, 0.09)
			t.tween_callback(func(): struck.emit())
			t.tween_interval(0.3)
			t.tween_property(self, "act_arm_r", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_zoom", 0.0, 0.4)
			t.parallel().tween_property(self, "act_lean", 0.0, 0.4)
			t.tween_callback(func(): act_front = 0.0)
		"llorar":
			# Cabeza gacha, brazos caídos y un poco recogidos, hombros que tiemblan.
			t.tween_property(self, "act_head:y", -0.8, 0.4)
			t.parallel().tween_property(self, "act_arm_l", Vector2(-0.05, 0.12), 0.45).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_arm_r", Vector2(-0.05, 0.12), 0.45).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_tears", 1.0, 0.4)
			for i in 9:
				t.tween_property(self, "act_shake", 1.0, 0.11)
				t.tween_property(self, "act_shake", -1.0, 0.11)
			t.tween_property(self, "act_shake", 0.0, 0.1)
			t.tween_property(self, "act_head:y", 0.0, 0.5)
			t.parallel().tween_property(self, "act_arm_l", Vector2.ZERO, 0.5)
			t.parallel().tween_property(self, "act_arm_r", Vector2.ZERO, 0.5)
			t.parallel().tween_property(self, "act_tears", 0.0, 1.2)
		"mirar_otro_lado":
			t.tween_property(self, "act_head:x", -0.9, 0.3).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", -0.15, 0.3)
			t.parallel().tween_property(self, "act_lean", 0.3, 0.3)
			t.tween_interval(1.6)
			t.tween_property(self, "act_head:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(self, "act_roll", 0.0, 0.4)
			t.parallel().tween_property(self, "act_lean", 0.0, 0.4)
		_:
			t.kill()


func _reset_actions() -> void:
	if _idle_tween:
		_idle_tween.kill()
	idle_head = Vector2.ZERO
	idle_roll = 0.0
	idle_lean = 0.0
	idle_arm_l = Vector2.ZERO
	idle_arm_r = Vector2.ZERO
	act_head = Vector2.ZERO
	act_roll = 0.0
	act_body = Vector2.ZERO
	act_arm_l = Vector2.ZERO
	act_arm_r = Vector2.ZERO
	act_front = 0.0
	act_jump = 0.0
	act_zoom = 0.0
	act_shake = 0.0
	act_lean = 0.0
	act_tears = 0.0


# --- Movimiento por la pantalla ---------------------------------------------------

func walk_to_screen_x(x: float) -> void:
	if not _ready_ok or _in_bed:
		return
	await _walk_to(_screen_to_world_x(x))


func go_home() -> void:
	if _ready_ok and not _in_bed:
		await _walk_to(_home_x)


## Señala un punto de la pantalla con el brazo de ese lado.
func point_at_screen(point: Vector2, seconds := 1.0) -> void:
	if not _ready_ok or _in_bed:
		return
	var shoulder := _world_to_screen(_puppet.node_position("Body", Vector2(0, -330)))
	var right_side := point.x > shoulder.x
	var offset := point - shoulder
	# Ángulo del brazo medido desde "colgando hacia abajo".
	var from_down := atan2(absf(offset.x), offset.y)
	# El brazo solo se abre un poco hacia ese lado; el resto lo hacen el
	# cuerpo y la cabeza (girándose hacia el botón).
	var rotation := -clampf(from_down - 0.35, 0.0, 2.5) * 0.15
	var arm := "act_arm_l" if right_side else "act_arm_r"
	var t := create_tween()
	# Brazo casi recto, con el codo apenas doblado.
	t.tween_property(self, arm, Vector2(rotation, 0.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "act_head", Vector2(0.75 if right_side else -0.75, 0.35), 0.3)
	t.parallel().tween_property(self, "act_lean", 0.45 if right_side else -0.45, 0.3)
	t.tween_interval(seconds)
	t.tween_property(self, arm, Vector2.ZERO, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "act_head", Vector2.ZERO, 0.3)
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
	if _ready_ok:
		_puppet.position.x = _view_half_width() * (-1.3 if from_left else 1.3)
		_puppet.reset_physics()


func walk_out(to_right: bool) -> void:
	if _ready_ok and not _in_bed:
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
	if _in_bed:
		return point.distance_to(head) < size.y * 0.2
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


## Dormir: en el dormitorio se ve la cama de cerca y ella acostada y tapada.
func set_sleeping(sleeping: bool) -> void:
	if sleeping == _sleeping or not _ready_ok:
		return
	_sleeping = sleeping
	_in_bed = sleeping and room != null and room.place == "dormitorio"
	if _action_tween:
		_action_tween.kill()
	_reset_actions()
	_puppet.physics_enabled = not _in_bed
	_puppet.set_node_opacity("Tail", 0.0 if _in_bed else 1.0)
	if room:
		room.set_sleep_view(_in_bed)
	if not _in_bed:
		_puppet.rotation.z = 0.0
		_puppet.scale = Vector3.ONE
		_puppet.position = Vector3(_home_x, 0.0, 0.0)
		_puppet.reset_physics()
	_foreground.queue_redraw()


func is_sleeping() -> bool:
	return _sleeping


## Acostada de lado: pies a la izquierda (bajo la cobija), cara en la almohada.
func _lie_in_bed() -> void:
	var spot := room.sleep_spot()
	var meters_per_pixel := VIEW_HEIGHT / maxf(1.0, size.y)
	var length_px: float = spot["length"]
	var head: Vector2 = spot["head"]
	# La cara está más o menos al 80 % de su altura.
	var feet := Vector2(head.x - length_px * 0.8, head.y)
	_puppet.scale = Vector3.ONE * (length_px * meters_per_pixel / MODEL_HEIGHT)
	_puppet.rotation.z = -PI / 2.0
	_puppet.position = Vector3(_screen_to_world_x(global_position.x + feet.x), VIEW_TOP - feet.y * meters_per_pixel, 0.0)


## Lo que va por delante de ella: la cobija y las "Zzz".
func _draw_foreground() -> void:
	if not _sleeping:
		return
	var canvas := _foreground
	if _in_bed:
		var rect := room.blanket_rect()
		var color := room.blanket_color()
		if _night:
			color = color.darkened(0.25)
		# Cobija con el bulto del cuerpo: borde de arriba ondulado.
		var points := PackedVector2Array([Vector2(rect.position.x, rect.end.y)])
		for i in 17:
			var f := i / 16.0
			var bump := sin(f * PI * 0.9 + 0.3) * rect.size.y * 0.1 + sin(f * 9.0) * 3.0
			points.append(Vector2(rect.position.x + rect.size.x * f, rect.position.y - bump))
		points.append(rect.end)
		canvas.draw_colored_polygon(points, color)
		# Franjas y doblez
		for i in 4:
			var x := rect.position.x + rect.size.x * (0.14 + i * 0.2)
			canvas.draw_line(Vector2(x, rect.position.y + 4), Vector2(x - 14, rect.end.y), Color(1, 1, 1, 0.22), 14.0)
		var fold := StyleBoxFlat.new()
		fold.bg_color = Color(1, 1, 1, 0.92) if not _night else Color(0.82, 0.8, 0.95)
		fold.set_corner_radius_all(14)
		canvas.draw_style_box(fold, Rect2(rect.end.x - 12, rect.position.y - rect.size.y * 0.08, size.x * 0.06, rect.size.y * 1.08))
		canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 2, rect.size.x + size.x * 0.05, 6), color.darkened(0.12))
	var head := _world_to_screen(_puppet.node_position("Face")) - global_position
	var font := get_theme_default_font()
	for i in 3:
		var phase := fmod(_time * 0.45 + i * 0.33, 1.0)
		var at := head + Vector2(size.x * 0.1 + phase * 50.0, -size.y * 0.09 - phase * 80.0)
		canvas.draw_string(font, at, "z" if i < 2 else "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 + phase * 18.0), Color(1, 1, 1, sin(phase * PI)))


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
	var arms_goal: float = goal.get("arms", 0.0)
	if _sleeping:
		eyes_goal = 1.0
		head_goal = Vector2(0.15, -0.25) if _in_bed else Vector2(0.2, -0.6)
		roll_goal = 0.0 if _in_bed else 0.35
		mouth_goal = Vector2(0.5, 0.04)
		arms_goal = 0.75 if _in_bed else 0.3
	elif _turned_away:
		# Bloqueada: brazos cruzados, ojos cerrados y la cara para otro lado.
		eyes_goal = 1.0
		head_goal = Vector2(-1.0, 0.2)
		roll_goal = -0.2
		mouth_goal = Vector2(0.0, 0.0)
		arms_goal = 1.0
	_eyes = lerpf(_eyes, eyes_goal, k)
	_head = _head.lerp(head_goal, k)
	_roll = lerpf(_roll, roll_goal, k)
	_arms = lerpf(_arms, arms_goal, 1.0 - exp(-delta * 5.0))
	_brow = lerpf(_brow, float(goal["brow"]), k)
	_brow_y = lerpf(_brow_y, float(goal["brow_y"]), k)
	_blush = lerpf(_blush, float(goal.get("blush", 0.0)), k)

	# Boca: se abre y cierra al hablar.
	if _talking and not _sleeping:
		_talk_time += delta
		var open := clampf(0.45 + 0.55 * sin(_talk_time * 16.0) * absf(sin(_talk_time * 4.1)), 0.0, 1.0)
		if _voice_level >= 0.0 and _time - _voice_level_time < 0.3:
			# Con voz real: la boca sigue el volumen del audio.
			open = _voice_level
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

	_update_idle(delta)
	# Mirada: los ojos saltan de vez en cuando a otro punto (como una persona).
	_eye_timer -= delta
	if _eye_timer <= 0.0:
		_eye_timer = randf_range(0.8, 3.0)
		_eye_target = 0.0 if randf() < 0.45 else randf_range(-0.7, 0.7)
	_eye = lerpf(_eye, _eye_target, 1.0 - exp(-delta * 25.0))

	# Vida propia: respira y se mece un poco (dormida, apenas).
	var calm := 0.25 if _sleeping else 1.0
	var sway := Vector2(sin(_time * 0.7) * 0.12, sin(_time * 0.53 + 1.0) * 0.1) * calm
	var breath := 0.5 + 0.5 * sin(_time * (1.2 if _sleeping else 1.8))
	var walk_bob := absf(sin(_time * 9.0)) * 0.025 * absf(_walk)
	var talk_nod := sin(_talk_time * 7.0) * 0.06 if _talking else 0.0
	var p := _puppet
	var head_x := _head.x + act_head.x + idle_head.x + sway.x + _walk * 0.5
	p.set_param(P_HEAD, head_x, _head.y + act_head.y + idle_head.y + sway.y + talk_nod)
	p.set_param(P_HEAD_ROLL, _roll + act_roll + idle_roll + sin(_time * 0.9) * 0.05 * calm + act_shake * 0.08)
	p.set_param(P_BODY, act_body.x + act_lean + idle_lean + sway.x * 0.5 + _walk * 0.6, act_body.y + sway.y * 0.4)
	p.set_param(P_BODY_ROLL, sin(_time * 9.0) * 0.25 * absf(_walk) + act_shake * 0.15 + act_lean * 0.15)
	# Caderas que se mecen suave (más al caminar).
	p.set_param(P_BODY_X, act_shake * 0.2 + sin(_time * 0.6) * 0.07 * calm + sin(_time * 9.0) * 0.12 * absf(_walk))
	p.set_param(P_MOUTH, _mouth.x, _mouth.y)
	p.set_param(P_BLINK_L, eyes)
	p.set_param(P_BLINK_R, eyes)
	var eye := clampf(head_x * 0.4 + _eye, -1.0, 1.0)
	p.set_param(P_EYE_L, eye)
	p.set_param(P_EYE_R, eye)
	p.set_param(P_BREATH, breath)
	_apply_arms(calm)
	_update_tail(delta)
	_update_ears(delta)
	p.set_node_offset("Eyebrow:: Left", Vector2(0, _brow_y), -_brow)
	p.set_node_offset("Eyebrow:: Right", Vector2(0, _brow_y), _brow)
	p.set_node_opacity("blush", _blush)
	p.set_node_opacity("tears", act_tears)
	if _in_bed:
		_lie_in_bed()
	else:
		p.position.y = act_jump + walk_bob
		p.scale = Vector3.ONE * (1.0 + act_zoom)
	p.set_tint(Color(0.62, 0.62, 0.82) if _sleeping else (Color(0.84, 0.82, 0.95) if _night else Color.WHITE))
	p.update(delta)
	if _sleeping:
		_foreground.queue_redraw()


## Brazos: postura de la emoción + gesto + un balanceo leve. Cada brazo se
## dobla por el codo (en la GPU) y su mano sigue a la muñeca.
func _apply_arms(calm: float) -> void:
	var idle := sin(_time * 1.1) * 0.025 * calm
	var swing := sin(_time * 9.0) * 0.12 * absf(_walk)
	_update_arm_physics(get_process_delta_time())
	# La emoción recoge las manos hacia el cuerpo doblando sobre todo el codo.
	var posture := Vector2(_arms * 0.08, _arms * 0.35)
	var left: Vector2 = POSE_REST + posture + act_arm_l + idle_arm_l + Vector2(idle + swing, idle * 2.0) + _arm_lag_l
	var right: Vector2 = POSE_REST + posture + act_arm_r + idle_arm_r + Vector2(idle - swing, -idle * 2.0) + _arm_lag_r
	_bend_arm(ARM_L, HAND_L, ARM_L_PIVOT, ARM_L_ELBOW, WRIST_L, left, 1.0)
	_bend_arm(ARM_R, HAND_R, ARM_R_PIVOT, ARM_R_ELBOW, WRIST_R, right, -1.0)
	# Por delante del cuerpo en cuanto la mano se acerca al centro; si no,
	# queda escondida detrás de la falda.
	# Manos en la cintura (hombro abierto + codo doblado) quedan atrás.
	var left_front := act_front > 0.5 or (left.x > -0.2 and left.x + left.y * 0.5 > 0.5)
	var right_front := act_front > 0.5 or (right.x > -0.2 and right.x + right.y * 0.5 > 0.5)
	_puppet.set_node_z(ARM_L, ARM_FRONT_Z if left_front else 0.0)
	_puppet.set_node_z(ARM_R, ARM_FRONT_Z + 0.05 if right_front else 0.0)


## Física sutil de brazos (péndulo en hombro y codo): cuando el cuerpo se
## mueve, salta o se inclina, los brazos se quedan un poco atrás y rebotan.
func _update_arm_physics(delta: float) -> void:
	if delta <= 0.0:
		return
	var x := _puppet.position.x
	var y := _puppet.position.y
	var velocity := Vector2(x - _arm_last_pos.x, y - _arm_last_pos.y) / delta
	_arm_last_pos = Vector2(x, y)
	var lean := act_lean + idle_lean
	var lean_speed := (lean - _arm_last_lean) / delta
	_arm_last_lean = lean
	# Empuje: movimiento lateral abre un brazo y cierra el otro; subir/bajar
	# levanta un poco ambos codos; inclinarse los balancea.
	var push := clampf(-velocity.x * 0.25 - lean_speed * 0.05, -2.0, 2.0)
	var lift := clampf(velocity.y * 0.6, -2.0, 2.0)
	for side in [0, 1]:
		var lag: Vector2 = _arm_lag_l if side == 0 else _arm_lag_r
		var speed: Vector2 = _arm_lag_speed_l if side == 0 else _arm_lag_speed_r
		var sign := 1.0 if side == 0 else -1.0
		var force := Vector2(push * sign, -lift) * 1.0 - lag * 90.0 - speed * 9.0
		speed += force * delta
		lag += speed * delta
		lag = lag.clamp(Vector2(-0.12, -0.12), Vector2(0.12, 0.15))
		if side == 0:
			_arm_lag_l = lag
			_arm_lag_speed_l = speed
		else:
			_arm_lag_r = lag
			_arm_lag_speed_r = speed


## side = 1 para el brazo izquierdo del modelo, -1 para el derecho (espejo).
func _bend_arm(arm: String, hand: String, pivot: Vector2, elbow: Vector2, wrist: Vector2, pose: Vector2, side: float) -> void:
	# Dentro de lo anatómico: el codo no se dobla al revés y el hombro no
	# gira más de lo que puede.
	var limited := Vector2(
		clampf(pose.x, ARM_LIMITS[0].x, ARM_LIMITS[0].y),
		clampf(pose.y, ARM_LIMITS[1].x, ARM_LIMITS[1].y))
	var upper := limited.x * side
	var fore := limited.y * side
	_puppet.set_node_offset(arm, Vector2.ZERO, 0.0)
	# Brazo y antebrazo rígidos como huesos: solo se suavizan las
	# articulaciones (hombro y codo), y la manga ancha cuelga por gravedad.
	_puppet.set_node_bend(arm, pivot, elbow, upper, fore, 70.0, 110.0, wrist, 0.75)
	var hand_at := _puppet.node_base_translation(hand)
	var moved := Puppet.bent_point(hand_at, pivot, elbow, upper, fore)
	_puppet.set_node_offset(hand, moved - hand_at, upper + fore)


## Balanceo en cadena (como las físicas de los modelos VTuber): el pelo, la
## falda y el lazo siguen a la cabeza y al cuerpo con retraso y rebote.
func _add_sways() -> void:
	for node_name in _puppet.part_names():
		var lower: String = str(node_name).to_lower()
		if lower.contains("shadow") or lower.contains("light") or lower.contains("ligth"):
			continue
		if lower.contains("hair"):
			_puppet.add_sway(node_name, 38.0, 4.0, 1.5, 0.18)
		elif lower.begins_with("skirt"):
			_puppet.add_sway(node_name, 26.0, 3.2, 1.1, 0.12)
		elif lower.begins_with("ribbon"):
			_puppet.add_sway(node_name, 22.0, 2.6, 1.4, 0.25)


## Cola con resorte: menea según la emoción y se queda atrás cuando ella se
## mueve, salta o gira (luego rebota).
func _update_tail(delta: float) -> void:
	if _in_bed or delta <= 0.0:
		return
	var amplitude: float = _tail_mood[0]
	var speed: float = _tail_mood[1]
	var droop: float = _tail_mood[2]
	if _sleeping:
		amplitude = 0.01
	var target := droop + sin(_time * speed) * amplitude + sin(_time * speed * 0.37) * amplitude * 0.4
	# Inercia: si el cuerpo se mueve, la cola se atrasa.
	var x := _puppet.position.x
	var body_speed := (x - _last_x) / delta
	_last_x = x
	var force := (target - _tail_angle) * 60.0 - _tail_speed * 7.0 - body_speed * 6.0 - act_jump * 40.0
	_tail_speed += force * delta
	_tail_angle = clampf(_tail_angle + _tail_speed * delta, -0.6, 0.6)
	_puppet.set_node_bend(TAIL, TAIL_BASE, TAIL_MIDDLE, _tail_angle * 0.45, _tail_angle * 0.9, 300.0)


## Las orejas se sacuden solas de vez en cuando.
func _update_ears(delta: float) -> void:
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(3.0, 8.0)
		_twitch_ears(randf_range(0.6, 1.2))


func _twitch_ears(strength: float) -> void:
	if not _ready_ok or _sleeping:
		return
	var which := randi() % 3
	if which != 1:
		_puppet.nudge_physics("Ear:: Left:: Physics", Vector2(randf_range(-1, 1), -1.0) * 900.0 * strength)
	if which != 0:
		_puppet.nudge_physics("Ear:: Right:: Physics", Vector2(randf_range(-1, 1), -1.0) * 900.0 * strength)


## Pequeños gestos al azar: así nunca se queda congelada.
func _update_idle(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer > 0.0:
		return
	var busy := (_action_tween and _action_tween.is_running()) or absf(_walk) > 0.01
	if _sleeping or _in_bed or busy:
		_idle_timer = 1.0
		return
	if _talking:
		_idle_timer = randf_range(0.7, 1.6)
		_talk_gesture()
	else:
		_idle_timer = randf_range(2.5, 6.0)
		_idle_gesture()


func _new_idle_tween() -> Tween:
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _idle_tween


## Al hablar: acentos con la cabeza y, a veces, un ademán con una mano.
func _talk_gesture() -> void:
	var t := _new_idle_tween()
	var head := Vector2(randf_range(-0.35, 0.35), randf_range(-0.15, 0.25))
	t.tween_property(self, "idle_head", head, 0.35)
	t.tween_property(self, "idle_roll", randf_range(-0.12, 0.12), 0.4)
	var r := randf()
	if r < 0.3:
		t.tween_property(self, "idle_arm_l", POSE_PALM_UP * randf_range(0.6, 1.2), 0.35)
		t.chain().tween_property(self, "idle_arm_l", Vector2.ZERO, 0.5).set_delay(0.3)
	elif r < 0.6:
		t.tween_property(self, "idle_arm_r", POSE_PALM_UP * randf_range(0.6, 1.2), 0.35)
		t.chain().tween_property(self, "idle_arm_r", Vector2.ZERO, 0.5).set_delay(0.3)
	elif r < 0.75:
		t.tween_property(self, "idle_lean", randf_range(-0.3, 0.3), 0.5)


## Quieta: mira a un lado, ladea la cabeza, cambia el peso de pierna, se
## acomoda, mira arriba pensando... y vuelve a su postura.
func _idle_gesture() -> void:
	var t := _new_idle_tween()
	var hold := randf_range(0.8, 2.0)
	match randi() % 7:
		0:  # mirar a un lado
			var side := randf_range(0.4, 0.8) * (1.0 if randf() < 0.5 else -1.0)
			t.tween_property(self, "idle_head", Vector2(side, randf_range(-0.1, 0.15)), 0.45)
			_eye_target = side * 0.6
		1:  # ladear la cabeza
			t.tween_property(self, "idle_roll", randf_range(0.15, 0.25) * (1.0 if randf() < 0.5 else -1.0), 0.6)
			t.tween_property(self, "idle_head", Vector2(randf_range(-0.2, 0.2), 0.1), 0.6)
		2:  # cambiar el peso de pierna
			t.tween_property(self, "idle_lean", randf_range(0.25, 0.45) * (1.0 if randf() < 0.5 else -1.0), 0.9)
			t.tween_property(self, "idle_roll", randf_range(-0.08, 0.08), 0.9)
			hold += 1.5
		3:  # mirar arriba, pensativa
			t.tween_property(self, "idle_head", Vector2(randf_range(-0.4, 0.4), 0.5), 0.6)
			_eye_target = randf_range(-0.5, 0.5)
		4:  # acomodarse la ropa / estirar un brazo
			# Se acomoda la manga: lleva una mano hacia el centro.
			var arm := "idle_arm_l" if randf() < 0.5 else "idle_arm_r"
			t.tween_property(self, arm, Vector2(0.05, 0.3), 0.5)
			t.tween_property(self, "idle_head", Vector2(0, -0.3), 0.5)
			t.chain().tween_property(self, arm, Vector2.ZERO, 0.5).set_delay(0.6)
		5:  # pequeño balanceo alegre
			t.tween_property(self, "idle_lean", 0.25, 0.4)
			t.chain().tween_property(self, "idle_lean", -0.25, 0.5)
			t.chain().tween_property(self, "idle_lean", 0.0, 0.4)
		_:  # mirarte de frente con la cabeza un poco ladeada
			t.tween_property(self, "idle_head", Vector2(0, 0.08), 0.4)
			t.tween_property(self, "idle_roll", randf_range(-0.1, 0.1), 0.4)
	# Volver a la postura normal.
	var back := t.chain().set_parallel()
	back.tween_property(self, "idle_head", Vector2.ZERO, 0.7).set_delay(hold)
	back.tween_property(self, "idle_roll", 0.0, 0.7).set_delay(hold)
	back.tween_property(self, "idle_lean", 0.0, 0.8).set_delay(hold)


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


## Mancha redonda y suave de un color (para rubor y lágrimas).
static func _soft_spot(color: Color, width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var d := Vector2((x + 0.5) / width - 0.5, (y + 0.5) / height - 0.5).length() * 2.0
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * clampf(1.0 - d, 0.0, 1.0)))
	return image


## Rubor: dos manchas rosadas sobre las mejillas, recortadas a la cara.
func _add_blush() -> void:
	var spot := _soft_spot(Color(1.0, 0.35, 0.45, 0.65), 48, 48)
	var image := Image.create(192, 48, false, Image.FORMAT_RGBA8)
	image.blit_rect(spot, Rect2i(0, 0, 48, 48), Vector2i(0, 0))
	image.blit_rect(spot, Rect2i(0, 0, 48, 48), Vector2i(144, 0))
	_puppet.add_overlay("blush", "Face", ImageTexture.create_from_image(image), Vector2(10, 190), Vector2(520, 130), -0.05, "Face")


## Lágrimas: dos hilos celestes que bajan desde los ojos.
func _add_tears() -> void:
	var drop := _soft_spot(Color(0.55, 0.82, 1.0, 0.95), 12, 64)
	var image := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	image.blit_rect(drop, Rect2i(0, 0, 12, 64), Vector2i(8, 0))
	image.blit_rect(drop, Rect2i(0, 0, 12, 64), Vector2i(76, 0))
	_puppet.add_overlay("tears", "Face", ImageTexture.create_from_image(image), Vector2(12, 235), Vector2(440, 250), -0.06, "Face")
