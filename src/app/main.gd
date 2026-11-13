extends Control
## Pantalla principal. Arma la interfaz y conecta las piezas:
##
##   usuario escribe -> Brain (Mistral) -> AIReply -> chat + avatar + voz
##   Mood (autoload) decide si ella te bloquea; los regalos la calman.
##
## Capas (de atrás hacia adelante):
##   RoomBackground -> Avatar (pantalla completa) -> interfaz -> tarjeta de
##   bloqueo -> ventanas (Ajustes / Regalos)
##
## La lógica de cada pieza vive en su propio script; aquí solo se "cablea".

const HISTORY_ON_SCREEN := 40
## Fracción de la pantalla que ocupa el chat (el resto deja ver al avatar).
const CHAT_HEIGHT_RATIO := 0.36

var _brain: Brain
var _voice: Voice
var _avatar: Avatar
var _avatar_is_3d := false
var _avatar_layer: Control
var _chat: ChatView
var _name_pill: MoodBar
var _status_label: Label
var _input_row: Control
var _input: LineEdit
var _send_button: Button
var _gift_button: SideButton
var _keyboard_spacer: Control
var _block_card: BlockCard
var _overlay: ColorRect
var _settings_panel: SettingsPanel
var _gift_panel: GiftPanel


func _ready() -> void:
	theme = UIStyle.make_theme()
	get_tree().quit_on_go_back = false
	_build_layers()
	_build_overlay()
	_build_services()
	_rebuild_avatar()
	_connect_signals()
	_load_history_into_chat()
	_refresh_header()
	_refresh_input_state()
	resized.connect(_on_resized)
	_on_resized()
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

func _build_layers() -> void:
	var room := RoomBackground.new()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(room)

	_avatar_layer = Control.new()
	_avatar_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_avatar_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avatar_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_side_buttons())

	var avatar_space := Control.new()
	avatar_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avatar_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(avatar_space)

	_chat = ChatView.new()
	column.add_child(_chat)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	_status_label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	_status_label.add_theme_stylebox_override("normal", UIStyle.pill(Color(1, 1, 1, 0.85), Color.TRANSPARENT, 12, 2))
	_status_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_status_label)

	_input_row = _build_input_row()
	column.add_child(_input_row)

	_block_card = BlockCard.new()
	_block_card.visible = false
	column.add_child(_block_card)

	_keyboard_spacer = Control.new()
	_keyboard_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_keyboard_spacer)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)

	_name_pill = MoodBar.new(MoodBar.Kind.AFFECTION, "")
	header.add_child(_name_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	header.add_child(MoodBar.new(MoodBar.Kind.ANGER, "Enojo"))
	return header


func _build_side_buttons() -> Control:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 10)

	_gift_button = SideButton.new(SideButton.Icon.GIFT, "Regalo")
	column.add_child(_gift_button)

	var settings_button := SideButton.new(SideButton.Icon.GEAR, "Ajustes")
	settings_button.pressed.connect(_open_settings)
	column.add_child(settings_button)
	return column


func _build_input_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 50)
	row.add_child(_input)
	_send_button = Button.new()
	_send_button.text = "Enviar"
	_send_button.custom_minimum_size = Vector2(90, 50)
	row.add_child(_send_button)
	return row


## Fondo oscuro con una ventana centrada (Ajustes o Regalos).
func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.25, 0.08, 0.18, 0.45)
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


## Crea el avatar 3D o 2D según Ajustes. Si el 3D falla, usa el 2D.
func _rebuild_avatar() -> void:
	var want_3d := bool(Settings.get_value("avatar_3d"))
	if _avatar != null and want_3d == _avatar_is_3d:
		return
	if _avatar != null:
		_avatar.queue_free()
		_avatar = null

	if want_3d:
		var avatar_3d := Avatar3D.new()
		avatar_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_avatar_layer.add_child(avatar_3d)
		if avatar_3d.is_ready():
			_avatar = avatar_3d
			_avatar_is_3d = true
		else:
			avatar_3d.queue_free()
			_chat.add_message(ChatView.Sender.SYSTEM, "No se pudo cargar el avatar 3D; uso el 2D.")
	if _avatar == null:
		var avatar_2d := Avatar2D.new()
		# El 2D ocupa la parte de arriba (no toda la pantalla).
		avatar_2d.anchor_right = 1.0
		avatar_2d.anchor_bottom = 1.0 - CHAT_HEIGHT_RATIO
		avatar_2d.offset_top = 70
		_avatar_layer.add_child(avatar_2d)
		_avatar = avatar_2d
		_avatar_is_3d = false

	_avatar.touched.connect(_on_avatar_touched)


func _connect_signals() -> void:
	_send_button.pressed.connect(_on_send)
	_input.text_submitted.connect(func(_text: String): _on_send())
	_gift_button.pressed.connect(_open_gifts)

	_brain.reply_ready.connect(_on_reply)
	_brain.failed.connect(_on_brain_failed)
	_brain.thinking_changed.connect(func(_thinking: bool): _refresh_input_state())

	_voice.speaking_started.connect(func(): _avatar.set_talking(true))
	_voice.speaking_finished.connect(func(): _avatar.set_talking(false))

	Mood.blocked_changed.connect(func(is_blocked: bool): _announce_block.call_deferred(is_blocked))
	Settings.changed.connect(_on_settings_changed)
	Memory.cleared.connect(_chat.clear)

	_block_card.settings_requested.connect(_open_settings)
	_block_card.gift_requested.connect(_open_gifts)

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
		_chat.add_message(ChatView.Sender.EVENT, "%s te bloqueó." % companion)
	else:
		_chat.add_message(ChatView.Sender.EVENT, "%s te desbloqueó." % companion)
	_refresh_input_state()


# --- Estado de la interfaz -------------------------------------------------

func _on_settings_changed() -> void:
	_rebuild_avatar()
	_refresh_header()
	_refresh_input_state()


func _refresh_header() -> void:
	var personality: Dictionary = Personalities.fetch(str(Settings.get_value("personality")))
	_name_pill.set_title("%s · %s" % [Settings.get_value("companion_name"), personality["label"]])
	_block_card.set_companion_name(str(Settings.get_value("companion_name")))


func _refresh_input_state() -> void:
	var thinking := _brain.is_thinking()
	var companion := str(Settings.get_value("companion_name"))
	_input_row.visible = not Mood.blocked
	_block_card.visible = Mood.blocked
	_send_button.disabled = thinking
	_gift_button.set_disabled(thinking)
	_input.placeholder_text = "Escríbele a %s..." % companion
	_status_label.text = "%s está escribiendo..." % companion if thinking else ""
	_status_label.visible = thinking


func _on_resized() -> void:
	_chat.custom_minimum_size.y = get_viewport_rect().size.y * CHAT_HEIGHT_RATIO * 0.75


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
	_settings_panel.custom_minimum_size = Vector2(minf(view.x - 30.0, 440.0), minf(view.y - 60.0, 680.0))
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
