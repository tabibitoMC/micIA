class_name SidePanel
extends PanelContainer
## Panel lateral del concepto visual: una columna blanca con borde rosa,
## flecha arriba, los botones (desplazables) y flecha abajo.

const ARROW_HEIGHT := 26.0

var list: VBoxContainer
var _scroll: ScrollContainer
var _up: Button
var _down: Button


## Se arma al crearse (no al entrar en pantalla) para poder agregar botones
## a `list` enseguida.
func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.soft_pill(Color(1, 1, 1, 0.9), Color("f6b6cb"), 26, 4, 4))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	_up = _arrow("chevron-up")
	_up.pressed.connect(func(): _scroll_by(-1))
	box.add_child(_up)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.scroll_deadzone = 8
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	list.resized.connect(_update_arrows)
	_scroll.add_child(list)

	_down = _arrow("chevron-down")
	_down.pressed.connect(func(): _scroll_by(1))
	box.add_child(_down)
	resized.connect(_update_arrows)


func _ready() -> void:
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float): _update_arrows())


## Alto de la zona de botones (el panel crece hasta mostrar los que entren).
func set_list_height(height: float) -> void:
	if _scroll:
		_scroll.custom_minimum_size.y = maxf(SideButton.TILE_SIZE.y, height - ARROW_HEIGHT * 2.0 - 10.0)
		_update_arrows.call_deferred()


func _arrow(icon: String) -> Button:
	var button := Button.new()
	button.icon = Icons.texture(icon, Color("e0628f"), 60, 2.6)
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 20)
	button.custom_minimum_size = Vector2(SideButton.TILE_SIZE.x, ARROW_HEIGHT)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "focus", "hover", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_stylebox_override("pressed", UIStyle.rounded(Color("fbd0df"), 12, 0))
	return button


func _scroll_by(direction: int) -> void:
	var step := SideButton.TILE_SIZE.y + 4.0
	var tween := create_tween()
	tween.tween_property(_scroll, "scroll_vertical", int(_scroll.scroll_vertical + direction * step * 2.0), 0.2).set_trans(Tween.TRANS_SINE)


## Las flechas se atenúan cuando ya no hay más hacia ese lado.
func _update_arrows() -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	var max_scroll := bar.max_value - bar.page
	_up.modulate.a = 1.0 if _scroll.scroll_vertical > 1 else 0.35
	_down.modulate.a = 1.0 if _scroll.scroll_vertical < max_scroll - 1 else 0.35
