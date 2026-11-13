class_name Avatar2D
extends Avatar
## Avatar provisional: una cara anime dibujada por código.
##
## Sirve para probar emociones, acciones y la boca al hablar mientras no
## tengamos el modelo 3D (VRM). Funciona en cualquier dispositivo porque no
## usa texturas ni 3D.

const SKIN := Color("ffe0cf")
const HAIR := Color("3a2a5c")
const HAIR_SHADOW := Color("2b1f45")
const IRIS := Color("7a4bd1")
const MOUTH := Color("b5485d")
const BLUSH := Color(1.0, 0.55, 0.65, 0.45)
const ANGER_MARK := Color("e0405a")
const LINE := Color("4a2f3a")

## Desplazamiento y giro animados por las acciones (los usa _draw).
var anim_offset := Vector2.ZERO
var anim_tilt := 0.0
## Hacia dónde mira (-1..1 en cada eje).
var look := Vector2.ZERO

var _emotion := "neutral"
var _talking := false
var _mouth_open := 0.0
var _talk_time := 0.0
var _blink := 0.0
var _blink_timer := 0.0
var _idle_time := 0.0
var _action_tween: Tween
var _turned_away := false
## Desplazamiento horizontal al "caminar" por la pantalla.
var walk_offset := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_schedule_blink()


func set_emotion(emotion: String) -> void:
	_emotion = emotion
	look = Vector2.ZERO
	match emotion:
		"pensativa":
			look = Vector2(0.6, -0.6)
		"avergonzada":
			look = Vector2(-0.4, 0.6)
	queue_redraw()


func set_talking(talking: bool) -> void:
	_talking = talking
	if not talking:
		_mouth_open = 0.0


func play_action(action: String) -> void:
	if _action_tween:
		_action_tween.kill()
	anim_offset = Vector2.ZERO
	anim_tilt = 0.0
	_action_tween = create_tween()
	match action:
		"saludar":
			for i in 3:
				_action_tween.tween_property(self, "anim_tilt", -0.15, 0.15)
				_action_tween.tween_property(self, "anim_tilt", 0.15, 0.15)
			_action_tween.tween_property(self, "anim_tilt", 0.0, 0.15)
		"asentir":
			for i in 2:
				_action_tween.tween_property(self, "anim_offset:y", 14.0, 0.15)
				_action_tween.tween_property(self, "anim_offset:y", 0.0, 0.15)
		"negar":
			for i in 3:
				_action_tween.tween_property(self, "anim_offset:x", -14.0, 0.1)
				_action_tween.tween_property(self, "anim_offset:x", 14.0, 0.1)
			_action_tween.tween_property(self, "anim_offset:x", 0.0, 0.1)
		"saltar":
			_action_tween.tween_property(self, "anim_offset:y", -50.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			_action_tween.tween_property(self, "anim_offset:y", 0.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		"cruzar_brazos":
			_action_tween.tween_property(self, "anim_tilt", 0.12, 0.25)
			_action_tween.tween_interval(1.5)
			_action_tween.tween_property(self, "anim_tilt", 0.0, 0.3)
		"mirar_otro_lado":
			_action_tween.tween_property(self, "look", Vector2(-1.0, 0.0), 0.2)
			_action_tween.tween_property(self, "anim_tilt", -0.1, 0.2)
			_action_tween.tween_interval(1.5)
			_action_tween.tween_property(self, "look", Vector2.ZERO, 0.3)
			_action_tween.parallel().tween_property(self, "anim_tilt", 0.0, 0.3)
		_:
			_action_tween.kill()


func walk_to_screen_x(x: float) -> void:
	var target := x - (global_position.x + size.x / 2.0)
	var tween := create_tween()
	tween.tween_property(self, "walk_offset", target, absf(target - walk_offset) / 300.0 + 0.1)
	await tween.finished


func go_home() -> void:
	await walk_to_screen_x(global_position.x + size.x / 2.0)


func point_at_screen(point: Vector2, seconds := 1.0) -> void:
	var to_left := point.x < global_position.x + size.x / 2.0 + walk_offset
	var tween := create_tween()
	tween.tween_property(self, "anim_tilt", -0.15 if to_left else 0.15, 0.25)
	tween.tween_interval(seconds)
	tween.tween_property(self, "anim_tilt", 0.0, 0.25)
	await tween.finished


func set_turned_away(away: bool) -> void:
	_turned_away = away
	queue_redraw()


func _process(delta: float) -> void:
	_idle_time += delta
	# Parpadeo
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_schedule_blink()
	_blink = maxf(0.0, _blink - delta * 7.0)
	# Boca al hablar
	if _talking:
		_talk_time += delta
		_mouth_open = 0.5 + 0.5 * sin(_talk_time * 18.0) * absf(sin(_talk_time * 5.3))
	queue_redraw()


func _schedule_blink() -> void:
	_blink_timer = randf_range(2.0, 5.0)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.36
	if radius <= 1.0:
		return
	var breathing := sin(_idle_time * 2.0) * radius * 0.012
	var center := size / 2.0 + anim_offset + Vector2(walk_offset, breathing)
	draw_set_transform(center, anim_tilt, Vector2.ONE)

	if _turned_away:
		# De espaldas: solo se ve el pelo.
		_draw_hair_back(radius)
		draw_circle(Vector2(0, -radius * 0.05), radius * 1.05, HAIR)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	_draw_hair_back(radius)
	draw_circle(Vector2.ZERO, radius, SKIN)
	_draw_bangs(radius)
	_draw_eyes(radius)
	_draw_brows(radius)
	_draw_mouth(radius)
	if _emotion == "avergonzada" or _emotion == "feliz":
		_draw_blush(radius)
	if _emotion == "enojada":
		_draw_anger_mark(radius)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hair_back(r: float) -> void:
	draw_circle(Vector2(0, -r * 0.12), r * 1.18, HAIR_SHADOW)
	# Mechones laterales largos
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 1.15, -r * 0.2), Vector2(-r * 0.75, r * 0.2), Vector2(-r * 0.95, r * 1.35), Vector2(-r * 1.25, r * 1.1),
	]), HAIR_SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(r * 1.15, -r * 0.2), Vector2(r * 0.75, r * 0.2), Vector2(r * 0.95, r * 1.35), Vector2(r * 1.25, r * 1.1),
	]), HAIR_SHADOW)


func _draw_bangs(r: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(-r * 1.05, -r * 0.05))
	for i in range(0, 181, 15):
		var angle := deg_to_rad(180.0 + i)
		points.append(Vector2(cos(angle), sin(angle)) * r * 1.08 + Vector2(0, -r * 0.05))
	points.append(Vector2(r * 1.05, -r * 0.05))
	# Puntas del flequillo
	var tips := [0.85, 0.5, 0.15, -0.2, -0.55, -0.9]
	for i in tips.size():
		var x: float = tips[i] * r
		points.append(Vector2(x, -r * 0.25 if i % 2 == 0 else -r * 0.4))
	draw_colored_polygon(points, HAIR)


func _draw_eyes(r: float) -> void:
	var eye_y := r * 0.12
	var eye_dx := r * 0.38
	var happy_closed := _emotion == "feliz" and _talking == false and fmod(_idle_time, 6.0) < 1.5
	for side in [-1.0, 1.0]:
		var c := Vector2(eye_dx * side, eye_y)
		if _blink > 0.3:
			draw_line(c + Vector2(-r * 0.15, 0), c + Vector2(r * 0.15, 0), LINE, maxf(2.0, r * 0.035))
			continue
		if happy_closed:
			draw_arc(c + Vector2(0, r * 0.05), r * 0.14, PI, TAU, 12, LINE, maxf(2.0, r * 0.035))
			continue
		var open_y := 1.0
		if _emotion == "enojada":
			open_y = 0.75
		elif _emotion == "sorprendida":
			open_y = 1.15
		_draw_ellipse(c, Vector2(r * 0.17, r * 0.22 * open_y), Color.WHITE)
		var pupil_scale := 0.6 if _emotion == "sorprendida" else 1.0
		var iris_c := c + look * Vector2(r * 0.06, r * 0.07)
		_draw_ellipse(iris_c, Vector2(r * 0.12, r * 0.16 * open_y), IRIS)
		draw_circle(iris_c, r * 0.06 * pupil_scale, Color("221133"))
		draw_circle(iris_c + Vector2(-r * 0.04, -r * 0.06), r * 0.035, Color(1, 1, 1, 0.9))
		# Línea superior (pestañas)
		draw_arc(c, r * 0.18, deg_to_rad(200), deg_to_rad(340), 12, LINE, maxf(2.0, r * 0.04))


func _draw_brows(r: float) -> void:
	# inner_dy > 0: extremo interior más abajo (enojo); < 0: más arriba (tristeza)
	var inner_dy := 0.0
	var lift := 0.0
	match _emotion:
		"enojada": inner_dy = r * 0.1
		"triste": inner_dy = -r * 0.08
		"sorprendida": lift = -r * 0.08
		"avergonzada": inner_dy = -r * 0.04
		"pensativa": lift = -r * 0.03
	var y := -r * 0.18 + lift
	var width := maxf(2.0, r * 0.035)
	for side in [-1.0, 1.0]:
		var outer := Vector2(r * 0.55 * side, y)
		var inner := Vector2(r * 0.2 * side, y + inner_dy)
		draw_line(outer, inner, HAIR_SHADOW, width)


func _draw_mouth(r: float) -> void:
	var c := Vector2(0, r * 0.55)
	var width := maxf(2.0, r * 0.035)
	if _talking and _mouth_open > 0.1:
		_draw_ellipse(c, Vector2(r * 0.1, r * 0.03 + r * 0.1 * _mouth_open), MOUTH)
		return
	match _emotion:
		"feliz":
			draw_arc(c + Vector2(0, -r * 0.06), r * 0.14, deg_to_rad(20), deg_to_rad(160), 12, MOUTH, width)
		"triste", "enojada":
			draw_arc(c + Vector2(0, r * 0.1), r * 0.12, deg_to_rad(210), deg_to_rad(330), 12, MOUTH, width)
		"sorprendida":
			_draw_ellipse(c, Vector2(r * 0.06, r * 0.08), MOUTH)
		"avergonzada":
			var pts := PackedVector2Array()
			for i in 7:
				pts.append(c + Vector2((i - 3) * r * 0.035, (r * 0.015) * (1 if i % 2 == 0 else -1)))
			draw_polyline(pts, MOUTH, width)
		"pensativa":
			draw_line(c + Vector2(-r * 0.02, 0), c + Vector2(r * 0.1, -r * 0.02), MOUTH, width)
		_:
			draw_arc(c + Vector2(0, -r * 0.04), r * 0.09, deg_to_rad(30), deg_to_rad(150), 10, MOUTH, width)


func _draw_blush(r: float) -> void:
	for side in [-1.0, 1.0]:
		_draw_ellipse(Vector2(r * 0.55 * side, r * 0.4), Vector2(r * 0.14, r * 0.06), BLUSH)


func _draw_anger_mark(r: float) -> void:
	var c := Vector2(r * 0.7, -r * 0.65)
	var s := r * 0.12
	var width := maxf(2.0, r * 0.04)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = c + corner * s
		draw_arc(p, s * 0.6, corner.angle() + PI * 0.6, corner.angle() + PI * 1.4, 8, ANGER_MARK, width)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
