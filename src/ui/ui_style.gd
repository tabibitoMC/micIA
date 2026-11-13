class_name UIStyle
extends RefCounted
## Paleta y estilos de toda la interfaz: pastel rosa/crema, esquinas muy
## redondeadas y botones tipo píldora.

# Paleta
const PINK := Color("f48fb1")
const PINK_DEEP := Color("e0628f")
const PINK_SOFT := Color("ffe4ee")
const PINK_BORDER := Color("f3a9c3")
const CREAM := Color("fff8f3")
const WHITE := Color("ffffff")
const PLUM := Color("5a2d4a")
const PLUM_DIM := Color("9a7189")
const GREEN := Color("37c25a")
const GREEN_DEEP := Color("249a43")
const BLUE_CARD := Color("e8f3ff")
const ANGER := Color("ef5a6f")
const AFFECTION := Color("f06292")
const EVENT_TEXT := Color("c9677f")
const ERROR_TEXT := Color("d1455b")
const SHADOW := Color(0.35, 0.12, 0.25, 0.18)

# Burbujas
const COMPANION_BUBBLE := Color("ffe4ee")
const COMPANION_BORDER := Color("e98aab")
const USER_BUBBLE := Color("ffffff")
const USER_BORDER := Color("f3a9c3")

const FONT_SIZE := 18
const FONT_SIZE_SMALL := 14
const FONT_SIZE_TITLE := 24

enum ButtonKind { PRIMARY, SECONDARY, CTA, FLAT }


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_color("font_color", "Label", PLUM)
	theme.set_stylebox("panel", "PanelContainer", card(CREAM))
	_apply_button_styles(theme, "Button", ButtonKind.PRIMARY)
	_apply_button_styles(theme, "OptionButton", ButtonKind.SECONDARY)

	theme.set_stylebox("normal", "LineEdit", field())
	theme.set_stylebox("focus", "LineEdit", field(PINK_DEEP))
	theme.set_stylebox("read_only", "LineEdit", field(PINK_SOFT))
	theme.set_color("font_color", "LineEdit", PLUM)
	theme.set_color("font_placeholder_color", "LineEdit", PLUM_DIM)
	theme.set_color("caret_color", "LineEdit", PINK_DEEP)
	theme.set_color("selection_color", "LineEdit", Color(PINK, 0.4))

	theme.set_color("font_color", "CheckButton", PLUM)
	theme.set_color("font_hover_color", "CheckButton", PLUM)
	theme.set_color("font_pressed_color", "CheckButton", PLUM)
	theme.set_color("font_hover_pressed_color", "CheckButton", PLUM)
	theme.set_color("font_focus_color", "CheckButton", PLUM)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())

	var slider_track := rounded(PINK_SOFT, 6, 0)
	slider_track.content_margin_top = 4
	slider_track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_track)
	theme.set_stylebox("grabber_area", "HSlider", rounded(PINK, 6, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", rounded(PINK_DEEP, 6, 0))

	theme.set_stylebox("panel", "PopupMenu", card(WHITE, 16, 8))
	theme.set_color("font_color", "PopupMenu", PLUM)
	theme.set_color("font_hover_color", "PopupMenu", PINK_DEEP)
	theme.set_stylebox("hover", "PopupMenu", rounded(PINK_SOFT, 10, 4))
	return theme


## Aplica a un botón concreto un estilo distinto del predeterminado.
static func style_button(button: Button, kind: ButtonKind) -> void:
	var colors := _button_colors(kind)
	button.add_theme_stylebox_override("normal", pill(colors[0], colors[3]))
	button.add_theme_stylebox_override("hover", pill(colors[0].lightened(0.08), colors[3]))
	button.add_theme_stylebox_override("pressed", pill(colors[1], colors[3]))
	button.add_theme_stylebox_override("disabled", pill(colors[0].lerp(Color.WHITE, 0.55), colors[3]))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(c, colors[2])
	button.add_theme_color_override("font_disabled_color", Color(colors[2], 0.6))


static func rounded(color: Color, radius := 12, padding := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	box.anti_aliasing = true
	return box


## Píldora: muy redondeada, con borde opcional.
static func pill(color: Color, border := Color.TRANSPARENT, padding_h := 18, padding_v := 8) -> StyleBoxFlat:
	var box := rounded(color, 999, 0)
	box.content_margin_left = padding_h
	box.content_margin_right = padding_h
	box.content_margin_top = padding_v
	box.content_margin_bottom = padding_v
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(2)
	return box


## Tarjeta: fondo claro, borde rosado suave y sombra.
static func card(color: Color, radius := 24, padding := 18) -> StyleBoxFlat:
	var box := rounded(color, radius, padding)
	box.border_color = WHITE
	box.set_border_width_all(3)
	box.shadow_color = SHADOW
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	return box


## Burbuja de chat (con "colita" simulada en una esquina menos redondeada).
static func bubble(color: Color, border: Color, tail_left: bool) -> StyleBoxFlat:
	var box := rounded(color, 20, 0)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.border_color = border
	box.set_border_width_all(2)
	if tail_left:
		box.corner_radius_bottom_left = 4
	else:
		box.corner_radius_bottom_right = 4
	box.shadow_color = SHADOW
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	return box


static func field(border := PINK_BORDER) -> StyleBoxFlat:
	var box := pill(WHITE, border, 18, 10)
	return box


static func _apply_button_styles(theme: Theme, type_name: String, kind: ButtonKind) -> void:
	var colors := _button_colors(kind)
	theme.set_stylebox("normal", type_name, pill(colors[0], colors[3]))
	theme.set_stylebox("hover", type_name, pill(colors[0].lightened(0.08), colors[3]))
	theme.set_stylebox("pressed", type_name, pill(colors[1], colors[3]))
	theme.set_stylebox("disabled", type_name, pill(colors[0].lerp(Color.WHITE, 0.55), colors[3]))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(c, type_name, colors[2])
	theme.set_color("font_disabled_color", type_name, Color(colors[2], 0.6))


## [fondo, fondo presionado, texto, borde]
static func _button_colors(kind: ButtonKind) -> Array:
	match kind:
		ButtonKind.SECONDARY:
			return [WHITE, PINK_SOFT, PLUM, PINK_BORDER]
		ButtonKind.CTA:
			return [GREEN, GREEN_DEEP, WHITE, Color("2aa84b")]
		ButtonKind.FLAT:
			return [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.3), PLUM_DIM, Color.TRANSPARENT]
		_:
			return [PINK, PINK_DEEP, WHITE, Color.TRANSPARENT]
