class_name ChatView
extends ScrollContainer
## Lista de mensajes del chat (burbujas) que flota sobre el avatar, con
## desplazamiento automático al final.

enum Sender { USER, COMPANION, EVENT, SYSTEM }

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
