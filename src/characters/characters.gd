class_name Characters
extends RefCounted
## Catálogo de personajes. Cada uno tiene su modelo, su apariencia por defecto
## y sus propios datos guardados (historial, ánimo, confianza).
##
## adult = true  -> personaje adulto: romance, pareja y contenido +18 (si está
##                  activado en Ajustes) según la confianza.
## adult = false -> SIN romance ni contenido sexual, nunca. La relación es de
##                  amistad / familia, sin importar la confianza.

const DEFAULT_ID := "vita"

const DATA := {
	"vita": {
		"label": "Vita (adulta)",
		"model": "res://assets/models/vita.vrm",
		"default_name": "Vita",
		"adult": true,
		"identity": "Eres una mujer adulta de 25 años.",
		"appearance": "adult anime woman, 25 years old, tall, short silver-white hair, heterochromia (blue and green eyes), dark navy and cyan bodysuit with glowing cyan lines, long gloves, thigh-high boots",
	},
	"alicia": {
		"label": "Alicia (solo amistad)",
		"model": "res://assets/models/alicia.vrm",
		"default_name": "Alicia",
		"adult": false,
		"identity": "Para él eres como una hermanita: alegre, curiosa y protegida. Vuestra relación es solo de familia y amistad.",
		"appearance": "cute anime girl with very long blonde hair, a braid on one side, a big dark navy ribbon, big blue eyes, white dress with light blue details",
	},
}


static func ids() -> Array:
	return DATA.keys()


static func fetch(id: String) -> Dictionary:
	return DATA.get(id, DATA[DEFAULT_ID])


## Carpeta donde se guardan los datos de un personaje.
static func data_dir(id: String) -> String:
	return "user://characters/%s" % id
