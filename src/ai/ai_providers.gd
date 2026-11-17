class_name AIProviders
extends RefCounted
## Proveedores de IA para el chat. Los dos hablan el formato de OpenAI
## (/chat/completions), así que el resto de la app no cambia.
##
##  - groq: rapidísimo, 1.000 mensajes al día gratis (console.groq.com).
##  - gemini: Google AI Studio; modelos Flash gratis, ven fotos muy bien
##    (aistudio.google.com/apikey). En el plan gratis Google puede usar lo
##    que le mandas para mejorar sus productos.
##
## Para agregar otro proveedor compatible con OpenAI basta con una entrada.

const DEFAULT_ID := "groq"

const DATA := {
	"groq": {
		"label": "Groq",
		"base_url": "https://api.groq.com/openai/v1",
		"key_setting": "api_key",
		"console": "console.groq.com → API Keys",
		"key_url": "https://console.groq.com/keys",
		"models": ["openai/gpt-oss-120b", "qwen/qwen3.8-27b", "openai/gpt-oss-20b"],
		## Único modelo gratuito de Groq que acepta imágenes.
		"vision": "qwen/qwen3.8-27b",
		"penalties": true,
		"extra": {},
	},
	"gemini": {
		"label": "Gemini (Google)",
		"base_url": "https://generativelanguage.googleapis.com/v1beta/openai",
		"key_setting": "gemini_api_key",
		"console": "aistudio.google.com/apikey",
		"key_url": "https://aistudio.google.com/apikey",
		"models": ["gemini-3.8-flash", "gemini-3.6-flash", "gemini-3.5-flash-lite"],
		## Todos los Gemini ven imágenes: se usa el mismo modelo.
		"vision": "",
		"penalties": false,
		## Piensa poco antes de responder: más rápido para charlar.
		"extra": {"reasoning_effort": "low"},
	},
}


static func ids() -> Array:
	return DATA.keys()


static func fetch(id: String) -> Dictionary:
	return DATA.get(id, DATA[DEFAULT_ID])


static func current_id() -> String:
	var id := str(Settings.get_value("provider"))
	return id if DATA.has(id) else DEFAULT_ID


static func current() -> Dictionary:
	return fetch(current_id())


static func api_key(id := "") -> String:
	var provider := fetch(id if not id.is_empty() else current_id())
	return str(Settings.get_value(provider["key_setting"])).strip_edges()


## El modelo elegido en Ajustes si es de este proveedor; si no, el primero.
static func model() -> String:
	var provider := current()
	var chosen := str(Settings.get_value("model"))
	return chosen if chosen in provider["models"] else str(provider["models"][0])


## Cómo se llama el proveedor (para mensajes de error).
static func label() -> String:
	return str(current()["label"])
