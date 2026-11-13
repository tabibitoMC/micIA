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
var _image_generator: ImageGenerator
var _photo_picker: PhotoPicker
var _voice: Voice
var _avatar: Avatar
var _avatar_is_3d := false
var _avatar_layer: Control
var _room: RoomBackground
var _interface_actions: InterfaceActions
var _touch: TouchInteractions
var _current_character := ""
var _side_column: VBoxContainer
var _mod_panel: Control
var _chat: ChatView
var _name_pill: MoodBar
var _status_label: Label
var _input_row: Control
var _input: LineEdit
var _send_button: Button
var _photo_button: Button
var _gift_button: SideButton
var _keyboard_spacer: Control
var _block_card: BlockCard
var _overlay: ColorRect
var _settings_panel: SettingsPanel
var _gift_panel: GiftPanel
var _image_viewer: ImageViewer
var _image_request_panel: ImageRequestPanel
var _game_panel: GamePanel
var _outfit_panel: OutfitPanel
var _location_panel: LocationPanel
## Se despertó con el último mensaje (para contárselo a la IA una vez).
var _just_woke := false


func _ready() -> void:
	theme = UIStyle.make_theme()
	# Los mods registran su contenido antes de que se arme la interfaz.
	Mods.load_all(ModApi.new(self))
	get_tree().quit_on_go_back = false
	_build_layers()
	_build_overlay()
	_build_services()
	_current_character = str(Settings.get_value("character"))
	_rebuild_avatar()
	_connect_signals()
	_load_history_into_chat()
	_refresh_header()
	_refresh_input_state()
	resized.connect(_on_resized)
	_on_resized()
	Mods.app_ready()
	for error in Mods.errors:
		_chat.add_message(ChatView.Sender.SYSTEM, "Mod: " + error)
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
	_room = RoomBackground.new()
	_room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.theme_id = str(Settings.get_value("room_theme"))
	add_child(_room)

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
	column.add_child(TrustBar.new())
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
	_side_column = column

	_gift_button = SideButton.new(SideButton.Icon.GIFT, "Regalo")
	column.add_child(_gift_button)

	var place_button := SideButton.new(SideButton.Icon.PLACE, "Lugar")
	place_button.pressed.connect(_open_locations)
	column.add_child(place_button)

	var outfit_button := SideButton.new(SideButton.Icon.DRESS, "Ropa")
	outfit_button.pressed.connect(_open_outfits)
	column.add_child(outfit_button)

	var games_button := SideButton.new(SideButton.Icon.GAMEPAD, "Juegos")
	games_button.pressed.connect(_open_games)
	column.add_child(games_button)

	var image_button := SideButton.new(SideButton.Icon.PICTURE, "Imagen")
	image_button.pressed.connect(_open_image_request)
	column.add_child(image_button)

	var settings_button := SideButton.new(SideButton.Icon.GEAR, "Ajustes")
	settings_button.pressed.connect(_open_settings)
	column.add_child(settings_button)
	return column


func _build_input_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_photo_button = Button.new()
	_photo_button.text = ""
	_photo_button.icon = Icons.texture("camera", UIStyle.PINK_DEEP, 48)
	_photo_button.expand_icon = true
	_photo_button.add_theme_constant_override("icon_max_width", 26)
	_photo_button.tooltip_text = "Mandarle una foto"
	_photo_button.custom_minimum_size = Vector2(54, 50)
	UIStyle.style_button(_photo_button, UIStyle.ButtonKind.SECONDARY)
	row.add_child(_photo_button)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 50)
	row.add_child(_input)
	_send_button = Button.new()
	_send_button.text = ""
	_send_button.tooltip_text = "Enviar"
	_send_button.icon = Icons.texture("send", UIStyle.WHITE, 48)
	_send_button.expand_icon = true
	_send_button.add_theme_constant_override("icon_max_width", 24)
	_send_button.custom_minimum_size = Vector2(56, 50)
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

	_location_panel = LocationPanel.new()
	_location_panel.visible = false
	center.add_child(_location_panel)

	_outfit_panel = OutfitPanel.new()
	_outfit_panel.visible = false
	center.add_child(_outfit_panel)

	_game_panel = GamePanel.new()
	_game_panel.visible = false
	center.add_child(_game_panel)

	_image_request_panel = ImageRequestPanel.new()
	_image_request_panel.visible = false
	center.add_child(_image_request_panel)

	_image_viewer = ImageViewer.new()
	_image_viewer.visible = false
	center.add_child(_image_viewer)


func _build_services() -> void:
	_brain = Brain.new()
	add_child(_brain)
	_image_generator = ImageGenerator.new()
	add_child(_image_generator)
	_photo_picker = PhotoPicker.new()
	add_child(_photo_picker)
	_interface_actions = InterfaceActions.new()
	_interface_actions.room = _room
	_interface_actions.gift_button = _gift_button
	_interface_actions.is_occupied = func() -> bool:
		return Mood.blocked or _brain.is_thinking() or _input.has_focus() or _overlay.visible or _avatar.is_sleeping()
	add_child(_interface_actions)
	_touch = TouchInteractions.new()
	_touch.event_ready.connect(_on_touch_event)
	add_child(_touch)
	_voice = Voice.new()
	add_child(_voice)


## Cambia de personaje: cada uno tiene su historial, ánimo y confianza.
func _switch_character(character: String) -> void:
	_current_character = character
	Memory.reload()
	Mood.reload()
	Relationship.reload()
	_chat.clear()
	_load_history_into_chat()
	_avatar_model_path = ""


var _avatar_model_path := ""


## Crea el avatar 3D o 2D según Ajustes y el personaje. Si el 3D falla, usa el 2D.
func _rebuild_avatar() -> void:
	var want_3d := bool(Settings.get_value("avatar_3d"))
	var outfit := Settings.current_outfit()
	var model_path := str(outfit.get("model", Settings.character()["model"]))
	if _avatar != null and want_3d == _avatar_is_3d and (not want_3d or model_path == _avatar_model_path):
		_avatar.apply_tint(outfit.get("cloth", Color.WHITE), outfit.get("hair", Color.WHITE))
		return
	_avatar_model_path = model_path
	if _avatar != null:
		_avatar.queue_free()
		_avatar = null

	if want_3d:
		var avatar_3d := Avatar3D.new()
		avatar_3d.model_path = model_path
		avatar_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_avatar_layer.add_child(avatar_3d)
		if avatar_3d.is_ready():
			_avatar = avatar_3d
			_avatar_is_3d = true
			avatar_3d.set_room(str(Settings.get_value("location")), str(Settings.get_value("room_theme")))
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

	_avatar.set_turned_away(Mood.blocked)
	# El fondo dibujado solo se usa con el avatar 2D (el 3D tiene habitaciones).
	_room.visible = not _avatar_is_3d
	_avatar.apply_tint(outfit.get("cloth", Color.WHITE), outfit.get("hair", Color.WHITE))
	if _interface_actions:
		_interface_actions.avatar = _avatar
	_avatar.struck.connect(_shake_screen)
	if _touch:
		_touch.avatar = _avatar
		_avatar.touched.connect(_touch.on_touched)
	_avatar.touched.connect(Mods.notify_touch)


func _connect_signals() -> void:
	_send_button.pressed.connect(_on_send)
	_input.text_submitted.connect(func(_text: String): _on_send())
	_gift_button.pressed.connect(_open_gifts)
	_photo_button.pressed.connect(_photo_picker.open)
	_photo_picker.photo_chosen.connect(_on_photo_chosen)
	_photo_picker.failed.connect(_on_brain_failed)
	_chat.image_tapped.connect(_open_image_viewer)
	_image_viewer.closed.connect(_close_overlay)
	_image_request_panel.closed.connect(_close_overlay)
	_game_panel.closed.connect(_close_overlay)
	_outfit_panel.closed.connect(_close_overlay)
	_location_panel.closed.connect(_close_overlay)
	_location_panel.place_chosen.connect(_on_place_chosen)
	_brain.scene_context = _describe_scene
	_outfit_panel.outfit_chosen.connect(_on_outfit_chosen)
	_game_panel.companion_said.connect(_on_game_comment)
	_game_panel.companion_reacted.connect(func(emotion: String, action: String):
		_avatar.set_emotion(emotion)
		_avatar.play_action(action))
	_game_panel.finished.connect(_on_game_finished)
	_image_request_panel.requested.connect(_on_user_image_requested)

	_brain.reply_ready.connect(_on_reply)
	_brain.failed.connect(_on_brain_failed)
	_brain.thinking_changed.connect(func(_thinking: bool): _refresh_input_state())
	_brain.image_requested.connect(_on_image_requested)
	_image_generator.generated.connect(_on_image_generated)
	_image_generator.failed.connect(_on_image_failed)

	_voice.speaking_started.connect(func(): _avatar.set_talking(true))
	_voice.speaking_finished.connect(func(): _avatar.set_talking(false))

	Mood.blocked_changed.connect(func(is_blocked: bool): _announce_block.call_deferred(is_blocked))
	Settings.changed.connect(_on_settings_changed)
	Relationship.became_partner.connect(func():
		_chat.add_message(ChatView.Sender.EVENT, "¡Ahora %s y tú son pareja!" % Settings.get_value("companion_name")))
	_room.room_theme_changed.connect(_on_room_theme_changed)
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
	if _avatar.is_sleeping():
		_avatar.set_sleeping(false)
		_just_woke = true
	_brain.send_message(text)


func _on_photo_chosen(image: Image) -> void:
	if Mood.blocked or _brain.is_thinking():
		_chat.add_message(ChatView.Sender.SYSTEM, "Ahora no puede ver fotos.")
		return
	var caption := _input.text.strip_edges()
	_input.clear()
	var path := _brain.send_photo(image, caption)
	_chat.add_image(ChatView.Sender.USER, path, caption)


## Ella quiere mandarte una imagen (su respuesta trae el campo "imagen").
func _on_image_requested(prompt: String) -> void:
	_image_generator.generate(prompt, "", "companion")
	_refresh_input_state()


## Tú pides una imagen con el botón "Imagen".
func _on_user_image_requested(prompt: String, provider: String) -> void:
	_close_overlay()
	_image_generator.generate(prompt, provider, "user")
	_refresh_input_state()


func _on_image_generated(image_path: String, prompt: String, origin: String) -> void:
	if origin == "companion":
		# Su respuesta ya guarda la descripción ("imagen") en el historial,
		# así ella sabe qué te mandó.
		Memory.attach_image_to_last_reply(image_path)
		_chat.add_image(ChatView.Sender.COMPANION, image_path)
	else:
		_share_generated_image(image_path, prompt)
	_refresh_input_state()


## La imagen que generaste se le envía a ella (visión de Mistral) para que la
## vea y opine. Si está ocupada o bloqueada, solo se muestra en el chat.
func _share_generated_image(image_path: String, prompt: String) -> void:
	var image := ImageUtils.load_any(image_path)
	var caption := "Generé esta imagen con IA: \"%s\"" % prompt
	if image == null or Mood.blocked or _brain.is_thinking():
		_chat.add_image(ChatView.Sender.USER, image_path, caption)
		return
	var path := _brain.send_photo(image, caption)
	_chat.add_image(ChatView.Sender.USER, path, caption)


func _on_image_failed(message: String, _origin: String) -> void:
	_chat.add_message(ChatView.Sender.SYSTEM, message)
	_refresh_input_state()


func _on_reply(reply: AIReply) -> void:
	_chat.add_message(ChatView.Sender.COMPANION, reply.text)
	_avatar.set_emotion(reply.emotion)
	_avatar.play_action(reply.action)
	_voice.speak(reply.text)
	if reply.interface_action != "ninguna":
		# Primero el gesto, luego se mueve por la pantalla.
		await get_tree().create_timer(0.8).timeout
		_interface_actions.perform(reply.interface_action)


func _on_brain_failed(message: String) -> void:
	_chat.add_message(ChatView.Sender.SYSTEM, message)


func _on_gift_chosen(gift_id: String) -> void:
	_close_overlay()
	if _brain.is_thinking():
		_chat.add_message(ChatView.Sender.SYSTEM, "Espera a que termine de responder.")
		return
	var was_blocked := Mood.blocked
	var effectiveness := Mood.give_gift(gift_id)
	Relationship.on_gift(effectiveness)
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


## Caricias o golpes terminados: la IA reacciona (si no está ocupada).
func _on_touch_event(for_ai: String, for_chat: String) -> void:
	if _brain.is_thinking():
		return
	_chat.add_message(ChatView.Sender.EVENT, for_chat)
	_brain.send_event(for_ai, for_chat)


## Sacudida de pantalla cuando ella te golpea.
func _shake_screen() -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(self, "position", Vector2(randf_range(-12, 12), randf_range(-8, 8)), 0.04)
	tween.tween_property(self, "position", Vector2.ZERO, 0.05)


func _announce_block(is_blocked: bool) -> void:
	var companion := str(Settings.get_value("companion_name"))
	_avatar.set_turned_away(is_blocked)
	if is_blocked:
		_chat.add_message(ChatView.Sender.EVENT, "%s te bloqueó." % companion)
	else:
		_chat.add_message(ChatView.Sender.EVENT, "%s te desbloqueó." % companion)
	_refresh_input_state()


# --- Estado de la interfaz -------------------------------------------------

func _on_settings_changed() -> void:
	Mods.notify_settings_changed()
	_room.set_room_theme(str(Settings.get_value("room_theme")))
	var character := str(Settings.get_value("character"))
	if character != _current_character:
		_switch_character(character)
	_rebuild_avatar()
	_refresh_header()
	_refresh_input_state()


## Si ella cambió el fondo, se guarda para la próxima vez.
func _on_room_theme_changed(theme_id: String) -> void:
	_avatar.set_time_of_day(theme_id)
	if str(Settings.get_value("room_theme")) != theme_id:
		Settings.set_value("room_theme", theme_id)
		Settings.save()


func _refresh_header() -> void:
	var personality: Dictionary = Personalities.fetch(str(Settings.get_value("personality")))
	_name_pill.set_title("%s · %s" % [Settings.get_value("companion_name"), personality["label"]])
	_block_card.set_companion_name(str(Settings.get_value("companion_name")))


func _refresh_input_state() -> void:
	var thinking := _brain.is_thinking()
	var companion := str(Settings.get_value("companion_name"))
	_input_row.visible = not Mood.blocked
	_block_card.visible = Mood.blocked
	var drawing := _image_generator.is_busy()
	_send_button.disabled = thinking
	_photo_button.disabled = thinking
	_gift_button.set_disabled(thinking)
	_input.placeholder_text = "Escríbele a %s..." % companion
	if thinking:
		_status_label.text = "%s está escribiendo..." % companion
	elif drawing:
		_status_label.text = "Generando imagen..."
	else:
		_status_label.text = ""
	_status_label.visible = thinking or drawing


func _on_resized() -> void:
	_chat.custom_minimum_size.y = get_viewport_rect().size.y * CHAT_HEIGHT_RATIO * 0.75


func _load_history_into_chat() -> void:
	var start := maxi(0, Memory.history.size() - HISTORY_ON_SCREEN)
	for i in range(start, Memory.history.size()):
		var entry: Dictionary = Memory.history[i]
		var display := str(entry.get("display", ""))
		var sender := ChatView.Sender.USER if entry.get("role") == "user" else ChatView.Sender.COMPANION
		if entry.has("image"):
			if sender == ChatView.Sender.COMPANION:
				_chat.add_message(sender, display)
				_chat.add_image(sender, str(entry["image"]))
			else:
				_chat.add_image(sender, str(entry["image"]), display)
		elif entry.get("kind") == Memory.KIND_EVENT:
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
	_image_request_panel.visible = false
	_image_viewer.visible = false
	_settings_panel.visible = true
	_overlay.visible = true


func _open_gifts() -> void:
	_gift_panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 60.0, 320.0), 0)
	_settings_panel.visible = false
	_image_request_panel.visible = false
	_image_viewer.visible = false
	_gift_panel.visible = true
	_overlay.visible = true


func _open_games() -> void:
	if Mood.blocked:
		_chat.add_message(ChatView.Sender.SYSTEM, "%s no quiere jugar contigo ahora." % Settings.get_value("companion_name"))
		return
	var view := get_viewport_rect().size
	_game_panel.custom_minimum_size = Vector2(minf(view.x - 24.0, 460.0), 0)
	_hide_panels()
	_game_panel.show_menu()
	_game_panel.visible = true
	_overlay.color = Color(0.25, 0.08, 0.18, 0.2)
	_overlay.visible = true


## Comentario de ella durante el juego (no se guarda en el historial).
func _on_game_comment(text: String, emotion: String) -> void:
	_chat.add_message(ChatView.Sender.COMPANION, text)
	_avatar.set_emotion(emotion)
	_voice.speak(text)


## Al terminar el juego, ella reacciona al resultado con Mistral.
func _on_game_finished(for_ai: String, for_chat: String) -> void:
	_close_overlay()
	_chat.add_message(ChatView.Sender.EVENT, for_chat)
	if not Mood.blocked and not _brain.is_thinking():
		_brain.send_event(for_ai, for_chat)


func _open_locations() -> void:
	if not _avatar_is_3d:
		_chat.add_message(ChatView.Sender.SYSTEM, "Los lugares necesitan el avatar 3D (Ajustes).")
		return
	_hide_panels()
	_location_panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 60.0, 320.0), 0)
	_location_panel.refresh(_avatar.current_room())
	_location_panel.visible = true
	_overlay.color = Color(0.25, 0.08, 0.18, 0.2)
	_overlay.visible = true


## La llevas a otro lugar: camina hasta allá y ella se entera.
func _on_place_chosen(place_id: String) -> void:
	_close_overlay()
	if place_id == _avatar.current_room() or _interface_actions.is_busy():
		return
	var label: String = Environments.fetch(place_id)["label"]
	await _interface_actions.perform("ir_" + place_id)
	var for_chat := "Fueron a: %s" % label
	_chat.add_message(ChatView.Sender.EVENT, for_chat)
	if not Mood.blocked and not _brain.is_thinking():
		_brain.send_event("%s te llevó a: %s." % [Settings.user_display_name(), label], for_chat)


## Texto para la IA: dónde está ella y si estaba dormida.
func _describe_scene() -> String:
	var place := _avatar.current_room()
	var text := ("Estás en: %s de tu casa." % Environments.fetch(place)["label"]) if place != "" else ""
	if _avatar.is_sleeping():
		text += " Estás dormida en tu cama."
	elif _just_woke:
		text += " Estabas dormida y él te acaba de despertar con su mensaje."
		_just_woke = false
	return text


func _open_outfits() -> void:
	_hide_panels()
	_outfit_panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 60.0, 340.0), 0)
	_outfit_panel.refresh()
	_outfit_panel.visible = true
	_overlay.color = Color(0.25, 0.08, 0.18, 0.2)
	_overlay.visible = true


## Cambiar de ropa: se aplica al avatar y ella se entera (Mistral reacciona).
func _on_outfit_chosen(outfit_id: String) -> void:
	_close_overlay()
	Settings.set_outfit(outfit_id)
	Settings.save()
	var label: String = Settings.current_outfit()["label"]
	var for_chat := "Le cambiaste la ropa: %s" % label
	_chat.add_message(ChatView.Sender.EVENT, for_chat)
	if not Mood.blocked and not _brain.is_thinking():
		_brain.send_event("%s te cambió la ropa al conjunto \"%s\"." % [Settings.user_display_name(), label], for_chat)


## Ventana de un mod (ModApi.open_panel).
func show_mod_panel(panel: Control) -> void:
	_hide_panels()
	if _mod_panel and _mod_panel != panel:
		_mod_panel.get_parent().remove_child(_mod_panel)
	_mod_panel = panel
	if panel.get_parent() == null:
		_overlay.get_child(0).add_child(panel)
	panel.visible = true
	_overlay.visible = true


func _hide_panels() -> void:
	if _mod_panel:
		_mod_panel.visible = false
	_settings_panel.visible = false
	_gift_panel.visible = false
	_image_viewer.visible = false
	_image_request_panel.visible = false
	_game_panel.visible = false
	_outfit_panel.visible = false
	_location_panel.visible = false
	if _mod_panel:
		_mod_panel.visible = false


func _open_image_request() -> void:
	_image_request_panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 400.0), 0)
	_settings_panel.visible = false
	_gift_panel.visible = false
	_image_viewer.visible = false
	_image_request_panel.visible = false
	_image_request_panel.visible = true
	_overlay.visible = true


func _open_image_viewer(texture: Texture2D) -> void:
	_settings_panel.visible = false
	_gift_panel.visible = false
	_image_request_panel.visible = false
	_image_viewer.show_texture(texture, get_viewport_rect().size * 0.92)
	_image_viewer.visible = true
	_overlay.visible = true


func _close_overlay() -> void:
	_overlay.visible = false
	_overlay.color = Color(0.25, 0.08, 0.18, 0.45)
	if _mod_panel:
		_mod_panel.visible = false
	_game_panel.visible = false
	_outfit_panel.visible = false
	_settings_panel.visible = false
	_gift_panel.visible = false
	_image_viewer.visible = false
	_location_panel.visible = false


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
