extends Node
## Autoload "Settings": ajustes del usuario (API key, personalidad, voz, escala...).
##
## Se guardan en user://settings.cfg y se editan desde la pantalla de Ajustes.
## En PC, para desarrollo, también se puede crear res://config.json (está en
## .gitignore) con las mismas claves; sirve como valor inicial.

signal changed

const SAVE_PATH := "user://settings.cfg"
const DEV_CONFIG_PATH := "res://config.json"
const SECTION := "settings"

const DEFAULTS := {
	"api_key": "",
	"model": "openai/gpt-oss-120b",
	"character": "aka",
	"companion_name": "Aka",
	"user_name": "",
	"personality": "tsundere",
	## Instrucciones extra que tú escribes para ella (se añaden al prompt).
	"custom_prompt": "",
	"avatar_3d": true,
	"room_theme": "dia",
	## Lugar de la casa donde está ella (ver Environments).
	"location": "dormitorio",
	## Conjunto elegido por personaje: {"vita": "rosa", ...}
	"outfits": {},
	"voice_enabled": true,
	"voice_rate": 1.0,
	"voice_pitch": 1.2,
	"ui_scale": 1.0,
	## Contenido +18: solo afecta al personaje adulto. Apagado por defecto.
	"adult_content": false,
	## Imágenes gratis: Cloudflare Workers AI (opcional) y AI Horde.
	"cloudflare_account_id": "",
	"cloudflare_api_token": "",
	"horde_api_key": "",
	## Cómo es ella físicamente (se usa en sus selfies y para que se describa bien).
	"appearance": "anime fox girl, short orange hair with straight bangs, big fox ears, big fluffy orange tail, red eyes, a small red leaf on her head, white and red shrine maiden outfit with a big red bow, white thigh-high socks",
}

## Modelos de Mistral que se ofrecen en Ajustes.
const MODELS := ["mistral-small-latest", "mistral-medium-latest", "mistral-large-latest"]

var _values: Dictionary = {}


func _ready() -> void:
	_values = DEFAULTS.duplicate()
	_load_dev_config()
	_load_saved()
	apply_ui_scale()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Ajuste desconocido: %s" % key)
		return
	_values[key] = value


func character() -> Dictionary:
	return Characters.fetch(str(get_value("character")))


## ¿Se permite romance/+18 ahora? (personaje adulto y opción activada)
func adult_allowed() -> bool:
	return bool(character()["adult"]) and bool(get_value("adult_content"))


func current_outfit() -> Dictionary:
	var chosen: Dictionary = get_value("outfits") if typeof(get_value("outfits")) == TYPE_DICTIONARY else {}
	var character_id := str(get_value("character"))
	return Characters.outfit(character_id, str(chosen.get(character_id, "original")))


func set_outfit(outfit_id: String) -> void:
	var chosen: Dictionary = (get_value("outfits") as Dictionary).duplicate() if typeof(get_value("outfits")) == TYPE_DICTIONARY else {}
	chosen[str(get_value("character"))] = outfit_id
	set_value("outfits", chosen)


func has_api_key() -> bool:
	return not str(get_value("api_key")).strip_edges().is_empty()


## Nombre con el que ella llama al usuario (o "tú" si no se configuró).
func user_display_name() -> String:
	var user_name := str(get_value("user_name")).strip_edges()
	return user_name if not user_name.is_empty() else "el usuario"


func save() -> void:
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value(SECTION, key, _values[key])
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("No se pudieron guardar los ajustes (error %d)" % err)
	apply_ui_scale()
	changed.emit()


func apply_ui_scale() -> void:
	var tree := get_tree()
	if tree and tree.root:
		tree.root.content_scale_factor = clampf(float(get_value("ui_scale")), 0.5, 3.0)


func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in DEFAULTS:
		if cfg.has_section_key(SECTION, key):
			_values[key] = cfg.get_value(SECTION, key)


func _load_dev_config() -> void:
	var data: Variant = JsonStore.load_json(DEV_CONFIG_PATH, {})
	for key in data:
		if DEFAULTS.has(key):
			_values[key] = data[key]
