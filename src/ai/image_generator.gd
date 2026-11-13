class_name ImageGenerator
extends Node
## Genera imágenes con la herramienta "image_generation" de Mistral.
##
## Pasos (API de Agents/Conversations):
##   1. Crear (una sola vez) un agente con tools=[{"type":"image_generation"}].
##      Su id se guarda en Ajustes para no recrearlo cada vez.
##   2. POST /conversations con agent_id + el prompt.
##   3. Buscar en la respuesta el fragmento "tool_file" y su file_id.
##   4. GET /files/{file_id}/content para descargar la imagen.

signal generated(image_path: String)
signal failed(message: String)

const AGENT_MODEL := "mistral-medium-latest"
const AGENT_NAME := "micIA image generator"
const AGENT_INSTRUCTIONS := "Always use the image generation tool to create exactly one image that matches the user's request. Do not ask questions."

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
	var agent: Dictionary = await _ensure_agent(api_key)
	if not agent["error"].is_empty():
		return agent["error"]
	var agent_id: String = agent["id"]

	var response: Dictionary = await _api.post_json("/conversations", {
		"agent_id": agent_id,
		"inputs": prompt,
		"store": false,
	}, api_key)
	if not response["ok"]:
		# El agente pudo borrarse (o cambió la API key): se recrea la próxima vez.
		if response["code"] == 404:
			Settings.set_value("image_agent_id", "")
			Settings.save()
		return "No pude generar la imagen: " + str(response["error"])

	var file_id := _find_file_id(response["data"])
	if file_id.is_empty():
		return "Mistral no devolvió ninguna imagen."

	var download: Dictionary = await _api.get_bytes("/files/%s/content" % file_id, api_key)
	if not download["ok"]:
		return "No pude descargar la imagen: " + str(download["error"])
	var image := ImageUtils.from_bytes(download["bytes"])
	if image == null:
		return "La imagen descargada no tiene un formato conocido."
	var path := ImageUtils.save_to(ImageUtils.GENERATED_DIR, image)
	return path if not path.is_empty() else "No pude guardar la imagen."


## Devuelve {"id": String, "error": String}.
func _ensure_agent(api_key: String) -> Dictionary:
	var saved := str(Settings.get_value("image_agent_id"))
	if not saved.is_empty():
		return {"id": saved, "error": ""}
	var response: Dictionary = await _api.post_json("/agents", {
		"model": AGENT_MODEL,
		"name": AGENT_NAME,
		"description": "Genera imágenes para la app micIA.",
		"instructions": AGENT_INSTRUCTIONS,
		"tools": [{"type": "image_generation"}],
	}, api_key)
	if not response["ok"]:
		return {"id": "", "error": "No pude preparar el generador de imágenes: " + str(response["error"])}
	var agent_id := str(response["data"].get("id", ""))
	if agent_id.is_empty():
		return {"id": "", "error": "Mistral no devolvió el id del agente."}
	Settings.set_value("image_agent_id", agent_id)
	Settings.save()
	return {"id": agent_id, "error": ""}


## Busca el primer fragmento {"type": "tool_file", "file_id": ...} en outputs.
static func _find_file_id(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	for output in data.get("outputs", []):
		if typeof(output) != TYPE_DICTIONARY:
			continue
		var content: Variant = output.get("content", [])
		if typeof(content) != TYPE_ARRAY:
			continue
		for chunk in content:
			if typeof(chunk) == TYPE_DICTIONARY and chunk.get("type") == "tool_file":
				return str(chunk.get("file_id", ""))
	return ""
