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
	## Proveedor de IA del chat: "groq" o "gemini" (ver AIProviders).
	"provider": "groq",
	"api_key": "",
	"gemini_api_key": "",
	## Que ella pueda abrir YouTube, poner alarmas, etc. (ver PhoneActions).
	"phone_actions": true,
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
	## Avatar con muchos más vértices (más suave). Si va lento, desactivarlo.
	"avatar_high_quality": true,
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
	# Al girar la pantalla o cambiar de tamaño, recalcular el tamaño de la UI.
	get_tree().root.size_changed.connect(apply_ui_scale)
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
	return not AIProviders.api_key().is_empty()


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


## Tamaño de la interfaz = el de Ajustes x uno automático según el equipo.
##
## La app mira el tamaño físico de la pantalla (pulgadas, con los DPI) para
## saber si es teléfono o tablet:
##  - teléfono (< 7"): botones grandes, fáciles de tocar con el pulgar.
##  - tablet (>= 7"): una medida física parecida (se sostiene más lejos, así
##    que un poco mayor); la tablet no se agiganta, gana espacio.
## Y nunca deja que la interfaz sea más ancha que la pantalla: el diseño
## necesita MIN_WIDTH_UNITS de ancho; si no cabe, se achica lo justo.
const PHONE_MM_PER_UNIT := 0.165
const TABLET_MM_PER_UNIT := 0.175
const TABLET_MIN_INCHES := 7.0
const MIN_WIDTH_UNITS := 400.0
const MIN_HEIGHT_UNITS := 560.0


func apply_ui_scale() -> void:
	var tree := get_tree()
	if tree and tree.root:
		tree.root.content_scale_factor = ui_factor()


## Factor final (el que se aplica a la ventana).
func ui_factor() -> float:
	var wanted := clampf(float(get_value("ui_scale")), 0.5, 2.5) * auto_ui_factor()
	return clampf(minf(wanted, fit_factor()), 0.4, 3.5)


## Máximo que cabe: con esto la interfaz mide justo MIN_WIDTH_UNITS de ancho
## (y MIN_HEIGHT_UNITS de alto, por si el teléfono está acostado).
func fit_factor() -> float:
	var window := Vector2(DisplayServer.window_get_size())
	var stretch := _stretch_scale(window)
	if stretch <= 0.0:
		return 1.0
	return minf(window.x / (MIN_WIDTH_UNITS * stretch), window.y / (MIN_HEIGHT_UNITS * stretch))


func auto_ui_factor() -> float:
	var dpi := _dpi()
	if dpi <= 0.0:
		return 1.0
	var window := Vector2(DisplayServer.window_get_size())
	var stretch := _stretch_scale(window)
	if stretch <= 0.0:
		return 1.0
	var mm := TABLET_MM_PER_UNIT if device_type() == "tablet" else PHONE_MM_PER_UNIT
	return clampf((mm * dpi / 25.4) / stretch, 0.5, 2.0)


## "telefono", "tablet" o "pc".
func device_type() -> String:
	if _dpi() <= 0.0:
		return "pc"
	return "tablet" if screen_inches() >= TABLET_MIN_INCHES else "telefono"


## Diagonal física de la pantalla, en pulgadas (0 si no se sabe).
func screen_inches() -> float:
	var dpi := _dpi()
	if dpi <= 0.0:
		return 0.0
	# En teléfonos y tablets la app ocupa toda la pantalla: la ventana mide lo
	# mismo que la pantalla (y en pantalla dividida, cuenta lo que se ve).
	return Vector2(DisplayServer.window_get_size()).length() / dpi


## DPI reales en teléfonos y tablets. En PC no se usan (0), salvo para
## pruebas con la variable de entorno MICIA_TEST_DPI.
func _dpi() -> float:
	var test := OS.get_environment("MICIA_TEST_DPI")
	if not test.is_empty():
		return float(test)
	if not OS.has_feature("mobile"):
		return 0.0
	return float(DisplayServer.screen_get_dpi())


## Escala que ya aplica Godot (modo "expand"): la menor de las dos.
static func _stretch_scale(window: Vector2) -> float:
	var base := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 480)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	if window.x <= 0.0 or window.y <= 0.0:
		return 0.0
	return minf(window.x / base.x, window.y / base.y)


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
