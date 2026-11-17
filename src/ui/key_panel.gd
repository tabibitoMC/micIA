class_name KeyPanel
extends PanelContainer
## Pide la API key del cerebro elegido (Groq o Gemini) cuando falta, con un
## botón que abre la página donde se consigue gratis.

signal saved
signal closed

var _title: Label
var _hint: Label
var _field: LineEdit
var _status: Label
var _provider := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	box.add_child(_title)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	_hint.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	box.add_child(_hint)

	var get_key := Button.new()
	get_key.text = "Conseguir clave gratis"
	get_key.custom_minimum_size = Vector2(0, 44)
	get_key.pressed.connect(func(): OS.shell_open(str(AIProviders.fetch(_provider)["key_url"])))
	box.add_child(get_key)

	_field = LineEdit.new()
	_field.secret = true
	_field.placeholder_text = "Pega aquí la clave"
	_field.custom_minimum_size = Vector2(0, 46)
	_field.add_theme_stylebox_override("normal", UIStyle.field())
	box.add_child(_field)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	box.add_child(_status)

	var save := Button.new()
	save.text = "Guardar"
	save.custom_minimum_size = Vector2(0, 46)
	UIStyle.style_button(save, UIStyle.ButtonKind.CTA)
	save.pressed.connect(_save)
	box.add_child(save)

	var close := Button.new()
	close.text = "Ahora no"
	UIStyle.style_button(close, UIStyle.ButtonKind.FLAT)
	close.pressed.connect(func(): closed.emit())
	box.add_child(close)


## Prepara la ventana para un proveedor (por defecto, el elegido).
func open_for(provider_id := "") -> void:
	_provider = provider_id if not provider_id.is_empty() else AIProviders.current_id()
	var provider := AIProviders.fetch(_provider)
	_title.text = "Falta tu clave de %s" % provider["label"]
	_hint.text = "Ella necesita una API key de %s para pensar. Es gratis: toca el botón, crea la clave en %s, cópiala y pégala aquí." % [
		provider["label"], provider["console"]]
	if _provider == "gemini":
		_hint.text += " (En el plan gratis, Google puede usar los mensajes para mejorar sus modelos.)"
	_field.text = AIProviders.api_key(_provider)
	_status.text = ""


func _save() -> void:
	var key := _field.text.strip_edges()
	if key.length() < 20:
		_status.text = "Esa clave parece incompleta."
		_status.add_theme_color_override("font_color", UIStyle.ERROR_TEXT)
		return
	Settings.set_value(AIProviders.fetch(_provider)["key_setting"], key)
	Settings.set_value("provider", _provider)
	Settings.save()
	saved.emit()
