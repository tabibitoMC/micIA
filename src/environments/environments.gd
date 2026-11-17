class_name Environments
extends RefCounted
## Catálogo de lugares de la casa. RoomBackground dibuja cada uno.

const DATA := {
	"dormitorio": {"label": "Dormitorio", "icon": "bed-double"},
	"sala": {"label": "Sala", "icon": "sofa"},
	"cocina": {"label": "Cocina", "icon": "cooking-pot"},
	"patio": {"label": "Patio", "icon": "tree-palm"},
}


static func ids() -> Array:
	return DATA.keys()


static func fetch(id: String) -> Dictionary:
	return DATA.get(id, DATA["dormitorio"])
