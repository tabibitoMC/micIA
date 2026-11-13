class_name SideButton
extends VBoxContainer
## Botón lateral: un cuadrito redondeado con un ícono (Lucide) y una etiqueta
## tipo píldora debajo.

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

const TILE_SIZE := 54.0
const ICON_SIZE := 30

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
	add_theme_constant_override("separation", 2)

	_tile = Button.new()
	_tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tile.icon = Icons.texture(icon_name, UIStyle.PINK_DEEP, ICON_SIZE * 3)
	_tile.expand_icon = true
	_tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_tile.add_theme_constant_override("icon_max_width", ICON_SIZE)
	var tile_style := UIStyle.rounded(UIStyle.PINK_SOFT, 16, 12)
	tile_style.border_color = UIStyle.WHITE
	tile_style.set_border_width_all(3)
	tile_style.border_width_bottom = 5
	tile_style.shadow_color = UIStyle.SHADOW
	tile_style.shadow_size = 5
	tile_style.shadow_offset = Vector2(0, 3)
	for state in ["normal", "hover", "focus"]:
		_tile.add_theme_stylebox_override(state, tile_style)
	var pressed_style := tile_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = UIStyle.PINK_BORDER
	pressed_style.border_width_bottom = 3
	pressed_style.shadow_size = 2
	_tile.add_theme_stylebox_override("pressed", pressed_style)
	_tile.pressed.connect(func(): pressed.emit())
	_tile.disabled = _disabled
	add_child(_tile)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_stylebox_override("normal", UIStyle.pill(UIStyle.WHITE, UIStyle.PINK_BORDER, 8, 1, 1))
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
	_disabled = disabled
	if _tile:
		_tile.disabled = disabled
	modulate.a = 0.5 if disabled else 1.0
