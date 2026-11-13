class_name ModApi
extends RefCounted
## Lo que un mod puede hacer con la app. Se pasa a cada mod como `api`.

var _main: Node


func _init(main: Node) -> void:
	_main = main


# --- Acceso directo (para cosas avanzadas) --------------------------------

## El avatar actual (Avatar3D o Avatar2D).
var avatar: Avatar:
	get: return _main._avatar
## El cerebro (Mistral): send_message, send_event, señales reply_ready...
var brain: Brain:
	get: return _main._brain
var chat: ChatView:
	get: return _main._chat
var voice: Voice:
	get: return _main._voice
var room: RoomBackground:
	get: return _main._room


# --- Acciones simples -------------------------------------------------------

## Ella dice algo (local, sin gastar peticiones a la IA).
func say(text: String, emotion := "neutral", action := "ninguna") -> void:
	chat.add_message(ChatView.Sender.COMPANION, text)
	avatar.set_emotion(emotion)
	avatar.play_action(action)
	voice.speak(text)


## Mensaje del sistema en el chat (texto rojo).
func system_message(text: String) -> void:
	chat.add_message(ChatView.Sender.SYSTEM, text)


## Avisa a la IA de algo que pasó; ella responde en personaje.
## for_ai: descripción para ella. for_chat: lo que se ve en el chat.
func post_event(for_ai: String, for_chat: String) -> void:
	chat.add_message(ChatView.Sender.EVENT, for_chat)
	if not brain.is_thinking():
		brain.send_event(for_ai, for_chat)


## Botón lateral nuevo (con el ícono que elijas de SideButton.Icon).
func add_side_button(label: String, callback: Callable, icon := SideButton.Icon.HEART) -> SideButton:
	var button := SideButton.new(icon, label)
	button.pressed.connect(callback)
	_main._side_column.add_child(button)
	return button


## Muestra cualquier Control como ventana centrada (como Ajustes o Juegos).
func open_panel(panel: Control) -> void:
	_main.show_mod_panel(panel)


func close_panel() -> void:
	_main._close_overlay()


# --- Registrar contenido -----------------------------------------------------
# Llamar desde on_register() para que aparezca en los menús.

## data: mismo formato que en src/characters/characters.gd
func register_character(id: String, data: Dictionary) -> void:
	Characters.register(id, data)


## outfit: {"id", "label", y opcionales "model", "cloth", "hair"}
func register_outfit(character_id: String, outfit: Dictionary) -> void:
	Characters.register_outfit(character_id, outfit)


## data: mismo formato que en src/ai/personalities.gd
func register_personality(id: String, data: Dictionary) -> void:
	Personalities.register(id, data)


## data: {"label", "anger_relief", "affection"}
func register_gift(id: String, data: Dictionary) -> void:
	Gifts.register(id, data)


## game_script: un script que extiende MiniGame.
func register_game(title: String, game_script: GDScript) -> void:
	GamePanel.extra_games.append([title, game_script])


# --- Datos propios del mod ---------------------------------------------------

## Guarda/lee datos del mod en user://mods_data/<mod_id>.json
func load_data(mod_id: String) -> Dictionary:
	return JsonStore.load_json("user://mods_data/%s.json" % mod_id, {})


func save_data(mod_id: String, data: Dictionary) -> void:
	JsonStore.save_json("user://mods_data/%s.json" % mod_id, data)
