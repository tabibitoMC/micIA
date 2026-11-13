class_name TouchInteractions
extends Node
## Interpreta los toques sobre ella: caricias en la cabeza o golpes.
##
##  - Toques lentos en la cabeza -> caricia: se sonroja.
##  - Muchos toques rápidos -> golpes: se enoja o se pone triste.
##  - Un toque suelto -> se sorprende.
##
## La reacción inmediata es local (gratis). Cuando terminas de tocarla, se
## envía UN solo evento a la IA con el resumen ("te acarició 3 veces"), así
## reacciona en personaje y anota el trato (base de la personalidad adaptativa).

## Se pide a main.gd que mande el evento a la IA.
signal event_ready(for_ai: String, for_chat: String)

## Toques más seguidos que esto cuentan como "rápidos".
const FAST_TAP_SECONDS := 0.35
## Cuántos toques rápidos seguidos son un golpe.
const HITS_FOR_SLAP := 3
## Pausa sin tocar para dar por terminada la interacción.
const QUIET_SECONDS := 2.0
## Mínimo de segundos entre eventos enviados a la IA (cuida el límite gratis).
const MIN_SECONDS_BETWEEN_EVENTS := 8.0
## Enojo local por golpe cuando está bloqueada (no se le puede escribir).
const BLOCKED_HIT_ANGER := 4.0

var avatar: Avatar

var _pets := 0
var _hits := 0
var _taps := 0
var _last_tap := -100.0
var _last_event := -100.0
var _quiet_timer: Timer


func _ready() -> void:
	_quiet_timer = Timer.new()
	_quiet_timer.one_shot = true
	_quiet_timer.timeout.connect(_finish_interaction)
	add_child(_quiet_timer)


func on_touched(point: Vector2) -> void:
	if avatar == null or not avatar.is_body_at(point):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var fast := now - _last_tap < FAST_TAP_SECONDS
	_last_tap = now
	_taps += 1

	if fast:
		_hits += 1
	elif avatar.is_head_at(point):
		_pets += 1

	if _hits >= HITS_FOR_SLAP:
		avatar.set_emotion("enojada" if Mood.affection < 60.0 else "triste")
		avatar.play_action("negar")
	elif _pets > 0 and not fast:
		avatar.set_emotion("avergonzada")
		avatar.play_action("asentir" if _pets % 2 == 0 else "ninguna")
	elif not fast:
		avatar.set_emotion("sorprendida")
		avatar.play_action("saltar")

	if Mood.blocked and fast:
		Mood.add_anger(BLOCKED_HIT_ANGER)
	_quiet_timer.start(QUIET_SECONDS)


func _finish_interaction() -> void:
	var pets := _pets
	var hits := _hits
	_pets = 0
	_hits = 0
	_taps = 0
	var now := Time.get_ticks_msec() / 1000.0
	if Mood.blocked or now - _last_event < MIN_SECONDS_BETWEEN_EVENTS:
		return

	var user := Settings.user_display_name()
	if hits >= HITS_FOR_SLAP:
		_last_event = now
		event_ready.emit(
			"%s te golpeó varias veces seguidas (%d golpes)." % [user, hits],
			"Le diste %d golpes" % hits)
	elif pets >= 2:
		_last_event = now
		event_ready.emit(
			"%s te acarició la cabeza con cariño (%d caricias)." % [user, pets],
			"Le acariciaste la cabeza")
