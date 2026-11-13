class_name BlockCard
extends PanelContainer
## Tarjeta que aparece cuando ella te bloquea: mensaje, cuenta regresiva hasta
## que se calme y botones para Ajustes o darle un regalo.

signal settings_requested
signal gift_requested

var _title: Label
var _countdown: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.BLUE_CARD, 26, 20))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	var text := Label.new()
	text.text = "Está demasiado enojada para hablar. Espera a que se calme o intenta con un regalo."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	box.add_child(text)

	_countdown = Label.new()
	_countdown.add_theme_color_override("font_color", UIStyle.PINK_DEEP)
	box.add_child(_countdown)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var settings := Button.new()
	settings.text = "Ajustes"
	settings.custom_minimum_size = Vector2(0, 48)
	UIStyle.style_button(settings, UIStyle.ButtonKind.SECONDARY)
	settings.pressed.connect(func(): settings_requested.emit())
	buttons.add_child(settings)
	var gift := Button.new()
	gift.text = "Darle un regalo"
	gift.custom_minimum_size = Vector2(0, 48)
	gift.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.style_button(gift, UIStyle.ButtonKind.CTA)
	gift.pressed.connect(func(): gift_requested.emit())
	buttons.add_child(gift)


func set_companion_name(companion: String) -> void:
	_title.text = "%s te bloqueó..." % companion


func _process(_delta: float) -> void:
	if not visible:
		return
	var seconds := int(ceil(Mood.seconds_until_unblock()))
	_countdown.text = "Se calma en  %02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
