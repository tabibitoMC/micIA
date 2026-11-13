class_name ImageViewer
extends TextureRect
## Muestra una imagen en grande. Se cierra al tocarla.

signal closed


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_texture(tex: Texture2D, max_size: Vector2) -> void:
	texture = tex
	custom_minimum_size = max_size


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		closed.emit()
		accept_event()
