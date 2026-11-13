class_name VrmExpressionMixer
extends RefCounted
## Mezcla varias expresiones VRM a la vez (emoción + parpadeo + boca).
##
## El addon godot-vrm importa cada expresión ("happy", "aa", "blink"...) como
## una animación con pistas de blend shapes. Aquí se leen esas pistas una vez
## y luego, cada frame, se suman las expresiones según su peso. Así se puede
## estar feliz, parpadear y hablar al mismo tiempo (un AnimationPlayer solo
## reproduce una animación a la vez).

## expresión -> Array de {"mesh": MeshInstance3D, "index": int, "value": float}
var _targets: Dictionary = {}
## peso actual y peso objetivo de cada expresión (0..1)
var _weights: Dictionary = {}
var _goals: Dictionary = {}
## Todos los (mesh, index) que tocamos, para ponerlos a 0 antes de sumar.
var _touched: Array = []


func _init(model_root: Node, player: AnimationPlayer) -> void:
	if player == null:
		return
	var seen := {}
	var base := player.get_node(player.root_node)
	for anim_name in player.get_animation_list():
		if anim_name == "RESET":
			continue
		var anim := player.get_animation(anim_name)
		var list: Array = []
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_BLEND_SHAPE or anim.track_get_key_count(t) == 0:
				continue
			var path := anim.track_get_path(t)
			var mesh := base.get_node_or_null(NodePath(path.get_concatenated_names())) as MeshInstance3D
			if mesh == null:
				continue
			var index := mesh.find_blend_shape_by_name(path.get_concatenated_subnames())
			if index == -1:
				continue
			var value := float(anim.track_get_key_value(t, anim.track_get_key_count(t) - 1))
			list.append({"mesh": mesh, "index": index, "value": value})
			var key := "%d:%d" % [mesh.get_instance_id(), index]
			if not seen.has(key):
				seen[key] = true
				_touched.append({"mesh": mesh, "index": index})
		if not list.is_empty():
			_targets[anim_name] = list
			_weights[anim_name] = 0.0
			_goals[anim_name] = 0.0


func has_expression(expression: String) -> bool:
	return _targets.has(expression)


## Peso al que la expresión irá acercándose suavemente.
func set_goal(expression: String, weight: float) -> void:
	if _targets.has(expression):
		_goals[expression] = clampf(weight, 0.0, 1.0)


## Pone el peso de golpe (útil para la boca y el parpadeo, que son rápidos).
func set_now(expression: String, weight: float) -> void:
	if _targets.has(expression):
		_goals[expression] = clampf(weight, 0.0, 1.0)
		_weights[expression] = _goals[expression]


func clear_goals(except: Array = []) -> void:
	for expression in _goals:
		if not expression in except:
			_goals[expression] = 0.0


func update(delta: float, speed := 8.0) -> void:
	var t := clampf(delta * speed, 0.0, 1.0)
	for expression in _weights:
		_weights[expression] = lerpf(_weights[expression], _goals[expression], t)

	for item in _touched:
		item["mesh"].set_blend_shape_value(item["index"], 0.0)
	for expression in _targets:
		var weight: float = _weights[expression]
		if weight <= 0.001:
			continue
		for target in _targets[expression]:
			var mesh: MeshInstance3D = target["mesh"]
			var current := mesh.get_blend_shape_value(target["index"])
			mesh.set_blend_shape_value(target["index"], minf(1.0, current + target["value"] * weight))
