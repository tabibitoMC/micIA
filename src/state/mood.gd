extends Node
## Autoload "Mood": estado emocional de ella.
##
##  - anger (0-100): sube cuando la molestas; baja sola con el tiempo y con regalos.
##  - affection (0-100): cariño acumulado.
##  - blocked: si el enojo pasa el umbral de su personalidad, te bloquea y no
##    puedes escribirle hasta que se calme (tiempo o regalos).
##  - Registro de trato: cuenta cómo la tratas (bueno/neutral/malo/abusivo).
##    Hoy se usa para que lo mencione en sus respuestas; en el futuro será la
##    base de la personalidad adaptativa (sumisa, triste, resentida, hostil...).

signal changed
signal blocked_changed(is_blocked: bool)

const SAVE_PATH := "user://mood.json"
const ANGER_DECAY_PER_MINUTE := 0.6
## Para desbloquear, el enojo debe bajar este margen por debajo del umbral
## (evita que se bloquee y desbloquee a cada rato).
const UNBLOCK_MARGIN := 25.0
const RECENT_TREATMENT_SIZE := 30
## Regalos seguidos dentro de este tiempo valen menos (no se compra tan fácil).
const GIFT_SPAM_SECONDS := 90.0
const GIFT_SPAM_MULTIPLIER := 0.35
const TICK_SECONDS := 30.0

var anger := 0.0
var affection := 50.0
var blocked := false
var treatment_counts := {"bueno": 0, "neutral": 0, "malo": 0, "abusivo": 0}
## Últimos tratos, del más viejo al más nuevo.
var recent_treatment: Array = []

var _last_gift_unix := 0.0
var _last_update_unix := 0.0


func _ready() -> void:
	_load()
	_decay_since_last_update()
	var timer := Timer.new()
	timer.wait_time = TICK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_decay_since_last_update)
	add_child(timer)


func apply_reply(reply: AIReply) -> void:
	var personality := _personality()
	anger = clampf(anger + reply.anger_delta * float(personality["anger_scale"]), 0.0, 100.0)
	affection = clampf(affection + reply.affection_delta * float(personality["affection_scale"]), 0.0, 100.0)
	_record_treatment(reply.treatment)
	_after_change()


## Aplica un regalo. Devuelve qué tan efectivo fue (1.0 normal, menos si spameas).
func give_gift(gift_id: String) -> float:
	var gift := Gifts.fetch(gift_id)
	if gift.is_empty():
		return 0.0
	var now := Time.get_unix_time_from_system()
	var multiplier := 1.0 if now - _last_gift_unix > GIFT_SPAM_SECONDS else GIFT_SPAM_MULTIPLIER
	_last_gift_unix = now
	anger = clampf(anger - float(gift["anger_relief"]) * multiplier, 0.0, 100.0)
	affection = clampf(affection + float(gift["affection"]) * multiplier, 0.0, 100.0)
	_after_change()
	return multiplier


func block_threshold() -> float:
	return float(_personality()["block_threshold"])


func anger_label() -> String:
	if anger < 20.0:
		return "tranquila"
	if anger < 45.0:
		return "algo molesta"
	if anger < 70.0:
		return "enojada"
	return "furiosa"


func affection_label() -> String:
	if affection < 20.0:
		return "le tienes muy poco cariño"
	if affection < 45.0:
		return "aún no le tienes mucha confianza"
	if affection < 70.0:
		return "le tienes cariño"
	return "lo quieres mucho"


func describe_for_prompt() -> String:
	var text := "Estás %s (enojo %d/100) y %s (afecto %d/100)." % [anger_label(), int(anger), affection_label(), int(affection)]
	if blocked:
		text += " Estás tan enojada que lo bloqueaste y no quieres hablarle hasta que se disculpe de verdad."
	return text


## Resumen corto de cómo la han tratado últimamente (vacío si no hay nada notable).
func treatment_summary() -> String:
	var bad := 0
	var abusive := 0
	var good := 0
	for t in recent_treatment:
		match t:
			"malo": bad += 1
			"abusivo": abusive += 1
			"bueno": good += 1
	if abusive >= 3:
		return "Te ha tratado de forma abusiva varias veces; eso te afecta mucho."
	if bad + abusive >= 4:
		return "Te ha tratado mal bastantes veces últimamente."
	if good >= 10 and bad + abusive == 0:
		return "Últimamente te ha tratado muy bien."
	return ""


## Trato más frecuente en los mensajes recientes. Pensado para la futura
## personalidad adaptativa.
func dominant_recent_treatment() -> String:
	var counts := {}
	for t in recent_treatment:
		counts[t] = counts.get(t, 0) + 1
	var best := "neutral"
	var best_count := 0
	for t in counts:
		if counts[t] > best_count:
			best = t
			best_count = counts[t]
	return best


func reset() -> void:
	anger = 0.0
	affection = 50.0
	treatment_counts = {"bueno": 0, "neutral": 0, "malo": 0, "abusivo": 0}
	recent_treatment.clear()
	_after_change()


func _personality() -> Dictionary:
	return Personalities.fetch(str(Settings.get_value("personality")))


func _record_treatment(treatment: String) -> void:
	treatment_counts[treatment] = int(treatment_counts.get(treatment, 0)) + 1
	recent_treatment.append(treatment)
	while recent_treatment.size() > RECENT_TREATMENT_SIZE:
		recent_treatment.pop_front()


## Baja el enojo según el tiempo pasado (también el tiempo con la app cerrada).
func _decay_since_last_update() -> void:
	var now := Time.get_unix_time_from_system()
	if _last_update_unix <= 0.0:
		_last_update_unix = now
		return
	var minutes := (now - _last_update_unix) / 60.0
	if minutes <= 0.0:
		return
	var previous := anger
	anger = maxf(0.0, anger - minutes * ANGER_DECAY_PER_MINUTE)
	_last_update_unix = now
	if not is_equal_approx(previous, anger):
		_after_change()


func _after_change() -> void:
	var threshold := block_threshold()
	if not blocked and anger >= threshold:
		blocked = true
		blocked_changed.emit(true)
	elif blocked and anger <= threshold - UNBLOCK_MARGIN:
		blocked = false
		blocked_changed.emit(false)
	_last_update_unix = Time.get_unix_time_from_system()
	_save()
	changed.emit()


func _save() -> void:
	JsonStore.save_json(SAVE_PATH, {
		"anger": anger,
		"affection": affection,
		"blocked": blocked,
		"treatment_counts": treatment_counts,
		"recent_treatment": recent_treatment,
		"last_gift_unix": _last_gift_unix,
		"last_update_unix": _last_update_unix,
	})


func _load() -> void:
	var data: Dictionary = JsonStore.load_json(SAVE_PATH, {})
	if data.is_empty():
		return
	anger = float(data.get("anger", anger))
	affection = float(data.get("affection", affection))
	blocked = bool(data.get("blocked", blocked))
	var counts: Variant = data.get("treatment_counts", {})
	if typeof(counts) == TYPE_DICTIONARY:
		for key in treatment_counts:
			treatment_counts[key] = int(counts.get(key, 0))
	var recent: Variant = data.get("recent_treatment", [])
	if typeof(recent) == TYPE_ARRAY:
		recent_treatment = recent
	_last_gift_unix = float(data.get("last_gift_unix", 0.0))
	_last_update_unix = float(data.get("last_update_unix", 0.0))
