class_name SideButton
extends VBoxContainer
## Botón lateral: un cuadrito redondeado con un ícono dibujado y una etiqueta
## tipo píldora debajo.

signal pressed

enum Icon { GIFT, GEAR, HEART, PICTURE, GAMEPAD, DRESS }

const TILE_SIZE := 54.0

var icon := Icon.GIFT
var label_text := ""

var _tile: Button
var _icon_canvas: Control


func _init(p_icon: Icon = Icon.GIFT, p_label := "") -> void:
	icon = p_icon
	label_text = p_label


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)

	_tile = Button.new()
	_tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tile_style := UIStyle.rounded(UIStyle.PINK_SOFT, 14, 0)
	tile_style.border_color = UIStyle.WHITE
	tile_style.set_border_width_all(3)
	tile_style.shadow_color = UIStyle.SHADOW
	tile_style.shadow_size = 4
	for state in ["normal", "hover", "focus"]:
		_tile.add_theme_stylebox_override(state, tile_style)
	var pressed_style := tile_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = UIStyle.PINK_BORDER
	_tile.add_theme_stylebox_override("pressed", pressed_style)
	_tile.pressed.connect(func(): pressed.emit())
	add_child(_tile)

	_icon_canvas = Control.new()
	_icon_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_canvas.draw.connect(_draw_icon)
	_tile.add_child(_icon_canvas)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_stylebox_override("normal", UIStyle.pill(UIStyle.WHITE, UIStyle.PINK_BORDER, 8, 1))
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(label)


## Pequeño salto para llamar la atención (cuando ella lo señala).
func pulse() -> void:
	_tile.pivot_offset = _tile.size / 2.0
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_tile, "scale", Vector2(1.25, 1.25), 0.15)
		tween.tween_property(_tile, "scale", Vector2.ONE, 0.15)


func set_disabled(disabled: bool) -> void:
	_tile.disabled = disabled
	modulate.a = 0.5 if disabled else 1.0


func _draw_icon() -> void:
	var c := _icon_canvas.size / 2.0
	var s := minf(_icon_canvas.size.x, _icon_canvas.size.y) * 0.28
	match icon:
		Icon.GIFT:
			var box := Rect2(c + Vector2(-s, -s * 0.35), Vector2(s * 2, s * 1.35))
			_icon_canvas.draw_rect(box, UIStyle.PINK)
			_icon_canvas.draw_rect(Rect2(c + Vector2(-s * 1.15, -s * 0.75), Vector2(s * 2.3, s * 0.5)), UIStyle.PINK_DEEP)
			_icon_canvas.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.75), Vector2(s * 0.36, s * 1.75)), UIStyle.WHITE)
			_icon_canvas.draw_circle(c + Vector2(-s * 0.35, -s * 0.95), s * 0.3, UIStyle.PINK_DEEP)
			_icon_canvas.draw_circle(c + Vector2(s * 0.35, -s * 0.95), s * 0.3, UIStyle.PINK_DEEP)
		Icon.GEAR:
			for i in 8:
				var a := TAU * i / 8.0
				_icon_canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * s * 1.2, UIStyle.PLUM_DIM, s * 0.45)
			_icon_canvas.draw_circle(c, s * 0.9, UIStyle.PLUM_DIM)
			_icon_canvas.draw_circle(c, s * 0.4, UIStyle.PINK_SOFT)
		Icon.PICTURE:
			var frame := Rect2(c + Vector2(-s * 1.15, -s * 0.9), Vector2(s * 2.3, s * 1.8))
			_icon_canvas.draw_rect(frame, UIStyle.WHITE)
			_icon_canvas.draw_rect(frame.grow(-s * 0.15), Color("9fd2f5"))
			_icon_canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s, s * 0.75), c + Vector2(-s * 0.2, -s * 0.15), c + Vector2(s * 0.3, s * 0.4),
				c + Vector2(s * 0.6, s * 0.1), c + Vector2(s, s * 0.75),
			]), UIStyle.PINK)
			_icon_canvas.draw_circle(c + Vector2(s * 0.5, -s * 0.4), s * 0.22, Color("ffd54f"))
			_icon_canvas.draw_rect(frame, UIStyle.PLUM_DIM, false, 2.0)
		Icon.GAMEPAD:
			var body := Rect2(c + Vector2(-s * 1.2, -s * 0.55), Vector2(s * 2.4, s * 1.2))
			_icon_canvas.draw_style_box(UIStyle.rounded(UIStyle.PLUM_DIM, int(s * 0.6), 0), body)
			_icon_canvas.draw_rect(Rect2(c + Vector2(-s * 0.85, -s * 0.12), Vector2(s * 0.6, s * 0.2)), UIStyle.WHITE)
			_icon_canvas.draw_rect(Rect2(c + Vector2(-s * 0.65, -s * 0.32), Vector2(s * 0.2, s * 0.6)), UIStyle.WHITE)
			_icon_canvas.draw_circle(c + Vector2(s * 0.5, -s * 0.15), s * 0.14, UIStyle.PINK)
			_icon_canvas.draw_circle(c + Vector2(s * 0.8, s * 0.12), s * 0.14, Color("9fd2f5"))
		Icon.DRESS:
			_icon_canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.35, -s * 1.0), c + Vector2(s * 0.35, -s * 1.0),
				c + Vector2(s * 0.45, -s * 0.2), c + Vector2(s * 1.1, s * 1.0),
				c + Vector2(-s * 1.1, s * 1.0), c + Vector2(-s * 0.45, -s * 0.2),
			]), UIStyle.PINK)
			_icon_canvas.draw_line(c + Vector2(-s * 0.45, -s * 0.2), c + Vector2(s * 0.45, -s * 0.2), UIStyle.WHITE, 2.0)
		Icon.HEART:
			_icon_canvas.draw_circle(c + Vector2(-s * 0.5, -s * 0.2), s * 0.6, UIStyle.AFFECTION)
			_icon_canvas.draw_circle(c + Vector2(s * 0.5, -s * 0.2), s * 0.6, UIStyle.AFFECTION)
			_icon_canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 1.08, 0), c + Vector2(s * 1.08, 0), c + Vector2(0, s * 1.15),
			]), UIStyle.AFFECTION)
