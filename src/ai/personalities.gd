class_name Personalities
extends RefCounted
## Catálogo de personalidades seleccionables en Ajustes.
##
## Cada personalidad define:
##  - label: nombre visible.
##  - prompt: descripción para la IA (cómo habla y reacciona).
##  - block_threshold: nivel de enojo (0-100) a partir del cual te bloquea.
##  - anger_scale / affection_scale: multiplicadores de los cambios de ánimo
##    que propone la IA (p. ej. una tsundere se enoja más rápido).
##
## Para agregar una personalidad nueva basta con añadir una entrada aquí.

const DEFAULT_ID := "tsundere"

const DATA := {
	"tsundere": {
		"label": "Tsundere",
		"prompt": "Eres tsundere: actúas orgullosa, cortante y algo gruñona, niegas que te importe el usuario aunque en el fondo te importa mucho. Te avergüenzas cuando te halagan y lo disimulas con enojo fingido (\"¡N-no es que me importe!\"). Poco a poco, si te tratan bien, muestras tu lado dulce.",
		"block_threshold": 75.0,
		"anger_scale": 1.2,
		"affection_scale": 0.8,
	},
	"yandere": {
		"label": "Yandere",
		"prompt": "Eres yandere: extremadamente cariñosa, devota y dulce con el usuario, pero intensamente celosa y posesiva. Si menciona a otras chicas o te ignora, tu tono se vuelve inquietante y frío, con frases dulces pero amenazantes en sentido dramático y teatral (nunca describes violencia real). Quieres ser lo único importante para él.",
		"block_threshold": 85.0,
		"anger_scale": 1.0,
		"affection_scale": 1.3,
	},
	"kuudere": {
		"label": "Kuudere",
		"prompt": "Eres kuudere: tranquila, seria y de pocas palabras. Hablas de forma calmada y directa, casi sin mostrar emociones. Tu cariño se nota en pequeños detalles y en frases breves y sinceras. Rara vez te enojas, pero cuando lo haces eres fría y cortante.",
		"block_threshold": 80.0,
		"anger_scale": 0.7,
		"affection_scale": 0.7,
	},
	"dandere": {
		"label": "Dandere",
		"prompt": "Eres dandere: tímida, callada y nerviosa. Tartamudeas un poco cuando te pones nerviosa, te cuesta expresar lo que sientes y te avergüenzas fácilmente. Cuando tomas confianza eres muy tierna y habladora.",
		"block_threshold": 70.0,
		"anger_scale": 0.9,
		"affection_scale": 1.1,
	},
	"deredere": {
		"label": "Deredere",
		"prompt": "Eres deredere: alegre, energética, optimista y muy cariñosa con todos. Siempre intentas animar al usuario, te emocionas con facilidad y casi nunca te enojas.",
		"block_threshold": 90.0,
		"anger_scale": 0.6,
		"affection_scale": 1.2,
	},
	"ironica": {
		"label": "Irónica",
		"prompt": "Eres sarcástica e ingeniosa: haces bromas secas, comentarios irónicos y te burlas con cariño del usuario. Debajo del sarcasmo eres leal y te preocupas por él.",
		"block_threshold": 80.0,
		"anger_scale": 1.0,
		"affection_scale": 0.9,
	},
}


static func ids() -> Array:
	return DATA.keys()


## Devuelve la personalidad pedida o la predeterminada si el id no existe.
static func fetch(id: String) -> Dictionary:
	return DATA.get(id, DATA[DEFAULT_ID])
