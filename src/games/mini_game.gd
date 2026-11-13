class_name MiniGame
extends VBoxContainer
## Base de los minijuegos. Cada juego construye su interfaz en build() y
## llama a finish() al terminar.

## Al terminar: texto para la IA (evento) y para el chat.
signal finished(for_ai: String, for_chat: String)
## Ella dice algo durante el juego (comentario de su jugada).
signal companion_said(text: String, emotion: String)

var ai: GameAI
var _status: Label


func game_title() -> String:
	return "Juego"


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	add_child(header)
	var title := Label.new()
	title.text = game_title()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	header.add_child(title)
	var quit := Button.new()
	quit.text = "Salir"
	UIStyle.style_button(quit, UIStyle.ButtonKind.SECONDARY)
	quit.pressed.connect(func(): finish("%s dejó la partida de %s a medias." % [Settings.user_display_name(), game_title()], "Saliste del juego"))
	header.add_child(quit)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	add_child(_status)

	ai.move_chosen.connect(_on_ai_move)
	build()


## Cada juego arma aquí su interfaz.
func build() -> void:
	pass


## Cada juego aplica aquí la jugada de ella.
func on_ai_move(_move: String) -> void:
	pass


func set_status(text: String) -> void:
	_status.text = text


func finish(for_ai: String, for_chat: String) -> void:
	finished.emit(for_ai, for_chat)


func companion_name() -> String:
	return str(Settings.get_value("companion_name"))


func _on_ai_move(move: String, comment: String, emotion: String) -> void:
	if not comment.is_empty():
		companion_said.emit(comment, emotion)
	on_ai_move(move)
