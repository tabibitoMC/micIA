class_name Characters
extends RefCounted
## Catálogo de personajes. Cada uno tiene su modelo, su apariencia por defecto
## y sus propios datos guardados (historial, ánimo, confianza).
##
## adult = true  -> personaje adulto: romance, pareja y contenido +18 (si está
##                  activado en Ajustes) según la confianza.
## adult = false -> SIN romance ni contenido sexual, nunca. La relación es de
##                  amistad / familia, sin importar la confianza.
##
## outfits: conjuntos de ropa. Cada uno puede:
##   - "model": usar otro .puppet del mismo personaje (otra ropa dibujada).
##   - "cloth": color hacia el que gira el tono de la ropa.

const DEFAULT_ID := "aka"

const DATA := {
	"aka": {
		"label": "Aka (zorrita, solo amistad)",
		"model": "res://assets/puppets/aka.puppet",
		"default_name": "Aka",
		"adult": false,
		"identity": "Eres una chica zorro (kitsune) alegre y curiosa. Para él eres una amiga cercana; vuestra relación es solo de amistad.",
		"appearance": "anime fox girl, short orange hair with straight bangs, big fox ears, big fluffy orange tail, red eyes, a small red leaf on her head, white and red shrine maiden outfit with a big red bow, white thigh-high socks",
		"outfits": [
			{"id": "original", "label": "Original"},
			{"id": "azul", "label": "Azul", "cloth": Color(0.3, 0.5, 1.0)},
			{"id": "morado", "label": "Morado", "cloth": Color(0.65, 0.35, 1.0)},
			{"id": "verde", "label": "Verde", "cloth": Color(0.3, 0.9, 0.5)},
			{"id": "rosa", "label": "Rosa", "cloth": Color(1.0, 0.35, 0.75)},
		],
	},
}


## Personajes y conjuntos añadidos por mods (ver ModApi).
static var extra := {}
static var extra_outfits := {}


static func register(id: String, data: Dictionary) -> void:
	extra[id] = data


static func register_outfit(character_id: String, outfit: Dictionary) -> void:
	if not extra_outfits.has(character_id):
		extra_outfits[character_id] = []
	extra_outfits[character_id].append(outfit)


## Conjuntos del personaje (los suyos + los de mods).
static func outfits(character_id: String) -> Array:
	var list: Array = fetch(character_id).get("outfits", [{"id": "original", "label": "Original"}]).duplicate()
	list.append_array(extra_outfits.get(character_id, []))
	return list


## Conjunto por id (o el primero si no existe).
static func outfit(character_id: String, outfit_id: String) -> Dictionary:
	var outfits: Array = outfits(character_id)
	for entry in outfits:
		if entry["id"] == outfit_id:
			return entry
	return outfits[0]


static func ids() -> Array:
	return DATA.keys() + extra.keys()


static func fetch(id: String) -> Dictionary:
	if extra.has(id):
		return extra[id]
	return DATA.get(id, DATA[DEFAULT_ID])


## Carpeta donde se guardan los datos de un personaje.
static func data_dir(id: String) -> String:
	return "user://characters/%s" % id
