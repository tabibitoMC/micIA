class_name Voice
extends Node
## Voz de ella.
##
##  1. Voz neuronal (natural): MeloTTS en Cloudflare Workers AI, si hay
##     Account ID y token de Cloudflare en Ajustes. Gasta muy poca cuota.
##     La boca se mueve según el volumen real del audio.
##  2. Si no hay Cloudflare o falla: el texto a voz del sistema (Android usa
##     el motor del teléfono; suena más robótico).
##  3. Si tampoco hay eso: se "simula" el tiempo de habla para mover la boca.
##
## Emite speaking_started / speaking_finished y level_changed (0..1, cuánto
## abrir la boca) para sincronizar al avatar.

signal speaking_started
signal speaking_finished
signal level_changed(level: float)

const PREFERRED_LANGUAGE := "es"
const NEURAL_MODEL := "@cf/myshell-ai/melotts"
## Si no hay TTS, cuánto "dura" cada carácter al simular el habla.
const SIMULATED_SECONDS_PER_CHAR := 0.055
## Muestras por segundo de la envoltura de volumen (para la boca).
const ENVELOPE_RATE := 60.0
const VOICE_BUS := "Voz"

var _voice_id := ""
var _utterance_counter := 0
var _current_utterance := -1
var _simulation_timer: Timer
var _web: WebRequest
var _player: AudioStreamPlayer
var _pitch_effect: AudioEffectPitchShift
var _envelope := PackedFloat32Array()
var _request_id := 0
var _neural_failed_at := -1000.0


func _ready() -> void:
	_simulation_timer = Timer.new()
	_simulation_timer.one_shot = true
	_simulation_timer.timeout.connect(_finish)
	add_child(_simulation_timer)
	_web = WebRequest.new()
	add_child(_web)
	_setup_audio()
	_voice_id = _pick_voice()
	if not _voice_id.is_empty():
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED, _on_utterance_started)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_utterance_ended)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_utterance_ended)


func has_real_voice() -> bool:
	return _neural_configured() or not _voice_id.is_empty()


func speak(text: String) -> void:
	stop()
	var clean := _clean(text)
	if clean.is_empty():
		return
	if not bool(Settings.get_value("voice_enabled")):
		_simulate(clean)
		return
	# Si la voz neuronal falló hace poco, no insistir en cada mensaje.
	if _neural_configured() and Time.get_ticks_msec() / 1000.0 - _neural_failed_at > 120.0:
		_speak_neural(clean)
	elif not _voice_id.is_empty():
		_speak_system(clean)
	else:
		_simulate(clean)


func stop() -> void:
	_request_id += 1
	_simulation_timer.stop()
	if _player.playing:
		_player.stop()
	if not _voice_id.is_empty() and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	if _current_utterance != -1:
		_finish()


func _process(_delta: float) -> void:
	if not _player.playing or _envelope.is_empty():
		return
	var index := int(_player.get_playback_position() * ENVELOPE_RATE)
	level_changed.emit(_envelope[clampi(index, 0, _envelope.size() - 1)])


# --- Voz neuronal (Cloudflare) -------------------------------------------------------

func _neural_configured() -> bool:
	return not str(Settings.get_value("cloudflare_account_id")).strip_edges().is_empty() \
		and not str(Settings.get_value("cloudflare_api_token")).strip_edges().is_empty()


func _speak_neural(text: String) -> void:
	var my_request := _request_id
	var url := "https://api.cloudflare.com/client/v4/accounts/%s/ai/run/%s" % [
		str(Settings.get_value("cloudflare_account_id")).strip_edges(), NEURAL_MODEL]
	var headers := PackedStringArray(["Authorization: Bearer " + str(Settings.get_value("cloudflare_api_token")).strip_edges()])
	var response := await _web.post_json(url, {"prompt": text, "lang": PREFERRED_LANGUAGE}, headers)
	if my_request != _request_id:
		return  # Mientras tanto llegó otro mensaje o se canceló.
	var audio := ""
	if response["ok"] and typeof(response["data"]) == TYPE_DICTIONARY:
		var result: Variant = response["data"].get("result", {})
		if typeof(result) == TYPE_DICTIONARY:
			audio = str(result.get("audio", ""))
	var stream: AudioStream = null
	if not audio.is_empty():
		stream = _decode(Marshalls.base64_to_raw(audio))
	if stream == null:
		push_warning("Voz neuronal no disponible: %s" % response.get("error", "audio vacío"))
		_neural_failed_at = Time.get_ticks_msec() / 1000.0
		if not _voice_id.is_empty():
			_speak_system(text)
		else:
			_simulate(text)
		return
	_apply_voice_settings()
	_player.stream = stream
	_current_utterance = 0
	_player.play()
	speaking_started.emit()


## MeloTTS devuelve WAV (a veces MP3). También calcula la envoltura de volumen.
func _decode(bytes: PackedByteArray) -> AudioStream:
	if bytes.size() < 64:
		return null
	if bytes.slice(0, 4).get_string_from_ascii() == "RIFF":
		var wav := AudioStreamWAV.load_from_buffer(bytes)
		if wav:
			_envelope = _wav_envelope(bytes)
		return wav
	var mp3 := AudioStreamMP3.load_from_buffer(bytes)
	if mp3:
		_envelope = PackedFloat32Array()
	return mp3


## Volumen por ventanas de 1/60 s, normalizado a 0..1, para abrir la boca.
func _wav_envelope(bytes: PackedByteArray) -> PackedFloat32Array:
	var envelope := PackedFloat32Array()
	# Busca el bloque "data" del WAV (PCM 16 bits).
	var pos := 12
	var data_start := -1
	var data_size := 0
	var channels := 1
	var rate := 44100
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if id == "fmt ":
			channels = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
		elif id == "data":
			data_start = pos + 8
			data_size = mini(size, bytes.size() - data_start)
			break
		pos += 8 + size + (size % 2)
	if data_start < 0 or rate <= 0:
		return envelope
	var frame_bytes := 2 * channels
	var window := int(rate / ENVELOPE_RATE)
	var frames := data_size / frame_bytes
	var peak := 0.0001
	var step := maxi(1, window / 64)
	var start := 0
	while start < frames:
		var total := 0.0
		var count := 0
		var end := mini(start + window, frames)
		var i := start
		while i < end:
			var sample := bytes.decode_s16(data_start + i * frame_bytes) / 32768.0
			total += sample * sample
			count += 1
			i += step
		var rms := sqrt(total / maxf(1.0, count))
		envelope.append(rms)
		peak = maxf(peak, rms)
		start += window
	# Normaliza y aplica una curva para que la boca se abra con naturalidad.
	for j in envelope.size():
		envelope[j] = clampf(pow(envelope[j] / (peak * 0.7), 0.7), 0.0, 1.0)
	return envelope


## Velocidad y tono de Ajustes: la velocidad cambia el ritmo del audio y el
## efecto de tono la compensa, así se pueden ajustar por separado.
func _apply_voice_settings() -> void:
	var rate := clampf(float(Settings.get_value("voice_rate")), 0.5, 2.0)
	var pitch := clampf(float(Settings.get_value("voice_pitch")), 0.5, 2.0)
	# El tono del sistema por defecto es 1.2; en la voz neuronal eso sería
	# demasiado agudo, así que se suaviza a la mitad.
	var neural_pitch := 1.0 + (pitch - 1.0) * 0.5
	_player.pitch_scale = rate
	_pitch_effect.pitch_scale = clampf(neural_pitch / rate, 0.5, 2.0)


func _setup_audio() -> void:
	var bus := AudioServer.get_bus_index(VOICE_BUS)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, VOICE_BUS)
		_pitch_effect = AudioEffectPitchShift.new()
		AudioServer.add_bus_effect(bus, _pitch_effect)
	else:
		_pitch_effect = AudioServer.get_bus_effect(bus, 0) as AudioEffectPitchShift
	_player = AudioStreamPlayer.new()
	_player.bus = VOICE_BUS
	_player.finished.connect(func():
		level_changed.emit(0.0)
		_finish())
	add_child(_player)


# --- Voz del sistema -------------------------------------------------------------------

func _speak_system(text: String) -> void:
	_utterance_counter += 1
	_current_utterance = _utterance_counter
	DisplayServer.tts_speak(
		text, _voice_id, 100,
		float(Settings.get_value("voice_pitch")),
		float(Settings.get_value("voice_rate")),
		_current_utterance
	)


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


## Quita lo que suena mal leído en voz alta (asteriscos, emojis, "~").
static func _clean(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("[*_~#`>\\[\\]]|[\\x{1F000}-\\x{1FAFF}\\x{2600}-\\x{27BF}]")
	return regex.sub(text, "", true).strip_edges().left(600)


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
