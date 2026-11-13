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


func _gui_input(event: InputEvent) -> void:
	# En Android los toques llegan también como clic de mouse (emulación por
	# defecto de Godot), así que basta con escuchar el clic.
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		touched.emit()
		accept_event()
