class_name Gifts
extends RefCounted
## Catálogo de regalos. Calman su enojo y suben su afecto.
##  - anger_relief: cuánto enojo quita.
##  - affection: cuánto afecto suma.

const DATA := {
	"flores": {"label": "Flores", "anger_relief": 30.0, "affection": 4.0},
	"chocolate": {"label": "Chocolate", "anger_relief": 40.0, "affection": 5.0},
	"carta": {"label": "Carta de disculpa", "anger_relief": 35.0, "affection": 6.0},
	"peluche": {"label": "Peluche", "anger_relief": 60.0, "affection": 8.0},
}


## Entradas añadidas por mods (ver ModApi).
static var extra := {}


static func register(id: String, data: Dictionary) -> void:
	extra[id] = data


static func ids() -> Array:
	return DATA.keys() + extra.keys()


static func fetch(id: String) -> Dictionary:
	if extra.has(id):
		return extra[id]
	return DATA.get(id, {})
