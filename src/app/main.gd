extends Control
## Pantalla principal. Arma la interfaz y conecta las piezas:
##
##   usuario escribe -> Brain (Groq) -> AIReply -> chat + avatar + voz
##   Mood (autoload) decide si ella te bloquea; los regalos la calman.
##
## Capas (de atrás hacia adelante):
##   RoomBackground -> Avatar (pantalla completa) -> interfaz -> tarjeta de
##   bloqueo -> ventanas (Ajustes / Regalos)
##
## La lógica de cada pieza vive en su propio script; aquí solo se "cablea".

const HISTORY_ON_SCREEN := 40
## Fracción de la pantalla que ocupa el chat (el resto deja ver al avatar).
## Ancho máximo del chat en pantallas anchas.
const CHAT_MAX_WIDTH := 620.0
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
var _side_panel: SidePanel
var _side_layer: MarginContainer
var _trust_bar: TrustBar
var _mod_panel: Control
var _chat: ChatView
var _name_pill: MoodBar
var _status_label: Label
var _placeholder: RichTextLabel
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
var _welcome_panel: WelcomePanel
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
		_open_welcome()


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
	# Pétalos de sakura que caen despacio sobre el fondo (detrás de ella).
	add_child(PetalLayer.new())

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
	_trust_bar = TrustBar.new()
	column.add_child(_trust_bar)
	# Los botones laterales flotan aparte: así nunca empujan el chat ni la
	# caja de texto fuera de la pantalla (p. ej. en tablets apaisadas).
	var side_layer := MarginContainer.new()
	side_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_layer.add_theme_constant_override("margin_left", 12)
	side_layer.add_theme_constant_override("margin_top", 96)
	_side_layer = side_layer
	_side_panel = SidePanel.new()
	_side_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_side_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side_layer.add_child(_side_panel)
	_build_side_buttons()
	add_child.call_deferred(side_layer)

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

	# La del nombre ocupa lo que sobra (y recorta el texto si no cabe); la del
	# enojo, solo lo que necesita.
	_name_pill = MoodBar.new(MoodBar.Kind.AFFECTION, "")
	_name_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_pill.size_flags_stretch_ratio = 1.6
	header.add_child(_name_pill)

	var anger := MoodBar.new(MoodBar.Kind.ANGER, "Enojo")
	anger.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(anger)
	return header


func _build_side_buttons() -> Control:
	var column := _side_panel.list
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


## Barra de escritura del concepto visual: una píldora rosa translúcida con
## el botón de cámara (círculo blanco), el campo de texto y el botón de enviar
## (círculo rosa).
func _build_input_row() -> Control:
	var bar := PanelContainer.new()
	var bar_style := UIStyle.soft_pill(Color(1.0, 0.86, 0.91, 0.82), Color(1, 1, 1, 0.9), 999, 8, 7)
	bar.add_theme_stylebox_override("panel", bar_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	_photo_button = _round_button("camera", Color.WHITE, Color("e0628f"), Color("f6b6cb"))
	_photo_button.tooltip_text = "Mandarle una foto"
	row.add_child(_photo_button)

	var field := Control.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 52)
	row.add_child(field)
	_input = LineEdit.new()
	_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var input_style := UIStyle.rounded(Color(1, 1, 1, 0.97), 999, 0)
	input_style.content_margin_left = 20
	input_style.content_margin_right = 14
	input_style.border_color = Color("fbd3e1")
	input_style.set_border_width_all(2)
	_input.add_theme_stylebox_override("normal", input_style)
	var focus_style := input_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color("ef7aa5")
	_input.add_theme_stylebox_override("focus", focus_style)
	_input.add_theme_font_override("font", UIStyle.font(600))
	_input.add_theme_font_size_override("font_size", 18)
	field.add_child(_input)
	# "Escríbele a *Aka*..." con el nombre en cursiva (un LineEdit no puede
	# mezclar estilos en su texto de ayuda, así que va encima).
	_placeholder = RichTextLabel.new()
	_placeholder.bbcode_enabled = true
	_placeholder.fit_content = true
	_placeholder.scroll_active = false
	_placeholder.autowrap_mode = TextServer.AUTOWRAP_OFF
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder.add_theme_font_override("normal_font", UIStyle.font(600))
	_placeholder.add_theme_font_override("italics_font", UIStyle.font(600, true))
	_placeholder.add_theme_font_size_override("normal_font_size", 18)
	_placeholder.add_theme_font_size_override("italics_font_size", 18)
	_placeholder.add_theme_color_override("default_color", UIStyle.PLUM_DIM)
	_placeholder.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_placeholder.position = Vector2(21, 0)
	field.add_child(_placeholder)
	field.resized.connect(func(): _placeholder.position = Vector2(21, (field.size.y - _placeholder.size.y) / 2.0))
	_input.text_changed.connect(func(_t: String): _update_placeholder())

	_send_button = _round_button("send", Color("ef7aa5"), Color.WHITE, Color("f7a8c4"))
	_send_button.tooltip_text = "Enviar"
	row.add_child(_send_button)
	return bar


## Botón circular con ícono (cámara / enviar).
func _round_button(icon: String, fill: Color, icon_color: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = ""
	button.icon = Icons.texture(icon, icon_color, 72, 2.2)
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 26)
	button.custom_minimum_size = Vector2(52, 52)
	var style := UIStyle.rounded(fill, 999, 0)
	style.border_color = border
	style.set_border_width_all(2)
	style.shadow_color = Color(0.85, 0.35, 0.55, 0.2)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.08)
	pressed.shadow_size = 1
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = fill.lerp(Color.WHITE, 0.45)
	button.add_theme_stylebox_override("disabled", disabled)
	return button


## El texto de ayuda con el nombre de ella en cursiva, solo con el campo vacío.
func _update_placeholder() -> void:
	if _placeholder == null:
		return
	_placeholder.visible = _input.text.is_empty() and _input.editable
	_placeholder.text = "Escríbele a [i]%s[/i]..." % Settings.get_value("companion_name")


## Fondo oscuro con una ventana centrada (Ajustes o Regalos).
func _build_overlay() -> void:
	_overlay = ColorRect.new()
	# Por encima de los botones laterales (que se añaden después).
	_overlay.z_index = 20
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

	_welcome_panel = WelcomePanel.new()
	_welcome_panel.visible = false
	center.add_child(_welcome_panel)

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
var _last_action := ""
var _avatar_quality := true


## Crea el avatar 3D o 2D según Ajustes y el personaje. Si el 3D falla, usa el 2D.
func _rebuild_avatar() -> void:
	var want_3d := true
	var outfit := Settings.current_outfit()
	var model_path := str(outfit.get("model", Settings.character()["model"]))
	var quality := bool(Settings.get_value("avatar_high_quality"))
	if _avatar != null and want_3d == _avatar_is_3d and (not want_3d or model_path == _avatar_model_path) and quality == _avatar_quality:
		_avatar.apply_tint(outfit.get("cloth", Color.WHITE), outfit.get("hair", Color.WHITE))
		return
	_avatar_model_path = model_path
	_avatar_quality = quality
	if _avatar != null:
		_avatar.queue_free()
		_avatar = null

	if want_3d:
		var avatar_3d := AvatarPuppet.new()
		avatar_3d.model_path = model_path
		avatar_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_avatar_layer.add_child(avatar_3d)
		if avatar_3d.is_ready():
			_avatar = avatar_3d
			_avatar_is_3d = true
			avatar_3d.room = _room
			avatar_3d.set_room(str(Settings.get_value("location")), str(Settings.get_value("room_theme")))
		else:
			avatar_3d.queue_free()
			_chat.add_message(ChatView.Sender.SYSTEM, "No se pudo cargar el avatar VTuber; uso el dibujado.")
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
	_room.visible = true
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
	_voice.level_changed.connect(func(level: float): _avatar.set_mouth_level(level))

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
	_update_placeholder()
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
	_update_placeholder()
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


## La imagen que generaste se le envía a ella (visión de Groq) para que la
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
	# El mismo gesto dos veces seguidas se ve robótico: la segunda vez se
	# deja solo la expresión (salvo golpes y llanto, que son reacciones).
	var action := reply.action
	if action == _last_action and action not in ["golpear", "llorar"]:
		action = "ninguna"
	_last_action = reply.action
	_avatar.play_action(action)
	_voice.speak(reply.text)
	if not reply.phone.is_empty() and bool(Settings.get_value("phone_actions")):
		_do_phone_action(reply.phone)
	if reply.interface_action != "ninguna":
		# Primero el gesto, luego se mueve por la pantalla.
		await get_tree().create_timer(0.8).timeout
		_interface_actions.perform(reply.interface_action)


## Abre YouTube, pone la alarma, etc. Espera un poco para que se lea su
## respuesta antes de que otra app tape la pantalla.
func _do_phone_action(data: Dictionary) -> void:
	var opens_other_app := str(data.get("accion", "")) not in ["alarma", "temporizador"]
	await get_tree().create_timer(1.6 if opens_other_app else 0.4).timeout
	var result := PhoneActions.perform(data)
	if not result.is_empty():
		_chat.add_message(ChatView.Sender.SYSTEM, result)


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

	for_ai += " Te gusta que te den regalos: reacciona según tu personalidad (puedes disimular), pero en el fondo te alegra y se te pasa el enojo."
	var for_chat := "Le diste: %s" % gift_label
	_chat.add_message(ChatView.Sender.EVENT, for_chat)
	_brain.send_event(for_ai, for_chat, "regalo")


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
	_input.placeholder_text = ""
	_update_placeholder()
	if thinking:
		_status_label.text = "%s está escribiendo..." % companion
	elif drawing:
		_status_label.text = "Generando imagen..."
	else:
		_status_label.text = ""
	_status_label.visible = thinking or drawing


func _on_resized() -> void:
	var view := get_viewport_rect().size
	_chat.custom_minimum_size.y = view.y * CHAT_HEIGHT_RATIO * 0.75
	# Los botones laterales no bajan más allá de donde empieza el chat.
	# En pantallas anchas (tablet, horizontal) el chat y la barra de escritura
	# no se estiran de lado a lado: quedan centrados con un ancho cómodo.
	var usable := view.x - 24.0
	var wide := usable > CHAT_MAX_WIDTH
	for part in [_chat, _input_row]:
		if part:
			part.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
			part.custom_minimum_size.x = CHAT_MAX_WIDTH if wide else 0.0
	_place_side_panel.call_deferred()


## El panel lateral empieza justo debajo de la barra de confianza y termina
## antes del chat.
func _place_side_panel() -> void:
	if _side_panel == null or _side_layer == null or _trust_bar == null:
		return
	var top := _trust_bar.get_global_rect().end.y - get_global_rect().position.y + 10.0
	_side_layer.add_theme_constant_override("margin_top", int(top))
	var bottom := _chat.get_global_rect().position.y - get_global_rect().position.y - 10.0
	_side_panel.set_list_height(clampf(bottom - top, 150.0, 6.0 * (SideButton.TILE_SIZE.y + 2.0) + 62.0))


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


## Al terminar el juego, ella reacciona al resultado con Groq.
func _on_game_finished(for_ai: String, for_chat: String) -> void:
	_close_overlay()
	_chat.add_message(ChatView.Sender.EVENT, for_chat)
	if not Mood.blocked and not _brain.is_thinking():
		_brain.send_event(for_ai, for_chat)


## Primer inicio: pide las claves y las guarda en el dispositivo.
func _open_welcome() -> void:
	_hide_panels()
	var view := get_viewport_rect().size
	_welcome_panel.custom_minimum_size = Vector2(minf(view.x - 30.0, 440.0), minf(view.y - 60.0, 720.0))
	_welcome_panel.visible = true
	_overlay.visible = true
	if not _welcome_panel.finished.is_connected(_on_welcome_finished):
		_welcome_panel.finished.connect(_on_welcome_finished)


func _on_welcome_finished() -> void:
	_close_overlay()
	_chat.add_message(ChatView.Sender.EVENT, "¡Listo! Ya puedes hablar con %s." % Settings.get_value("companion_name"))


func _open_locations() -> void:
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


## Cambiar de ropa: se aplica al avatar y ella se entera (Groq reacciona).
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
	_welcome_panel.visible = false
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
	_welcome_panel.visible = false


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
