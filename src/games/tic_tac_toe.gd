class_name TicTacToeGame
extends MiniGame
## Tres en raya: tú eres X, ella es O.

const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]

var _cells: Array = []
var _board: Array = ["", "", "", "", "", "", "", "", ""]
var _done := false


func game_title() -> String:
	return "Tres en raya"


func build() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(grid)
	for i in 9:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(84, 84)
		cell.add_theme_font_size_override("font_size", 40)
		UIStyle.style_button(cell, UIStyle.ButtonKind.SECONDARY)
		cell.pressed.connect(_on_cell.bind(i))
		grid.add_child(cell)
		_cells.append(cell)
	set_status("Tu turno (eres X).")


func _on_cell(i: int) -> void:
	if _done or _board[i] != "" or ai.is_thinking():
		return
	_place(i, "X")
	if _check_end():
		return
	set_status("%s está pensando..." % companion_name())
	ai.choose("tres en raya (ella es O)", _board_text(), _free_cells())


func on_ai_move(move: String) -> void:
	_place(int(move) - 1, "O")
	if not _check_end():
		set_status("Tu turno.")


func _place(i: int, mark: String) -> void:
	_board[i] = mark
	_cells[i].text = mark
	_cells[i].add_theme_color_override("font_color", UIStyle.PINK_DEEP if mark == "X" else Color("4a7bd1"))
	_cells[i].add_theme_color_override("font_disabled_color", UIStyle.PINK_DEEP if mark == "X" else Color("4a7bd1"))


func _check_end() -> bool:
	var winner := ""
	for line in LINES:
		if _board[line[0]] != "" and _board[line[0]] == _board[line[1]] and _board[line[1]] == _board[line[2]]:
			winner = _board[line[0]]
	if winner == "" and not "" in _board:
		winner = "empate"
	if winner == "":
		return false
	_done = true
	var user := Settings.user_display_name()
	match winner:
		"X":
			set_status("¡Ganaste!")
			finish("Jugaron tres en raya y %s te ganó." % user, "Ganaste en tres en raya")
		"O":
			set_status("Ganó %s." % companion_name())
			finish("Jugaron tres en raya y tú le ganaste a %s." % user, "Perdiste en tres en raya")
		_:
			set_status("Empate.")
			finish("Jugaron tres en raya y quedaron empate.", "Empate en tres en raya")
	return true


func _free_cells() -> Array:
	var free: Array = []
	for i in 9:
		if _board[i] == "":
			free.append(str(i + 1))
	return free


## Casillas numeradas 1-9 de izquierda a derecha y de arriba abajo.
func _board_text() -> String:
	var rows: PackedStringArray = []
	for r in 3:
		var row: PackedStringArray = []
		for c in 3:
			var v: String = _board[r * 3 + c]
			row.append(v if v != "" else str(r * 3 + c + 1))
		rows.append(" | ".join(row))
	return "Tablero (números = casillas libres):\n" + "\n".join(rows)
