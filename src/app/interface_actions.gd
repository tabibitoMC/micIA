class_name InterfaceActions
extends Node
## Lo que ella hace con la interfaz: caminar hasta un botón y señalarlo,
## cambiar el fondo tocando la ventana, pasear sola...
##
## La IA elige la acción con el campo "interfaz" de su respuesta; aquí está
## cómo se ejecuta cada una. Para agregar una acción nueva:
##   1. Añadir su id a AIReply.INTERFACE_ACTIONS (y explicarla en el prompt).
##   2. Añadir su caso en perform().

## Paseos sola cuando no pasa nada (segundos entre uno y otro).
const IDLE_WANDER_MIN := 40.0
const IDLE_WANDER_MAX := 90.0

var avatar: Avatar
var room: RoomBackground
var gift_button: SideButton
## Función que devuelve true si ahora no debe moverse (hablando, bloqueada...).
var is_occupied: Callable = func() -> bool: return false

var _busy := false
var _wander_timer: Timer


func _ready() -> void:
	_wander_timer = Timer.new()
	_wander_timer.one_shot = true
	_wander_timer.timeout.connect(_on_wander_timeout)
	add_child(_wander_timer)
	_restart_wander_timer()


func is_busy() -> bool:
	return _busy


func perform(action: String) -> void:
	if _busy or avatar == null or action == "ninguna" or action.is_empty():
		return
	_busy = true
	match action:
		"pedir_regalo":
			await _walk_and_point(gift_button.get_global_rect().get_center())
			gift_button.pulse()
			await avatar.go_home()
		"fondo_dia", "fondo_atardecer", "fondo_noche":
			await _walk_and_point(room.window_global_center())
			room.set_room_theme(action.trim_prefix("fondo_"))
			await avatar.go_home()
		"pasear":
			await _wander()
	_busy = false
	_restart_wander_timer()


## Camina hasta quedar al lado del punto y lo señala.
func _walk_and_point(point: Vector2) -> void:
	var screen_width := avatar.get_viewport_rect().size.x
	# Se para un poco hacia el centro para que el brazo alcance el punto.
	var stand_x := clampf(point.x, screen_width * 0.3, screen_width * 0.7)
	await avatar.walk_to_screen_x(stand_x)
	await avatar.point_at_screen(point, 0.8)


func _wander() -> void:
	var screen_width := avatar.get_viewport_rect().size.x
	await avatar.walk_to_screen_x(randf_range(screen_width * 0.3, screen_width * 0.7))
	await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
	await avatar.go_home()


func _on_wander_timeout() -> void:
	if not _busy and not is_occupied.call():
		await perform("pasear")
	else:
		_restart_wander_timer()


func _restart_wander_timer() -> void:
	_wander_timer.start(randf_range(IDLE_WANDER_MIN, IDLE_WANDER_MAX))
