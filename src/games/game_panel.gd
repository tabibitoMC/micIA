class_name GamePanel
extends PanelContainer
## Menú de minijuegos y contenedor del juego en curso.

signal finished(for_ai: String, for_chat: String)
signal companion_said(text: String, emotion: String)
## Reacción rápida de ella (sin Mistral), p. ej. en cada punto del ping-pong.
signal companion_reacted(emotion: String, action: String)
signal closed

## [nombre, clase]. Para agregar un juego: crear una clase que extienda
## MiniGame y añadirla aquí.
static func games() -> Array:
	return [
		["Tres en raya", TicTacToeGame],
		["Piedra, papel o tijera", RockPaperScissorsGame],
		["Ajedrez", ChessGame],
		["Ping-pong", PingPongGame],
	] + extra_games


## Juegos añadidos por mods: [nombre, script que extiende MiniGame].
static var extra_games: Array = []

var _ai: GameAI
var _menu: VBoxContainer
var _game: MiniGame


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	_ai = GameAI.new()
	add_child(_ai)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	var title := Label.new()
	title.text = "Juegos"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	_menu.add_child(title)
	for entry in games():
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(_start.bind(entry[1]))
		_menu.add_child(button)
	var close := Button.new()
	close.text = "Cerrar"
	UIStyle.style_button(close, UIStyle.ButtonKind.FLAT)
	close.pressed.connect(func(): closed.emit())
	_menu.add_child(close)


func show_menu() -> void:
	if _game:
		_game.queue_free()
		_game = null
	_menu.visible = true


func is_playing() -> bool:
	return _game != null


func _start(game_class: GDScript) -> void:
	_game = game_class.new()
	_game.ai = _ai
	_game.finished.connect(_on_finished)
	_game.companion_said.connect(func(text: String, emotion: String): companion_said.emit(text, emotion))
	if _game.has_signal("point_scored"):
		_game.point_scored.connect(func(user_scored: bool):
			companion_reacted.emit("enojada" if user_scored else "feliz", "negar" if user_scored else "saltar"))
	_menu.visible = false
	add_child(_game)


func _on_finished(for_ai: String, for_chat: String) -> void:
	# Deja ver el resultado un momento antes de cerrar.
	await get_tree().create_timer(1.8).timeout
	finished.emit(for_ai, for_chat)
	show_menu()
