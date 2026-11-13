extends Node
## Autoload "Memory": historial de la conversación y recuerdos a largo plazo.
## Todo se guarda en user:// y sobrevive entre sesiones.

signal cleared

const HISTORY_PATH := "user://history.json"
const FACTS_PATH := "user://facts.json"
const MAX_STORED_MESSAGES := 300
const MAX_FACTS := 40

## Tipos de entrada del historial.
const KIND_MESSAGE := "message"
const KIND_EVENT := "event"

## Cada entrada:
## {"role": "user"|"assistant", "content": lo que se envía a la IA,
##  "display": lo que se muestra en el chat, "kind": KIND_MESSAGE|KIND_EVENT}
var history: Array = []
## Datos sobre el usuario que la IA pidió recordar.
var facts: Array = []


func _ready() -> void:
	history = JsonStore.load_json(HISTORY_PATH, [])
	facts = JsonStore.load_json(FACTS_PATH, [])


func add_exchange(user_entry: Dictionary, assistant_entry: Dictionary) -> void:
	history.append(user_entry)
	history.append(assistant_entry)
	if history.size() > MAX_STORED_MESSAGES:
		history = history.slice(history.size() - MAX_STORED_MESSAGES)
	JsonStore.save_json(HISTORY_PATH, history)


func make_entry(role: String, content: String, display: String, kind := KIND_MESSAGE) -> Dictionary:
	return {"role": role, "content": content, "display": display, "kind": kind}


## Últimos `count` mensajes en el formato de la API. Siempre empieza con un
## mensaje del usuario (Mistral no acepta que el historial empiece por la IA).
func recent_for_api(count: int) -> Array:
	var start := maxi(0, history.size() - count)
	while start < history.size() and history[start].get("role") != "user":
		start += 1
	var out: Array = []
	for i in range(start, history.size()):
		out.append({"role": history[i]["role"], "content": history[i]["content"]})
	return out


func add_fact(fact: String) -> void:
	fact = fact.strip_edges()
	if fact.is_empty() or fact in facts:
		return
	facts.append(fact)
	while facts.size() > MAX_FACTS:
		facts.pop_front()
	JsonStore.save_json(FACTS_PATH, facts)


func clear_all() -> void:
	history.clear()
	facts.clear()
	JsonStore.save_json(HISTORY_PATH, history)
	JsonStore.save_json(FACTS_PATH, facts)
	cleared.emit()
