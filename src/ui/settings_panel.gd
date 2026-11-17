class_name SettingsPanel
extends PanelContainer
## Pantalla de Ajustes. Lee y escribe en el autoload Settings.

signal closed
signal memory_cleared

var _api_key: LineEdit
var _model: OptionButton
var _companion_name: LineEdit
var _user_name: LineEdit
var _personality: OptionButton
var _appearance: LineEdit
var _character: OptionButton
var _adult: CheckButton
var _cf_account: LineEdit
var _cf_token: LineEdit
var _horde_key: LineEdit
var _room_theme: OptionButton
var _voice_enabled: CheckButton
var _avatar_3d: CheckButton
var _voice_rate: HSlider
var _voice_pitch: HSlider
var _ui_scale: HSlider
var _clear_button: Button
var _clear_armed := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	_add_title(form, "Ajustes")

	_add_label(form, "API key de Groq")
	_api_key = LineEdit.new()
	_api_key.secret = true
	_api_key.placeholder_text = "Pega aquí tu clave"
	form.add_child(_api_key)

	_add_label(form, "Modelo")
	_model = OptionButton.new()
	for model_name in Settings.MODELS:
		_model.add_item(model_name)
	form.add_child(_model)

	_add_label(form, "Personaje")
	_character = OptionButton.new()
	for id in Characters.ids():
		_character.add_item(Characters.fetch(id)["label"])
	_character.item_selected.connect(_on_character_selected)
	form.add_child(_character)

	_add_label(form, "Nombre de ella")
	_companion_name = LineEdit.new()
	form.add_child(_companion_name)

	_add_label(form, "Tu nombre (cómo te llama)")
	_user_name = LineEdit.new()
	form.add_child(_user_name)

	_add_label(form, "Personalidad")
	_personality = OptionButton.new()
	for id in Personalities.ids():
		_personality.add_item(Personalities.fetch(id)["label"])
	form.add_child(_personality)

	_add_label(form, "Su apariencia (para sus fotos, en inglés)")
	_appearance = LineEdit.new()
	form.add_child(_appearance)

	_add_label(form, "Fondo de la habitación")
	_room_theme = OptionButton.new()
	for id in RoomBackground.theme_ids():
		_room_theme.add_item(RoomBackground.THEMES[id]["label"])
	form.add_child(_room_theme)

	_adult = CheckButton.new()
	_adult.text = "Contenido adulto +18"
	form.add_child(_adult)
	var adult_note := Label.new()
	adult_note.text = "Solo con el personaje adulto y con mucha confianza. Al activarlo confirmas que eres mayor de edad."
	adult_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adult_note.add_theme_font_size_override("font_size", 12)
	adult_note.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	form.add_child(adult_note)

	_avatar_3d = CheckButton.new()
	_avatar_3d.text = "Avatar 3D (apágalo si va lento)"
	form.add_child(_avatar_3d)

	_voice_enabled = CheckButton.new()
	_voice_enabled.text = "Voz activada"
	form.add_child(_voice_enabled)

	_voice_rate = _add_slider(form, "Velocidad de voz", 0.5, 2.0, 0.05)
	_voice_pitch = _add_slider(form, "Tono de voz", 0.5, 2.0, 0.05)
	_ui_scale = _add_slider(form, "Tamaño de la interfaz", 0.5, 2.5, 0.05)

	_add_title_small(form, "Imágenes gratis")
	_add_label(form, "Cloudflare Account ID (opcional)")
	_cf_account = LineEdit.new()
	form.add_child(_cf_account)
	_add_label(form, "Cloudflare API token (Workers AI)")
	_cf_token = LineEdit.new()
	_cf_token.secret = true
	form.add_child(_cf_token)
	_add_label(form, "AI Horde API key (vacío = anónimo)")
	_horde_key = LineEdit.new()
	_horde_key.secret = true
	form.add_child(_horde_key)

	_add_title_small(form, "Mods")
	var mods_label := Label.new()
	var loaded := Mods.info_list()
	mods_label.text = ("Cargados: " + ", ".join(loaded)) if not loaded.is_empty() else "Ningún mod cargado. Mira mods/README.md para crear uno."
	mods_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mods_label.add_theme_font_size_override("font_size", 12)
	mods_label.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	form.add_child(mods_label)

	_clear_button = Button.new()
	_clear_button.text = "Borrar memoria y reiniciar ánimo"
	UIStyle.style_button(_clear_button, UIStyle.ButtonKind.SECONDARY)
	_clear_button.pressed.connect(_on_clear_pressed)
	form.add_child(_clear_button)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	form.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	UIStyle.style_button(cancel, UIStyle.ButtonKind.SECONDARY)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): closed.emit())
	buttons.add_child(cancel)
	var save := Button.new()
	save.text = "Guardar"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_on_save_pressed)
	buttons.add_child(save)


## Carga los valores actuales en el formulario (llamar antes de mostrarlo).
func load_values() -> void:
	_clear_armed = false
	_clear_button.text = "Borrar memoria y reiniciar ánimo"
	_api_key.text = str(Settings.get_value("api_key"))
	_select_by_text(_model, str(Settings.get_value("model")))
	_companion_name.text = str(Settings.get_value("companion_name"))
	_user_name.text = str(Settings.get_value("user_name"))
	var ids := Personalities.ids()
	_personality.select(maxi(0, ids.find(str(Settings.get_value("personality")))))
	_appearance.text = str(Settings.get_value("appearance"))
	_character.select(maxi(0, Characters.ids().find(str(Settings.get_value("character")))))
	_adult.button_pressed = bool(Settings.get_value("adult_content"))
	_cf_account.text = str(Settings.get_value("cloudflare_account_id"))
	_cf_token.text = str(Settings.get_value("cloudflare_api_token"))
	_horde_key.text = str(Settings.get_value("horde_api_key"))
	_room_theme.select(maxi(0, RoomBackground.theme_ids().find(str(Settings.get_value("room_theme")))))
	_avatar_3d.button_pressed = bool(Settings.get_value("avatar_3d"))
	_voice_enabled.button_pressed = bool(Settings.get_value("voice_enabled"))
	_voice_rate.value = float(Settings.get_value("voice_rate"))
	_voice_pitch.value = float(Settings.get_value("voice_pitch"))
	_ui_scale.value = float(Settings.get_value("ui_scale"))


func _on_save_pressed() -> void:
	Settings.set_value("api_key", _api_key.text.strip_edges())
	Settings.set_value("model", _model.get_item_text(_model.selected))
	var name_text := _companion_name.text.strip_edges()
	Settings.set_value("companion_name", name_text if not name_text.is_empty() else "Mia")
	Settings.set_value("user_name", _user_name.text.strip_edges())
	Settings.set_value("personality", Personalities.ids()[_personality.selected])
	if not _appearance.text.strip_edges().is_empty():
		Settings.set_value("appearance", _appearance.text.strip_edges())
	Settings.set_value("room_theme", RoomBackground.theme_ids()[_room_theme.selected])
	Settings.set_value("character", Characters.ids()[_character.selected])
	Settings.set_value("adult_content", _adult.button_pressed)
	Settings.set_value("cloudflare_account_id", _cf_account.text.strip_edges())
	Settings.set_value("cloudflare_api_token", _cf_token.text.strip_edges())
	Settings.set_value("horde_api_key", _horde_key.text.strip_edges())
	Settings.set_value("avatar_3d", _avatar_3d.button_pressed)
	Settings.set_value("voice_enabled", _voice_enabled.button_pressed)
	Settings.set_value("voice_rate", _voice_rate.value)
	Settings.set_value("voice_pitch", _voice_pitch.value)
	Settings.set_value("ui_scale", _ui_scale.value)
	Settings.save()
	closed.emit()


## Al elegir otro personaje se proponen su nombre y apariencia por defecto.
func _on_character_selected(index: int) -> void:
	var character := Characters.fetch(Characters.ids()[index])
	_companion_name.text = character["default_name"]
	_appearance.text = character["appearance"]


## Pide confirmación con un segundo toque para no borrar por accidente.
func _on_clear_pressed() -> void:
	if not _clear_armed:
		_clear_armed = true
		_clear_button.text = "¿Seguro? Toca otra vez para borrar"
		return
	_clear_armed = false
	_clear_button.text = "Memoria borrada"
	Memory.clear_all()
	Mood.reset()
	Relationship.reset()
	memory_cleared.emit()


func _add_title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	parent.add_child(label)


func _add_title_small(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE)
	parent.add_child(label)


func _add_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	parent.add_child(label)


func _add_slider(parent: Control, text: String, min_value: float, max_value: float, step: float) -> HSlider:
	var label := Label.new()
	label.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(func(v: float): label.text = "%s: %.2f" % [text, v])
	parent.add_child(slider)
	label.text = "%s: %.2f" % [text, slider.value]
	return slider


static func _select_by_text(option: OptionButton, text: String) -> void:
	for i in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)
			return
	option.select(0)
