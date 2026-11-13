class_name ChatView
extends ScrollContainer
## Lista de mensajes del chat (burbujas) que flota sobre el avatar, con
## desplazamiento automático al final.

enum Sender { USER, COMPANION, EVENT, SYSTEM }

## Se emite al tocar una imagen del chat (para verla en grande).
signal image_tapped(texture: Texture2D)

## Ancho máximo de las imágenes dentro del chat.
const IMAGE_MAX_WIDTH := 220.0

## Cuántas burbujas se mantienen en pantalla (el historial completo está en Memory).
const MAX_BUBBLES := 60

var _list: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.alignment = BoxContainer.ALIGNMENT_END
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)


func add_message(sender: Sender, text: String) -> void:
	var row: Control
	match sender:
		Sender.USER:
			row = _bubble_row(text, UIStyle.USER_BUBBLE, UIStyle.USER_BORDER, true)
		Sender.COMPANION:
			row = _bubble_row(text, UIStyle.COMPANION_BUBBLE, UIStyle.COMPANION_BORDER, false)
		Sender.EVENT:
			row = _note(text, UIStyle.EVENT_TEXT)
		_:
			row = _note(text, UIStyle.ERROR_TEXT)
	_list.add_child(row)
	while _list.get_child_count() > MAX_BUBBLES:
		var oldest := _list.get_child(0)
		_list.remove_child(oldest)
		oldest.queue_free()
	_scroll_to_bottom()


## Burbuja con imagen (foto enviada o imagen generada) y texto opcional.
func add_image(sender: Sender, image_path: String, caption := "") -> void:
	var texture := ImageUtils.texture_from_path(image_path)
	if texture == null:
		add_message(sender, caption if not caption.is_empty() else "(imagen no disponible)")
		return
	var is_user := sender == Sender.USER
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bubble := PanelContainer.new()
	var color := UIStyle.USER_BUBBLE if is_user else UIStyle.COMPANION_BUBBLE
	var border := UIStyle.USER_BORDER if is_user else UIStyle.COMPANION_BORDER
	var style := UIStyle.bubble(color, border, not is_user)
	style.set_content_margin_all(6)
	bubble.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	bubble.add_child(box)

	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var aspect := float(texture.get_height()) / maxf(1.0, texture.get_width())
	picture.custom_minimum_size = Vector2(IMAGE_MAX_WIDTH, IMAGE_MAX_WIDTH * aspect)
	picture.mouse_filter = Control.MOUSE_FILTER_STOP
	picture.gui_input.connect(func(event: InputEvent):
		var mouse := event as InputEventMouseButton
		if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			image_tapped.emit(texture))
	box.add_child(picture)

	if not caption.is_empty():
		var label := Label.new()
		label.text = caption
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = IMAGE_MAX_WIDTH
		box.add_child(label)

	if is_user:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)
	_list.add_child(row)
	_scroll_to_bottom()


func clear() -> void:
	for child in _list.get_children():
		child.queue_free()


func _bubble_row(text: String, color: Color, border: Color, align_right: bool) -> Control:
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.3
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", UIStyle.bubble(color, border, not align_right))
	bubble.mouse_filter = Control.MOUSE_FILTER_PASS
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_child(label)

	if align_right:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)
	return row


func _note(text: String, color: Color) -> Control:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	label.add_theme_stylebox_override("normal", UIStyle.rounded(Color(1, 1, 1, 0.8), 12, 4))
	return label


func _scroll_to_bottom() -> void:
	# Hay que esperar a que el contenedor recalcule su tamaño.
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_vertical = int(get_v_scroll_bar().max_value)
