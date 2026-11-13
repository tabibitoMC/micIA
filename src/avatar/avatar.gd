class_name Avatar
extends Control
## Contrato común de todos los avatares.
##
## main.gd solo habla con el avatar a través de estos métodos, así se puede
## cambiar el avatar 2D provisional por el modelo 3D (VRM) sin tocar el resto.
##
## emotion: uno de AIReply.EMOTIONS
## action:  uno de AIReply.ACTIONS

## Se emite cuando el usuario toca el avatar (base para interacciones futuras).
signal touched


func set_emotion(_emotion: String) -> void:
	pass


func play_action(_action: String) -> void:
	pass


func set_talking(_talking: bool) -> void:
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


func _gui_input(event: InputEvent) -> void:
	# En Android los toques llegan también como clic de mouse (emulación por
	# defecto de Godot), así que basta con escuchar el clic.
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		touched.emit()
		accept_event()
