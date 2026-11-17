class_name MistralApi
extends Node
## Capa HTTP común para el proveedor de IA elegido (Groq o Gemini; ver
## AIProviders). Las rutas relativas van a su base_url.
##
## Cada llamada crea su propio HTTPRequest, así se pueden hacer varias a la
## vez (por ejemplo, chatear mientras se genera una imagen). Las funciones son
## asíncronas: se usan con `await`.
##
## Devuelven siempre un Dictionary:
##   {"ok": bool, "code": int, "data": Variant (JSON), "bytes": PackedByteArray, "error": String}

## Base por defecto (la de Groq); en cada petición se usa la del proveedor.
const BASE_URL := "https://api.groq.com/openai/v1"
const TIMEOUT_SECONDS := 90.0
const MAX_RETRIES := 2
const RETRY_DELAY_SECONDS := 1.5


func post_json(path: String, payload: Dictionary, api_key: String) -> Dictionary:
	return await _request(path, HTTPClient.METHOD_POST, JSON.stringify(payload), api_key, true)


func get_json(path: String, api_key: String) -> Dictionary:
	return await _request(path, HTTPClient.METHOD_GET, "", api_key, true)


func get_bytes(path: String, api_key: String) -> Dictionary:
	return await _request(path, HTTPClient.METHOD_GET, "", api_key, false)


## Descarga una URL completa (p. ej. una imagen generada). Solo se manda la
## API key si la URL es de Groq.
func get_url_bytes(url: String, api_key: String) -> Dictionary:
	var key := api_key if url.begins_with(str(AIProviders.current()["base_url"])) else ""
	return await _request(url, HTTPClient.METHOD_GET, "", key, false)


func _request(path: String, method: int, body: String, api_key: String, parse_json: bool) -> Dictionary:
	var url := path if path.begins_with("https://") else str(AIProviders.current()["base_url"]) + path
	var headers := PackedStringArray(["Accept: application/json" if parse_json else "Accept: */*"])
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key.strip_edges())
	if not body.is_empty():
		headers.append("Content-Type: application/json")

	var retries_left := MAX_RETRIES
	while true:
		var http := HTTPRequest.new()
		http.timeout = TIMEOUT_SECONDS
		add_child(http)
		var err := http.request(url, headers, method, body)
		if err != OK:
			http.queue_free()
			return _fail(0, "No se pudo iniciar la conexión (error %d)." % err)
		var response: Array = await http.request_completed
		http.queue_free()

		var result: int = response[0]
		var code: int = response[1]
		var bytes: PackedByteArray = response[3]
		if result != HTTPRequest.RESULT_SUCCESS:
			return _fail(0, "Sin conexión con %s (resultado %d). ¿Hay internet?" % [AIProviders.label(), result])
		if code == 429 and retries_left > 0:
			retries_left -= 1
			await get_tree().create_timer(RETRY_DELAY_SECONDS).timeout
			continue
		if code < 200 or code >= 300:
			var text := bytes.get_string_from_utf8()
			# Gemini responde 400 (no 401) cuando la clave es mala.
			if code == 400 and (text.contains("API key") or text.contains("API_KEY_INVALID")):
				code = 401
			return _fail(code, describe_http_error(code, text))

		var data: Variant = null
		if parse_json:
			data = JSON.parse_string(bytes.get_string_from_utf8())
			if data == null:
				return _fail(code, "%s devolvió algo que no es JSON." % AIProviders.label())
		return {"ok": true, "code": code, "data": data, "bytes": bytes, "error": ""}
	return _fail(0, "Error inesperado.")


static func _fail(code: int, message: String) -> Dictionary:
	return {"ok": false, "code": code, "data": null, "bytes": PackedByteArray(), "error": message}


static func describe_http_error(code: int, body: String) -> String:
	match code:
		401:
			return "API key inválida. Revísala en Ajustes."
		403:
			return "Tu plan de %s no permite esto (403)." % AIProviders.label()
		429:
			return "%s dice que vas muy rápido (límite del plan gratis). Espera un momento." % AIProviders.label()
		_:
			return "Error de %s (%d): %s" % [AIProviders.label(), code, body.substr(0, 200)]
