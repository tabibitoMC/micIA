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
		"personality": "tsundere",
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
	## Personaje original: ilustración generada con FLUX.1 [schnell] y
	## reescalada con Real-ESRGAN (ver assets/characters/mireya/LICENSE.txt).
	## Se anima con AvatarIllustrated; "rig" dice dónde está cada cosa en la
	## imagen (en píxeles).
	"mireya": {
		"label": "Mireya (vampira, adulta)",
		"illustration": "res://assets/characters/mireya/mireya.pic",
		"default_name": "Mireya",
		"personality": "coqueta",
		"voice_pitch": 0.9,
		"adult": true,
		"identity": "Eres una vampira noble, una mujer adulta de unos 30 años (en realidad tienes siglos, pero lo dices en broma). Elegante, segura de ti misma, juguetona y algo dramática; te encanta la noche, el vino tinto (dices que es \"casi\" sangre), la música clásica y las cosas bonitas. Hablas con calma y un humor pícaro, como una \"onee-san\" que lo mima y lo molesta a la vez. Vives con él dentro de su teléfono.",
		"appearance": "anime gothic vampire noblewoman, mature adult woman around 30, long black hair in a voluminous updo with golden hairpins, sharp crimson eyes, red lipstick, small fangs, pale skin, tall curvy figure, dusty rose satin camisole with black lace, long black high-waisted mermaid skirt, white fluffy fur stole, black choker, red nails",
		"outfits": [{"id": "original", "label": "Gótica"}],
		"rig": {
			"neck": Vector2(608, 850),
			"face": Vector2(600, 715),
			"face_radius": 175.0,
			"hair_line": 640.0,
			"top": 27.0,
			"feet": 3024.0,
			"eyes": [Vector2(519, 691), Vector2(684, 691)],
			"eye_half": [Vector2(41, 21), Vector2(38, 20)],
			"mouth": Vector2(600, 783),
			"mouth_width": 40.0,
			"cheeks": [Vector2(515, 752), Vector2(688, 752)],
			"skin": Color8(250, 214, 205),
			"lid_top": Color8(236, 184, 172),
			"lid_bottom": Color8(250, 182, 170),
			"lash": Color8(30, 16, 22),
			"lips": Color8(165, 28, 42),
			"chest_top": 1000.0,
			"chest_bottom": 1500.0,
			"skirt_top": 2000.0,
			"fur_box": Vector4(760, 1168, 1170, 2500),
		},
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


# --- Personajes creados por el usuario (CharacterCreator) -------------------

const CUSTOM_DIR := "user://custom_characters"


## Carga los personajes creados (llamado al iniciar, desde Settings).
static func load_custom() -> void:
	var dir := DirAccess.open(CUSTOM_DIR)
	if dir == null:
		return
	for id in dir.get_directories():
		var data: Variant = JsonStore.load_json(CUSTOM_DIR + "/" + id + "/data.json", {})
		if data is Dictionary and not (data as Dictionary).is_empty():
			register_custom(id, data)


## Convierte los datos guardados (data.json) en un personaje y su personalidad.
static func register_custom(id: String, data: Dictionary) -> void:
	var folder := CUSTOM_DIR + "/" + id
	var base: Dictionary = Personalities.fetch(str(data.get("personality_base", Personalities.DEFAULT_ID)))
	var personality := base.duplicate()
	personality["label"] = "%s (%s)" % [data.get("name", "Personaje"), base["label"]]
	var extra_text := str(data.get("personality_text", "")).strip_edges()
	if not extra_text.is_empty():
		personality["prompt"] = str(base["prompt"]) + " Además: " + extra_text
	personality["anger_scale"] = float(data.get("temper", 1.0))
	personality["affection_scale"] = float(data.get("affection", 1.0))
	personality["block_threshold"] = float(data.get("patience", 80.0))
	Personalities.register("custom_" + id, personality)

	var adult := bool(data.get("adult", true))
	var entry := {
		"label": "%s (creada por ti)" % data.get("name", "Personaje"),
		"default_name": str(data.get("name", "Personaje")),
		"personality": "custom_" + id,
		"voice_pitch": float(data.get("voice_pitch", 1.0)),
		"adult": adult,
		"identity": str(data.get("identity", "")) + ("" if adult else " Tu relación con él es solo de amistad."),
		"appearance": str(data.get("appearance", "")) if not str(data.get("appearance", "")).is_empty() else DATA["mireya"]["appearance"],
		"outfits": [{"id": "original", "label": "Original"}],
		"custom": true,
	}
	if data.has("illustration"):
		entry["illustration"] = folder + "/" + str(data["illustration"])
		entry["rig"] = rig_from_json(data.get("rig", {}))
		if data.has("outfits"):
			var outfits := []
			for i in data["outfits"].size():
				var outfit: Dictionary = data["outfits"][i]
				outfits.append({"id": "original" if i == 0 else "o%d" % i, "label": str(outfit["label"]),
					"illustration": folder + "/" + str(outfit["illustration"])})
			entry["outfits"] = outfits
	elif data.has("model"):
		entry["model"] = folder + "/" + str(data["model"])
	else:
		# Sin modelo propio: usa la ilustración de Mireya.
		entry["illustration"] = DATA["mireya"]["illustration"]
		entry["rig"] = DATA["mireya"]["rig"]
	register(id, entry)


## Borra un personaje creado (sus archivos y su memoria).
static func delete_custom(id: String) -> void:
	for folder in [CUSTOM_DIR + "/" + id, data_dir(id)]:
		var dir := DirAccess.open(folder)
		if dir:
			for file in dir.get_files():
				dir.remove(file)
			DirAccess.remove_absolute(folder)
	extra.erase(id)


## El rig tiene Vector2/Color/Vector4: en JSON van como listas.
static func rig_to_json(rig: Dictionary) -> Dictionary:
	var out := {}
	for key in rig:
		out[key] = _to_json(rig[key])
	return out


static func _to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_VECTOR4:
			return [value.x, value.y, value.z, value.w]
		TYPE_COLOR:
			return {"color": value.to_html()}
		TYPE_ARRAY:
			return (value as Array).map(_to_json)
	return value


static func rig_from_json(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		out[key] = _from_json(data[key])
	return out


static func _from_json(value: Variant) -> Variant:
	if value is Dictionary and value.has("color"):
		return Color(str(value["color"]))
	if value is Array:
		var list := value as Array
		if list.size() == 2 and (list[0] is float or list[0] is int) and (list[1] is float or list[1] is int):
			return Vector2(list[0], list[1])
		if list.size() == 4 and list.all(func(v): return v is float or v is int):
			return Vector4(list[0], list[1], list[2], list[3])
		return list.map(_from_json)
	return value


## Carpeta donde se guardan los datos de un personaje.
static func data_dir(id: String) -> String:
	return "user://characters/%s" % id
