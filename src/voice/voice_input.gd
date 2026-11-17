class_name VoiceInput
extends Node
## Hablarle con la voz: graba el micrófono y lo convierte en texto.
##
##  - Groq: Whisper (whisper-large-v3-turbo, gratis) en /audio/transcriptions.
##  - Gemini: se le manda el audio (input_audio) y lo transcribe él.
## Si el proveedor elegido no tiene clave pero el otro sí, usa el otro.
##
## Necesita el permiso RECORD_AUDIO (export_presets.cfg) y
## audio/driver/enable_input=true (project.godot).

signal state_changed(listening: bool)
signal transcribed(text: String)
signal failed(message: String)

const BUS := "Microfono"
const MAX_SECONDS := 30.0
const WHISPER_MODEL := "whisper-large-v3-turbo"

var _player: AudioStreamPlayer
var _record: AudioEffectRecord
var _listening := false
var _started_at := 0.0


func _ready() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		# Se graba pero no se oye (si no, haría eco).
		AudioServer.set_bus_mute(index, true)
		_record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(index, _record)
	else:
		_record = AudioServer.get_bus_effect(index, 0) as AudioEffectRecord
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS
	add_child(_player)


func is_listening() -> bool:
	return _listening


## Empieza o termina de grabar (botón del micrófono).
func toggle() -> void:
	if _listening:
		stop()
	else:
		start()


func start() -> void:
	if _listening:
		return
	if OS.get_name() == "Android" and not "android.permission.RECORD_AUDIO" in OS.get_granted_permissions():
		OS.request_permission("android.permission.RECORD_AUDIO")
		failed.emit("Dale permiso al micrófono y vuelve a tocar el botón.")
		return
	_player.play()
	_record.set_recording_active(true)
	_listening = true
	_started_at = Time.get_ticks_msec() / 1000.0
	state_changed.emit(true)


func _process(_delta: float) -> void:
	if _listening and Time.get_ticks_msec() / 1000.0 - _started_at > MAX_SECONDS:
		stop()


func stop() -> void:
	if not _listening:
		return
	_listening = false
	_record.set_recording_active(false)
	var recording := _record.get_recording()
	_player.stop()
	state_changed.emit(false)
	if recording == null or recording.data.size() < 8000:
		failed.emit("No se escuchó nada. Toca el micrófono, habla y vuelve a tocarlo.")
		return
	var path := "user://voz.wav"
	recording.save_to_wav(path)
	var wav := FileAccess.get_file_as_bytes(path)
	var text := await transcribe(wav)
	if not text.is_empty():
		transcribed.emit(text)


## Convierte un WAV en texto con el proveedor que tenga clave.
func transcribe(wav: PackedByteArray) -> String:
	var use_gemini := AIProviders.current_id() == "gemini" and not AIProviders.api_key("gemini").is_empty()
	if not use_gemini and AIProviders.api_key("groq").is_empty() and not AIProviders.api_key("gemini").is_empty():
		use_gemini = true
	var result: Dictionary
	if use_gemini:
		result = await _gemini(wav)
	else:
		result = await _whisper(wav)
	if not result["ok"]:
		failed.emit("No pude entender el audio: " + str(result["error"]))
		return ""
	var text := str(result["text"]).strip_edges()
	if text.is_empty():
		failed.emit("No se entendió nada. Prueba hablando más cerca.")
	return text


func _whisper(wav: PackedByteArray) -> Dictionary:
	var key := AIProviders.api_key("groq")
	if key.is_empty():
		return {"ok": false, "error": "falta la clave de Groq"}
	var boundary := "----micia%d" % randi()
	var body := PackedByteArray()
	var fields := {"model": WHISPER_MODEL, "language": "es", "response_format": "json", "temperature": "0"}
	for name in fields:
		body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, name, fields[name]]).to_utf8_buffer())
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"voz.wav\"\r\nContent-Type: audio/wav\r\n\r\n" % boundary).to_utf8_buffer())
	body.append_array(wav)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	var response := await _post("https://api.groq.com/openai/v1/audio/transcriptions",
		PackedStringArray(["Authorization: Bearer " + key, "Content-Type: multipart/form-data; boundary=" + boundary]), body)
	if not response["ok"]:
		return response
	return {"ok": true, "text": str(response["data"].get("text", ""))}


func _gemini(wav: PackedByteArray) -> Dictionary:
	var key := AIProviders.api_key("gemini")
	var models: Array = AIProviders.fetch("gemini")["models"]
	var payload := {
		"model": models[models.size() - 1],
		"reasoning_effort": "low",
		"messages": [{"role": "user", "content": [
			{"type": "text", "text": "Transcribe exactamente lo que dice este audio en español. Responde solo con el texto dicho, sin comillas ni comentarios. Si no se entiende nada, responde vacío."},
			{"type": "input_audio", "input_audio": {"data": Marshalls.raw_to_base64(wav), "format": "wav"}},
		]}],
	}
	var response := await _post(str(AIProviders.fetch("gemini")["base_url"]) + "/chat/completions",
		PackedStringArray(["Authorization: Bearer " + key, "Content-Type: application/json"]), JSON.stringify(payload).to_utf8_buffer())
	if not response["ok"]:
		return response
	var choices: Array = response["data"].get("choices", [])
	if choices.is_empty():
		return {"ok": false, "error": "respuesta vacía"}
	return {"ok": true, "text": str(choices[0].get("message", {}).get("content", ""))}


func _post(url: String, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 60.0
	add_child(http)
	if http.request_raw(url, headers, HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		return {"ok": false, "error": "sin conexión"}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "sin conexión"}
	if code < 200 or code >= 300:
		return {"ok": false, "error": "error %d %s" % [code, text.left(160)]}
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return {"ok": false, "error": "respuesta rara"}
	return {"ok": true, "data": data}
