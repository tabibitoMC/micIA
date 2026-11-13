class_name RoomBackground
extends Control
## Fondo de habitación pastel dibujado por código (ventana, cortinas, cuadros
## y piso). Se reemplazará por una imagen cuando haya una propia.

const WALL_TOP := Color("fdeef0")
const WALL_BOTTOM := Color("f7dde3")
const FLOOR := Color("e9cfc9")
const SKY_TOP := Color("9fd2f5")
const SKY_BOTTOM := Color("dff1fb")
const FRAME := Color("ffffff")
const CURTAIN := Color(1.0, 0.75, 0.84, 0.75)
const PETAL := Color(1.0, 0.72, 0.82, 0.9)
const PICTURE := Color("f3e2c8")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var floor_y := h * 0.78
	_gradient_rect(Rect2(0, 0, w, floor_y), WALL_TOP, WALL_BOTTOM)
	draw_rect(Rect2(0, floor_y, w, h - floor_y), FLOOR)
	draw_rect(Rect2(0, floor_y - 6, w, 6), Color("ffffff", 0.7))

	# Ventana a la izquierda
	var window := Rect2(w * 0.02, h * 0.04, w * 0.38, h * 0.42)
	draw_rect(window.grow(8), FRAME)
	_gradient_rect(window, SKY_TOP, SKY_BOTTOM)
	_cloud(window.position + Vector2(window.size.x * 0.3, window.size.y * 0.3), window.size.x * 0.12)
	_cloud(window.position + Vector2(window.size.x * 0.75, window.size.y * 0.55), window.size.x * 0.09)
	draw_line(window.position + Vector2(window.size.x / 2, 0), window.position + Vector2(window.size.x / 2, window.size.y), FRAME, 6)
	draw_line(window.position + Vector2(0, window.size.y / 2), window.position + Vector2(window.size.x, window.size.y / 2), FRAME, 6)
	# Cortinas
	_curtain(Rect2(window.position.x - 14, window.position.y - 12, window.size.x * 0.22, window.size.y + 40))
	_curtain(Rect2(window.end.x - window.size.x * 0.22 + 14, window.position.y - 12, window.size.x * 0.22, window.size.y + 40))

	# Cuadros a la derecha
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
		draw_circle(p, rng.randf_range(2.5, 5.0), PETAL)


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _cloud(center: Vector2, r: float) -> void:
	var white := Color(1, 1, 1, 0.9)
	draw_circle(center, r, white)
	draw_circle(center + Vector2(-r * 0.9, r * 0.3), r * 0.7, white)
	draw_circle(center + Vector2(r * 0.9, r * 0.3), r * 0.75, white)


func _curtain(rect: Rect2) -> void:
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - rect.size.x * 0.2, rect.end.y),
		Vector2(rect.position.x + rect.size.x * 0.2, rect.end.y),
	])
	draw_colored_polygon(points, CURTAIN)
