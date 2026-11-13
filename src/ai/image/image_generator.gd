class_name ImageGenerator
extends Node
## Genera imágenes probando varios servicios gratuitos en orden:
##   1. Cloudflare Workers AI (si pusiste Account ID y token en Ajustes)
##   2. AI Horde (funciona sin cuenta)
##   3. Mistral (si tu plan lo permite)
## Si uno falla (cuota, error, cola), pasa al siguiente.

signal generated(image_path: String)
signal failed(message: String)

var _web: WebRequest
var _busy := false


func _ready() -> void:
	_web = WebRequest.new()
	add_child(_web)


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


static func _providers() -> Array[ImageProvider]:
	return [CloudflareImageProvider.new(), HordeImageProvider.new(), MistralImageProvider.new()]


## Devuelve la ruta de la imagen guardada o un mensaje con los errores.
func _generate(prompt: String) -> String:
	var errors: PackedStringArray = []
	for provider in _providers():
		if not provider.is_configured():
			continue
		var result: Dictionary = await provider.generate(_web, prompt)
		if result.has("error"):
			errors.append(str(result["error"]))
			continue
		var image := ImageUtils.from_bytes(result["bytes"])
		if image == null:
			errors.append("%s: formato de imagen desconocido." % provider.display_name())
			continue
		var path := ImageUtils.save_to(ImageUtils.GENERATED_DIR, image)
		if not path.is_empty():
			return path
		errors.append("No pude guardar la imagen.")
	if errors.is_empty():
		return "No hay ningún servicio de imágenes disponible."
	return "No pude generar la imagen:\n- " + "\n- ".join(errors)
