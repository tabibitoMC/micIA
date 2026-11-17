class_name AIReply
extends RefCounted
## Respuesta estructurada de la IA.
##
## La IA siempre contesta con un JSON así (claves en español porque el prompt
## está en español):
## {"texto": "...", "emocion": "feliz", "accion": "saludar",
##  "enojo": 0, "afecto": 2, "trato": "bueno", "recordar": "", "imagen": ""}
##
## Esta clase lo valida: cualquier valor fuera de lo permitido se reemplaza
## por uno seguro, para que un error de la IA nunca rompa la app.

const EMOTIONS := ["neutral", "feliz", "triste", "enojada", "sorprendida", "avergonzada", "pensativa", "coqueta"]
const ACTIONS := ["ninguna", "saludar", "asentir", "negar", "cruzar_brazos", "saltar", "celebrar", "abrazar", "mirar_otro_lado", "golpear", "llorar"]
const TREATMENTS := ["bueno", "neutral", "malo", "abusivo"]
## Cosas que ella puede hacer con la interfaz (ver InterfaceActions).
const INTERFACE_ACTIONS := ["ninguna", "pedir_regalo", "fondo_dia", "fondo_atardecer", "fondo_noche", "pasear",
	"ir_dormitorio", "ir_sala", "ir_cocina", "ir_patio", "dormir"]

## Límites de cuánto puede cambiar el ánimo en un solo mensaje.
const ANGER_DELTA_RANGE := Vector2i(-15, 25)
const AFFECTION_DELTA_RANGE := Vector2i(-10, 10)

var text := ""
var emotion := "neutral"
var action := "ninguna"
var anger_delta := 0
var affection_delta := 0
var treatment := "neutral"
var remember := ""
## Si no está vacío, ella quiere mandarte una imagen: descripción en inglés.
var image_prompt := ""
var interface_action := "ninguna"
## Qué tan picante fue el último mensaje de él: 0 nada, 1 coqueteo,
## 2 subido de tono, 3 explícito.
var spice := 0
## Ella acepta ser su pareja en esta respuesta.
var accepts_partner := false
## Algo que hace en el teléfono (ver PhoneActions), o {} si nada.
var phone := {}


## Convierte el texto devuelto por la IA en un AIReply. Devuelve null si no
## se encontró ningún JSON utilizable.
static func from_text(raw: String) -> AIReply:
	var json_text := _extract_json_object(raw)
	if json_text.is_empty():
		return null
	var data: Variant = JSON.parse_string(json_text)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var reply := AIReply.new()
	reply.text = str(data.get("texto", "")).strip_edges()
	if reply.text.is_empty():
		return null
	reply.emotion = _pick(data.get("emocion"), EMOTIONS, "neutral")
	reply.action = _pick(data.get("accion"), ACTIONS, "ninguna")
	reply.treatment = _pick(data.get("trato"), TREATMENTS, "neutral")
	reply.anger_delta = _clamp_int(data.get("enojo", 0), ANGER_DELTA_RANGE)
	reply.affection_delta = _clamp_int(data.get("afecto", 0), AFFECTION_DELTA_RANGE)
	var remember_value: Variant = data.get("recordar", "")
	reply.remember = str(remember_value).strip_edges() if remember_value != null else ""
	reply.interface_action = _pick(data.get("interfaz"), INTERFACE_ACTIONS, "ninguna")
	reply.spice = _clamp_int(data.get("picante", 0), Vector2i(0, 3))
	reply.accepts_partner = data.get("acepta_pareja", false) == true
	var phone_value: Variant = data.get("telefono", {})
	if typeof(phone_value) == TYPE_DICTIONARY and str(phone_value.get("accion", "")) in PhoneActions.ACTIONS:
		reply.phone = phone_value
	var image_value: Variant = data.get("imagen", "")
	reply.image_prompt = str(image_value).strip_edges() if image_value != null else ""
	return reply


## JSON compacto para guardar en el historial (así la IA ve sus respuestas
## anteriores en el mismo formato y lo mantiene).
func to_json_string() -> String:
	return JSON.stringify({
		"texto": text,
		"emocion": emotion,
		"accion": action,
		"enojo": anger_delta,
		"afecto": affection_delta,
		"trato": treatment,
		"recordar": remember,
		"imagen": image_prompt,
		"interfaz": interface_action,
		"telefono": phone,
		"picante": spice,
		"acepta_pareja": accepts_partner,
	})


## Recorta el primer objeto {...} del texto, por si la IA añadió ``` u otro texto.
static func _extract_json_object(raw: String) -> String:
	var start := raw.find("{")
	var end := raw.rfind("}")
	if start == -1 or end <= start:
		return ""
	return raw.substr(start, end - start + 1)


static func _pick(value: Variant, allowed: Array, fallback: String) -> String:
	var s := str(value).strip_edges().to_lower() if value != null else ""
	return s if s in allowed else fallback


static func _clamp_int(value: Variant, limits: Vector2i) -> int:
	var n := 0
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		n = int(value)
	elif typeof(value) == TYPE_STRING and str(value).is_valid_float():
		n = int(float(value))
	return clampi(n, limits.x, limits.y)
