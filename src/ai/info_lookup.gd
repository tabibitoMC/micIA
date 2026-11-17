class_name InfoLookup
extends Node
## Consultas de información real para que ella conteste con datos de hoy.
##
## La IA pide una consulta con el campo "consultar" de su JSON; la app la
## hace y le devuelve el resultado como [EVENTO] para que lo cuente en
## personaje. Funciona con Groq y con Gemini:
##  - clima: Open-Meteo (gratis, sin clave).
##  - wikipedia: API pública de Wikipedia en español.
##  - web: con Gemini se intenta la búsqueda de Google (en la API gratis
##    puede no estar disponible); si no, la búsqueda web de Groq (modelos
##    GPT-OSS con "browser_search", si hay clave de Groq); si no, DuckDuckGo
##    y Wikipedia.

const KINDS := ["clima", "wikipedia", "web"]

## Códigos del tiempo de Open-Meteo (WMO) en español.
const WEATHER := {
	0: "despejado", 1: "casi despejado", 2: "parcialmente nublado", 3: "nublado",
	45: "con neblina", 48: "con neblina helada", 51: "con llovizna ligera", 53: "con llovizna",
	55: "con llovizna fuerte", 56: "con llovizna helada", 57: "con llovizna helada fuerte",
	61: "con lluvia ligera", 63: "con lluvia", 65: "con lluvia fuerte", 66: "con lluvia helada",
	67: "con lluvia helada fuerte", 71: "con nevada ligera", 73: "con nieve", 75: "con nevada fuerte",
	77: "con granizo fino", 80: "con chubascos ligeros", 81: "con chubascos", 82: "con chubascos fuertes",
	85: "con nieve ligera", 86: "con nevada fuerte", 95: "con tormenta", 96: "con tormenta y granizo",
	99: "con tormenta fuerte y granizo",
}


## Hace la consulta. Devuelve {"ok": bool, "text": String, "source": String}.
func lookup(kind: String, query: String) -> Dictionary:
	query = query.strip_edges()
	match kind:
		"clima":
			return await _weather(query)
		"wikipedia":
			return await _wikipedia(query)
		"web":
			return await _web(query)
	return {"ok": false, "text": "No sé hacer esa consulta.", "source": ""}


# --- Clima ---------------------------------------------------------------------

func _weather(place: String) -> Dictionary:
	if place.is_empty():
		return {"ok": false, "text": "Falta el lugar para ver el clima.", "source": ""}
	var geo := await _get_json("https://geocoding-api.open-meteo.com/v1/search?count=1&language=es&format=json&name=" + place.uri_encode())
	if not geo["ok"] or not (geo["data"] is Dictionary) or (geo["data"] as Dictionary).get("results", []).is_empty():
		return {"ok": false, "text": "No encontré el lugar \"%s\"." % place, "source": "Open-Meteo"}
	var spot: Dictionary = geo["data"]["results"][0]
	var url := "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&timezone=auto&forecast_days=3" % [spot["latitude"], spot["longitude"]]
	url += "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m"
	url += "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
	var forecast := await _get_json(url)
	if not forecast["ok"] or not (forecast["data"] is Dictionary):
		return {"ok": false, "text": "No pude ver el clima ahora.", "source": "Open-Meteo"}
	var data: Dictionary = forecast["data"]
	var now: Dictionary = data.get("current", {})
	var daily: Dictionary = data.get("daily", {})
	var name := "%s (%s)" % [spot.get("name", place), spot.get("country", "")]
	var lines := PackedStringArray()
	lines.append("Clima ahora en %s: %d °C (sensación %d °C), %s, humedad %d %%, viento %d km/h." % [
		name, roundi(float(now.get("temperature_2m", 0))), roundi(float(now.get("apparent_temperature", 0))),
		WEATHER.get(int(now.get("weather_code", 0)), "variable"), roundi(float(now.get("relative_humidity_2m", 0))),
		roundi(float(now.get("wind_speed_10m", 0)))])
	var labels := ["Hoy", "Mañana", "Pasado mañana"]
	var days: Array = daily.get("time", [])
	for i in mini(days.size(), 3):
		lines.append("%s: %s, entre %d y %d °C, %d %% de probabilidad de lluvia." % [
			labels[i], WEATHER.get(int(daily["weather_code"][i]), "variable"),
			roundi(float(daily["temperature_2m_min"][i])), roundi(float(daily["temperature_2m_max"][i])),
			int(daily["precipitation_probability_max"][i]) if daily["precipitation_probability_max"][i] != null else 0])
	return {"ok": true, "text": "\n".join(lines), "source": "Open-Meteo"}


# --- Wikipedia ---------------------------------------------------------------------

func _wikipedia(topic: String) -> Dictionary:
	if topic.is_empty():
		return {"ok": false, "text": "Falta el tema.", "source": ""}
	var search := await _get_json("https://es.wikipedia.org/w/api.php?action=query&list=search&format=json&srlimit=1&srsearch=" + topic.uri_encode())
	var hits: Array = []
	if search["ok"] and search["data"] is Dictionary:
		hits = search["data"].get("query", {}).get("search", [])
	if hits.is_empty():
		return {"ok": false, "text": "Wikipedia no tiene nada sobre \"%s\"." % topic, "source": "Wikipedia"}
	var title := str(hits[0]["title"])
	var summary := await _get_json("https://es.wikipedia.org/api/rest_v1/page/summary/" + title.replace(" ", "_").uri_encode())
	if not summary["ok"] or not (summary["data"] is Dictionary):
		return {"ok": false, "text": "No pude leer Wikipedia ahora.", "source": "Wikipedia"}
	var extract := str(summary["data"].get("extract", "")).left(1400)
	return {"ok": not extract.is_empty(), "text": "%s (Wikipedia): %s" % [title, extract], "source": "Wikipedia"}


# --- Web ---------------------------------------------------------------------

func _web(query: String) -> Dictionary:
	if query.is_empty():
		return {"ok": false, "text": "Falta qué buscar.", "source": ""}
	var prompt := "Busca en internet y resume en español, en 4 a 6 frases, con datos concretos y fechas (hoy es %s). Usa SOLO lo que dicen las páginas que encuentres, sin suponer ni agregar detalles: %s" % [
		Time.get_date_string_from_system(), query]
	if AIProviders.current_id() == "gemini" and not AIProviders.api_key("gemini").is_empty():
		var gemini := await _gemini_search(prompt)
		if gemini["ok"]:
			return gemini
	if not AIProviders.api_key("groq").is_empty():
		var groq := await _groq_search(prompt)
		if groq["ok"]:
			return groq
	var ddg := await _duckduckgo(query)
	if ddg["ok"]:
		return ddg
	return await _wikipedia(query)


## Búsqueda de Google integrada en Gemini (API nativa, no la de OpenAI).
func _gemini_search(prompt: String) -> Dictionary:
	var model := AIProviders.model() if AIProviders.current_id() == "gemini" else "gemini-3.5-flash-lite"
	var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent" % model
	var body := {"contents": [{"parts": [{"text": prompt}]}], "tools": [{"google_search": {}}]}
	var response := await _post_json(url, body, PackedStringArray(["x-goog-api-key: " + AIProviders.api_key("gemini")]))
	if not response["ok"] or not (response["data"] is Dictionary):
		return {"ok": false, "text": "", "source": ""}
	var candidates: Array = response["data"].get("candidates", [])
	if candidates.is_empty():
		return {"ok": false, "text": "", "source": ""}
	var text := ""
	for part in candidates[0].get("content", {}).get("parts", []):
		text += str(part.get("text", ""))
	return {"ok": not text.strip_edges().is_empty(), "text": _clean(text), "source": "Google (Gemini)"}


## Búsqueda web integrada de Groq (herramienta "browser_search" de GPT-OSS).
## Primero el modelo grande (el chico tiende a adornar los datos); si está
## saturado por el límite por minuto, el chico.
func _groq_search(prompt: String) -> Dictionary:
	for model in ["openai/gpt-oss-120b", "openai/gpt-oss-20b"]:
		var body := {
			"model": model,
			"messages": [{"role": "user", "content": prompt}],
			"tools": [{"type": "browser_search"}],
			"reasoning_effort": "low",
		}
		var response := await _post_json("https://api.groq.com/openai/v1/chat/completions", body,
			PackedStringArray(["Authorization: Bearer " + AIProviders.api_key("groq")]))
		if response["ok"] and response["data"] is Dictionary:
			var choices: Array = response["data"].get("choices", [])
			if not choices.is_empty():
				var text := str(choices[0].get("message", {}).get("content", ""))
				if not text.strip_edges().is_empty():
					return {"ok": true, "text": _clean(text), "source": "web (Groq)"}
	return {"ok": false, "text": "", "source": ""}


func _duckduckgo(query: String) -> Dictionary:
	var response := await _get_json("https://api.duckduckgo.com/?format=json&no_html=1&skip_disambig=1&q=" + query.uri_encode())
	if not response["ok"] or not (response["data"] is Dictionary):
		return {"ok": false, "text": "", "source": ""}
	var data: Dictionary = response["data"]
	var text := str(data.get("AbstractText", ""))
	if text.is_empty():
		for topic in data.get("RelatedTopics", []).slice(0, 3):
			if topic is Dictionary and topic.has("Text"):
				text += str(topic["Text"]) + "\n"
	return {"ok": not text.strip_edges().is_empty(), "text": text.strip_edges().left(1400), "source": "DuckDuckGo"}


## Quita las marcas de cita (【1†L8】) y lo deja corto.
static func _clean(text: String) -> String:
	var regex := RegEx.create_from_string("【[^】]*】|\\[\\d+\\]")
	return regex.sub(text, "", true).strip_edges().left(1600)


# --- HTTP ---------------------------------------------------------------------

func _get_json(url: String) -> Dictionary:
	return await _request(url, HTTPClient.METHOD_GET, "", PackedStringArray())


func _post_json(url: String, body: Dictionary, headers: PackedStringArray) -> Dictionary:
	headers.append("Content-Type: application/json")
	return await _request(url, HTTPClient.METHOD_POST, JSON.stringify(body), headers)


func _request(url: String, method: int, body: String, headers: PackedStringArray) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 45.0
	add_child(http)
	headers.append("User-Agent: micIA/3.5 (app de compañía)")
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		return {"ok": false, "data": null}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	if result[0] != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return {"ok": false, "data": null, "code": code}
	return {"ok": true, "data": JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())}
