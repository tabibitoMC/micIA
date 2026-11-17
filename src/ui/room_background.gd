class_name RoomBackground
extends Control
## Fondo pastel dibujado por código. Tiene cuatro lugares de la casa
## (dormitorio, sala, cocina y patio con piscina), tres ambientes (día,
## atardecer y noche) y una vista de cerca de la cama para cuando duerme.
## Ella puede cambiar el ambiente caminando hasta la ventana.

signal room_theme_changed(theme_id: String)

const THEMES := {
	"dia": {
		"label": "Día",
		"wall_top": Color("fdeef0"), "wall_bottom": Color("f9dfe6"), "panel": Color("f4cfda"), "floor": Color("e7c3b4"),
		"sky_top": Color("9fd2f5"), "sky_bottom": Color("dff1fb"),
		"curtain": Color(1.0, 0.72, 0.82, 0.85), "petal": Color(1.0, 0.72, 0.82, 0.9),
		"stars": false, "dim": 1.0,
	},
	"atardecer": {
		"label": "Atardecer",
		"wall_top": Color("fde3d8"), "wall_bottom": Color("f6cfc9"), "panel": Color("eeb8b4"), "floor": Color("d9a999"),
		"sky_top": Color("f7a072"), "sky_bottom": Color("ffd6a5"),
		"curtain": Color(0.98, 0.6, 0.64, 0.85), "petal": Color(1.0, 0.65, 0.6, 0.85),
		"stars": false, "dim": 0.9,
	},
	"noche": {
		"label": "Noche",
		"wall_top": Color("8f88bd"), "wall_bottom": Color("7b72ad"), "panel": Color("6a629c"), "floor": Color("5d5589"),
		"sky_top": Color("1c1f4a"), "sky_bottom": Color("3b3f7a"),
		"curtain": Color(0.66, 0.58, 0.9, 0.9), "petal": Color(0.95, 0.9, 1.0, 0.5),
		"stars": true, "dim": 0.62,
	},
}
const DEFAULT_THEME := "dia"
const PLACES := ["dormitorio", "sala", "cocina", "patio"]
const FRAME := Color("ffffff")
const WOOD := Color("d2a983")
const WOOD_DARK := Color("ad8263")
const CREAM := Color("fff8f0")
const LIGHTS := [Color("ffd166"), Color("ff9fbc"), Color("9fe3d0"), Color("b8a6ff")]

## Fondos ilustrados (assets/backgrounds/<lugar>_<hora>.bg, WebP). Si falta
## alguno se usa el fondo dibujado por código.
const BG_DIR := "res://assets/backgrounds/"
## Dónde está la ventana en cada imagen (coordenadas 0..1 de la imagen).
const IMAGE_WINDOWS := {"dormitorio": Vector2(0.12, 0.2), "sala": Vector2(0.12, 0.23), "cocina": Vector2(0.08, 0.2)}
## Qué parte de la imagen queda siempre a la vista al recortarla (0..1).
const IMAGE_FOCUS := Vector2(0.5, 0.62)
## Cama de cerca (cama.bg): dónde va su cara y la cobija que la tapa.
const BED_HEAD := Vector2(0.735, 0.6)
## Los pies van más abajo que la cabeza: la cama está en diagonal.
const BED_FEET := Vector2(0.02, 0.76)
const BLANKET := [
	Vector2(0.0, 0.555), Vector2(0.1, 0.548), Vector2(0.2, 0.545), Vector2(0.3, 0.548),
	Vector2(0.4, 0.552), Vector2(0.48, 0.553), Vector2(0.53, 0.565), Vector2(0.565, 0.62),
	Vector2(0.595, 0.75), Vector2(0.607, 0.9), Vector2(0.0, 0.93),
]

var _images := {}

var theme_id := DEFAULT_THEME
## Lugar de la casa que se dibuja.
var place := "dormitorio"
## Vista de cerca de la cama (cuando ella duerme).
var sleep_view := false

var _boxes := {}
var _dim := 1.0


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


## Textura del fondo ilustrado de ahora (o null si no hay).
func current_image() -> Texture2D:
	return _image("cama" if sleep_view else "%s_%s" % [place, theme_id])


func _image(image_name: String) -> Texture2D:
	if not _images.has(image_name):
		var texture: Texture2D = null
		var path := BG_DIR + image_name + ".bg"
		if FileAccess.file_exists(path):
			var image := Image.new()
			if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
				texture = ImageTexture.create_from_image(image)
		_images[image_name] = texture
	return _images[image_name]


## Dónde se dibuja la imagen para cubrir toda la pantalla (se recorta lo que
## sobra: en teléfonos los lados, en tablets arriba y abajo).
func _cover_rect(texture: Texture2D) -> Rect2:
	var image_size := Vector2(texture.get_size())
	var scale_by := maxf(size.x / image_size.x, size.y / image_size.y)
	var drawn := image_size * scale_by
	return Rect2((size - drawn) * IMAGE_FOCUS, drawn)


## Punto de la imagen (0..1) -> coordenadas locales de este fondo.
func image_point(normalized: Vector2) -> Vector2:
	var texture := current_image()
	if texture == null:
		return size * normalized
	var rect := _cover_rect(texture)
	return rect.position + normalized * rect.size


## La cobija de la imagen de la cama, para dibujarla ENCIMA de ella al dormir:
## {"points": local, "uvs": 0..1, "texture": Texture2D}, o {} si no hay.
func blanket_overlay() -> Dictionary:
	var texture := current_image()
	if not sleep_view or texture == null:
		return {}
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in BLANKET:
		points.append(image_point(point))
		uvs.append(point)
	return {"points": points, "uvs": uvs, "texture": texture}


func set_place(id: String) -> void:
	if id in PLACES and id != place:
		place = id
		queue_redraw()


func set_sleep_view(enabled: bool) -> void:
	if enabled != sleep_view:
		sleep_view = enabled
		queue_redraw()


## Dónde queda su cara al dormir (centro de la almohada, coordenadas locales)
## y cuánto debe medir ella de largo, en píxeles.
func sleep_spot() -> Dictionary:
	if current_image() != null:
		var head := image_point(BED_HEAD)
		var feet := image_point(BED_FEET)
		# La cara queda a ~80 % del largo del cuerpo.
		return {"head": head, "feet": feet, "length": head.distance_to(feet) / 0.8}
	return {"head": Vector2(size.x * 0.7, size.y * 0.455), "length": size.x * 1.75}


## Borde superior de la cobija en la vista de dormir (para taparla).
func blanket_rect() -> Rect2:
	return Rect2(-size.x * 0.05, size.y * 0.335, size.x * 0.56, size.y * 0.3)


## Color de la cobija según el ambiente.
func blanket_color() -> Color:
	var color: Color = THEMES[theme_id]["curtain"]
	color.a = 1.0
	return color.lightened(0.12)


## Centro de la ventana en coordenadas globales (para que ella camine hasta ahí).
func window_global_center() -> Vector2:
	if current_image() != null and IMAGE_WINDOWS.has(place):
		return global_position + image_point(IMAGE_WINDOWS[place])
	return global_position + _window_rect().get_center()


func _window_rect() -> Rect2:
	return Rect2(size.x * 0.03, size.y * 0.05, size.x * 0.36, size.y * 0.36)


# --- Dibujo ------------------------------------------------------------------------

func _draw() -> void:
	var t: Dictionary = THEMES[theme_id]
	_dim = t["dim"]
	var w := size.x
	var h := size.y
	var texture := current_image()
	if texture != null:
		draw_texture_rect(texture, _cover_rect(texture), false)
		_draw_vignette(w, h)
		return
	if sleep_view:
		_draw_sleep_view(t, w, h)
	elif place == "patio":
		_draw_patio(t, w, h)
	else:
		var floor_y := h * 0.76
		_draw_interior(t, w, h, floor_y)
		match place:
			"sala":
				_draw_living_room(t, w, h, floor_y)
			"cocina":
				_draw_kitchen(t, w, h, floor_y)
			_:
				_draw_bedroom(t, w, h, floor_y)
	_draw_vignette(w, h)


## Pared con zócalo de madera, piso de tablas y ventana con su luz.
func _draw_interior(t: Dictionary, w: float, h: float, floor_y: float) -> void:
	_gradient_rect(Rect2(0, 0, w, floor_y), t["wall_top"], t["wall_bottom"])
	# Rayas verticales muy suaves en la pared
	var stripe := w / 14.0
	for i in 15:
		draw_rect(Rect2(i * stripe, 0, stripe * 0.5, floor_y), Color(1, 1, 1, 0.07))
	# Zócalo
	var panel_y := floor_y - h * 0.13
	draw_rect(Rect2(0, panel_y, w, floor_y - panel_y), t["panel"])
	draw_rect(Rect2(0, panel_y - 5, w, 7), Color(1, 1, 1, 0.75))
	var panel_step := w / 6.0
	for i in 6:
		draw_rect(Rect2(i * panel_step + 10, panel_y + 12, panel_step - 20, floor_y - panel_y - 26), Color(1, 1, 1, 0.16), false, 2.0)
	# Piso de tablas
	var floor_color: Color = t["floor"]
	_gradient_rect(Rect2(0, floor_y, w, h - floor_y), floor_color.lightened(0.08), floor_color.darkened(0.1))
	draw_rect(Rect2(0, floor_y - 4, w, 8), Color(1, 1, 1, 0.8))
	for i in 9:
		var x := w * (i / 8.0)
		draw_line(Vector2(w * 0.5 + (x - w * 0.5) * 0.82, floor_y + 4), Vector2(w * 0.5 + (x - w * 0.5) * 1.5, h), Color(0, 0, 0, 0.06), 2.0)
	_draw_window(t)
	# Luz que entra por la ventana
	if not t["stars"]:
		var window := _window_rect()
		var beam := PackedVector2Array([Vector2(window.position.x, window.end.y), Vector2(window.end.x, window.end.y), Vector2(window.end.x + w * 0.3, h), Vector2(window.position.x + w * 0.12, h)])
		draw_colored_polygon(beam, Color(1, 1, 0.92, 0.1))


func _draw_window(t: Dictionary) -> void:
	var window := _window_rect()
	_box(window.grow(10), FRAME * Color(_dim, _dim, _dim), 10)
	_gradient_rect(window, t["sky_top"], t["sky_bottom"])
	if t["stars"]:
		_draw_night_sky(window)
	else:
		if theme_id == "atardecer":
			draw_circle(window.position + Vector2(window.size.x * 0.62, window.size.y * 0.7), window.size.x * 0.16, Color("fff0b8"))
		_cloud(window.position + Vector2(window.size.x * 0.3, window.size.y * 0.3), window.size.x * 0.11)
		_cloud(window.position + Vector2(window.size.x * 0.72, window.size.y * 0.5), window.size.x * 0.08)
	var frame := FRAME * Color(_dim, _dim, _dim)
	draw_line(window.position + Vector2(window.size.x / 2, 0), window.position + Vector2(window.size.x / 2, window.size.y), frame, 6)
	draw_line(window.position + Vector2(0, window.size.y * 0.45), window.position + Vector2(window.size.x, window.size.y * 0.45), frame, 6)
	# Repisa y cortinas recogidas
	_box(Rect2(window.position.x - 16, window.end.y + 8, window.size.x + 32, 10), frame, 4)
	draw_line(Vector2(window.position.x - 22, window.position.y - 16), Vector2(window.end.x + 22, window.position.y - 16), WOOD_DARK * Color(_dim, _dim, _dim), 5)
	_curtain(window, true, t["curtain"])
	_curtain(window, false, t["curtain"])


func _curtain(window: Rect2, left: bool, color: Color) -> void:
	var top := window.position.y - 16.0
	var bottom := window.end.y + 34.0
	var outer := window.position.x - 20.0 if left else window.end.x + 20.0
	var direction := 1.0 if left else -1.0
	var width := window.size.x * 0.3
	var points := PackedVector2Array([
		Vector2(outer, top),
		Vector2(outer + direction * width, top),
		Vector2(outer + direction * width * 0.75, top + (bottom - top) * 0.3),
		Vector2(outer + direction * width * 0.35, top + (bottom - top) * 0.55),
		Vector2(outer + direction * width * 0.5, bottom),
		Vector2(outer, bottom),
	])
	draw_colored_polygon(points, color)
	for i in 3:
		var x := outer + direction * width * (0.12 + i * 0.1)
		draw_line(Vector2(x, top + 6), Vector2(x, bottom - 6), Color(1, 1, 1, 0.22), 2.0)
	# Lazo que la recoge
	_box(Rect2(outer + direction * width * 0.42 - 8 - (0.0 if left else 0.0), top + (bottom - top) * 0.53, 16, 9), Color(1, 1, 1, 0.9), 4)


## Cuadro con un paisajito.
func _picture(rect: Rect2, sky: Color) -> void:
	_shadow(Rect2(rect.position + Vector2(4, 8), rect.size), 6)
	_box(rect.grow(6), FRAME * Color(_dim, _dim, _dim), 6)
	_gradient_rect(rect, sky * Color(_dim, _dim, _dim), Color("fff1dc") * Color(_dim, _dim, _dim))
	draw_circle(rect.position + rect.size * Vector2(0.7, 0.32), rect.size.y * 0.14, Color("ffe08a") * Color(_dim, _dim, _dim))
	var hill := PackedVector2Array([Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - rect.size.y * 0.25), Vector2(rect.position.x + rect.size.x * 0.35, rect.end.y - rect.size.y * 0.5), Vector2(rect.position.x + rect.size.x * 0.65, rect.end.y - rect.size.y * 0.22), Vector2(rect.end.x, rect.end.y - rect.size.y * 0.38), rect.end])
	draw_colored_polygon(hill, Color("a9dcb5") * Color(_dim, _dim, _dim))


## Guirnalda de luces colgada en la pared.
func _string_lights(from: Vector2, to: Vector2, sag: float) -> void:
	var previous := from
	for i in 13:
		var f := i / 12.0
		var point := from.lerp(to, f) + Vector2(0, sin(f * PI) * sag)
		draw_line(previous, point, Color(0.45, 0.35, 0.4, 0.6), 1.5)
		previous = point
		if i > 0 and i < 12:
			var color: Color = LIGHTS[i % LIGHTS.size()]
			if theme_id != "dia":
				draw_circle(point + Vector2(0, 7), 13, Color(color.r, color.g, color.b, 0.25))
			draw_circle(point + Vector2(0, 7), 5, color)


func _plant(base: Vector2, scale_by: float) -> void:
	var green := Color("7fc592") * Color(_dim, _dim, _dim)
	for i in 7:
		var angle := -PI / 2.0 + (i - 3) * 0.3
		var tip := base + Vector2(cos(angle), sin(angle)) * 90.0 * scale_by
		draw_line(base, tip, green.darkened(0.1), 7.0 * scale_by)
		draw_circle(tip, 10.0 * scale_by, green)
		draw_circle(base.lerp(tip, 0.6) + Vector2(6, 0) * scale_by, 8.0 * scale_by, green.lightened(0.1))
	_box(Rect2(base.x - 26 * scale_by, base.y - 4, 52 * scale_by, 44 * scale_by), Color("f0b9a3") * Color(_dim, _dim, _dim), 8)
	_box(Rect2(base.x - 30 * scale_by, base.y - 8, 60 * scale_by, 12 * scale_by), Color("f7cdbb") * Color(_dim, _dim, _dim), 5)


## Dormitorio: cama grande con colcha, mesita con lámpara, luces y alfombra.
func _draw_bedroom(t: Dictionary, w: float, h: float, floor_y: float) -> void:
	_string_lights(Vector2(w * 0.42, h * 0.07), Vector2(w * 1.02, h * 0.1), h * 0.05)
	_picture(Rect2(w * 0.52, h * 0.2, w * 0.17, h * 0.1), Color("cfe6f5"))
	_picture(Rect2(w * 0.76, h * 0.17, w * 0.2, h * 0.13), Color("f5d0e3"))
	# Alfombra
	_shadow(Rect2(w * 0.04, floor_y + h * 0.05, w * 0.6, h * 0.07), 60)
	var rug: Color = t["curtain"]
	rug.a = 1.0
	_box(Rect2(w * 0.04, floor_y + h * 0.04, w * 0.6, h * 0.07), rug.lightened(0.25), 60)
	_box(Rect2(w * 0.09, floor_y + h * 0.052, w * 0.5, h * 0.046), rug.lightened(0.45), 50)
	# Mesita con lámpara
	var table := Rect2(w * 0.3, floor_y - h * 0.12, w * 0.13, h * 0.13)
	_shadow(Rect2(table.position.x - 6, table.end.y - 6, table.size.x + 12, 14), 8)
	_box(table, WOOD * Color(_dim, _dim, _dim), 8)
	_box(Rect2(table.position.x + 8, table.position.y + 12, table.size.x - 16, table.size.y * 0.36), WOOD_DARK * Color(_dim, _dim, _dim), 5)
	draw_circle(table.position + Vector2(table.size.x / 2.0, 12 + table.size.y * 0.18), 4, CREAM)
	var lamp := table.position + Vector2(table.size.x / 2.0, 0)
	if t["stars"]:
		draw_circle(lamp - Vector2(0, h * 0.075), w * 0.2, Color(1.0, 0.9, 0.55, 0.14))
		draw_circle(lamp - Vector2(0, h * 0.075), w * 0.11, Color(1.0, 0.9, 0.55, 0.16))
	draw_line(lamp, lamp - Vector2(0, h * 0.05), WOOD_DARK, 5)
	draw_colored_polygon(PackedVector2Array([lamp - Vector2(w * 0.055, h * 0.045), lamp + Vector2(w * 0.055, -h * 0.045), lamp + Vector2(w * 0.035, -h * 0.105), lamp - Vector2(w * 0.035, h * 0.105)]), Color("fff0c2") if t["stars"] else Color("fff6dc"))
	# Cama
	var bed := Rect2(w * 0.46, floor_y - h * 0.2, w * 0.6, h * 0.22)
	_shadow(Rect2(bed.position.x - 10, bed.end.y - 10, bed.size.x, 22), 12)
	_box(Rect2(bed.end.x - w * 0.14, bed.position.y - h * 0.13, w * 0.16, bed.size.y + h * 0.1), WOOD * Color(_dim, _dim, _dim), 26)
	_box(Rect2(bed.position.x, bed.position.y + bed.size.y * 0.5, bed.size.x, bed.size.y * 0.5), WOOD_DARK * Color(_dim, _dim, _dim), 12)
	_box(Rect2(bed.position.x - 4, bed.position.y + bed.size.y * 0.12, bed.size.x, bed.size.y * 0.52), CREAM * Color(_dim, _dim, _dim), 20)
	# Almohadas
	_box(Rect2(bed.position.x + bed.size.x * 0.56, bed.position.y - bed.size.y * 0.12, bed.size.x * 0.24, bed.size.y * 0.34), Color.WHITE * Color(_dim, _dim, _dim), 18)
	_box(Rect2(bed.position.x + bed.size.x * 0.64, bed.position.y - bed.size.y * 0.04, bed.size.x * 0.2, bed.size.y * 0.3), Color("ffe3ec") * Color(_dim, _dim, _dim), 16)
	# Colcha con franjas
	var quilt := blanket_color() * Color(_dim, _dim, _dim)
	var quilt_rect := Rect2(bed.position.x - 8, bed.position.y + bed.size.y * 0.16, bed.size.x * 0.56, bed.size.y * 0.62)
	_box(quilt_rect, quilt, 20)
	for i in 4:
		_box(Rect2(quilt_rect.position.x + quilt_rect.size.x * (0.1 + i * 0.22), quilt_rect.position.y + 6, quilt_rect.size.x * 0.08, quilt_rect.size.y - 12), Color(1, 1, 1, 0.3), 8)
	_box(Rect2(quilt_rect.end.x - 10, quilt_rect.position.y, bed.size.x * 0.06, quilt_rect.size.y), Color(1, 1, 1, 0.9) * Color(_dim, _dim, _dim, 1), 10)
	# Peluche sobre la cama
	var toy := Vector2(bed.position.x + bed.size.x * 0.5, bed.position.y + bed.size.y * 0.06)
	var toy_color := Color("f6d2a8") * Color(_dim, _dim, _dim)
	draw_circle(toy + Vector2(-13, -20), 8, toy_color)
	draw_circle(toy + Vector2(13, -20), 8, toy_color)
	draw_circle(toy, 20, toy_color)
	draw_circle(toy + Vector2(-7, -3), 2.5, Color("5c4a4a"))
	draw_circle(toy + Vector2(7, -3), 2.5, Color("5c4a4a"))
	draw_circle(toy + Vector2(0, 5), 3, Color("e89aa6"))


## Sala: sofá grande con cojines, lámpara de pie, estante y planta.
func _draw_living_room(t: Dictionary, w: float, h: float, floor_y: float) -> void:
	_picture(Rect2(w * 0.47, h * 0.12, w * 0.2, h * 0.13), Color("ffd9c2"))
	_picture(Rect2(w * 0.74, h * 0.07, w * 0.22, h * 0.11), Color("cfe6f5"))
	# Estante con libros y una plantita
	var shelf := Rect2(w * 0.7, h * 0.3, w * 0.28, h * 0.014)
	_shadow(Rect2(shelf.position + Vector2(0, 8), shelf.size), 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := shelf.position.x + 8.0
	while x < shelf.end.x - 50.0:
		var book_w := rng.randf_range(8.0, 14.0)
		var book_h := rng.randf_range(h * 0.04, h * 0.062)
		_box(Rect2(x, shelf.position.y - book_h, book_w, book_h), Color.from_hsv(rng.randf(), 0.32, 0.95) * Color(_dim, _dim, _dim), 2)
		x += book_w + 2.0
	_plant(Vector2(shelf.end.x - 24, shelf.position.y - 22), 0.4)
	_box(shelf, WOOD * Color(_dim, _dim, _dim), 4)
	# Lámpara de pie
	var lamp_base := Vector2(w * 0.44, floor_y)
	if t["stars"]:
		draw_circle(lamp_base - Vector2(0, h * 0.33), w * 0.22, Color(1.0, 0.9, 0.55, 0.13))
	draw_line(lamp_base, lamp_base - Vector2(0, h * 0.3), WOOD_DARK * Color(_dim, _dim, _dim), 5)
	_box(Rect2(lamp_base.x - 22, lamp_base.y - 6, 44, 10), WOOD_DARK * Color(_dim, _dim, _dim), 5)
	draw_colored_polygon(PackedVector2Array([lamp_base + Vector2(-w * 0.06, -h * 0.29), lamp_base + Vector2(w * 0.06, -h * 0.29), lamp_base + Vector2(w * 0.04, -h * 0.36), lamp_base + Vector2(-w * 0.04, -h * 0.36)]), Color("fff0c2") if t["stars"] else Color("fff6dc"))
	# Sofá
	var fabric := blanket_color() * Color(_dim, _dim, _dim)
	var sofa := Rect2(w * 0.5, floor_y - h * 0.2, w * 0.56, h * 0.2)
	_shadow(Rect2(sofa.position.x - 14, sofa.end.y - 8, sofa.size.x, 20), 12)
	_box(Rect2(sofa.position.x, sofa.position.y - h * 0.09, sofa.size.x, h * 0.2), fabric.darkened(0.07), 34)
	_box(Rect2(sofa.position.x - w * 0.05, sofa.position.y + h * 0.01, w * 0.12, sofa.size.y - h * 0.012), fabric.darkened(0.14), 26)
	_box(Rect2(sofa.position.x + w * 0.04, sofa.position.y + h * 0.06, sofa.size.x, h * 0.1), fabric.lightened(0.06), 20)
	_box(Rect2(sofa.position.x + w * 0.04, sofa.position.y + h * 0.15, sofa.size.x, h * 0.05), fabric.darkened(0.18), 10)
	_box(Rect2(sofa.position.x + w * 0.09, sofa.position.y - h * 0.035, w * 0.15, h * 0.1), Color("fff3c9") * Color(_dim, _dim, _dim), 18)
	_box(Rect2(sofa.position.x + w * 0.29, sofa.position.y - h * 0.03, w * 0.15, h * 0.1), Color("d6f1e4") * Color(_dim, _dim, _dim), 18)
	# Planta grande y mesa baja con taza
	_plant(Vector2(w * 0.1, floor_y - h * 0.035), 1.0)
	var table := Rect2(w * 0.14, floor_y + h * 0.045, w * 0.4, h * 0.024)
	_shadow(Rect2(table.position + Vector2(8, 16), table.size), 10)
	_box(table, WOOD * Color(_dim, _dim, _dim), 10)
	_box(Rect2(table.position.x + table.size.x * 0.6, table.position.y - 16, 22, 18), CREAM * Color(_dim, _dim, _dim), 5)
	draw_arc(Vector2(table.position.x + table.size.x * 0.6 + 26, table.position.y - 8), 6, -PI / 2, PI / 2, 8, CREAM * Color(_dim, _dim, _dim), 3)


## Cocina: azulejos, alacenas, mesón con estufa, refrigerador y lámpara.
func _draw_kitchen(t: Dictionary, w: float, h: float, floor_y: float) -> void:
	# Azulejos
	var tiles := Rect2(w * 0.42, floor_y - h * 0.34, w * 0.6, h * 0.16)
	draw_rect(tiles, Color(1, 1, 1, 0.5))
	var step := tiles.size.y / 4.0
	for i in 5:
		draw_line(tiles.position + Vector2(0, step * i), tiles.position + Vector2(tiles.size.x, step * i), Color(0.92, 0.72, 0.8, 0.5), 1.5)
	for i in int(tiles.size.x / step) + 1:
		draw_line(tiles.position + Vector2(step * i, 0), tiles.position + Vector2(step * i, tiles.size.y), Color(0.92, 0.72, 0.8, 0.5), 1.5)
	# Alacenas de arriba
	for i in 3:
		var cabinet := Rect2(w * (0.44 + i * 0.135), h * 0.08, w * 0.125, h * 0.2)
		_shadow(Rect2(cabinet.position + Vector2(0, 8), cabinet.size), 10)
		_box(cabinet, CREAM * Color(_dim, _dim, _dim), 10)
		draw_rect(cabinet.grow(-10), Color(0.93, 0.8, 0.76, 0.5), false, 2.0)
		draw_circle(cabinet.position + Vector2(cabinet.size.x * 0.82, cabinet.size.y * 0.86), 4, WOOD_DARK)
	# Reloj
	var clock := Vector2(w * 0.9, h * 0.15)
	draw_circle(clock, w * 0.05, WOOD * Color(_dim, _dim, _dim))
	draw_circle(clock, w * 0.04, CREAM * Color(_dim, _dim, _dim))
	draw_line(clock, clock + Vector2(0, -w * 0.028), Color("7a6170"), 2.5)
	draw_line(clock, clock + Vector2(w * 0.018, w * 0.008), Color("7a6170"), 2.5)
	# Refrigerador
	var fridge := Rect2(w * 0.84, floor_y - h * 0.44, w * 0.22, h * 0.44)
	_shadow(Rect2(fridge.position.x - 12, fridge.end.y - 8, fridge.size.x, 18), 10)
	_box(fridge, Color("e6f1f6") * Color(_dim, _dim, _dim), 16)
	draw_line(fridge.position + Vector2(0, fridge.size.y * 0.36), fridge.position + Vector2(fridge.size.x, fridge.size.y * 0.36), Color("c2d3db") * Color(_dim, _dim, _dim), 3)
	_box(Rect2(fridge.position.x + 10, fridge.position.y + fridge.size.y * 0.16, 6, fridge.size.y * 0.14), Color("9fb3bd"), 3)
	_box(Rect2(fridge.position.x + 10, fridge.position.y + fridge.size.y * 0.44, 6, fridge.size.y * 0.18), Color("9fb3bd"), 3)
	_box(Rect2(fridge.position.x + fridge.size.x * 0.4, fridge.position.y + fridge.size.y * 0.1, 22, 26), Color("ffd9e4"), 3)
	# Mesón
	var counter := Rect2(w * 0.42, floor_y - h * 0.18, w * 0.42, h * 0.18)
	_shadow(Rect2(counter.position.x - 10, counter.end.y - 8, counter.size.x, 18), 8)
	_box(counter, CREAM * Color(_dim, _dim, _dim), 8)
	_box(Rect2(counter.position.x - 8, counter.position.y - 10, counter.size.x + 8, 16), WOOD * Color(_dim, _dim, _dim), 6)
	for i in 3:
		var door := Rect2(counter.position.x + 10 + i * counter.size.x / 3.0, counter.position.y + 18, counter.size.x / 3.0 - 18, counter.size.y - 30)
		draw_rect(door, Color(0.93, 0.8, 0.76, 0.6), false, 2.0)
		draw_circle(door.position + Vector2(door.size.x - 10, 14), 3.5, WOOD_DARK)
	# Estufa con olla humeante
	var stove := Vector2(counter.position.x + counter.size.x * 0.3, counter.position.y - 10)
	_box(Rect2(stove.x - w * 0.08, stove.y - 6, w * 0.16, 7), Color("5c5560"), 3)
	_box(Rect2(stove.x - w * 0.05, stove.y - h * 0.05, w * 0.1, h * 0.046), Color("f29bb5") * Color(_dim, _dim, _dim), 8)
	_box(Rect2(stove.x - w * 0.06, stove.y - h * 0.058, w * 0.12, 9), Color("d97a98") * Color(_dim, _dim, _dim), 4)
	for i in 3:
		draw_arc(stove + Vector2((i - 1) * 13.0, -h * 0.082), 7, PI * 0.6, PI * 1.6, 8, Color(1, 1, 1, 0.75), 2.5)
	# Frutero
	var bowl := Vector2(counter.position.x + counter.size.x * 0.76, counter.position.y - 12)
	draw_circle(bowl + Vector2(-9, -13), 10, Color("ff9f6b") * Color(_dim, _dim, _dim))
	draw_circle(bowl + Vector2(9, -13), 10, Color("f25f5c") * Color(_dim, _dim, _dim))
	draw_circle(bowl + Vector2(0, -25), 10, Color("ffd166") * Color(_dim, _dim, _dim))
	_box(Rect2(bowl.x - 28, bowl.y - 11, 56, 14), Color("bfe3f2") * Color(_dim, _dim, _dim), 7)
	# Lámpara colgante
	var lamp := Vector2(w * 0.62, h * 0.36)
	if t["stars"]:
		draw_circle(lamp + Vector2(0, 14), w * 0.2, Color(1.0, 0.9, 0.55, 0.12))
	draw_line(Vector2(lamp.x, 0), lamp, Color(0.4, 0.33, 0.38, 0.7), 2.5)
	draw_colored_polygon(PackedVector2Array([lamp + Vector2(-w * 0.055, 22), lamp + Vector2(w * 0.055, 22), lamp + Vector2(w * 0.022, -4), lamp + Vector2(-w * 0.022, -4)]), Color("ffd0dc") * Color(_dim, _dim, _dim))
	draw_circle(lamp + Vector2(0, 24), 7, Color("fff3c2"))


## Patio: cielo abierto, cerca con luces, palmera, piscina, sombrilla y flores.
func _draw_patio(t: Dictionary, w: float, h: float) -> void:
	var d := Color(_dim, _dim, _dim)
	var horizon := h * 0.5
	_gradient_rect(Rect2(0, 0, w, horizon), t["sky_top"], t["sky_bottom"])
	if t["stars"]:
		_draw_night_sky(Rect2(0, 0, w, horizon * 0.9))
	else:
		var sun := Vector2(w * 0.8, h * 0.13 if theme_id == "dia" else h * 0.36)
		draw_circle(sun, w * 0.15, Color(1, 0.95, 0.7, 0.3))
		draw_circle(sun, w * 0.08, Color("fff3b0") if theme_id == "dia" else Color("ffc59a"))
		_cloud(Vector2(w * 0.22, h * 0.13), w * 0.075)
		_cloud(Vector2(w * 0.58, h * 0.25), w * 0.055)
	# Árboles lejanos y seto
	for i in 6:
		draw_circle(Vector2(w * (0.1 + i * 0.2), horizon - h * 0.07), w * 0.11, Color("9ad7ae") * d)
	for i in 10:
		draw_circle(Vector2(w * (i / 9.0), horizon - h * 0.015), w * 0.075, Color("7fc592") * d)
	# Cerca
	var fence := Color(1, 1, 1, 1) * d
	var post := 0.0
	while post < w:
		_box(Rect2(post, horizon - h * 0.085, w * 0.04, h * 0.1), fence, 6)
		post += w * 0.062
	draw_rect(Rect2(0, horizon - h * 0.055, w, h * 0.012), fence)
	draw_rect(Rect2(0, horizon - h * 0.02, w, h * 0.012), fence)
	_string_lights(Vector2(-10, h * 0.3), Vector2(w + 10, h * 0.31), h * 0.05)
	# Pasto con franjas
	var grass := Color("a8e0a0") * d
	_gradient_rect(Rect2(0, horizon, w, h - horizon), grass, grass.darkened(0.14))
	for i in 5:
		draw_rect(Rect2(0, horizon + (h - horizon) * (i * 0.2), w, (h - horizon) * 0.1), Color(1, 1, 1, 0.06))
	# Palmera
	var trunk := Vector2(w * 0.12, horizon + h * 0.12)
	var top := trunk + Vector2(w * 0.04, -h * 0.4)
	for i in 8:
		var a := trunk.lerp(top, i / 8.0)
		var b := trunk.lerp(top, (i + 1) / 8.0)
		draw_line(a, b, (WOOD_DARK if i % 2 == 0 else WOOD) * d, w * 0.035)
	for i in 7:
		var angle := -PI * 1.05 + i * PI * 1.1 / 6.0
		var middle := top + Vector2(cos(angle) * w * 0.13, sin(angle) * h * 0.05 - h * 0.01)
		var tip := top + Vector2(cos(angle) * w * 0.25, sin(angle) * h * 0.05 + h * 0.06)
		draw_line(top, middle, Color("5fb574") * d, w * 0.03)
		draw_line(middle, tip, Color("6fc584") * d, w * 0.022)
	draw_circle(top, w * 0.025, Color("8a6a4f") * d)
	# Piscina
	var pool := PackedVector2Array([Vector2(w * 0.42, horizon + h * 0.08), Vector2(w * 1.02, horizon + h * 0.08), Vector2(w * 1.02, horizon + h * 0.3), Vector2(w * 0.32, horizon + h * 0.3)])
	var border := PackedVector2Array([pool[0] + Vector2(-w * 0.03, -h * 0.014), pool[1] + Vector2(0, -h * 0.014), pool[2] + Vector2(0, h * 0.016), pool[3] + Vector2(-w * 0.035, h * 0.016)])
	draw_colored_polygon(border, Color("fff7ee") * d)
	var water := Color("7fd6f2") * d
	draw_polygon(pool, PackedColorArray([water.lightened(0.2), water.lightened(0.2), water.darkened(0.08), water.darkened(0.08)]))
	for i in 6:
		var y := horizon + h * (0.105 + i * 0.033)
		var start := w * (0.44 + (i % 2) * 0.07)
		for j in 3:
			draw_arc(Vector2(start + w * (0.06 + j * 0.19), y + j * 3.0), w * 0.045, PI * 1.15, PI * 1.85, 10, Color(1, 1, 1, 0.5), 2.5)
	# Flotador y escalera
	draw_arc(Vector2(w * 0.8, horizon + h * 0.2), w * 0.05, 0, TAU, 28, Color("ff9fbc") * d, w * 0.026)
	draw_arc(Vector2(w * 0.8, horizon + h * 0.2), w * 0.05, 0.3, 1.0, 8, Color(1, 1, 1, 0.9), w * 0.026)
	for i in 2:
		draw_arc(Vector2(w * (0.47 + i * 0.05), horizon + h * 0.085), w * 0.022, PI, TAU, 10, Color("c9d6dd") * d, 4)
	# Sombrilla y tumbona
	var pole := Vector2(w * 0.3, horizon + h * 0.2)
	draw_line(pole, pole - Vector2(0, h * 0.26), Color("f4f0ec") * d, 5)
	var canopy := pole - Vector2(0, h * 0.26)
	for i in 4:
		var left := canopy + Vector2(-w * 0.16 + i * w * 0.08, h * 0.05)
		draw_colored_polygon(PackedVector2Array([canopy, left, left + Vector2(w * 0.08, 0)]), (Color("ff9fbc") if i % 2 == 0 else Color("fff4f7")) * d)
	_box(Rect2(pole.x - w * 0.11, pole.y - h * 0.015, w * 0.2, h * 0.02), Color("fff4f7") * d, 6)
	draw_line(Vector2(pole.x - w * 0.11, pole.y - h * 0.012), Vector2(pole.x - w * 0.16, pole.y - h * 0.055), Color("fff4f7") * d, 9)
	# Flores
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		var p := Vector2(rng.randf() * w * 0.36, horizon + h * 0.03 + rng.randf() * h * 0.07)
		draw_circle(p, 4.5, Color.from_hsv(rng.randf_range(0.85, 1.0), 0.45, 1.0) * d)
		draw_circle(p, 1.8, Color("fff3b0") * d)


## Vista de cerca de la cama: almohada grande a la derecha, colchón ancho.
func _draw_sleep_view(t: Dictionary, w: float, h: float) -> void:
	var d := Color(_dim, _dim, _dim)
	_gradient_rect(Rect2(0, 0, w, h * 0.7), t["wall_top"], t["wall_bottom"])
	var stripe := w / 8.0
	for i in 9:
		draw_rect(Rect2(i * stripe, 0, stripe * 0.5, h * 0.7), Color(1, 1, 1, 0.06))
	# Ventana pequeña con el cielo
	var window := Rect2(w * 0.08, h * 0.07, w * 0.34, h * 0.2)
	_box(window.grow(9), FRAME * d, 10)
	_gradient_rect(window, t["sky_top"], t["sky_bottom"])
	if t["stars"]:
		_draw_night_sky(window)
	else:
		_cloud(window.position + window.size * Vector2(0.4, 0.45), window.size.x * 0.13)
	draw_line(window.position + Vector2(window.size.x / 2, 0), window.position + Vector2(window.size.x / 2, window.size.y), FRAME * d, 5)
	_string_lights(Vector2(w * 0.46, h * 0.09), Vector2(w * 1.02, h * 0.12), h * 0.05)
	# Piso
	var floor_color: Color = t["floor"]
	_gradient_rect(Rect2(0, h * 0.7, w, h * 0.3), floor_color.lightened(0.05), floor_color.darkened(0.12))
	# Cabecera, base, colchón y sábana
	_box(Rect2(w * 0.84, h * 0.24, w * 0.3, h * 0.46), WOOD * d, 40)
	_box(Rect2(w * 0.87, h * 0.27, w * 0.3, h * 0.2), WOOD_DARK * d, 30)
	_shadow(Rect2(-w * 0.05, h * 0.71, w * 1.1, h * 0.03), 10)
	_box(Rect2(-w * 0.1, h * 0.6, w * 1.2, h * 0.12), WOOD_DARK * d, 16)
	_box(Rect2(-w * 0.1, h * 0.5, w * 1.07, h * 0.13), CREAM * d, 30)
	draw_line(Vector2(0, h * 0.585), Vector2(w * 0.95, h * 0.585), Color(0, 0, 0, 0.06), 3)
	# Almohada mullida
	_shadow(Rect2(w * 0.47, h * 0.49, w * 0.46, h * 0.03), 14)
	_box(Rect2(w * 0.46, h * 0.4, w * 0.47, h * 0.115), Color.WHITE * d, 44)
	_box(Rect2(w * 0.49, h * 0.412, w * 0.41, h * 0.05), Color(1, 1, 1, 0.5), 30)


func _draw_vignette(w: float, h: float) -> void:
	var shade := Color(0.25, 0.1, 0.2, 0.16 if theme_id != "noche" else 0.3)
	var clear := Color(shade.r, shade.g, shade.b, 0.0)
	_gradient_rect(Rect2(0, 0, w, h * 0.16), shade, clear)
	_gradient_rect(Rect2(0, h * 0.8, w, h * 0.2), clear, shade)


func _draw_night_sky(window: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 28:
		var p := window.position + Vector2(rng.randf() * window.size.x, rng.randf() * window.size.y)
		draw_circle(p, rng.randf_range(0.8, 2.0), Color(1, 1, 0.9, rng.randf_range(0.5, 1.0)))
	var radius := minf(window.size.x, window.size.y) * 0.13
	var moon := window.position + Vector2(window.size.x * 0.72, window.size.y * 0.28)
	draw_circle(moon, radius * 1.8, Color(1, 1, 0.85, 0.12))
	draw_circle(moon, radius, Color("fff6d5"))
	draw_circle(moon + Vector2(radius * 0.4, -radius * 0.25), radius * 0.88, THEMES["noche"]["sky_top"].lerp(THEMES["noche"]["sky_bottom"], 0.3))


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _cloud(center: Vector2, r: float) -> void:
	var white := Color(1, 1, 1, 0.92)
	draw_circle(center, r, white)
	draw_circle(center + Vector2(-r * 0.9, r * 0.3), r * 0.7, white)
	draw_circle(center + Vector2(r * 0.9, r * 0.3), r * 0.75, white)


## Sombra suave bajo un mueble.
func _shadow(rect: Rect2, radius: int) -> void:
	_box(rect.grow(4), Color(0.3, 0.12, 0.25, 0.1), radius + 4)
	_box(rect, Color(0.3, 0.12, 0.25, 0.1), radius)


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
