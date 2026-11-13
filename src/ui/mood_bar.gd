class_name MoodBar
extends VBoxContainer
## Dos barritas: enojo y afecto. Se actualiza solo con las señales de Mood.

var _anger: ProgressBar
var _affection: ProgressBar


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	custom_minimum_size = Vector2(110, 0)
	_anger = _make_bar(UIStyle.ANGER)
	_affection = _make_bar(UIStyle.AFFECTION)
	Mood.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_anger.value = Mood.anger
	_affection.value = Mood.affection
	_anger.tooltip_text = "Enojo: %d" % int(Mood.anger)
	_affection.tooltip_text = "Afecto: %d" % int(Mood.affection)


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("background", UIStyle.panel(UIStyle.SURFACE_LIGHT, 5, 0))
	bar.add_theme_stylebox_override("fill", UIStyle.panel(color, 5, 0))
	add_child(bar)
	return bar
