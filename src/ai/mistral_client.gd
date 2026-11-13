class_name MistralClient
extends Node
## Cliente mínimo para la API de chat de Mistral (/v1/chat/completions).
##
## Uso:
##   client.completed.connect(func(content): ...)
##   client.failed.connect(func(message): ...)
##   client.chat(messages, api_key, model)
##
## Solo maneja una petición a la vez. El plan gratuito permite ~1 petición por
## segundo, así que si Mistral responde 429 (demasiadas peticiones) se
## reintenta automáticamente un par de veces.

signal completed(content: String)
signal failed(message: String)

const ENDPOINT := "https://api.mistral.ai/v1/chat/completions"
const TIMEOUT_SECONDS := 60.0
const MAX_RETRIES := 2
const RETRY_DELAY_SECONDS := 1.5

var _http: HTTPRequest
var _busy := false
var _headers := PackedStringArray()
var _body := ""
var _retries_left := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func is_busy() -> bool:
	return _busy


## messages: Array de {"role": "system"|"user"|"assistant", "content": ...}
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
	_headers = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer " + api_key.strip_edges(),
	])
	_body = JSON.stringify(payload)
	_retries_left = MAX_RETRIES
	_busy = true
	_send()


func _send() -> void:
	var err := _http.request(ENDPOINT, _headers, HTTPClient.METHOD_POST, _body)
	if err != OK:
		_finish_with_error("No se pudo iniciar la conexión (error %d)." % err)


func _on_request_completed(result: int, code: int, _response_headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_with_error("Sin conexión con Mistral (resultado %d). ¿Hay internet?" % result)
		return

	if code == 429 and _retries_left > 0:
		_retries_left -= 1
		await get_tree().create_timer(RETRY_DELAY_SECONDS).timeout
		_send()
		return

	var text := body.get_string_from_utf8()
	if code != 200:
		_finish_with_error(_describe_http_error(code, text))
		return

	var data: Variant = JSON.parse_string(text)
	var content := _extract_content(data)
	if content.is_empty():
		_finish_with_error("Mistral devolvió una respuesta vacía.")
		return
	_busy = false
	completed.emit(content)


func _finish_with_error(message: String) -> void:
	_busy = false
	failed.emit(message)


## La respuesta normal es choices[0].message.content (String). Algunos modelos
## devuelven el contenido como lista de fragmentos; se unen los de texto.
static func _extract_content(data: Variant) -> String:
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


static func _describe_http_error(code: int, body: String) -> String:
	match code:
		401:
			return "API key inválida. Revísala en Ajustes."
		429:
			return "Mistral dice que vas muy rápido (límite del plan gratis). Espera un momento."
		_:
			var detail := body.substr(0, 200)
			return "Error de Mistral (%d): %s" % [code, detail]
