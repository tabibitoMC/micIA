class_name MistralClient
extends Node
## Chat con Mistral (/v1/chat/completions), una petición a la vez.
##
## Uso:
##   client.completed.connect(func(content): ...)
##   client.failed.connect(func(message): ...)
##   client.chat(messages, api_key, model)

signal completed(content: String)
signal failed(message: String)

var _api: MistralApi
var _busy := false


func _ready() -> void:
	_api = MistralApi.new()
	add_child(_api)


func is_busy() -> bool:
	return _busy


## messages: Array de {"role": "system"|"user"|"assistant", "content": String o
## Array de fragmentos (texto/imagen)}.
## json_mode: obliga a la IA a responder con un objeto JSON válido.
func chat(messages: Array, api_key: String, model: String, json_mode := true, temperature := 0.8) -> void:
	if _busy:
		failed.emit("Ya hay una petición en curso.")
		return
	var payload := {
		"model": model,
		"messages": messages,
		"temperature": temperature,
	}
	if json_mode:
		payload["response_format"] = {"type": "json_object"}

	_busy = true
	var response: Dictionary = await _api.post_json("/chat/completions", payload, api_key)
	_busy = false
	if not response["ok"]:
		failed.emit(response["error"])
		return
	var content := extract_content(response["data"])
	if content.is_empty():
		failed.emit("Mistral devolvió una respuesta vacía.")
		return
	completed.emit(content)


## La respuesta normal es choices[0].message.content (String). Algunos modelos
## devuelven el contenido como lista de fragmentos; se unen los de texto.
static func extract_content(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var choices: Variant = data.get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		return ""
	var message: Variant = choices[0].get("message", {})
	var content: Variant = message.get("content", "")
	if typeof(content) == TYPE_STRING:
		return content
	if typeof(content) == TYPE_ARRAY:
		var pieces: PackedStringArray = []
		for chunk in content:
			if typeof(chunk) == TYPE_DICTIONARY and chunk.get("type") == "text":
				pieces.append(str(chunk.get("text", "")))
		return "".join(pieces)
	return ""
