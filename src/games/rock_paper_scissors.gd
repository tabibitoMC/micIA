class_name RockPaperScissorsGame
extends MiniGame
## Piedra, papel o tijera al mejor de 5 (gana quien llegue a 3).
## Ella elige SIN ver tu elección: se le pide su jugada y luego se revelan.

const OPTIONS := ["piedra", "papel", "tijera"]
const BEATS := {"piedra": "tijera", "papel": "piedra", "tijera": "papel"}
const WIN_SCORE := 3

var _user_score := 0
var _her_score := 0
var _round := 1
var _user_choice := ""
var _buttons: Array = []
var _result: Label
var _history: PackedStringArray = []


func game_title() -> String:
	return "Piedra, papel o tijera"


func build() -> void:
	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_theme_font_size_override("font_size", 22)
	add_child(_result)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for option in OPTIONS:
		var b := Button.new()
		b.text = option.capitalize()
		b.custom_minimum_size = Vector2(100, 54)
		b.pressed.connect(_on_choice.bind(option))
		row.add_child(b)
		_buttons.append(b)
	_update_score()


func _on_choice(option: String) -> void:
	if ai.is_thinking():
		return
	_user_choice = option
	for b in _buttons:
		b.disabled = true
	set_status("%s está eligiendo..." % companion_name())
	var past := ("Rondas anteriores (tú vs él): " + ", ".join(_history)) if not _history.is_empty() else "Primera ronda."
	ai.choose("piedra, papel o tijera", "Ronda %d. Marcador: tú %d - él %d. %s" % [_round, _her_score, _user_score, past], OPTIONS)


func on_ai_move(move: String) -> void:
	for b in _buttons:
		b.disabled = false
	var text := "Tú: %s  vs  %s: %s\n" % [_user_choice, companion_name(), move]
	if move == _user_choice:
		text += "Empate"
	elif BEATS[_user_choice] == move:
		_user_score += 1
		text += "¡Ganas la ronda!"
	else:
		_her_score += 1
		text += "Gana %s" % companion_name()
	_history.append("%s vs %s" % [move, _user_choice])
	_result.text = text
	_round += 1
	_update_score()
	if _user_score >= WIN_SCORE or _her_score >= WIN_SCORE:
		for b in _buttons:
			b.disabled = true
		var user := Settings.user_display_name()
		if _user_score > _her_score:
			finish("Jugaron piedra, papel o tijera y %s te ganó %d a %d." % [user, _user_score, _her_score], "Ganaste %d-%d" % [_user_score, _her_score])
		else:
			finish("Jugaron piedra, papel o tijera y tú le ganaste a %s %d a %d." % [user, _her_score, _user_score], "Perdiste %d-%d" % [_user_score, _her_score])


func _update_score() -> void:
	set_status("Ronda %d · Tú %d - %d %s (gana quien llegue a %d)" % [_round, _user_score, _her_score, companion_name(), WIN_SCORE])
