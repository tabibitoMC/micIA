class_name ChessRules
extends RefCounted
## Reglas completas de ajedrez: jugadas legales (enroque, captura al paso,
## coronación), jaque, jaque mate y ahogado. Sin interfaz: se puede probar sola.
##
## Tablero: Array de 64 casillas, índice = fila * 8 + columna, fila 0 = fila "1"
## (lado de las blancas). Pieza = color + tipo: "wP", "bK"... o "" si vacía.
## Las jugadas usan notación UCI: "e2e4", "e7e8q" (coronación).

const KNIGHT_STEPS := [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
const KING_STEPS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const ROOK_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const BISHOP_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
## Nombres en español para el texto que lee la IA.
const PIECE_NAMES := {"P": "peón", "N": "caballo", "B": "alfil", "R": "torre", "Q": "dama", "K": "rey"}

var board: Array = []
var turn := "w"
## Derechos de enroque: "K" corto blancas, "Q" largo blancas, "k", "q" negras.
var castling := {"K": true, "Q": true, "k": true, "q": true}
## Casilla donde se puede capturar al paso (-1 si ninguna).
var en_passant := -1
var move_number := 1
var history: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	board.resize(64)
	board.fill("")
	var back := ["R", "N", "B", "Q", "K", "B", "N", "R"]
	for file in 8:
		board[file] = "w" + back[file]
		board[8 + file] = "wP"
		board[48 + file] = "bP"
		board[56 + file] = "b" + back[file]
	turn = "w"
	castling = {"K": true, "Q": true, "k": true, "q": true}
	en_passant = -1
	move_number = 1
	history.clear()


func duplicate_state() -> ChessRules:
	var copy := ChessRules.new()
	copy.board = board.duplicate()
	copy.turn = turn
	copy.castling = castling.duplicate()
	copy.en_passant = en_passant
	copy.move_number = move_number
	return copy


# --- Coordenadas ----------------------------------------------------------

static func square_name(index: int) -> String:
	return "abcdefgh"[index % 8] + str(index / 8 + 1)


static func square_index(name: String) -> int:
	return (int(name.substr(1, 1)) - 1) * 8 + "abcdefgh".find(name.substr(0, 1))


static func _inside(file: int, rank: int) -> bool:
	return file >= 0 and file < 8 and rank >= 0 and rank < 8


static func _other(color: String) -> String:
	return "b" if color == "w" else "w"


# --- Jugadas ---------------------------------------------------------------

## Jugadas legales del bando que mueve.
func legal_moves() -> Array:
	var result: Array = []
	for move in _pseudo_moves(turn):
		var test := duplicate_state()
		test._apply(move)
		if not test.is_in_check(turn):
			result.append(move)
	return result


## Juega una jugada UCI (se asume legal). Devuelve false si no lo es.
func make_move(move: String) -> bool:
	if not move in legal_moves():
		return false
	_apply(move)
	history.append(move)
	return true


func is_in_check(color: String) -> bool:
	var king := board.find(color + "K")
	return king != -1 and is_attacked(king, _other(color))


## "jugando", "jaque_mate" o "ahogado".
func status() -> String:
	if not legal_moves().is_empty():
		return "jugando"
	return "jaque_mate" if is_in_check(turn) else "ahogado"


## ¿La casilla está atacada por el color indicado?
func is_attacked(index: int, by_color: String) -> bool:
	var file := index % 8
	var rank := index / 8
	# Peones
	var pawn_dir := -1 if by_color == "w" else 1
	for df in [-1, 1]:
		var f: int = file + df
		var r: int = rank + pawn_dir
		if _inside(f, r) and board[r * 8 + f] == by_color + "P":
			return true
	# Caballos y rey
	for step in KNIGHT_STEPS:
		if _inside(file + step.x, rank + step.y) and board[(rank + step.y) * 8 + file + step.x] == by_color + "N":
			return true
	for step in KING_STEPS:
		if _inside(file + step.x, rank + step.y) and board[(rank + step.y) * 8 + file + step.x] == by_color + "K":
			return true
	# Piezas que se deslizan
	for dir in ROOK_DIRS + BISHOP_DIRS:
		var f: int = file + dir.x
		var r: int = rank + dir.y
		while _inside(f, r):
			var piece: String = board[r * 8 + f]
			if piece != "":
				if piece[0] == by_color:
					var kind := piece[1]
					if kind == "Q" or (kind == "R" and dir in ROOK_DIRS) or (kind == "B" and dir in BISHOP_DIRS):
						return true
				break
			f += dir.x
			r += dir.y
	return false


func _pseudo_moves(color: String) -> Array:
	var moves: Array = []
	for index in 64:
		var piece: String = board[index]
		if piece == "" or piece[0] != color:
			continue
		var file := index % 8
		var rank := index / 8
		match piece[1]:
			"P": _pawn_moves(index, file, rank, color, moves)
			"N": _step_moves(index, file, rank, color, KNIGHT_STEPS, moves)
			"K":
				_step_moves(index, file, rank, color, KING_STEPS, moves)
				_castle_moves(index, color, moves)
			"B": _slide_moves(index, file, rank, color, BISHOP_DIRS, moves)
			"R": _slide_moves(index, file, rank, color, ROOK_DIRS, moves)
			"Q": _slide_moves(index, file, rank, color, ROOK_DIRS + BISHOP_DIRS, moves)
	return moves


func _pawn_moves(index: int, file: int, rank: int, color: String, moves: Array) -> void:
	var dir := 1 if color == "w" else -1
	var start_rank := 1 if color == "w" else 6
	var last_rank := 7 if color == "w" else 0
	var one := index + dir * 8
	if _inside(file, rank + dir) and board[one] == "":
		_add_pawn_move(index, one, rank + dir == last_rank, moves)
		var two := index + dir * 16
		if rank == start_rank and board[two] == "":
			moves.append(square_name(index) + square_name(two))
	for df in [-1, 1]:
		var f: int = file + df
		var r: int = rank + dir
		if not _inside(f, r):
			continue
		var target := r * 8 + f
		var piece: String = board[target]
		if (piece != "" and piece[0] != color) or target == en_passant:
			_add_pawn_move(index, target, r == last_rank, moves)


func _add_pawn_move(from: int, to: int, promotes: bool, moves: Array) -> void:
	moves.append(square_name(from) + square_name(to) + ("q" if promotes else ""))


func _step_moves(index: int, file: int, rank: int, color: String, steps: Array, moves: Array) -> void:
	for step in steps:
		var f: int = file + step.x
		var r: int = rank + step.y
		if not _inside(f, r):
			continue
		var piece: String = board[r * 8 + f]
		if piece == "" or piece[0] != color:
			moves.append(square_name(index) + square_name(r * 8 + f))


func _slide_moves(index: int, file: int, rank: int, color: String, dirs: Array, moves: Array) -> void:
	for dir in dirs:
		var f: int = file + dir.x
		var r: int = rank + dir.y
		while _inside(f, r):
			var piece: String = board[r * 8 + f]
			if piece == "" or piece[0] != color:
				moves.append(square_name(index) + square_name(r * 8 + f))
			if piece != "":
				break
			f += dir.x
			r += dir.y


func _castle_moves(index: int, color: String, moves: Array) -> void:
	var home := 4 if color == "w" else 60
	if index != home or is_in_check(color):
		return
	var enemy := _other(color)
	var short_key := "K" if color == "w" else "k"
	var long_key := "Q" if color == "w" else "q"
	if castling[short_key] and board[home + 1] == "" and board[home + 2] == "" \
			and board[home + 3] == color + "R" \
			and not is_attacked(home + 1, enemy) and not is_attacked(home + 2, enemy):
		moves.append(square_name(home) + square_name(home + 2))
	if castling[long_key] and board[home - 1] == "" and board[home - 2] == "" and board[home - 3] == "" \
			and board[home - 4] == color + "R" \
			and not is_attacked(home - 1, enemy) and not is_attacked(home - 2, enemy):
		moves.append(square_name(home) + square_name(home - 2))


## Aplica la jugada sin comprobar si es legal.
func _apply(move: String) -> void:
	var from := square_index(move.substr(0, 2))
	var to := square_index(move.substr(2, 2))
	var piece: String = board[from]
	var color := piece[0]
	var kind := piece[1]

	# Captura al paso: el peón capturado no está en la casilla de destino.
	if kind == "P" and to == en_passant and board[to] == "":
		board[to - (8 if color == "w" else -8)] = ""
	# Enroque: mover también la torre.
	if kind == "K" and absi(to - from) == 2:
		if to > from:
			board[from + 1] = board[from + 3]
			board[from + 3] = ""
		else:
			board[from - 1] = board[from - 4]
			board[from - 4] = ""

	board[to] = piece
	board[from] = ""
	if move.length() == 5:
		board[to] = color + move.substr(4, 1).to_upper()

	en_passant = (from + to) / 2 if kind == "P" and absi(to - from) == 16 else -1
	_update_castling(from, to, piece)
	if color == "b":
		move_number += 1
	turn = _other(color)


func _update_castling(from: int, to: int, piece: String) -> void:
	if piece == "wK":
		castling["K"] = false
		castling["Q"] = false
	elif piece == "bK":
		castling["k"] = false
		castling["q"] = false
	for square in [from, to]:
		match square:
			0: castling["Q"] = false
			7: castling["K"] = false
			56: castling["q"] = false
			63: castling["k"] = false


# --- Texto para la IA ------------------------------------------------------

## Tablero en texto (mayúsculas = blancas, minúsculas = negras).
func to_text() -> String:
	var lines: PackedStringArray = []
	for rank in range(7, -1, -1):
		var row := "%d " % (rank + 1)
		for file in 8:
			var piece: String = board[rank * 8 + file]
			if piece == "":
				row += ". "
			else:
				row += (piece[1] if piece[0] == "w" else piece[1].to_lower()) + " "
		lines.append(row)
	lines.append("  a b c d e f g h")
	return "\n".join(lines)


## Descripción humana de una jugada: "caballo g1->f3 (captura alfil)".
func describe_move(move: String) -> String:
	var piece: String = board[square_index(move.substr(0, 2))]
	var target: String = board[square_index(move.substr(2, 2))]
	var text := "%s %s->%s" % [PIECE_NAMES.get(piece.substr(1, 1), "?"), move.substr(0, 2), move.substr(2, 2)]
	if target != "":
		text += " (captura %s)" % PIECE_NAMES.get(target.substr(1, 1), "?")
	return text
