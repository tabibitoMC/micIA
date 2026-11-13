class_name RoomBackground
extends Control
## Fondo de habitación pastel dibujado por código (ventana, cortinas, cuadros
## y piso). Tiene tres ambientes: día, atardecer y noche. Ella puede
## cambiarlos caminando hasta la ventana.

signal room_theme_changed(theme_id: String)

const THEMES := {
	"dia": {
		"label": "Día",
		"wall_top": Color("fdeef0"), "wall_bottom": Color("f7dde3"), "floor": Color("e9cfc9"),
		"sky_top": Color("9fd2f5"), "sky_bottom": Color("dff1fb"),
		"curtain": Color(1.0, 0.75, 0.84, 0.75), "petal": Color(1.0, 0.72, 0.82, 0.9),
		"stars": false,
	},
	"atardecer": {
		"label": "Atardecer",
		"wall_top": Color("fde3d8"), "wall_bottom": Color("f4c9c9"), "floor": Color("dcb3ad"),
		"sky_top": Color("f7a072"), "sky_bottom": Color("ffd6a5"),
		"curtain": Color(0.98, 0.62, 0.66, 0.75), "petal": Color(1.0, 0.65, 0.6, 0.85),
		"stars": false,
	},
	"noche": {
		"label": "Noche",
		"wall_top": Color("b9b2d8"), "wall_bottom": Color("9d93c4"), "floor": Color("837aa8"),
		"sky_top": Color("1c1f4a"), "sky_bottom": Color("3b3f7a"),
		"curtain": Color(0.62, 0.55, 0.85, 0.8), "petal": Color(0.95, 0.9, 1.0, 0.6),
		"stars": true,
	},
}
const DEFAULT_THEME := "dia"
const FRAME := Color("ffffff")
const PICTURE := Color("f3e2c8")

var theme_id := DEFAULT_THEME


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func theme_ids() -> Array:
	return THEMES.keys()


func set_room_theme(id: String) -> void:
	if not THEMES.has(id) or id == theme_id:
		return
	theme_id = id
	queue_redraw()
	room_theme_changed.emit(id)


## Centro de la ventana en coordenadas globales (para que ella camine hasta ahí).
func window_global_center() -> Vector2:
	return global_position + _window_rect().get_center()


func _window_rect() -> Rect2:
	return Rect2(size.x * 0.02, size.y * 0.04, size.x * 0.38, size.y * 0.42)


func _draw() -> void:
	var t: Dictionary = THEMES[theme_id]
	var w := size.x
	var h := size.y
	var floor_y := h * 0.78
	_gradient_rect(Rect2(0, 0, w, floor_y), t["wall_top"], t["wall_bottom"])
	draw_rect(Rect2(0, floor_y, w, h - floor_y), t["floor"])
	draw_rect(Rect2(0, floor_y - 6, w, 6), Color(1, 1, 1, 0.7))

	# Ventana
	var window := _window_rect()
	draw_rect(window.grow(8), FRAME)
	_gradient_rect(window, t["sky_top"], t["sky_bottom"])
	if t["stars"]:
		_draw_night_sky(window)
	else:
		_cloud(window.position + Vector2(window.size.x * 0.3, window.size.y * 0.3), window.size.x * 0.12)
		_cloud(window.position + Vector2(window.size.x * 0.75, window.size.y * 0.55), window.size.x * 0.09)
	draw_line(window.position + Vector2(window.size.x / 2, 0), window.position + Vector2(window.size.x / 2, window.size.y), FRAME, 6)
	draw_line(window.position + Vector2(0, window.size.y / 2), window.position + Vector2(window.size.x, window.size.y / 2), FRAME, 6)
	_curtain(Rect2(window.position.x - 14, window.position.y - 12, window.size.x * 0.22, window.size.y + 40), t["curtain"])
	_curtain(Rect2(window.end.x - window.size.x * 0.22 + 14, window.position.y - 12, window.size.x * 0.22, window.size.y + 40), t["curtain"])

	# Cuadros
	var pic1 := Rect2(w * 0.74, h * 0.1, w * 0.2, h * 0.12)
	var pic2 := Rect2(w * 0.78, h * 0.3, w * 0.16, h * 0.1)
	for pic in [pic1, pic2]:
		draw_rect(pic.grow(5), FRAME)
		_gradient_rect(pic, PICTURE, Color("e9d0ef"))

	# Pétalos
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 18:
		var p := Vector2(rng.randf() * w, rng.randf() * floor_y)
		draw_circle(p, rng.randf_range(2.5, 5.0), t["petal"])


func _draw_night_sky(window: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 25:
		var p := window.position + Vector2(rng.randf() * window.size.x, rng.randf() * window.size.y)
		draw_circle(p, rng.randf_range(0.8, 2.0), Color(1, 1, 0.9, rng.randf_range(0.5, 1.0)))
	var moon := window.position + Vector2(window.size.x * 0.72, window.size.y * 0.25)
	draw_circle(moon, window.size.x * 0.09, Color("fff6d5"))
	draw_circle(moon + Vector2(window.size.x * 0.035, -window.size.x * 0.02), window.size.x * 0.08, THEMES["noche"]["sky_top"])


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _cloud(center: Vector2, r: float) -> void:
	var white := Color(1, 1, 1, 0.9)
	draw_circle(center, r, white)
	draw_circle(center + Vector2(-r * 0.9, r * 0.3), r * 0.7, white)
	draw_circle(center + Vector2(r * 0.9, r * 0.3), r * 0.75, white)


func _curtain(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - rect.size.x * 0.2, rect.end.y),
		Vector2(rect.position.x + rect.size.x * 0.2, rect.end.y),
	])
	draw_colored_polygon(points, color)
