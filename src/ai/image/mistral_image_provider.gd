class_name MistralImageProvider
extends ImageProvider
## Mistral con la herramienta "image_generation" en /v1/chat/completions.
## Puede no estar incluida en el plan gratuito; queda como último recurso.
##
## La documentación no fija el formato de la respuesta, así que la imagen se
## busca en cualquier forma conocida (image_url, tool_file o un enlace).

const MODEL := "mistral-small-latest"
const BASE := "https://api.mistral.ai/v1"


func display_name() -> String:
	return "Mistral"


func is_configured() -> bool:
	return Settings.has_api_key()


func generate(web: WebRequest, prompt: String) -> Dictionary:
	var auth := PackedStringArray(["Authorization: Bearer " + str(Settings.get_value("api_key")).strip_edges()])
	var response := await web.post_json(BASE + "/chat/completions", {
		"model": MODEL,
		"messages": [{"role": "user", "content": "Generate this image (one image, no text in it): " + prompt}],
		"tools": [{"type": "image_generation"}],
	}, auth)
	if not response["ok"]:
		return {"error": "Mistral: " + str(response["error"])}

	var found := find_image_reference(response["data"])
	match found.get("kind", ""):
		"data_url":
			return {"bytes": Marshalls.base64_to_raw(str(found["value"]).get_slice(",", 1))}
		"file_id":
			var file := await web.get_bytes(BASE + "/files/%s/content" % found["value"], auth)
			return {"bytes": file["bytes"]} if file["ok"] else {"error": "Mistral: " + str(file["error"])}
		"url":
			var headers := auth if str(found["value"]).contains("mistral.ai") else PackedStringArray()
			var download := await web.get_bytes(str(found["value"]), headers)
			return {"bytes": download["bytes"]} if download["ok"] else {"error": "Mistral: " + str(download["error"])}
	return {"error": "Mistral no devolvió imagen (quizá tu plan no la incluye)."}


## Recorre la respuesta buscando la imagen. Devuelve
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
