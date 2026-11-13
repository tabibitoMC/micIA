class_name Avatar
extends Control
## Contrato común de todos los avatares.
##
## main.gd solo habla con el avatar a través de estos métodos, así se puede
## cambiar el avatar 2D provisional por el modelo 3D (VRM) sin tocar el resto.
##
## emotion: uno de AIReply.EMOTIONS
## action:  uno de AIReply.ACTIONS

## Se emite cuando el usuario toca el avatar. `point` es global (pantalla).
signal touched(point: Vector2)
## Se emite cuando ella "te golpea" (acción golpear), para sacudir la pantalla.
signal struck


func set_emotion(_emotion: String) -> void:
	pass


func play_action(_action: String) -> void:
	pass


func set_talking(_talking: bool) -> void:
	pass


## Colores del conjunto de ropa (solo el avatar 3D lo usa).
func apply_tint(_cloth: Color, _hair: Color) -> void:
	pass


# --- Movimiento por la pantalla (fase 3) ------------------------------------
# Son asíncronas: se pueden usar con `await` para esperar a que terminen.
# Las coordenadas son globales de la interfaz (las de Control.global_position).

## Camina hasta que su cuerpo quede en la X de pantalla indicada.
func walk_to_screen_x(_x: float) -> void:
	pass


## Señala un punto de la pantalla durante `seconds` segundos.
func point_at_screen(_point: Vector2, _seconds := 1.0) -> void:
	pass


## Vuelve a su lugar de siempre (el centro).
func go_home() -> void:
	pass


## Darte la espalda (por ejemplo, cuando te bloquea).
func set_turned_away(_away: bool) -> void:
	pass


# --- Lugares (solo el avatar 3D tiene habitaciones) --------------------------

func set_room(_env_id: String, _time_theme: String) -> void:
	pass


func set_time_of_day(_time_theme: String) -> void:
	pass


func current_room() -> String:
	return ""


func fade(_to_black: bool, _seconds := 0.35) -> void:
	pass


func place_at_side(_from_left: bool) -> void:
	pass


## Sale caminando por un lado (para cambiar de lugar).
func walk_out(to_right: bool) -> void:
	await walk_to_screen_x(get_viewport_rect().size.x * (1.0 if to_right else 0.0))


func set_sleeping(_sleeping: bool) -> void:
	pass


func is_sleeping() -> bool:
	return false


## Posición en pantalla de la ventana del cuarto (o null si no hay).
func window_screen_position() -> Variant:
	return null


func _gui_input(event: InputEvent) -> void:
	# En Android los toques llegan también como clic de mouse (emulación por
	# defecto de Godot), así que basta con escuchar el clic.
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		touched.emit(get_global_mouse_position())
		accept_event()


## ¿El punto (global) cae sobre su cabeza? Lo usan las caricias.
func is_head_at(_point: Vector2) -> bool:
	return false


## ¿El punto (global) cae sobre su cuerpo? Fuera de él los toques se ignoran.
func is_body_at(_point: Vector2) -> bool:
	return true
