extends Control
## Pantalla principal. Arma la interfaz y conecta las piezas:
##
##   usuario escribe -> Brain (Mistral) -> AIReply -> chat + avatar + voz
##   Mood (autoload) decide si ella te bloquea; los regalos la calman.
##
## La lógica de cada pieza vive en su propio script; aquí solo se "cablea".

const HISTORY_ON_SCREEN := 40

var _brain: Brain
var _voice: Voice
var _avatar: Avatar
var _chat: ChatView
var _name_label: Label
var _status_label: Label
var _input: LineEdit
var _send_button: Button
var _gift_button: Button
var _keyboard_spacer: Control
var _overlay: ColorRect
var _settings_panel: SettingsPanel
var _gift_panel: GiftPanel


func _ready() -> void:
	theme = UIStyle.make_theme()
	get_tree().quit_on_go_back = false
	_build_layout()
	_build_overlay()
	_build_services()
	_connect_signals()
	_load_history_into_chat()
	_refresh_header()
	_refresh_input_state()
	if not Settings.has_api_key():
		_chat.add_message(ChatView.Sender.SYSTEM, "Primero pon tu API key de Mistral en Ajustes.")
		_open_settings()


func _process(_delta: float) -> void:
	_update_keyboard_spacer()


func _notification(what: int) -> void:
	# Botón "atrás" de Android: cierra la ventana abierta o sale de la app.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlay.visible:
			_close_overlay()
		else:
			get_tree().quit()


# --- Construcción de la interfaz -------------------------------------------

func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = UIStyle.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(_build_header())

	_avatar = Avatar2D.new()
	_avatar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_avatar.size_flags_stretch_ratio = 1.0
	_avatar.custom_minimum_size = Vector2(0, 150)
	column.add_child(_avatar)

	_chat = ChatView.new()
	_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat.size_flags_stretch_ratio = 1.2
	column.add_child(_chat)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	_status_label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	column.add_child(_status_label)

	column.add_child(_build_input_row())

	_keyboard_spacer = Control.new()
	column.add_child(_keyboard_spacer)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	header.add_child(_name_label)

	var mood_bar := MoodBar.new()
	mood_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(mood_bar)

	_gift_button = Button.new()
	_gift_button.text = "Regalo"
	header.add_child(_gift_button)

	var settings_button := Button.new()
	settings_button.text = "Ajustes"
	settings_button.pressed.connect(_open_settings)
	header.add_child(settings_button)
	return header


func _build_input_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 44)
	row.add_child(_input)
	_send_button = Button.new()
	_send_button.text = "Enviar"
	_send_button.custom_minimum_size = Vector2(80, 44)
	row.add_child(_send_button)
	return row


## Fondo oscuro con una ventana centrada (Ajustes o Regalos).
func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	center.add_child(_settings_panel)

	_gift_panel = GiftPanel.new()
	_gift_panel.visible = false
	center.add_child(_gift_panel)


func _build_services() -> void:
	_brain = Brain.new()
	add_child(_brain)
	_voice = Voice.new()
	add_child(_voice)


func _connect_signals() -> void:
	_send_button.pressed.connect(_on_send)
	_input.text_submitted.connect(func(_text: String): _on_send())
	_gift_button.pressed.connect(_open_gifts)

	_brain.reply_ready.connect(_on_reply)
	_brain.failed.connect(_on_brain_failed)
	_brain.thinking_changed.connect(func(_thinking: bool): _refresh_input_state())

	_voice.speaking_started.connect(func(): _avatar.set_talking(true))
	_voice.speaking_finished.connect(func(): _avatar.set_talking(false))

	_avatar.touched.connect(_on_avatar_touched)

	Mood.blocked_changed.connect(func(is_blocked: bool): _announce_block.call_deferred(is_blocked))
	Settings.changed.connect(_refresh_header)
	Memory.cleared.connect(_chat.clear)

	_settings_panel.closed.connect(_close_overlay)
	_gift_panel.closed.connect(_close_overlay)
	_gift_panel.gift_chosen.connect(_on_gift_chosen)


# --- Flujo de conversación -------------------------------------------------

func _on_send() -> void:
	var text := _input.text.strip_edges()
	if text.is_empty() or Mood.blocked or _brain.is_thinking():
		return
	_input.clear()
	_chat.add_message(ChatView.Sender.USER, text)
	_brain.send_message(text)


func _on_reply(reply: AIReply) -> void:
	_chat.add_message(ChatView.Sender.COMPANION, reply.text)
	_avatar.set_emotion(reply.emotion)
	_avatar.play_action(reply.action)
	_voice.speak(reply.text)


func _on_brain_failed(message: String) -> void:
	_chat.add_message(ChatView.Sender.SYSTEM, message)


func _on_gift_chosen(gift_id: String) -> void:
	_close_overlay()
	if _brain.is_thinking():
		_chat.add_message(ChatView.Sender.SYSTEM, "Espera a que termine de responder.")
		return
	var was_blocked := Mood.blocked
	var effectiveness := Mood.give_gift(gift_id)
	var gift_label: String = Gifts.fetch(gift_id)["label"]

	var for_ai := "%s te dio un regalo: %s." % [Settings.user_display_name(), gift_label]
	if effectiveness < 1.0:
		for_ai += " Te acaba de dar otro regalo hace muy poco; parece que intenta comprarte."
	if was_blocked and not Mood.blocked:
		for_ai += " Lo tenías bloqueado, pero con este regalo decides desbloquearlo."
	elif Mood.blocked:
		for_ai += " Sigues demasiado enojada para desbloquearlo todavía."

	var for_chat := "Le diste: %s" % gift_label
	_chat.add_message(ChatView.Sender.EVENT, for_chat)
	_brain.send_event(for_ai, for_chat)


## Por ahora tocarla solo la sorprende (sin gastar peticiones a la IA).
## Aquí se conectarán en el futuro las caricias / golpes.
func _on_avatar_touched() -> void:
	_avatar.set_emotion("sorprendida")
	_avatar.play_action("saltar")


func _announce_block(is_blocked: bool) -> void:
	var companion := str(Settings.get_value("companion_name"))
	if is_blocked:
		_chat.add_message(ChatView.Sender.EVENT, "%s te bloqueó. Espera a que se calme o dale un regalo." % companion)
	else:
		_chat.add_message(ChatView.Sender.EVENT, "%s te desbloqueó." % companion)
	_refresh_input_state()


# --- Estado de la interfaz -------------------------------------------------

func _refresh_header() -> void:
	var personality: Dictionary = Personalities.fetch(str(Settings.get_value("personality")))
	_name_label.text = "%s  ·  %s" % [Settings.get_value("companion_name"), personality["label"]]


func _refresh_input_state() -> void:
	var thinking := _brain.is_thinking()
	var companion := str(Settings.get_value("companion_name"))
	_input.editable = not Mood.blocked
	_send_button.disabled = Mood.blocked or thinking
	_gift_button.disabled = thinking
	if Mood.blocked:
		_input.placeholder_text = "%s te bloqueó..." % companion
	else:
		_input.placeholder_text = "Escríbele a %s" % companion
	_status_label.text = "%s está escribiendo..." % companion if thinking else ""


func _load_history_into_chat() -> void:
	var start := maxi(0, Memory.history.size() - HISTORY_ON_SCREEN)
	for i in range(start, Memory.history.size()):
		var entry: Dictionary = Memory.history[i]
		var display := str(entry.get("display", ""))
		if entry.get("kind") == Memory.KIND_EVENT:
			_chat.add_message(ChatView.Sender.EVENT, display)
		elif entry.get("role") == "user":
			_chat.add_message(ChatView.Sender.USER, display)
		else:
			_chat.add_message(ChatView.Sender.COMPANION, display)


func _open_settings() -> void:
	var view := get_viewport_rect().size
	_settings_panel.custom_minimum_size = Vector2(minf(view.x - 30.0, 440.0), minf(view.y - 60.0, 640.0))
	_settings_panel.load_values()
	_gift_panel.visible = false
	_settings_panel.visible = true
	_overlay.visible = true


func _open_gifts() -> void:
	_gift_panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 60.0, 320.0), 0)
	_settings_panel.visible = false
	_gift_panel.visible = true
	_overlay.visible = true


func _close_overlay() -> void:
	_overlay.visible = false
	_settings_panel.visible = false
	_gift_panel.visible = false


## En Android, deja espacio para que el teclado no tape la caja de texto.
func _update_keyboard_spacer() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var keyboard_px := DisplayServer.virtual_keyboard_get_height()
	var target := 0.0
	if keyboard_px > 0:
		var window_height := float(DisplayServer.window_get_size().y)
		if window_height > 0.0:
			target = keyboard_px * get_viewport_rect().size.y / window_height
	if not is_equal_approx(_keyboard_spacer.custom_minimum_size.y, target):
		_keyboard_spacer.custom_minimum_size.y = target
