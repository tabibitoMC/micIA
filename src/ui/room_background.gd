class_name RoomBackground
extends Control
## Fondo pastel dibujado por código. Tiene cuatro lugares de la casa
## (dormitorio, sala, cocina y patio con piscina) y tres ambientes: día,
## atardecer y noche. Ella puede cambiar el ambiente caminando a la ventana.

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

const PLACES := ["dormitorio", "sala", "cocina", "patio"]
const WOOD := Color("c9a27e")
const WOOD_DARK := Color("a67c5b")

var theme_id := DEFAULT_THEME
## Lugar de la casa que se dibuja.
var place := "dormitorio"
var _boxes := {}


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


func set_place(id: String) -> void:
	if id in PLACES and id != place:
		place = id
		queue_redraw()


## La cama del dormitorio (coordenadas locales), para acostarla a dormir.
func bed_rect() -> Rect2:
	return Rect2(size.x * 0.44, size.y * 0.56, size.x * 0.6, size.y * 0.2)


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
	if place == "patio":
		_draw_patio(t, w, h)
		return
	_gradient_rect(Rect2(0, 0, w, floor_y), t["wall_top"], t["wall_bottom"])
	draw_rect(Rect2(0, floor_y, w, h - floor_y), t["floor"])
	draw_rect(Rect2(0, floor_y - 6, w, 6), Color(1, 1, 1, 0.7))
	_draw_window(t)
	match place:
		"sala":
			_draw_living_room(t, w, h, floor_y)
		"cocina":
			_draw_kitchen(t, w, h, floor_y)
		_:
			_draw_bedroom(t, w, h, floor_y)
	# Pétalos / motas de luz
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var p := Vector2(rng.randf() * w, rng.randf() * floor_y * 0.5)
		draw_circle(p, rng.randf_range(2.0, 4.0), t["petal"])


func _draw_window(t: Dictionary) -> void:
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


func _picture(rect: Rect2, tint: Color) -> void:
	draw_rect(rect.grow(5), FRAME)
	_gradient_rect(rect, PICTURE, tint)


## Dormitorio: cama a la derecha, mesita con lámpara, cuadros y alfombra.
func _draw_bedroom(t: Dictionary, w: float, h: float, floor_y: float) -> void:
	_picture(Rect2(w * 0.74, h * 0.1, w * 0.2, h * 0.12), Color("e9d0ef"))
	_picture(Rect2(w * 0.56, h * 0.16, w * 0.12, h * 0.09), Color("cfe6f5"))
	# Alfombra
	_box(Rect2(w * 0.08, floor_y + h * 0.03, w * 0.5, h * 0.06), t["curtain"].lightened(0.2), 40)
	# Mesita y lámpara
	var table := Rect2(w * 0.31, floor_y - h * 0.11, w * 0.12, h * 0.11)
	_box(table, WOOD, 6)
	_box(Rect2(table.position.x + 6, table.position.y + table.size.y * 0.45, table.size.x - 12, 5), WOOD_DARK, 2)
	var lamp := table.position + Vector2(table.size.x / 2.0, 0)
	draw_line(lamp, lamp - Vector2(0, h * 0.05), WOOD_DARK, 4)
	draw_colored_polygon(PackedVector2Array([lamp - Vector2(w * 0.045, h * 0.05), lamp + Vector2(w * 0.045, -h * 0.05), lamp + Vector2(w * 0.03, -h * 0.1), lamp - Vector2(w * 0.03, h * 0.1)]), Color("fff1c9"))
	if t["stars"]:
		draw_circle(lamp - Vector2(0, h * 0.07), w * 0.16, Color(1.0, 0.92, 0.6, 0.18))
	# Cama: cabecera a la derecha, colchón, almohada y cobija.
	var bed := bed_rect()
	_box(Rect2(bed.end.x - w * 0.09, bed.position.y - h * 0.09, w * 0.12, bed.size.y + h * 0.09), WOOD, 18)
	_box(Rect2(bed.position.x, bed.position.y + bed.size.y * 0.55, bed.size.x, bed.size.y * 0.45), WOOD_DARK, 10)
	_box(Rect2(bed.position.x, bed.position.y + bed.size.y * 0.2, bed.size.x - w * 0.05, bed.size.y * 0.5), Color("fffaf5"), 16)
	_box(Rect2(bed.position.x + bed.size.x * 0.66, bed.position.y + bed.size.y * 0.02, bed.size.x * 0.22, bed.size.y * 0.3), Color("ffffff"), 14)
	_box(Rect2(bed.position.x, bed.position.y + bed.size.y * 0.24, bed.size.x * 0.56, bed.size.y * 0.52), t["curtain"].lightened(0.1), 16)
	_box(Rect2(bed.position.x + bed.size.x * 0.5, bed.position.y + bed.size.y * 0.24, bed.size.x * 0.08, bed.size.y * 0.52), Color(1, 1, 1, 0.75), 10)


## Sala: sofá con cojines, estante con libros, planta y mesa baja.
func _draw_living_room(t: Dictionary, w: float, h: float, floor_y: float) -> void:
	_picture(Rect2(w * 0.5, h * 0.12, w * 0.16, h * 0.1), Color("f7d9c4"))
	_picture(Rect2(w * 0.72, h * 0.08, w * 0.22, h * 0.14), Color("cfe6f5"))
	# Estante con libros
	var shelf := Rect2(w * 0.74, h * 0.28, w * 0.24, h * 0.012)
	_box(shelf, WOOD, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := shelf.position.x + 6.0
	while x < shelf.end.x - 14.0:
		var book_w := rng.randf_range(7.0, 13.0)
		var book_h := rng.randf_range(h * 0.035, h * 0.055)
		draw_rect(Rect2(x, shelf.position.y - book_h, book_w, book_h), Color.from_hsv(rng.randf(), 0.35, 0.92))
		x += book_w + 2.0
	# Sofá
	var sofa := Rect2(w * 0.46, floor_y - h * 0.17, w * 0.56, h * 0.17)
	var fabric: Color = t["curtain"].lightened(0.15)
	fabric.a = 1.0
	_box(Rect2(sofa.position.x, sofa.position.y - h * 0.07, sofa.size.x, h * 0.16), fabric.darkened(0.08), 26)
	_box(Rect2(sofa.position.x - w * 0.03, sofa.position.y + h * 0.01, w * 0.09, sofa.size.y - h * 0.01), fabric.darkened(0.14), 20)
	_box(Rect2(sofa.position.x + w * 0.04, sofa.position.y + h * 0.05, sofa.size.x, h * 0.09), fabric, 16)
	_box(Rect2(sofa.position.x + w * 0.08, sofa.position.y - h * 0.02, w * 0.13, h * 0.08), Color("fff6d5"), 14)
	_box(Rect2(sofa.position.x + w * 0.3, sofa.position.y - h * 0.02, w * 0.13, h * 0.08), Color("d9f0e3"), 14)
	# Planta
	var pot := Rect2(w * 0.04, floor_y - h * 0.06, w * 0.09, h * 0.06)
	for i in 5:
		var angle := -PI / 2.0 + (i - 2) * 0.38
		var tip := pot.position + Vector2(pot.size.x / 2.0, 0) + Vector2(cos(angle), sin(angle)) * h * 0.13
		draw_line(pot.position + Vector2(pot.size.x / 2.0, 4), tip, Color("7fbf8e"), 9)
		draw_circle(tip, 8, Color("8fd19e"))
	_box(pot, Color("e8b9a0"), 8)
	# Mesa baja
	_box(Rect2(w * 0.16, floor_y + h * 0.035, w * 0.36, h * 0.022), WOOD, 8)


## Cocina: azulejos, alacenas, mesón con estufa y refrigerador.
func _draw_kitchen(t: Dictionary, w: float, h: float, floor_y: float) -> void:
	# Azulejos sobre el mesón
	var tiles := Rect2(w * 0.44, floor_y - h * 0.3, w * 0.56, h * 0.13)
	draw_rect(tiles, Color(1, 1, 1, 0.55))
	var step := tiles.size.y / 3.0
	for i in 4:
		draw_line(tiles.position + Vector2(0, step * i), tiles.position + Vector2(tiles.size.x, step * i), Color(0.9, 0.75, 0.8, 0.6), 1.5)
	var columns := int(tiles.size.x / step)
	for i in columns + 1:
		draw_line(tiles.position + Vector2(step * i, 0), tiles.position + Vector2(step * i, tiles.size.y), Color(0.9, 0.75, 0.8, 0.6), 1.5)
	# Alacenas de arriba
	for i in 3:
		var cabinet := Rect2(w * (0.46 + i * 0.125), h * 0.1, w * 0.115, h * 0.2)
		_box(cabinet, Color("fff4ea"), 8)
		draw_circle(cabinet.position + Vector2(cabinet.size.x * 0.82, cabinet.size.y * 0.85), 4, WOOD_DARK)
	# Refrigerador
	var fridge := Rect2(w * 0.85, floor_y - h * 0.42, w * 0.2, h * 0.42)
	_box(fridge, Color("e8f1f5"), 14)
	draw_line(fridge.position + Vector2(0, fridge.size.y * 0.36), fridge.position + Vector2(fridge.size.x, fridge.size.y * 0.36), Color("c7d6dd"), 3)
	draw_line(fridge.position + Vector2(10, fridge.size.y * 0.16), fridge.position + Vector2(10, fridge.size.y * 0.3), Color("9fb3bd"), 4)
	draw_line(fridge.position + Vector2(10, fridge.size.y * 0.44), fridge.position + Vector2(10, fridge.size.y * 0.62), Color("9fb3bd"), 4)
	# Mesón y gabinetes de abajo
	var counter := Rect2(w * 0.44, floor_y - h * 0.17, w * 0.41, h * 0.17)
	_box(counter, Color("fff4ea"), 6)
	_box(Rect2(counter.position.x - 6, counter.position.y - 8, counter.size.x + 6, 14), WOOD, 5)
	for i in 3:
		var door := Rect2(counter.position.x + 8 + i * counter.size.x / 3.0, counter.position.y + 16, counter.size.x / 3.0 - 14, counter.size.y - 26)
		draw_rect(door, Color(0.93, 0.82, 0.76, 0.6), false, 2.0)
	# Estufa con olla
	var stove := Vector2(counter.position.x + counter.size.x * 0.3, counter.position.y - 8)
	_box(Rect2(stove.x - w * 0.07, stove.y - 5, w * 0.14, 6), Color("5c5560"), 3)
	_box(Rect2(stove.x - w * 0.045, stove.y - h * 0.045, w * 0.09, h * 0.042), Color("f29bb5"), 6)
	_box(Rect2(stove.x - w * 0.055, stove.y - h * 0.052, w * 0.11, 8), Color("d97a98"), 4)
	for i in 3:
		draw_arc(stove + Vector2((i - 1) * 12.0, -h * 0.075), 6, PI * 0.6, PI * 1.6, 8, Color(1, 1, 1, 0.7), 2.5)
	# Frutero
	var bowl := Vector2(counter.position.x + counter.size.x * 0.75, counter.position.y - 10)
	draw_circle(bowl + Vector2(-8, -12), 9, Color("ff9f6b"))
	draw_circle(bowl + Vector2(8, -12), 9, Color("f25f5c"))
	draw_circle(bowl + Vector2(0, -22), 9, Color("ffd166"))
	_box(Rect2(bowl.x - 24, bowl.y - 10, 48, 12), Color("bfe3f2"), 6)


## Patio: cielo abierto, cerca, palmera, piscina y pasto.
func _draw_patio(t: Dictionary, w: float, h: float) -> void:
	var horizon := h * 0.52
	_gradient_rect(Rect2(0, 0, w, horizon), t["sky_top"], t["sky_bottom"])
	if t["stars"]:
		_draw_night_sky(Rect2(0, 0, w, horizon * 0.9))
	else:
		var sun := Vector2(w * 0.8, h * 0.12)
		draw_circle(sun, w * 0.13, Color(1, 0.95, 0.7, 0.35))
		draw_circle(sun, w * 0.075, Color("fff3b0") if theme_id == "dia" else Color("ffb38a"))
		_cloud(Vector2(w * 0.25, h * 0.14), w * 0.07)
		_cloud(Vector2(w * 0.6, h * 0.26), w * 0.05)
	var dim := 0.55 if t["stars"] else (0.85 if theme_id == "atardecer" else 1.0)
	# Seto y cerca
	for i in 9:
		draw_circle(Vector2(w * (i / 8.0), horizon - h * 0.02), w * 0.09, Color("8fd19e") * Color(dim, dim, dim))
	var fence := Color(1, 1, 1, 0.92) * Color(dim, dim, dim, 1)
	var post := 0.0
	while post < w:
		draw_rect(Rect2(post, horizon - h * 0.075, w * 0.035, h * 0.09), fence)
		post += w * 0.06
	draw_rect(Rect2(0, horizon - h * 0.045, w, h * 0.012), fence)
	# Pasto
	var grass := Color("a8e0a0") * Color(dim, dim, dim)
	_gradient_rect(Rect2(0, horizon, w, h - horizon), grass, grass.darkened(0.12))
	# Palmera
	var trunk := Vector2(w * 0.12, horizon + h * 0.1)
	var top := trunk - Vector2(-w * 0.03, h * 0.36)
	draw_line(trunk, top, WOOD_DARK * Color(dim, dim, dim), w * 0.03)
	for i in 6:
		var angle := -PI + i * PI / 5.0
		var tip := top + Vector2(cos(angle) * w * 0.2, sin(angle) * h * 0.06 + h * 0.035)
		draw_line(top, tip, Color("6fbf7f") * Color(dim, dim, dim), w * 0.022)
	# Piscina
	var pool := PackedVector2Array([Vector2(w * 0.4, horizon + h * 0.07), Vector2(w * 1.02, horizon + h * 0.07), Vector2(w * 1.02, horizon + h * 0.27), Vector2(w * 0.3, horizon + h * 0.27)])
	var border := PackedVector2Array()
	for point in pool:
		border.append(point + Vector2(-w * 0.02 if point.x < w * 0.5 else 0.0, -h * 0.012 if point.y < horizon + h * 0.1 else h * 0.012))
	draw_colored_polygon(border, Color("fff7ee") * Color(dim, dim, dim))
	var water := Color("7fd6f2") * Color(dim, dim, dim)
	draw_polygon(pool, PackedColorArray([water.lightened(0.15), water.lightened(0.15), water.darkened(0.1), water.darkened(0.1)]))
	for i in 5:
		var y := horizon + h * (0.1 + i * 0.035)
		var start := w * (0.42 + (i % 2) * 0.08)
		draw_arc(Vector2(start + w * 0.06, y), w * 0.05, PI * 1.15, PI * 1.85, 10, Color(1, 1, 1, 0.55), 2.5)
		draw_arc(Vector2(start + w * 0.3, y + 6), w * 0.05, PI * 1.15, PI * 1.85, 10, Color(1, 1, 1, 0.45), 2.5)
	# Flotador
	draw_arc(Vector2(w * 0.78, horizon + h * 0.17), w * 0.045, 0, TAU, 24, Color("ff9fbc"), w * 0.022)


## Rectángulo de esquinas redondeadas.
func _box(rect: Rect2, color: Color, radius: int) -> void:
	var key := "%s:%d" % [color.to_html(), radius]
	if not _boxes.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		style.anti_aliasing = true
		_boxes[key] = style
	draw_style_box(_boxes[key], rect)


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
