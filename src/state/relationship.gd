extends Node
## Autoload "Relationship": la relación a largo plazo con él.
##
##  - trust (0-100): confianza. Sube despacio si la tratas bien y baja rápido
##    si la tratas mal. Decide qué tan íntima puede ser la conversación.
##  - resentment (0-100): rencor acumulado por malos tratos y ofensas. Frena
##    la confianza y cambia su actitud según su personalidad.
##  - partner: si ya son pareja (solo personaje adulto, confianza >= 90).
##  - Estados temporales (feliz, triste, enojada, dolida, distante, lasciva):
##    duran una cantidad de mensajes y cambian cómo responde. Es un sistema
##    universal: cualquier emoción fuerte puede dejarla en un estado.
##
## Picante (lo que la IA evalúa de TU mensaje): 0 nada, 1 coqueteo,
## 2 subido de tono, 3 explícito. Si pasa su límite actual, se ofende y
## reacciona según su personalidad (ver Personalities: offense_*).

signal changed
signal state_changed(state_id: String)
signal became_partner

const STATES := {
	"normal": {"label": "", "duration": 0, "negative": false,
		"prompt": ""},
	"feliz": {"label": "Feliz", "duration": 5, "negative": false,
		"prompt": "Estás de muy buen humor: más cariñosa, bromista y expresiva de lo normal."},
	"triste": {"label": "Triste", "duration": 5, "negative": true,
		"prompt": "Estás triste y desanimada: respuestas cortas, buscas consuelo."},
	"enojada": {"label": "Enojada", "duration": 6, "negative": true,
		"prompt": "Estás enojada con él: cortante, a la defensiva, le reclamas lo que hizo."},
	"dolida": {"label": "Dolida", "duration": 6, "negative": true,
		"prompt": "Te sentiste ofendida y herida: estás llorosa y en silencio; respondes casi solo con \"...\" o frases muy cortas."},
	"distante": {"label": "Distante", "duration": 6, "negative": true,
		"prompt": "Te ofendió: estás fría y distante, respondes con indiferencia y sin interés."},
	"lasciva": {"label": "Lasciva", "duration": 10, "negative": false,
		"prompt": "Llevan un rato hablando de forma sugerente y te contagiaste: estás excitada y muy coqueta, tomas la iniciativa con insinuaciones y propuestas atrevidas."},
}

## Niveles de confianza (mínimo, nombre).
const TRUST_LEVELS := [
	[0.0, "Desconocidos"],
	[20.0, "Conocidos"],
	[40.0, "Amigos"],
	[60.0, "Confianza"],
	[80.0, "Muy cercanos"],
	[90.0, "Íntimos"],
]
const PARTNER_TRUST := 90.0
## Puntos de picante acumulados para entrar en estado lascivo.
const LEWD_STREAK_FOR_STATE := 6.0

var trust := 10.0
var resentment := 0.0
var partner := false
var state := "normal"
var state_remaining := 0
var lewd_streak := 0.0

var SAVE_PATH: String:
	get: return Characters.data_dir(str(Settings.get_value("character"))) + "/relationship.json"


func _ready() -> void:
	reload()


func reload() -> void:
	trust = 10.0
	resentment = 0.0
	partner = false
	state = "normal"
	state_remaining = 0
	lewd_streak = 0.0
	var data: Dictionary = JsonStore.load_json(SAVE_PATH, {})
	trust = float(data.get("trust", trust))
	resentment = float(data.get("resentment", resentment))
	partner = bool(data.get("partner", partner)) and bool(Settings.character()["adult"])
	state = str(data.get("state", state)) if STATES.has(str(data.get("state", ""))) else "normal"
	state_remaining = int(data.get("state_remaining", 0))
	lewd_streak = float(data.get("lewd_streak", 0.0))
	changed.emit()


## Hasta qué nivel de picante acepta ahora (0-3).
func allowed_spice() -> int:
	if not bool(Settings.character()["adult"]):
		return 0
	var adult := bool(Settings.get_value("adult_content"))
	if partner or trust >= 85.0:
		return 3 if adult else 1
	if trust >= 60.0:
		return 2 if adult else 1
	if trust >= 35.0:
		return 1
	return 0


func trust_label() -> String:
	if partner:
		return "Pareja"
	var label: String = TRUST_LEVELS[0][1]
	for level in TRUST_LEVELS:
		if trust >= float(level[0]):
			label = level[1]
	if not bool(Settings.character()["adult"]) and trust >= 80.0:
		return "Familia"
	return label


func state_label() -> String:
	return str(STATES[state]["label"])


## Aplica la respuesta de la IA a la relación.
func apply_reply(reply: AIReply, personality: Dictionary) -> void:
	_tick_state()
	var allowed := allowed_spice()
	var offended := reply.spice > allowed

	# Confianza y rencor según el trato
	var gains := {"bueno": 1.2, "neutral": 0.4, "malo": -3.0, "abusivo": -8.0}
	var gain: float = gains.get(reply.treatment, 0.0)
	if gain > 0.0:
		gain *= clampf(1.0 - resentment / 150.0, 0.2, 1.0)
	trust += gain
	match reply.treatment:
		"bueno": resentment -= 0.5
		"malo": resentment += 3.0
		"abusivo": resentment += 8.0

	if offended:
		var excess := reply.spice - allowed
		trust -= 4.0 * excess
		resentment += 5.0 * excess
		lewd_streak = 0.0
		Mood.add_anger(float(personality.get("offense_anger", 15.0)) * excess)
		_set_state(str(personality.get("offense_state", "enojada")))
	else:
		if reply.spice >= 1:
			lewd_streak += reply.spice
			if state == "lasciva":
				state_remaining = int(STATES["lasciva"]["duration"])
			elif lewd_streak >= LEWD_STREAK_FOR_STATE and allowed >= 2 and not _is_negative():
				_set_state("lasciva")
		else:
			lewd_streak = maxf(0.0, lewd_streak - 1.0)

		# Estados universales por emociones fuertes
		if reply.anger_delta >= 10 or reply.treatment == "abusivo":
			_set_state("enojada" if reply.anger_delta >= 10 else "triste")
		elif reply.treatment == "malo" and state == "lasciva":
			_set_state("normal")
		elif reply.emotion == "triste" and reply.affection_delta <= -3:
			_set_state("triste")
		elif reply.affection_delta >= 5 and state == "normal":
			_set_state("feliz")

	if reply.accepts_partner and not partner and trust >= PARTNER_TRUST and bool(Settings.character()["adult"]):
		partner = true
		became_partner.emit()

	_clamp_and_save()


## Un regalo baja el rencor y la alegra un poco.
func on_gift(effectiveness: float) -> void:
	resentment -= 5.0 * effectiveness
	trust += 1.0 * effectiveness
	if not _is_negative() and state != "lasciva":
		_set_state("feliz")
	_clamp_and_save()


func reset() -> void:
	trust = 10.0
	resentment = 0.0
	partner = false
	lewd_streak = 0.0
	_set_state("normal")
	_clamp_and_save()


## Texto para el prompt de sistema.
func describe_for_prompt(personality: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Nivel de confianza: %s (%d/100)." % [trust_label(), int(trust)])
	lines.append("Cuanto más confianza, más cosas personales e íntimas le cuentas de ti; ahora compartes cosas acordes a \"%s\"." % trust_label())

	if not bool(Settings.character()["adult"]):
		lines.append("LÍMITE ABSOLUTO: tu relación con él es solo de familia y amistad. NUNCA aceptas romance, coqueteo ni nada sexual, sin importar la confianza. Si él lo intenta, te incomoda y lo rechazas (cuenta como picante por encima de tu límite).")
	else:
		match allowed_spice():
			0: lines.append("Todavía no tienes confianza para coqueteos ni temas sexuales.")
			1: lines.append("Aceptas coqueteos ligeros y bromas pícaras suaves, pero nada sexual.")
			2: lines.append("Aceptas bromas subidas de tono y conversaciones sensuales; también hablas de cosas íntimas.")
			3: lines.append("Confías en él al 100%: aceptas conversaciones sexuales explícitas entre adultos sin filtros si él quiere, y eres muy permisiva con él.")
		lines.append("Si su mensaje supera lo que aceptas ahora: " + str(personality.get("offense_text", "te ofendes y te enojas.")))
		if partner:
			lines.append("Ya son pareja: lo tratas como tu novio.")
		elif trust >= PARTNER_TRUST:
			lines.append("Si él te pide ser su pareja/novia, puedes aceptar (pon \"acepta_pareja\": true).")
		else:
			lines.append("Si te pide ser su pareja, todavía es muy pronto: lo rechazas según tu personalidad.")

	if resentment >= 50.0:
		lines.append("Le guardas mucho rencor por cómo te ha tratado: " + str(personality.get("resentment_style", "estás resentida.")))
	elif resentment >= 20.0:
		lines.append("Le guardas algo de rencor; te cuesta confiar del todo.")

	if state != "normal":
		lines.append("ESTADO TEMPORAL — %s: %s" % [state_label(), STATES[state]["prompt"]])
	return "\n".join(lines)


func _set_state(new_state: String) -> void:
	if not STATES.has(new_state):
		return
	state = new_state
	state_remaining = int(STATES[new_state]["duration"])
	state_changed.emit(state)


## Cada mensaje gasta un turno del estado actual.
func _tick_state() -> void:
	if state == "normal":
		return
	state_remaining -= 1
	if state_remaining <= 0:
		_set_state("normal")


func _is_negative() -> bool:
	return bool(STATES[state]["negative"])


func _clamp_and_save() -> void:
	trust = clampf(trust, 0.0, 100.0)
	resentment = clampf(resentment, 0.0, 100.0)
	JsonStore.save_json(SAVE_PATH, {
		"trust": trust,
		"resentment": resentment,
		"partner": partner,
		"state": state,
		"state_remaining": state_remaining,
		"lewd_streak": lewd_streak,
	})
	changed.emit()
