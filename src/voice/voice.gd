class_name Voice
extends Node
## Voz usando el texto a voz (TTS) del sistema operativo.
##
##  - Android: usa el motor de voz del teléfono (Google TTS, etc.).
##  - Linux: necesita speech-dispatcher instalado. Si no hay voces, la app
##    sigue funcionando: se "simula" el tiempo de habla para que el avatar
##    mueva la boca igual.
##
## Emite speaking_started / speaking_finished para sincronizar la boca.

signal speaking_started
signal speaking_finished

const PREFERRED_LANGUAGE := "es"
## Si no hay TTS, cuánto "dura" cada carácter al simular el habla.
const SIMULATED_SECONDS_PER_CHAR := 0.055

var _voice_id := ""
var _utterance_counter := 0
var _current_utterance := -1
var _simulation_timer: Timer


func _ready() -> void:
	_simulation_timer = Timer.new()
	_simulation_timer.one_shot = true
	_simulation_timer.timeout.connect(_finish)
	add_child(_simulation_timer)
	_voice_id = _pick_voice()
	if not _voice_id.is_empty():
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED, _on_utterance_started)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_utterance_ended)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_utterance_ended)


func has_real_voice() -> bool:
	return not _voice_id.is_empty()


func speak(text: String) -> void:
	stop()
	if text.strip_edges().is_empty():
		return
	if not bool(Settings.get_value("voice_enabled")) or _voice_id.is_empty():
		_simulate(text)
		return
	_utterance_counter += 1
	_current_utterance = _utterance_counter
	DisplayServer.tts_speak(
		text, _voice_id, 100,
		float(Settings.get_value("voice_pitch")),
		float(Settings.get_value("voice_rate")),
		_current_utterance
	)


func stop() -> void:
	_simulation_timer.stop()
	if not _voice_id.is_empty() and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	if _current_utterance != -1:
		_finish()


func _simulate(text: String) -> void:
	_current_utterance = 0
	speaking_started.emit()
	_simulation_timer.start(clampf(text.length() * SIMULATED_SECONDS_PER_CHAR, 0.6, 12.0))


func _finish() -> void:
	_current_utterance = -1
	speaking_finished.emit()


func _on_utterance_started(utterance_id: int) -> void:
	if utterance_id == _current_utterance:
		speaking_started.emit()


func _on_utterance_ended(utterance_id: int) -> void:
	if utterance_id == _current_utterance:
		_finish()


## Busca una voz en español; si no hay, cualquier voz disponible.
static func _pick_voice() -> String:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return ""
	var spanish := DisplayServer.tts_get_voices_for_language(PREFERRED_LANGUAGE)
	if not spanish.is_empty():
		return spanish[0]
	var voices := DisplayServer.tts_get_voices()
	if not voices.is_empty():
		return str(voices[0].get("id", ""))
	return ""
