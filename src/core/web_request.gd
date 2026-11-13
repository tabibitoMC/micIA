class_name WebRequest
extends Node
## Peticiones HTTP genéricas y asíncronas (se usan con await).
##
## Devuelve siempre:
##   {"ok": bool, "code": int, "data": Variant (JSON o null), "bytes": PackedByteArray, "error": String}

const TIMEOUT_SECONDS := 90.0


func get_json(url: String, headers := PackedStringArray()) -> Dictionary:
	return await request(url, HTTPClient.METHOD_GET, headers, "", true)


func post_json(url: String, payload: Dictionary, headers := PackedStringArray()) -> Dictionary:
	var all_headers := headers.duplicate()
	all_headers.append("Content-Type: application/json")
	return await request(url, HTTPClient.METHOD_POST, all_headers, JSON.stringify(payload), true)


func get_bytes(url: String, headers := PackedStringArray()) -> Dictionary:
	return await request(url, HTTPClient.METHOD_GET, headers, "", false)


func request(url: String, method: int, headers: PackedStringArray, body: String, parse_json: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return fail(0, "No se pudo iniciar la conexión (error %d)." % err)
	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var code: int = response[1]
	var bytes: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return fail(0, "Sin conexión (resultado %d). ¿Hay internet?" % result)
	if code < 200 or code >= 300:
		return fail(code, "Error %d: %s" % [code, bytes.get_string_from_utf8().substr(0, 200)])
	var data: Variant = null
	if parse_json:
		data = JSON.parse_string(bytes.get_string_from_utf8())
		if data == null:
			return fail(code, "La respuesta no es JSON.")
	return {"ok": true, "code": code, "data": data, "bytes": bytes, "error": ""}


static func fail(code: int, message: String) -> Dictionary:
	return {"ok": false, "code": code, "data": null, "bytes": PackedByteArray(), "error": message}
