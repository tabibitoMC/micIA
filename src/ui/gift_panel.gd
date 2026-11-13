class_name GiftPanel
extends PanelContainer
## Ventana para elegir un regalo.

signal gift_chosen(gift_id: String)
signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.SURFACE, 14, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "Dale un regalo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	for gift_id in Gifts.ids():
		var button := Button.new()
		button.text = Gifts.fetch(gift_id)["label"]
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_gift_pressed.bind(gift_id))
		box.add_child(button)

	var close := Button.new()
	close.text = "Cerrar"
	close.flat = true
	close.pressed.connect(func(): closed.emit())
	box.add_child(close)


func _on_gift_pressed(gift_id: String) -> void:
	gift_chosen.emit(gift_id)
