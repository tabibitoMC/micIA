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
##   - "model": usar otro .vrm del mismo personaje (p. ej. hecho en VRoid con
##     pijama o ropa casual). Si no se indica, usa el modelo del personaje.
##   - "cloth": color que tiñe la ropa (materiales *_CLOTH de VRoid).
##   - "hair": color que tiñe el pelo (materiales *_HAIR).

const DEFAULT_ID := "vita"

const DATA := {
	"vita": {
		"label": "Vita (adulta)",
		"model": "res://assets/models/vita.vrm",
		"default_name": "Vita",
		"adult": true,
		"identity": "Eres una mujer adulta de 25 años.",
		"appearance": "adult anime woman, 25 years old, tall, short silver-white hair, heterochromia (blue and green eyes), dark navy and cyan bodysuit with glowing cyan lines, long gloves, thigh-high boots",
		"outfits": [
			{"id": "original", "label": "Original"},
			{"id": "rosa", "label": "Rosa", "cloth": Color(1.0, 0.62, 0.8)},
			{"id": "noche", "label": "Noche", "cloth": Color(0.55, 0.45, 0.8)},
			{"id": "menta", "label": "Menta", "cloth": Color(0.6, 1.0, 0.82)},
			{"id": "dorado", "label": "Dorado", "cloth": Color(1.0, 0.85, 0.5), "hair": Color(1.0, 0.92, 0.75)},
		],
	},
	"alicia": {
		"label": "Alicia (solo amistad)",
		"model": "res://assets/models/alicia.vrm",
		"default_name": "Alicia",
		"adult": false,
		"identity": "Para él eres como una hermanita: alegre, curiosa y protegida. Vuestra relación es solo de familia y amistad.",
		"appearance": "cute anime girl with very long blonde hair, a braid on one side, a big dark navy ribbon, big blue eyes, white dress with light blue details",
		"outfits": [
			{"id": "original", "label": "Original"},
			{"id": "rosa", "label": "Rosa", "cloth": Color(1.0, 0.75, 0.85)},
			{"id": "lavanda", "label": "Lavanda", "cloth": Color(0.8, 0.75, 1.0)},
			{"id": "menta", "label": "Menta", "cloth": Color(0.75, 1.0, 0.88)},
		],
	},
}


## Conjunto por id (o el primero si no existe).
static func outfit(character_id: String, outfit_id: String) -> Dictionary:
	var outfits: Array = fetch(character_id).get("outfits", [{"id": "original", "label": "Original"}])
	for entry in outfits:
		if entry["id"] == outfit_id:
			return entry
	return outfits[0]


static func ids() -> Array:
	return DATA.keys()


static func fetch(id: String) -> Dictionary:
	return DATA.get(id, DATA[DEFAULT_ID])


## Carpeta donde se guardan los datos de un personaje.
static func data_dir(id: String) -> String:
	return "user://characters/%s" % id
