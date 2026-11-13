class_name OutfitPanel
extends PanelContainer
## Ventana de vestuario: lista los conjuntos del personaje actual.

signal outfit_chosen(outfit_id: String)
signal closed

var _list: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "Vestuario"
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


## Rellena la lista con los conjuntos del personaje actual.
func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var current := str(Settings.current_outfit()["id"])
	for outfit in Settings.character().get("outfits", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.color = outfit.get("cloth", Color("dfe7f2"))
		row.add_child(swatch)
		var button := Button.new()
		button.text = outfit["label"] + ("  (puesto)" if outfit["id"] == current else "")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		if outfit["id"] == current:
			UIStyle.style_button(button, UIStyle.ButtonKind.SECONDARY)
		button.pressed.connect(func(): outfit_chosen.emit(outfit["id"]))
		row.add_child(button)
		_list.add_child(row)
