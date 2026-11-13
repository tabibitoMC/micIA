class_name Environments
extends RefCounted
## Catálogo de lugares de la casa. Cada lugar es una habitación 3D que
## Room3D construye con muebles de KayKit (CC0) y piezas simples.
##
## Coordenadas en metros: ella está en (0, 0, 0) mirando a la cámara (+Z).
## La pared del fondo está en z = BACK_Z. Los muebles se escalan con
## FURNITURE_SCALE porque KayKit viene más grande que un humano.
##
## props: [ruta, posición, giro Y en grados, escala extra (opcional)]
## spots: lugares con nombre (p. ej. "cama" para dormir).

const BACK_Z := -2.2
const SIDE_X := 2.8
const FURNITURE_SCALE := 0.6
const KITCHEN_SCALE := 0.72

const F := "res://assets/environment/furniture/"
const K := "res://assets/environment/kitchen/"

const DATA := {
	"dormitorio": {
		"label": "Dormitorio",
		"icon": "bed-double",
		"wall": Color("f2cfdd"),
		"wall_trim": Color("ffffff"),
		"floor": Color("c9a184"),
		"window": Vector3(0.9, 1.55, -2.19),
		"props": [
			[F + "bed_double_A.gltf", Vector3(-1.25, 0, -1.3), 0.0],
			[F + "pillow_A.gltf", Vector3(-1.55, 0.62, -1.95), 0.0],
			[F + "pillow_A.gltf", Vector3(-0.95, 0.62, -1.95), 0.0],
			[F + "cabinet_small_decorated.gltf", Vector3(0.3, 0, -1.95), 0.0],
			[F + "lamp_table.gltf", Vector3(0.3, 0.97, -1.95), 0.0, 0.6],
			[F + "lamp_standing.gltf", Vector3(2.0, 0, -1.8), 0.0],
			[F + "rug_oval_A.gltf", Vector3(0.2, 0.005, -0.3), 0.0],
			[F + "pictureframe_large_A.gltf", Vector3(-1.25, 1.6, -2.18), 0.0],
			[F + "pictureframe_small_A.gltf", Vector3(1.9, 1.45, -2.18), 0.0],
			[F + "cactus_small_B.gltf", Vector3(1.55, 0, -1.9), 0.0],
		],
		"spots": {"cama": Vector3(-1.25, 0.56, -1.2), "almohada": Vector3(-1.25, 0.72, -1.88)},
	},
	"sala": {
		"label": "Sala",
		"icon": "sofa",
		"wall": Color("ddd2f0"),
		"wall_trim": Color("ffffff"),
		"floor": Color("b98d6e"),
		"window": Vector3(-1.6, 1.55, -2.19),
		"props": [
			[F + "couch_pillows.gltf", Vector3(0.1, 0, -1.65), 0.0],
			[F + "table_low.gltf", Vector3(0.1, 0, -0.75), 0.0],
			[F + "book_set.gltf", Vector3(-0.1, 0.45, -0.75), 20.0, 0.7],
			[F + "armchair_pillows.gltf", Vector3(-2.0, 0, -0.9), 50.0],
			[F + "shelf_B_large_decorated.gltf", Vector3(1.6, 1.25, -2.15), 0.0],
			[F + "lamp_standing.gltf", Vector3(2.15, 0, -1.6), 0.0],
			[F + "rug_rectangle_stripes_A.gltf", Vector3(0.1, 0.005, -0.6), 0.0],
			[F + "cactus_medium_A.gltf", Vector3(-1.15, 0, -1.85), 0.0],
			[F + "pictureframe_medium.gltf", Vector3(0.1, 1.75, -2.18), 0.0],
		],
		"spots": {"sofa": Vector3(0.1, 0.45, -1.5)},
	},
	"cocina": {
		"label": "Cocina",
		"icon": "cooking-pot",
		"wall": Color("f6e6c2"),
		"wall_trim": Color("ffffff"),
		"floor": Color("d9d4cc"),
		"tiles": true,
		"window": Vector3(1.55, 1.75, -2.19),
		"props": [
			[K + "stove_multi.gltf", Vector3(-1.45, 0, -1.4), 0.0, KITCHEN_SCALE / FURNITURE_SCALE],
			[K + "kitchencounter_straight_A_decorated.gltf", Vector3(0.0, 0, -1.4), 0.0, KITCHEN_SCALE / FURNITURE_SCALE],
			[K + "kitchencounter_sink.gltf", Vector3(1.45, 0, -1.4), 0.0, KITCHEN_SCALE / FURNITURE_SCALE],
			[K + "kitchencabinet.gltf", Vector3(-0.7, 0.0, -2.2), 0.0, KITCHEN_SCALE / FURNITURE_SCALE],
			[K + "fridge_A.gltf", Vector3(-2.45, 0, -1.3), 90.0, KITCHEN_SCALE / FURNITURE_SCALE],
			[F + "chair_A_wood.gltf", Vector3(2.2, 0, -0.3), -90.0],
		],
		"spots": {},
	},
	"patio": {
		"label": "Patio",
		"icon": "tree-palm",
		"outdoor": true,
		"wall": Color("ffffff"),
		"wall_trim": Color("e6d5c3"),
		"floor": Color("8fc97a"),
		"pool": true,
		"props": [
			[F + "cactus_medium_A.gltf", Vector3(-2.2, 0, -1.6), 0.0, 1.4],
			[F + "cactus_small_B.gltf", Vector3(2.3, 0, -1.2), 0.0, 1.5],
			[F + "chair_B_wood.gltf", Vector3(1.9, 0, -0.4), -60.0],
			[F + "table_medium.gltf", Vector3(2.15, 0, 0.35), 0.0, 0.6],
		],
		"spots": {},
	},
}


static func ids() -> Array:
	return DATA.keys()


static func fetch(id: String) -> Dictionary:
	return DATA.get(id, DATA["dormitorio"])
