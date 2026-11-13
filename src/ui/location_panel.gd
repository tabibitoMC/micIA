class_name LocationPanel
extends PanelContainer
## Ventana para llevarla a otro lugar de la casa.

signal place_chosen(place_id: String)
signal closed

var _list: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "Ir a..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	box.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	var close := Button.new()
	close.text = "Cerrar"
	UIStyle.style_button(close, UIStyle.ButtonKind.FLAT)
	close.pressed.connect(func(): closed.emit())
	box.add_child(close)


func refresh(current: String) -> void:
	for child in _list.get_children():
		child.queue_free()
	for id in Environments.ids():
		var data := Environments.fetch(id)
		var button := Button.new()
		button.text = data["label"] + ("  (aquí)" if id == current else "")
		button.icon = Icons.texture(data["icon"], UIStyle.WHITE if id != current else UIStyle.PINK_DEEP, 48)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.custom_minimum_size = Vector2(0, 48)
		if id == current:
			UIStyle.style_button(button, UIStyle.ButtonKind.SECONDARY)
		button.pressed.connect(func(): place_chosen.emit(id))
		_list.add_child(button)
