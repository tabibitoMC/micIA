class_name SideButton
extends VBoxContainer
## Botón del panel lateral: ícono rosa arriba y el nombre debajo, todo dentro
## de un mismo botón (toda el área es tocable).

signal pressed

enum Icon { GIFT, GEAR, HEART, PICTURE, GAMEPAD, DRESS, PLACE }

## Ícono de Lucide (ver Icons.SVG) para cada valor del enum.
const ICON_NAMES := {
	Icon.GIFT: "gift",
	Icon.GEAR: "settings",
	Icon.HEART: "heart",
	Icon.PICTURE: "image",
	Icon.GAMEPAD: "gamepad-2",
	Icon.DRESS: "shirt",
	Icon.PLACE: "map-pin",
}

const TILE_SIZE := Vector2(70, 58)
const ICON_SIZE := 28

var icon_name := "heart"
var label_text := ""

var _tile: Button
var _disabled := false


## p_icon: un valor de Icon o directamente el nombre de un ícono de Lucide.
func _init(p_icon: Variant = Icon.HEART, p_label := "") -> void:
	icon_name = ICON_NAMES.get(p_icon, "heart") if typeof(p_icon) == TYPE_INT else str(p_icon)
	label_text = p_label


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	_tile = Button.new()
	_tile.text = label_text
	_tile.custom_minimum_size = TILE_SIZE
	_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tile.icon = Icons.texture(icon_name, Color("e0628f"), ICON_SIZE * 3, 2.1)
	_tile.expand_icon = false
	_tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_tile.add_theme_constant_override("icon_max_width", ICON_SIZE)
	_tile.add_theme_constant_override("h_separation", 0)
	_tile.add_theme_font_override("font", UIStyle.font(700))
	_tile.add_theme_font_size_override("font_size", 13)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		_tile.add_theme_color_override(c, UIStyle.PLUM)
	_tile.add_theme_color_override("font_disabled_color", Color(UIStyle.PLUM, 0.5))
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "focus", "disabled"]:
		_tile.add_theme_stylebox_override(state, empty)
	_tile.add_theme_stylebox_override("hover", UIStyle.rounded(Color(1, 0.89, 0.93, 0.6), 16, 4))
	_tile.add_theme_stylebox_override("pressed", UIStyle.rounded(Color("fbd0df"), 16, 4))
	_tile.pressed.connect(func(): pressed.emit())
	_tile.disabled = _disabled
	add_child(_tile)


## Pequeño salto para llamar la atención (cuando ella lo señala).
func pulse() -> void:
	_tile.pivot_offset = _tile.size / 2.0
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_tile, "scale", Vector2(1.25, 1.25), 0.15)
		tween.tween_property(_tile, "scale", Vector2.ONE, 0.15)


func set_disabled(disabled: bool) -> void:
	_disabled = disabled
	if _tile:
		_tile.disabled = disabled
	modulate.a = 0.5 if disabled else 1.0
