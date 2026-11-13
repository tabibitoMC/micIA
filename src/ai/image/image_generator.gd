class_name ImageGenerator
extends Node
## Genera imágenes probando varios servicios gratuitos en orden:
##   1. Cloudflare Workers AI (si pusiste Account ID y token en Ajustes)
##   2. AI Horde, "comunitaria" (funciona sin cuenta)
##   3. Mistral (si tu plan lo permite)
## Se puede pedir un servicio preferido; si falla, pasa a los demás.
##
## origin: quién pidió la imagen ("companion" = ella, "user" = tú con el botón).

signal generated(image_path: String, prompt: String, origin: String)
signal failed(message: String, origin: String)

const PROVIDER_CLOUDFLARE := "cloudflare"
const PROVIDER_HORDE := "horde"
const PROVIDER_MISTRAL := "mistral"

var _web: WebRequest
var _busy := false


func _ready() -> void:
	_web = WebRequest.new()
	add_child(_web)


func is_busy() -> bool:
	return _busy


func generate(prompt: String, preferred := "", origin := "companion") -> void:
	if _busy:
		failed.emit("Ya hay una imagen generándose.", origin)
		return
	_busy = true
	var result := await _generate(prompt, preferred)
	_busy = false
	if result.begins_with("user://"):
		generated.emit(result, prompt, origin)
	else:
		failed.emit(result, origin)


## Proveedores en orden; el preferido (si se indica) va primero.
static func _providers(preferred := "") -> Array[ImageProvider]:
	var by_id := {
		PROVIDER_CLOUDFLARE: CloudflareImageProvider.new(),
		PROVIDER_HORDE: HordeImageProvider.new(),
		PROVIDER_MISTRAL: MistralImageProvider.new(),
	}
	var order: Array = [PROVIDER_CLOUDFLARE, PROVIDER_HORDE, PROVIDER_MISTRAL]
	if by_id.has(preferred):
		order.erase(preferred)
		order.push_front(preferred)
	var list: Array[ImageProvider] = []
	for id in order:
		list.append(by_id[id])
	return list


## Devuelve la ruta de la imagen guardada o un mensaje con los errores.
func _generate(prompt: String, preferred: String) -> String:
	var errors: PackedStringArray = []
	for provider in _providers(preferred):
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
