class_name MistralClient
extends Node
## Chat con Groq (/v1/chat/completions), una petición a la vez.
##
## Uso:
##   client.completed.connect(func(content): ...)
##   client.failed.connect(func(message): ...)
##   client.chat(messages, api_key, model)

signal completed(content: String)
signal failed(message: String)

## Si el modelo elegido está saturado (429), se prueba con estos en orden.
## En el plan gratuito los límites son por modelo, así que otro suele responder.
const FALLBACK_MODELS := ["openai/gpt-oss-120b", "qwen/qwen3.8-27b", "openai/gpt-oss-20b"]


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
	var response: Dictionary = {}
	var rate_limited := false
	for candidate in _models_to_try(model, messages):
		payload["model"] = candidate
		response = await _api.post_json("/chat/completions", payload, api_key)
		# 429 = límite de ese modelo; 403/404 = modelo no incluido en tu plan.
		if response["code"] == 429:
			rate_limited = true
		elif response["code"] not in [400, 403, 404]:
			break
	_busy = false
	if not response["ok"] and rate_limited:
		response["error"] = "Groq está limitando tu clave (demasiadas peticiones o cuota agotada). Espera unos minutos; si sigue, crea una clave nueva en console.groq.com."
	if not response["ok"]:
		failed.emit(response["error"])
		return
	var content := extract_content(response["data"])
	if content.is_empty():
		failed.emit("Groq devolvió una respuesta vacía.")
		return
	completed.emit(content)


## El modelo elegido primero y luego los de respaldo. Si el mensaje lleva una
## imagen, se omiten los que no tienen visión.
static func _models_to_try(preferred: String, messages: Array) -> Array:
	var has_image := JSON.stringify(messages).contains("\"image_url\"")
	if has_image:
		return [VISION_MODEL]
	var models: Array = [preferred]
	for m in FALLBACK_MODELS:
		if m not in models:
			models.append(m)
	return models


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
