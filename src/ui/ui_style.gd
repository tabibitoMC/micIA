class_name UIStyle
extends RefCounted
## Colores y estilos compartidos por toda la interfaz.

const BACKGROUND := Color("1d1729")
const SURFACE := Color("2b2140")
const SURFACE_LIGHT := Color("3a2d57")
const ACCENT := Color("b07cff")
const TEXT := Color("f2ecff")
const TEXT_DIM := Color("b9aed1")
const USER_BUBBLE := Color("4b3a78")
const COMPANION_BUBBLE := Color("33294a")
const EVENT_TEXT := Color("ffcf7a")
const ERROR_TEXT := Color("ff8a8a")
const ANGER := Color("e0405a")
const AFFECTION := Color("ff8fc6")

const FONT_SIZE := 18
const FONT_SIZE_SMALL := 14


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", panel(SURFACE, 12))
	return theme


static func panel(color: Color, radius := 10, padding := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box
