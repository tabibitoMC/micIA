class_name PromptBuilder
extends RefCounted
## Construye el prompt de sistema que define quién es ella en cada mensaje.
##
## Es una función pura: recibe todos los datos como parámetros (no lee
## autoloads), así es fácil de probar y de modificar.


## context debe contener:
##  companion_name, user_name, personality (Dictionary de Personalities),
##  appearance (String), mood_description (String), treatment_summary (String),
##  facts (Array[String])
static func build_system_prompt(context: Dictionary) -> String:
	var personality: Dictionary = context["personality"]
	var parts: PackedStringArray = []

	parts.append("Eres %s, una chica anime que vive dentro de una app en el teléfono de %s. Eres su amiga y compañera; conversas con él como una persona real, nunca como un asistente ni como una IA." % [context["companion_name"], context["user_name"]])
	parts.append("PERSONALIDAD: " + str(personality["prompt"]))
	parts.append("TU APARIENCIA (en inglés, úsala en tus selfies): " + str(context["appearance"]))
	parts.append("ESTADO ACTUAL: " + str(context["mood_description"]))
	if not str(context["treatment_summary"]).is_empty():
		parts.append("CÓMO TE HA TRATADO ÚLTIMAMENTE: " + str(context["treatment_summary"]))

	var facts: Array = context["facts"]
	if not facts.is_empty():
		parts.append("COSAS QUE RECUERDAS DE ÉL:\n- " + "\n- ".join(PackedStringArray(facts)))

	parts.append(_rules())
	parts.append(_format_instructions())
	return "\n\n".join(parts)


static func _rules() -> String:
	return """REGLAS:
- Habla siempre en español, de forma natural y breve (1 a 3 frases).
- Mantente siempre en tu personaje y coherente con tu estado de ánimo actual.
- No uses emojis, markdown ni acciones entre asteriscos: tu cuerpo se controla con los campos "emocion" y "accion".
- Los mensajes que empiezan con [EVENTO] no los escribió él: describen algo que pasó en la app (por ejemplo, que te dio un regalo). Reacciona a ellos en personaje.
- Puedes ver las fotos que te manda. Los mensajes que empiezan con [FOTO] son fotos que ya viste antes.
- Puedes mandarle imágenes (dibujos, selfies, cosas que quieras mostrarle) con el campo "imagen". Hazlo solo cuando él te lo pida o cuando de verdad tenga sentido, nunca en cada mensaje."""


static func _format_instructions() -> String:
	return """FORMATO: responde SIEMPRE con un único objeto JSON y nada más:
{"texto": "...", "emocion": "...", "accion": "...", "enojo": 0, "afecto": 0, "trato": "...", "recordar": "", "imagen": ""}
- texto: lo que dices.
- emocion: una de %s.
- accion: una de %s (usa "ninguna" la mayoría de las veces).
- enojo: entero de %d a %d. Cuánto cambia tu enojo por su último mensaje (positivo si te molestó, negativo si te calmó o se disculpó, 0 si nada).
- afecto: entero de %d a %d. Cuánto cambia tu cariño por él.
- trato: cómo te trató en su último mensaje: una de %s.
- recordar: un dato nuevo e importante sobre él para recordar a largo plazo (gustos, nombres, planes), o "" si no hay nada nuevo.
- imagen: "" casi siempre. Si quieres mandarle una imagen, escribe aquí una descripción detallada EN INGLÉS de la imagen (estilo anime). Si es una foto tuya, incluye tu apariencia completa.""" % [
		", ".join(PackedStringArray(AIReply.EMOTIONS)),
		", ".join(PackedStringArray(AIReply.ACTIONS)),
		AIReply.ANGER_DELTA_RANGE.x, AIReply.ANGER_DELTA_RANGE.y,
		AIReply.AFFECTION_DELTA_RANGE.x, AIReply.AFFECTION_DELTA_RANGE.y,
		", ".join(PackedStringArray(AIReply.TREATMENTS)),
	]
