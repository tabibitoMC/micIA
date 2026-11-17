class_name Brain
extends Node
## El "cerebro": arma la conversación, llama a Mistral e interpreta la respuesta.
##
## No sabe nada de la interfaz: solo emite señales. Quien lo use (main.gd)
## decide cómo mostrar la respuesta, qué cara poner, si hablar, etc.

signal reply_ready(reply: AIReply)
signal failed(message: String)
signal thinking_changed(is_thinking: bool)
## Ella quiere mandar una imagen; `prompt` es la descripción (en inglés).
signal image_requested(prompt: String)

## Cuántos mensajes anteriores se envían como contexto.
const CONTEXT_MESSAGES := 16
## Lado máximo de las fotos que se envían a la IA (menos datos, más rápido).
const PHOTO_MAX_SIDE := 1024

## Descripción de dónde está ella ahora (la pone main.gd).
var scene_context: Callable = func() -> String: return ""

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
## Tipo del último evento enviado ("" = mensaje normal).
var _pending_kind := ""
## Palabras que, repetidas en mensajes seguidos, la hacen sonar a disco rayado.
const CATCHPHRASES := ["tonto", "tonta", "idiota", "baka", "supongo", "hmph", "presumido"]

## Lo último que se mandó a la IA (para pedirle que reescriba si se repite).
var _pending_messages: Array = []
var _retried := false


func send_message(text: String) -> void:
	_pending_kind = ""
	# Los mods pueden modificar lo que se envía (lo que se ve en el chat no cambia).
	_ask(Memory.make_entry("user", Mods.filter_user_message(text), text, Memory.KIND_MESSAGE))


## Algo que pasó en la app (regalo, desbloqueo...). `for_ai` es la descripción
## para la IA y `for_chat` lo que se muestra en el chat.
## kind = "regalo": su respuesta nunca puede subir el enojo ni bajar el cariño.
func send_event(for_ai: String, for_chat: String, kind := "") -> void:
	_pending_kind = kind
	_ask(Memory.make_entry("user", "[EVENTO] " + for_ai, for_chat, Memory.KIND_EVENT))


## Foto enviada por el usuario. La IA la ve solo en este mensaje; en el
## historial queda guardada como texto "[FOTO] ..." (las imágenes pesan mucho
## para reenviarlas siempre) y la foto en sí en user://photos.
## Devuelve la ruta donde se guardó la foto (para mostrarla en el chat).
func send_photo(image: Image, caption: String) -> String:
	var small := ImageUtils.shrink(image, PHOTO_MAX_SIDE)
	var saved_path := ImageUtils.save_to(ImageUtils.PHOTOS_DIR, small)
	var text := caption if not caption.is_empty() else "Te mando esta foto."
	var api_content := [
		{"type": "text", "text": text},
		{"type": "image_url", "image_url": {"url": ImageUtils.to_jpeg_data_url(small)}},
	]
	var entry := Memory.make_entry("user", "[FOTO] " + text, caption, Memory.KIND_MESSAGE, saved_path)
	_ask(entry, api_content)
	return saved_path


## user_entry: lo que se guarda en el historial.
## api_content: lo que se envía ahora a la IA (si es distinto, p. ej. con foto).
func _ask(user_entry: Dictionary, api_content: Variant = null) -> void:
	if _client.is_busy():
		failed.emit("Espera, todavía está pensando.")
		return
	if not Settings.has_api_key():
		failed.emit("Falta tu API key de %s. Ponla en Ajustes." % AIProviders.label())
		return

	_pending_user_entry = user_entry
	var messages: Array = [{"role": "system", "content": _system_prompt()}]
	messages.append_array(Memory.recent_for_api(CONTEXT_MESSAGES))
	messages.append({"role": "user", "content": api_content if api_content != null else user_entry["content"]})

	_pending_messages = messages
	_retried = false
	thinking_changed.emit(true)
	_client.chat(messages, AIProviders.api_key(), AIProviders.model(), true, 0.95)


## Si su respuesta repite una frase que ya dijo hace poco, devuelve esa frase
## (o "" si no repite). Compara grupos de 3 palabras seguidas y el inicio.
func _repeated_phrase(text: String) -> String:
	var words := _words(text)
	if words.size() < 3:
		return ""
	var recent := _recent_lines(5)
	# Muletillas e insultos cariñosos: no dos mensajes seguidos.
	for line in recent.slice(maxi(0, recent.size() - 2)):
		var old_words := _words(str(line))
		for word in CATCHPHRASES:
			if word in words and word in old_words:
				return word
	for line in recent:
		var old := _words(str(line))
		if old.size() >= 3 and words.slice(0, 3) == old.slice(0, 3):
			return " ".join(words.slice(0, 3))
		var seen := {}
		for i in old.size() - 2:
			seen[" ".join(old.slice(i, i + 3))] = true
		for i in words.size() - 2:
			var trio := " ".join(words.slice(i, i + 3))
			if seen.has(trio):
				return trio
	return ""


static func _words(text: String) -> Array:
	var regex := RegEx.new()
	regex.compile("[a-záéíóúñü]+")
	var words: Array = []
	for match in regex.search_all(text.to_lower()):
		words.append(match.get_string())
	return words


## Lo que ella dijo en sus últimas respuestas (para que no lo repita).
func _recent_lines(count: int) -> Array:
	var lines: Array = []
	for entry in Memory.recent_for_api(count * 2):
		if entry.get("role") != "assistant":
			continue
		var content: Variant = entry.get("content", "")
		var text := str(content)
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("texto"):
			text = str(parsed["texto"])
		if not text.strip_edges().is_empty():
			lines.append(text.strip_edges().left(160))
	return lines.slice(maxi(0, lines.size() - count))


func _system_prompt() -> String:
	return PromptBuilder.build_system_prompt({
		"companion_name": str(Settings.get_value("companion_name")),
		"user_name": Settings.user_display_name(),
		"personality": Personalities.fetch(str(Settings.get_value("personality"))),
		"appearance": str(Settings.get_value("appearance")),
		"identity": str(Settings.character()["identity"]) + " Ahora llevas puesto tu conjunto \"%s\"." % Settings.current_outfit()["label"],
		"relationship_description": Relationship.describe_for_prompt(Personalities.fetch(str(Settings.get_value("personality")))),
		"room_theme": RoomBackground.THEMES.get(str(Settings.get_value("room_theme")), {"label": "Día"})["label"],
		"mood_description": Mood.describe_for_prompt(),
		"treatment_summary": Mood.treatment_summary(),
		"custom_prompt": str(Settings.get_value("custom_prompt")),
		"recent_lines": _recent_lines(6),
		"facts": Memory.facts,
		"mods_prompt": Mods.extra_prompt(),
		"phone_actions": bool(Settings.get_value("phone_actions")),
		"now": _now_text(),
		"scene": scene_context.call(),
	})


## Fecha y hora reales, para que entienda "mañana a las 7" o "en 10 minutos".
static func _now_text() -> String:
	const DAYS := ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
	var t := Time.get_datetime_dict_from_system()
	return "%s %02d/%02d/%d y son las %02d:%02d" % [DAYS[int(t["weekday"])], t["day"], t["month"], t["year"], t["hour"], t["minute"]]


## La IA a veces confunde "fingir enojo" (tsundere) con enojarse de verdad.
## Estas reglas evitan que un regalo o un halago la enojen o la depriman.
func _keep_mood_coherent(reply: AIReply) -> void:
	var kind := _pending_kind
	if kind == "regalo":
		reply.anger_delta = mini(reply.anger_delta, -5)
		reply.affection_delta = maxi(reply.affection_delta, 2)
		reply.treatment = "bueno"
		if reply.emotion in ["triste", "enojada"]:
			reply.emotion = "avergonzada"
	elif reply.treatment == "bueno":
		reply.anger_delta = mini(reply.anger_delta, 0)
		reply.affection_delta = maxi(reply.affection_delta, 0)
		if reply.emotion == "triste":
			reply.emotion = "avergonzada"
	elif reply.treatment == "neutral":
		reply.anger_delta = mini(reply.anger_delta, 3)


func _on_completed(content: String) -> void:
	var reply := AIReply.from_text(content)
	if reply == null:
		thinking_changed.emit(false)
		failed.emit("No entendí la respuesta de la IA. Intenta de nuevo.")
		return
	# Si repite una frase de hace poco, se le pide UNA vez que la reescriba.
	var repeated := _repeated_phrase(reply.text)
	if not repeated.is_empty() and not _retried and not _pending_messages.is_empty():
		_retried = true
		var retry := _pending_messages.duplicate()
		retry.append({"role": "assistant", "content": content})
		retry.append({"role": "user", "content": "[EVENTO] (Mensaje del sistema, no de él.) Tu respuesta repite \"%s\", que ya dijiste hace poco. Responde de nuevo lo mismo pero con palabras totalmente distintas, sin esa frase ni muletillas repetidas. Mismo formato JSON." % repeated})
		_client.chat(retry, AIProviders.api_key(), AIProviders.model(), true, 1.0)
		return
	thinking_changed.emit(false)

	# El intercambio solo se guarda si salió bien, así el historial nunca
	# queda con dos mensajes seguidos del usuario.
	Memory.add_exchange(
		_pending_user_entry,
		Memory.make_entry("assistant", reply.to_json_string(), reply.text)
	)
	if not reply.remember.is_empty():
		Memory.add_fact(reply.remember)
	_keep_mood_coherent(reply)
	_pending_kind = ""
	Mood.apply_reply(reply)
	Relationship.apply_reply(reply, Personalities.fetch(str(Settings.get_value("personality"))))
	Mods.notify_reply(reply)
	reply_ready.emit(reply)
	if not reply.image_prompt.is_empty():
		image_requested.emit(reply.image_prompt)


func _on_failed(message: String) -> void:
	thinking_changed.emit(false)
	failed.emit(message)
