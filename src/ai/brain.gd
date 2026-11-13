class_name Brain
extends Node
## El "cerebro": arma la conversación, llama a Mistral e interpreta la respuesta.
##
## No sabe nada de la interfaz: solo emite señales. Quien lo use (main.gd)
## decide cómo mostrar la respuesta, qué cara poner, si hablar, etc.

signal reply_ready(reply: AIReply)
signal failed(message: String)
signal thinking_changed(is_thinking: bool)

## Cuántos mensajes anteriores se envían como contexto.
const CONTEXT_MESSAGES := 16

var _client: MistralClient
var _pending_user_entry: Dictionary = {}


func _ready() -> void:
	_client = MistralClient.new()
	add_child(_client)
	_client.completed.connect(_on_completed)
	_client.failed.connect(_on_failed)


func is_thinking() -> bool:
	return _client.is_busy()


## Mensaje escrito por el usuario.
func send_message(text: String) -> void:
	_ask(Memory.make_entry("user", text, text, Memory.KIND_MESSAGE))


## Algo que pasó en la app (regalo, desbloqueo...). `for_ai` es la descripción
## para la IA y `for_chat` lo que se muestra en el chat.
func send_event(for_ai: String, for_chat: String) -> void:
	_ask(Memory.make_entry("user", "[EVENTO] " + for_ai, for_chat, Memory.KIND_EVENT))


func _ask(user_entry: Dictionary) -> void:
	if _client.is_busy():
		failed.emit("Espera, todavía está pensando.")
		return
	if not Settings.has_api_key():
		failed.emit("Falta tu API key de Mistral. Ponla en Ajustes.")
		return

	_pending_user_entry = user_entry
	var messages: Array = [{"role": "system", "content": _system_prompt()}]
	messages.append_array(Memory.recent_for_api(CONTEXT_MESSAGES))
	messages.append({"role": "user", "content": user_entry["content"]})

	thinking_changed.emit(true)
	_client.chat(messages, str(Settings.get_value("api_key")), str(Settings.get_value("model")))


func _system_prompt() -> String:
	return PromptBuilder.build_system_prompt({
		"companion_name": str(Settings.get_value("companion_name")),
		"user_name": Settings.user_display_name(),
		"personality": Personalities.fetch(str(Settings.get_value("personality"))),
		"mood_description": Mood.describe_for_prompt(),
		"treatment_summary": Mood.treatment_summary(),
		"facts": Memory.facts,
	})


func _on_completed(content: String) -> void:
	thinking_changed.emit(false)
	var reply := AIReply.from_text(content)
	if reply == null:
		failed.emit("No entendí la respuesta de la IA. Intenta de nuevo.")
		return

	# El intercambio solo se guarda si salió bien, así el historial nunca
	# queda con dos mensajes seguidos del usuario.
	Memory.add_exchange(
		_pending_user_entry,
		Memory.make_entry("assistant", reply.to_json_string(), reply.text)
	)
	if not reply.remember.is_empty():
		Memory.add_fact(reply.remember)
	Mood.apply_reply(reply)
	reply_ready.emit(reply)


func _on_failed(message: String) -> void:
	thinking_changed.emit(false)
	failed.emit(message)
