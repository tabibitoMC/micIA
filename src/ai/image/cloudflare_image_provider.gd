class_name CloudflareImageProvider
extends ImageProvider
## Cloudflare Workers AI con FLUX.1 Schnell.
## Plan gratis: 10.000 "neuronas" al día (~170 imágenes), se reinicia a las
## 00:00 UTC. Necesita el Account ID y un API token con permiso "Workers AI".

const MODEL := "@cf/black-forest-labs/flux-1-schnell"
const STEPS := 4


func display_name() -> String:
	return "Cloudflare"


func is_configured() -> bool:
	return not _account_id().is_empty() and not _token().is_empty()


func generate(web: WebRequest, prompt: String) -> Dictionary:
	var url := "https://api.cloudflare.com/client/v4/accounts/%s/ai/run/%s" % [_account_id(), MODEL]
	var response := await web.post_json(url, {"prompt": prompt, "steps": STEPS},
		PackedStringArray(["Authorization: Bearer " + _token()]))
	if not response["ok"]:
		if response["code"] == 429:
			return {"error": "Cloudflare: se acabó la cuota de hoy (se recarga a las 7 p. m. hora de Perú)."}
		return {"error": "Cloudflare: " + str(response["error"])}
	var result: Variant = response["data"].get("result", {}) if typeof(response["data"]) == TYPE_DICTIONARY else {}
	var image_b64 := str(result.get("image", "")) if typeof(result) == TYPE_DICTIONARY else ""
	if image_b64.is_empty():
		return {"error": "Cloudflare no devolvió imagen."}
	return {"bytes": Marshalls.base64_to_raw(image_b64)}


func _account_id() -> String:
	return str(Settings.get_value("cloudflare_account_id")).strip_edges()


func _token() -> String:
	return str(Settings.get_value("cloudflare_api_token")).strip_edges()
