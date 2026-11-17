class_name WelcomePanel
extends PanelContainer
## Pantalla de bienvenida (primer inicio): pide las claves y las guarda en el
## teléfono (user://settings.cfg). Nunca van dentro del código ni del repo.
## Después se pueden cambiar en Ajustes.

signal finished

var _name: LineEdit
var _mistral: LineEdit
var _cf_account: LineEdit
var _cf_token: LineEdit
var _horde: LineEdit
var _status: Label
var _start: Button
var _web: WebRequest


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	_web = WebRequest.new()
	add_child(_web)
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	var title := Label.new()
	title.text = "¡Bienvenido a micIA!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	form.add_child(title)
	_note(form, "Para empezar necesito tus claves. Se guardan solo en este dispositivo.")

	_label(form, "¿Cómo te llamas?")
	_name = _field(form, "Tu nombre", false)

	_label(form, "API key de Groq (obligatoria)")
	_note(form, "Gratis en console.groq.com → API Keys")
	_mistral = _field(form, "Pega aquí tu clave de Groq", true)
	_mistral.text_changed.connect(func(_t: String): _refresh_start())

	_label(form, "Imágenes con Cloudflare (opcional)")
	_note(form, "dash.cloudflare.com → AI → Workers AI → Use REST API")
	_cf_account = _field(form, "Account ID", false)
	_cf_token = _field(form, "API token", true)

	_label(form, "AI Horde (opcional, vacío = anónimo)")
	_horde = _field(form, "API key de AI Horde", true)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	form.add_child(_status)

	var test := Button.new()
	test.text = "Comprobar clave de Groq"
	UIStyle.style_button(test, UIStyle.ButtonKind.SECONDARY)
	test.pressed.connect(_test_mistral)
	form.add_child(test)

	_start = Button.new()
	_start.text = "Empezar"
	_start.custom_minimum_size = Vector2(0, 50)
	UIStyle.style_button(_start, UIStyle.ButtonKind.CTA)
	_start.pressed.connect(_save)
	form.add_child(_start)

	_name.text = str(Settings.get_value("user_name"))
	_mistral.text = str(Settings.get_value("api_key"))
	_cf_account.text = str(Settings.get_value("cloudflare_account_id"))
	_cf_token.text = str(Settings.get_value("cloudflare_api_token"))
	_horde.text = str(Settings.get_value("horde_api_key"))
	_refresh_start()


func _refresh_start() -> void:
	_start.disabled = _mistral.text.strip_edges().is_empty()


## Pide la lista de modelos: si responde, la clave funciona.
func _test_mistral() -> void:
	var key := _mistral.text.strip_edges()
	if key.is_empty():
		_show("Primero pega tu clave.", UIStyle.ERROR_TEXT)
		return
	_show("Comprobando...", UIStyle.PLUM_DIM)
	var response := await _web.get_json("https://api.groq.com/openai/v1/models", PackedStringArray(["Authorization: Bearer " + key]))
	if response["ok"]:
		_show("¡La clave funciona!", Color("2a9d4b"))
	elif response["code"] == 401:
		_show("La clave no es válida.", UIStyle.ERROR_TEXT)
	else:
		_show("No pude comprobarla: " + str(response["error"]), UIStyle.ERROR_TEXT)


func _save() -> void:
	Settings.set_value("user_name", _name.text.strip_edges())
	Settings.set_value("api_key", _mistral.text.strip_edges())
	Settings.set_value("cloudflare_account_id", _cf_account.text.strip_edges())
	Settings.set_value("cloudflare_api_token", _cf_token.text.strip_edges())
	Settings.set_value("horde_api_key", _horde.text.strip_edges())
	Settings.save()
	finished.emit()


func _show(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _note(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	parent.add_child(label)


func _field(parent: Control, placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	parent.add_child(field)
	return field
