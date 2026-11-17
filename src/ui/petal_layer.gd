class_name PetalLayer
extends Control
## Pétalos de sakura que caen despacio y girando, de fondo (no se tocan).

const COUNT := 14

var _petals: Array = []
var _texture: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture = Icons.texture("sakura", Color(1.0, 0.72, 0.82), 64)
	for i in COUNT:
		_petals.append(_new_petal(true))


func _new_petal(anywhere: bool) -> Dictionary:
	var view := get_viewport_rect().size
	return {
		"pos": Vector2(randf() * view.x, randf() * view.y if anywhere else -20.0),
		"speed": randf_range(14.0, 34.0),
		"drift": randf_range(-12.0, 12.0),
		"phase": randf() * TAU,
		"spin": randf_range(-1.2, 1.2),
		"angle": randf() * TAU,
		"size": randf_range(9.0, 17.0),
		"alpha": randf_range(0.45, 0.85),
	}


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	for i in _petals.size():
		var petal: Dictionary = _petals[i]
		petal["phase"] += delta
		petal["pos"] += Vector2(petal["drift"] + sin(petal["phase"] * 1.3) * 18.0, petal["speed"]) * delta
		petal["angle"] += petal["spin"] * delta
		if petal["pos"].y > view.y * 0.7 or petal["pos"].x < -30.0 or petal["pos"].x > view.x + 30.0:
			_petals[i] = _new_petal(false)
	queue_redraw()


func _draw() -> void:
	for petal in _petals:
		var s: float = petal["size"]
		draw_set_transform(petal["pos"], petal["angle"], Vector2(1.0, 0.75))
		draw_texture_rect(_texture, Rect2(Vector2(-s, -s) / 2.0, Vector2(s, s)), false, Color(1, 1, 1, petal["alpha"]))
	draw_set_transform(Vector2.ZERO)
