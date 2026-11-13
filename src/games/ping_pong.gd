class_name PingPongGame
extends MiniGame
## Ping-pong en tiempo real. Tu paleta abajo (arrastra el dedo o el mouse),
## la de ella arriba con una IA local (Mistral no puede responder 60 veces
## por segundo). Al final ella comenta el resultado por Mistral.

const WIN_SCORE := 5
const PADDLE_SIZE := Vector2(80, 12)
const BALL_RADIUS := 8.0
const START_SPEED := 260.0
const SPEED_UP := 1.06
const HER_SPEED := 300.0

## Reacción de ella a cada punto (sin gastar peticiones).
signal point_scored(user_scored: bool)

var _field: Control
var _ball := Vector2.ZERO
var _velocity := Vector2.ZERO
var _user_x := 0.0
var _her_x := 0.0
var _user_score := 0
var _her_score := 0
var _playing := false
var _her_error := 0.0


func game_title() -> String:
	return "Ping-pong"


func build() -> void:
	_field = Control.new()
	_field.custom_minimum_size = Vector2(300, 380)
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.draw.connect(_draw_field)
	_field.gui_input.connect(_on_field_input)
	add_child(_field)
	set_status("Toca la mesa para sacar. Mueve tu paleta con el dedo.")
	_reset_ball(true)


func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_user_x = clampf(event.position.x, PADDLE_SIZE.x / 2, _field.size.x - PADDLE_SIZE.x / 2)
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and not _playing and _user_score < WIN_SCORE and _her_score < WIN_SCORE:
		_playing = true
		_user_x = clampf(mouse.position.x, PADDLE_SIZE.x / 2, _field.size.x - PADDLE_SIZE.x / 2)


func _process(delta: float) -> void:
	if _field == null or _field.size.x <= 0:
		return
	var w := _field.size.x
	var h := _field.size.y
	if _user_x == 0.0:
		_user_x = w / 2
		_her_x = w / 2
	if _playing:
		_ball += _velocity * delta
		# Paredes laterales
		if _ball.x < BALL_RADIUS or _ball.x > w - BALL_RADIUS:
			_velocity.x = -_velocity.x
			_ball.x = clampf(_ball.x, BALL_RADIUS, w - BALL_RADIUS)
		# Paleta de ella: sigue la pelota con un poco de error
		var target := (_ball.x + _her_error) if _velocity.y < 0 else w / 2
		_her_x = move_toward(_her_x, target, HER_SPEED * delta)
		_her_x = clampf(_her_x, PADDLE_SIZE.x / 2, w - PADDLE_SIZE.x / 2)
		_check_paddle_hits(h)
		if _ball.y < 0:
			_score(true)
		elif _ball.y > h:
			_score(false)
	_field.queue_redraw()


func _check_paddle_hits(h: float) -> void:
	var user_y := h - 24.0
	var her_y := 24.0
	if _velocity.y > 0 and absf(_ball.y - user_y) < BALL_RADIUS + PADDLE_SIZE.y / 2 and absf(_ball.x - _user_x) < PADDLE_SIZE.x / 2 + BALL_RADIUS:
		_bounce(_user_x, -1.0)
	elif _velocity.y < 0 and absf(_ball.y - her_y) < BALL_RADIUS + PADDLE_SIZE.y / 2 and absf(_ball.x - _her_x) < PADDLE_SIZE.x / 2 + BALL_RADIUS:
		_bounce(_her_x, 1.0)
		_her_error = randf_range(-PADDLE_SIZE.x * 0.7, PADDLE_SIZE.x * 0.7)


## Rebote: el ángulo depende de dónde pega en la paleta.
func _bounce(paddle_x: float, direction_y: float) -> void:
	var offset := clampf((_ball.x - paddle_x) / (PADDLE_SIZE.x / 2), -1.0, 1.0)
	var speed := _velocity.length() * SPEED_UP
	_velocity = Vector2(offset * 0.8, direction_y).normalized() * speed


func _score(user_scored: bool) -> void:
	_playing = false
	if user_scored:
		_user_score += 1
	else:
		_her_score += 1
	point_scored.emit(user_scored)
	var user := Settings.user_display_name()
	if _user_score >= WIN_SCORE or _her_score >= WIN_SCORE:
		if _user_score > _her_score:
			set_status("¡Ganaste %d a %d!" % [_user_score, _her_score])
			finish("Jugaron ping-pong y %s te ganó %d a %d." % [user, _user_score, _her_score], "Ganaste %d-%d al ping-pong" % [_user_score, _her_score])
		else:
			set_status("Ganó %s %d a %d." % [companion_name(), _her_score, _user_score])
			finish("Jugaron ping-pong y tú le ganaste a %s %d a %d." % [user, _her_score, _user_score], "Perdiste %d-%d al ping-pong" % [_user_score, _her_score])
		return
	set_status("Tú %d - %d %s · Toca para sacar." % [_user_score, _her_score, companion_name()])
	_reset_ball(not user_scored)


func _reset_ball(towards_user: bool) -> void:
	var w := maxf(_field.size.x, 300.0)
	var h := maxf(_field.size.y, 380.0)
	_ball = Vector2(w / 2, h / 2)
	_velocity = Vector2(randf_range(-0.5, 0.5), 1.0 if towards_user else -1.0).normalized() * START_SPEED
	_her_error = randf_range(-PADDLE_SIZE.x * 0.6, PADDLE_SIZE.x * 0.6)


func _draw_field() -> void:
	var s := _field.size
	_field.draw_style_box(UIStyle.rounded(Color("7fc8a9"), 16, 0), Rect2(Vector2.ZERO, s))
	_field.draw_line(Vector2(0, s.y / 2), Vector2(s.x, s.y / 2), Color(1, 1, 1, 0.8), 3)
	_field.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.8), false, 3)
	_draw_paddle(Vector2(_her_x, 24), Color("4a7bd1"))
	_draw_paddle(Vector2(_user_x, s.y - 24), UIStyle.PINK_DEEP)
	_field.draw_circle(_ball + Vector2(2, 3), BALL_RADIUS, Color(0, 0, 0, 0.2))
	_field.draw_circle(_ball, BALL_RADIUS, Color.WHITE)


func _draw_paddle(center: Vector2, color: Color) -> void:
	var rect := Rect2(center - PADDLE_SIZE / 2, PADDLE_SIZE)
	_field.draw_style_box(UIStyle.rounded(color, 6, 0), rect)
