class_name GameAI
extends Node
## Ella como jugadora: Mistral elige SU jugada entre las jugadas legales y
## comenta en personaje. Si la IA falla o elige algo inválido, se juega una
## jugada legal al azar para que el juego nunca se trabe.

signal move_chosen(move: String, comment: String, emotion: String)

var _client: MistralClient
var _legal: Array = []


func _ready() -> void:
	_client = MistralClient.new()
	add_child(_client)
	_client.completed.connect(_on_completed)
	_client.failed.connect(_on_failed)


func is_thinking() -> bool:
	return _client.is_busy()


## game: nombre del juego. state: situación actual en texto.
## legal: jugadas posibles (texto exacto que debe devolver).
func choose(game: String, state: String, legal: Array, rules := "") -> void:
	_legal = legal
	if legal.is_empty():
		return
	if not Settings.has_api_key():
		_play_random("")
		return
	var personality := Personalities.fetch(str(Settings.get_value("personality")))
	var system := """Eres %s y estás jugando %s contra %s dentro de la app. %s
PERSONALIDAD: %s
Juega en serio, intentando ganar. Comenta como tu personaje (una frase corta, en español, sin emojis).
%s
Responde SOLO con JSON: {"jugada": "...", "comentario": "...", "emocion": "..."}
- jugada: exactamente una de las jugadas legales que te doy.
- emocion: una de %s.""" % [
		Settings.get_value("companion_name"), game, Settings.user_display_name(),
		str(Settings.character()["identity"]), personality["prompt"], rules,
		", ".join(PackedStringArray(AIReply.EMOTIONS)),
	]
	var user := "%s\n\nJugadas legales: %s" % [state, ", ".join(PackedStringArray(legal))]
	_client.chat([{"role": "system", "content": system}, {"role": "user", "content": user}],
		AIProviders.api_key(), AIProviders.model(), true, 0.6)


func _on_completed(content: String) -> void:
	var data: Variant = JSON.parse_string(_extract(content))
	if typeof(data) != TYPE_DICTIONARY:
		_play_random("")
		return
	var move := str(data.get("jugada", "")).strip_edges().to_lower()
	var comment := str(data.get("comentario", "")).strip_edges()
	var emotion := str(data.get("emocion", "neutral"))
	if not emotion in AIReply.EMOTIONS:
		emotion = "neutral"
	var match_index := -1
	for i in _legal.size():
		if str(_legal[i]).to_lower() == move:
			match_index = i
	if match_index == -1:
		_play_random(comment)
		return
	move_chosen.emit(_legal[match_index], comment, emotion)


func _on_failed(_message: String) -> void:
	_play_random("")


func _play_random(comment: String) -> void:
	move_chosen.emit(_legal.pick_random(), comment, "pensativa")


static func _extract(raw: String) -> String:
	var start := raw.find("{")
	var end := raw.rfind("}")
	return raw.substr(start, end - start + 1) if start != -1 and end > start else ""
