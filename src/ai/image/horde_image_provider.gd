class_name HordeImageProvider
extends ImageProvider
## AI Horde: generación gratuita con GPUs de voluntarios.
## Sin cuenta se usa la clave anónima "0000000000" (prioridad baja, puede
## tardar). Con cuenta propia (aihorde.net/register) va más rápido.
##
## Flujo: POST /generate/async -> consultar /generate/check/{id} hasta que
## termine -> /generate/status/{id} trae la URL de la imagen.

const BASE := "https://aihorde.net/api/v2"
const ANONYMOUS_KEY := "0000000000"
const CLIENT_AGENT := "micIA:1.0:personal"
const POLL_SECONDS := 4.0
const MAX_WAIT_SECONDS := 180.0


func display_name() -> String:
	return "AI Horde"


func generate(web: WebRequest, prompt: String) -> Dictionary:
	var key := str(Settings.get_value("horde_api_key")).strip_edges()
	if key.is_empty():
		key = ANONYMOUS_KEY
	var headers := PackedStringArray(["apikey: " + key, "Client-Agent: " + CLIENT_AGENT])
	var anonymous := key == ANONYMOUS_KEY

	var submit := await web.post_json(BASE + "/generate/async", {
		"prompt": "anime style, high quality, " + prompt,
		"params": {
			"width": 512,
			"height": 512 if anonymous else 768,
			"steps": 20,
			"n": 1,
			"sampler_name": "k_euler_a",
			"cfg_scale": 7,
		},
		# Las imágenes de la app son siempre aptas para todo público.
		"nsfw": false,
		"censor_nsfw": true,
		"r2": true,
	}, headers)
	if not submit["ok"]:
		return {"error": "AI Horde: " + str(submit["error"])}
	var id := str(submit["data"].get("id", ""))
	if id.is_empty():
		return {"error": "AI Horde no aceptó el pedido."}

	var waited := 0.0
	while waited < MAX_WAIT_SECONDS:
		await web.get_tree().create_timer(POLL_SECONDS).timeout
		waited += POLL_SECONDS
		var check := await web.get_json(BASE + "/generate/check/" + id, headers)
		if not check["ok"]:
			continue
		if check["data"].get("faulted", false) or not check["data"].get("is_possible", true):
			return {"error": "AI Horde no pudo generar la imagen ahora."}
		if check["data"].get("done", false):
			break
	if waited >= MAX_WAIT_SECONDS:
		return {"error": "AI Horde tardó demasiado (mucha cola). Intenta más tarde."}

	var status := await web.get_json(BASE + "/generate/status/" + id, headers)
	if not status["ok"]:
		return {"error": "AI Horde: " + str(status["error"])}
	var generations: Array = status["data"].get("generations", [])
	if generations.is_empty():
		return {"error": "AI Horde no devolvió imagen."}
	var img := str(generations[0].get("img", ""))
	if img.begins_with("http"):
		var download := await web.get_bytes(img)
		if not download["ok"]:
			return {"error": "AI Horde: no pude descargar la imagen."}
		return {"bytes": download["bytes"]}
	return {"bytes": Marshalls.base64_to_raw(img)}
