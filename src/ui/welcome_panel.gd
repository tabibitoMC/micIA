class_name WelcomePanel
extends PanelContainer
## Pantalla de bienvenida (primer inicio): pide las claves y las guarda en el
## teléfono (user://settings.cfg). Nunca van dentro del código ni del repo.
## Después se pueden cambiar en Ajustes.

signal finished

var _name: LineEdit
var _mistral: LineEdit
var _provider: OptionButton
var _key_note: Label
## Claves escritas por proveedor mientras se cambia de uno a otro.
var _keys := {}
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

	_label(form, "Cerebro (elige uno; los dos son gratis)")
	_provider = OptionButton.new()
	for id in AIProviders.ids():
		_provider.add_item(AIProviders.fetch(id)["label"])
	form.add_child(_provider)
	_key_note = Label.new()
	_key_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key_note.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	form.add_child(_key_note)
	_mistral = _field(form, "Pega aquí tu clave", true)
	_mistral.text_changed.connect(func(t: String):
		_keys[_provider_id()] = t.strip_edges()
		_refresh_start())
	_provider.item_selected.connect(func(_i: int): _on_provider_changed())

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
	test.text = "Comprobar clave"
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
	for id in AIProviders.ids():
		_keys[id] = AIProviders.api_key(id)
	_provider.select(maxi(0, AIProviders.ids().find(AIProviders.current_id())))
	_on_provider_changed()
	_cf_account.text = str(Settings.get_value("cloudflare_account_id"))
	_cf_token.text = str(Settings.get_value("cloudflare_api_token"))
	_horde.text = str(Settings.get_value("horde_api_key"))
	_refresh_start()


func _provider_id() -> String:
	return AIProviders.ids()[_provider.selected]


func _on_provider_changed() -> void:
	var provider := AIProviders.fetch(_provider_id())
	_key_note.text = "API key de %s (obligatoria). Gratis en %s" % [provider["label"], provider["console"]]
	if _provider_id() == "gemini":
		_key_note.text += ". Ojo: en el plan gratis Google puede usar los mensajes para mejorar sus modelos."
	_mistral.text = str(_keys.get(_provider_id(), ""))
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
	var url := str(AIProviders.fetch(_provider_id())["base_url"]) + "/models"
	var response := await _web.get_json(url, PackedStringArray(["Authorization: Bearer " + key]))
	if response["ok"]:
		_show("¡La clave funciona!", Color("2a9d4b"))
	elif response["code"] in [400, 401, 403]:
		_show("La clave no es válida.", UIStyle.ERROR_TEXT)
	else:
		_show("No pude comprobarla: " + str(response["error"]), UIStyle.ERROR_TEXT)


func _save() -> void:
	Settings.set_value("user_name", _name.text.strip_edges())
	Settings.set_value("provider", _provider_id())
	for id in _keys:
		Settings.set_value(AIProviders.fetch(id)["key_setting"], _keys[id])
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
