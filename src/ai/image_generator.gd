class_name ImageGenerator
extends Node
## Genera imágenes con la herramienta "image_generation" de Mistral.
##
## Usa /v1/chat/completions con tools=[{"type": "image_generation"}]. No
## necesita crear agentes (algunas cuentas no pueden crearlos).
##
## La documentación no fija el formato exacto de la respuesta, así que se
## busca la imagen en todas las formas conocidas:
##   - fragmento {"type": "image_url", "image_url": "..."} o {"url": "..."}
##   - fragmento {"type": "tool_file", "file_id": "..."} -> /files/{id}/content
##   - un enlace https://... dentro del texto (p. ej. "[Image: https://...]")

signal generated(image_path: String)
signal failed(message: String)

const MODEL := "mistral-small-latest"

var _api: MistralApi
var _busy := false


func _ready() -> void:
	_api = MistralApi.new()
	add_child(_api)


func is_busy() -> bool:
	return _busy


func generate(prompt: String) -> void:
	if _busy:
		failed.emit("Ya estoy generando una imagen.")
		return
	_busy = true
	var result := await _generate(prompt)
	_busy = false
	if result.begins_with("user://"):
		generated.emit(result)
	else:
		failed.emit(result)


## Devuelve la ruta de la imagen guardada o un mensaje de error.
func _generate(prompt: String) -> String:
	var api_key := str(Settings.get_value("api_key"))
	var response: Dictionary = await _api.post_json("/chat/completions", {
		"model": MODEL,
		"messages": [{"role": "user", "content": "Generate this image (one image, no text in it): " + prompt}],
		"tools": [{"type": "image_generation"}],
	}, api_key)
	if not response["ok"]:
		return "No pude generar la imagen: " + str(response["error"])

	var found := find_image_reference(response["data"])
	var bytes := PackedByteArray()
	match found.get("kind", ""):
		"data_url":
			bytes = Marshalls.base64_to_raw(str(found["value"]).get_slice(",", 1))
		"file_id":
			var download: Dictionary = await _api.get_bytes("/files/%s/content" % found["value"], api_key)
			if not download["ok"]:
				return "No pude descargar la imagen: " + str(download["error"])
			bytes = download["bytes"]
		"url":
			var download: Dictionary = await _api.get_url_bytes(str(found["value"]), api_key)
			if not download["ok"]:
				return "No pude descargar la imagen: " + str(download["error"])
			bytes = download["bytes"]
		_:
			return "Mistral no devolvió ninguna imagen (puede que tu plan no incluya generación de imágenes)."

	var image := ImageUtils.from_bytes(bytes)
	if image == null:
		return "La imagen descargada no tiene un formato conocido."
	var path := ImageUtils.save_to(ImageUtils.GENERATED_DIR, image)
	return path if not path.is_empty() else "No pude guardar la imagen."


## Recorre toda la respuesta buscando la imagen. Devuelve
## {"kind": "data_url"|"file_id"|"url", "value": String} o {} si no hay.
static func find_image_reference(data: Variant) -> Dictionary:
	if typeof(data) == TYPE_DICTIONARY:
		var type := str(data.get("type", ""))
		if type == "tool_file" and data.has("file_id"):
			return {"kind": "file_id", "value": str(data["file_id"])}
		if type == "image_url" and data.has("image_url"):
			var value: Variant = data["image_url"]
			var url := str(value.get("url", "")) if typeof(value) == TYPE_DICTIONARY else str(value)
			if not url.is_empty():
				return {"kind": "data_url" if url.begins_with("data:") else "url", "value": url}
		for key in data:
			var inner := find_image_reference(data[key])
			if not inner.is_empty():
				return inner
	elif typeof(data) == TYPE_ARRAY:
		for item in data:
			var inner := find_image_reference(item)
			if not inner.is_empty():
				return inner
	elif typeof(data) == TYPE_STRING:
		var regex := RegEx.create_from_string("https://[^\\s\\]\\)\"']+")
		var match_result := regex.search(str(data))
		if match_result:
			return {"kind": "url", "value": match_result.get_string()}
	return {}
