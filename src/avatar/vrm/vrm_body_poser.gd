class_name VrmBodyPoser
extends RefCounted
## Pone el cuerpo del modelo VRM en pose y lo anima sin archivos de animación.
##
## Los modelos VRM vienen en pose "T" (brazos estirados). Aquí se bajan los
## brazos, se añade respiración y balanceo, y se generan las acciones
## (saludar, asentir, negar, cruzar brazos...) moviendo huesos por código.
##
## Todas las direcciones se calculan en el espacio del esqueleto y se apuntan
## los huesos con "shortest arc", así funciona con cualquier modelo VRM sin
## importar cómo estén orientados sus huesos.

## Huesos humanoides estándar (nombres del perfil humanoide de Godot).
const ARM_BONES := ["LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"]
const TORSO_BONES := ["Spine", "Chest", "UpperChest", "Neck", "Head"]
const LEG_BONES := ["LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"]

## Parámetros animables (los modifica Avatar3D con tweens).
var head_pitch := 0.0   # + = mirar abajo (asentir)
var head_yaw := 0.0     # girar la cabeza a los lados
var head_roll := 0.0    # inclinar la cabeza
var body_lean := 0.0    # inclinar el torso a los lados
var wave := 0.0         # 0..1 brazo derecho levantado saludando
var wave_swing := 0.0   # vaivén de la mano al saludar
var arms_crossed := 0.0 # 0..1 brazos cruzados
var walk_amount := 0.0  # 0..1 intensidad de la caminata (la fase avanza sola)
var point_amount := 0.0 # 0..1 brazo señalando hacia point_direction
var point_direction := Vector3.FORWARD  # espacio del esqueleto
var point_side := "Right"

var _skeleton: Skeleton3D
var _bones: Dictionary = {}   # nombre -> índice
var _forward := Vector3.FORWARD
var _right := Vector3.RIGHT
var _time := 0.0
var _walk_phase := 0.0


func _init(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	for bone_name in ARM_BONES + TORSO_BONES + LEG_BONES + ["LeftHand", "RightHand", "Hips", "LeftFoot", "RightFoot"]:
		var index := skeleton.find_bone(bone_name)
		if index != -1:
			_bones[bone_name] = index
	_detect_orientation()


func is_valid() -> bool:
	return _bones.has("Head") and _bones.has("LeftUpperArm") and _bones.has("RightUpperArm")


## Dirección hacia la que mira el personaje (espacio del esqueleto).
func forward() -> Vector3:
	return _forward


## Posición global del hueso de la cabeza (para encuadrar la cámara).
func head_global_position() -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_bones["Head"]).origin


func bone_global_position(bone_name: String) -> Vector3:
	var bone := _skeleton.find_bone(bone_name)
	if bone == -1:
		return hips_global_position()
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin


func hips_global_position() -> Vector3:
	var hips: int = _bones.get("Hips", _bones["Head"])
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(hips).origin


## Altura extra del cuerpo durante la caminata (rebote), en metros.
func walk_bounce() -> float:
	return absf(sin(_walk_phase)) * 0.025 * walk_amount


## Convierte una dirección del mundo al espacio del esqueleto.
func world_to_skeleton_direction(direction: Vector3) -> Vector3:
	return (_skeleton.global_transform.basis.orthonormalized().inverse() * direction).normalized()


## Posición global del hombro de un lado ("Left"/"Right").
func shoulder_global_position(side: String) -> Vector3:
	var bone: int = _bones[side + "UpperArm"]
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin


func update(delta: float) -> void:
	_time += delta
	_walk_phase += delta * 7.0 * walk_amount
	for bone_name in _bones:
		var index: int = _bones[bone_name]
		_skeleton.set_bone_pose_rotation(index, _skeleton.get_bone_rest(index).basis.get_rotation_quaternion())

	var breath := sin(_time * 1.6)
	var sway := sin(_time * 0.7)

	# Torso: respiración, balanceo e inclinación
	_rotate_global("Spine", _right, deg_to_rad(1.2) * breath)
	_rotate_global("Spine", _forward, deg_to_rad(1.5) * sway + body_lean)
	_rotate_global("Chest", _right, deg_to_rad(0.8) * breath)

	# Cabeza
	# En este espacio, girar en positivo sobre _right levanta la cabeza; por eso el signo menos.
	_rotate_global("Neck", _right, -head_pitch * 0.4)
	_rotate_global("Head", _right, -head_pitch * 0.6 + deg_to_rad(1.0) * sin(_time * 0.9))
	_rotate_global("Head", Vector3.UP, head_yaw)
	_rotate_global("Head", _forward, head_roll + deg_to_rad(2.0) * sway)

	_pose_legs()
	_pose_arms()


func _pose_legs() -> void:
	if walk_amount <= 0.001:
		return
	for prefix in ["Left", "Right"]:
		var phase := _walk_phase + (0.0 if prefix == "Left" else PI)
		var swing := sin(phase) * deg_to_rad(28.0) * walk_amount
		# Rodilla: se dobla al llevar la pierna hacia adelante
		var knee := maxf(0.0, sin(phase + 0.9)) * deg_to_rad(40.0) * walk_amount
		_rotate_global(prefix + "UpperLeg", _right, swing)
		_rotate_global(prefix + "LowerLeg", _right, -knee)


func _pose_arms() -> void:
	var side := {"Left": _side_sign("Left"), "Right": _side_sign("Right")}
	for prefix in ["Left", "Right"]:
		var s: float = side[prefix]
		var out := _right * s
		# Brazos relajados a los costados
		var relaxed_upper := (Vector3.DOWN + out * 0.18 + _forward * 0.05).normalized()
		var relaxed_lower := (Vector3.DOWN + out * 0.05 + _forward * 0.15).normalized()
		# Brazos cruzados: hacia adelante y atravesando el pecho
		var crossed_upper := (Vector3.DOWN * 0.6 + _forward * 0.8 + out * 0.22).normalized()
		var crossed_lower := (-out * 0.9 + _forward * 0.5 + Vector3.UP * 0.18).normalized()

		var upper := relaxed_upper.slerp(crossed_upper, arms_crossed)
		var lower := relaxed_lower.slerp(crossed_lower, arms_crossed)

		# Balanceo de brazos al caminar (opuesto a la pierna del mismo lado)
		if walk_amount > 0.001:
			var phase := _walk_phase + (PI if prefix == "Left" else 0.0)
			var arm_swing := _forward * sin(phase) * 0.35 * walk_amount
			upper = (upper + arm_swing).normalized()
			lower = (lower + arm_swing * 1.3).normalized()

		# Señalar algo (un botón, la ventana...)
		if prefix == point_side and point_amount > 0.0:
			upper = upper.slerp(point_direction, point_amount)
			lower = lower.slerp(point_direction, point_amount)

		if prefix == "Right" and wave > 0.0:
			var wave_upper := (out * 0.8 + Vector3.UP * 0.1 + _forward * 0.25).normalized()
			var wave_lower := (Vector3.UP + out * (0.25 + wave_swing * 0.45) + _forward * 0.1).normalized()
			upper = upper.slerp(wave_upper, wave)
			lower = lower.slerp(wave_lower, wave)

		_aim(prefix + "UpperArm", prefix + "LowerArm", upper)
		_aim(prefix + "LowerArm", prefix + "Hand", lower)


## -1/+1: hacia qué lado (eje _right) está el brazo indicado.
func _side_sign(prefix: String) -> float:
	var bone: int = _bones[prefix + "UpperArm"]
	var x := _skeleton.get_bone_global_rest(bone).origin.dot(_right)
	return 1.0 if x >= 0.0 else -1.0


## Gira un hueso para que apunte hacia `direction` (espacio del esqueleto).
func _aim(bone_name: String, child_name: String, direction: Vector3) -> void:
	if not _bones.has(bone_name):
		return
	var child := _skeleton.find_bone(child_name)
	if child == -1:
		return
	var bone: int = _bones[bone_name]
	var from := _skeleton.get_bone_global_pose(bone).origin
	var to := _skeleton.get_bone_global_pose(child).origin
	var current := (to - from).normalized()
	if current.length_squared() < 0.0001:
		return
	var axis := current.cross(direction)
	if axis.length_squared() < 0.000001:
		return
	_rotate_global(bone_name, axis.normalized(), current.angle_to(direction))


## Gira un hueso alrededor de un eje expresado en el espacio del esqueleto.
func _rotate_global(bone_name: String, axis: Vector3, angle: float) -> void:
	if not _bones.has(bone_name) or is_zero_approx(angle):
		return
	var bone: int = _bones[bone_name]
	var parent := _skeleton.get_bone_parent(bone)
	var parent_basis := Basis.IDENTITY
	if parent != -1:
		parent_basis = _skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var local_axis := (parent_basis.inverse() * axis).normalized()
	var current := _skeleton.get_bone_pose_rotation(bone)
	_skeleton.set_bone_pose_rotation(bone, (Quaternion(local_axis, angle) * current).normalized())


## El modelo mira hacia +Z o -Z; se deduce por el lado del brazo izquierdo.
func _detect_orientation() -> void:
	if not _bones.has("LeftUpperArm"):
		return
	var left_x := _skeleton.get_bone_global_rest(_bones["LeftUpperArm"]).origin.x
	# Mirando a +Z, el brazo izquierdo del personaje queda en +X.
	_forward = Vector3.BACK if left_x > 0.0 else Vector3.FORWARD
	_right = Vector3.UP.cross(_forward).normalized() * -1.0
