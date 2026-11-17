class_name ChessGame
extends MiniGame
## Ajedrez: tú con blancas (abajo), ella con negras. Las reglas están en
## ChessRules; aquí solo la interfaz y los turnos.

## Letras en español: Rey, Dama, Torre, Alfil, Caballo, Peón.
## Figuras de ajedrez (fuente DejaVu Sans, incluida en assets/fonts).
const GLYPHS := {"K": "♚", "Q": "♛", "R": "♜", "B": "♝", "N": "♞", "P": "♟"}
const PIECE_FONT := preload("res://assets/fonts/DejaVuSans.ttf")
const LIGHT := Color("fde8ef")
const DARK := Color("e7a6c0")
const SELECTED := Color("ffd54f")
const TARGET := Color("9be3b5")
const LAST_MOVE := Color("fff1a8")

var rules := ChessRules.new()
var _squares: Array = []
var _selected := -1
var _targets: Array = []
var _last_move := ""
var _done := false


func game_title() -> String:
	return "Ajedrez"


func build() -> void:
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(grid)
	# Fila 8 arriba, fila 1 abajo.
	for rank in range(7, -1, -1):
		for file in 8:
			var index := rank * 8 + file
			var square := Button.new()
			square.custom_minimum_size = Vector2(44, 44)
			square.add_theme_font_size_override("font_size", 34)
			square.add_theme_font_override("font", PIECE_FONT)
			square.pressed.connect(_on_square.bind(index))
			grid.add_child(square)
			_squares.resize(64)
			_squares[index] = square
	var legend := Label.new()
	legend.text = "Tú juegas con las blancas · Ella con las negras"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	add_child(legend)
	_refresh()
	set_status("Tu turno (blancas).")


func _on_square(index: int) -> void:
	if _done or rules.turn != "w" or ai.is_thinking():
		return
	var piece: String = rules.board[index]
	if index in _targets:
		var move := ChessRules.square_name(_selected) + ChessRules.square_name(index)
		if move + "q" in rules.legal_moves():
			move += "q"
		_play(move)
		return
	if piece.begins_with("w"):
		_selected = index
		_targets.clear()
		for move in rules.legal_moves():
			if move.substr(0, 2) == ChessRules.square_name(index):
				_targets.append(ChessRules.square_index(move.substr(2, 2)))
	else:
		_selected = -1
		_targets.clear()
	_refresh()


func _play(move: String) -> void:
	var description := rules.describe_move(move)
	rules.make_move(move)
	_last_move = move
	_selected = -1
	_targets.clear()
	_refresh()
	if _check_end():
		return
	set_status("%s está pensando..." % companion_name())
	var state := "Tú juegas con NEGRAS (minúsculas).\n%s\nÚltima jugada de él: %s.%s" % [
		rules.to_text(), description, " ¡Estás en jaque!" if rules.is_in_check("b") else ""]
	ai.choose("ajedrez", state, rules.legal_moves(),
		"Las jugadas van en formato UCI (casilla origen + destino, p. ej. e7e5).")


func on_ai_move(move: String) -> void:
	rules.make_move(move)
	_last_move = move
	_refresh()
	if not _check_end():
		set_status("Tu turno." + (" ¡Estás en jaque!" if rules.is_in_check("w") else ""))


func _check_end() -> bool:
	var state := rules.status()
	var user := Settings.user_display_name()
	if state == "jaque_mate":
		_done = true
		if rules.turn == "b":
			set_status("¡Jaque mate! Ganaste.")
			finish("Jugaron ajedrez y %s te ganó con jaque mate." % user, "Ganaste al ajedrez")
		else:
			set_status("Jaque mate. Ganó %s." % companion_name())
			finish("Jugaron ajedrez y tú le diste jaque mate a %s." % user, "Perdiste al ajedrez")
		return true
	if state == "ahogado" or rules.move_number > 150:
		_done = true
		set_status("Tablas.")
		finish("Jugaron ajedrez y quedaron tablas.", "Tablas en ajedrez")
		return true
	return false


func _refresh() -> void:
	for index in 64:
		var square: Button = _squares[index]
		var piece: String = rules.board[index]
		var light := (index / 8 + index % 8) % 2 == 1
		var color := LIGHT if light else DARK
		if _last_move != "" and (ChessRules.square_name(index) == _last_move.substr(0, 2) or ChessRules.square_name(index) == _last_move.substr(2, 2)):
			color = LAST_MOVE
		if index == _selected:
			color = SELECTED
		elif index in _targets:
			color = TARGET
		var style := UIStyle.rounded(color, 0, 0)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			square.add_theme_stylebox_override(state, style)
		square.text = GLYPHS[piece[1]] if piece != "" else ""
		# Blancas: letra blanca con borde fino. Negras: letra oscura y sin
		# borde. (Un borde grueso hacía que las blancas se vieran oscuras.)
		var white := piece.begins_with("w")
		var font := Color.WHITE if white else Color("2b1f45")
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			square.add_theme_color_override(c, font)
		square.add_theme_color_override("font_outline_color", Color("6b2f55"))
		square.add_theme_constant_override("outline_size", 5 if white else 0)
