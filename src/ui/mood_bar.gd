class_name MoodBar
extends PanelContainer
## Píldora con una barrita (afecto o enojo). Se actualiza sola con Mood.

enum Kind { AFFECTION, ANGER }

var kind := Kind.AFFECTION
var title := ""

var _title_label: Label
var _bar: ProgressBar
var _delta_label: Label
var _last_value := -1.0


func _init(p_kind: Kind = Kind.AFFECTION, p_title := "") -> void:
	kind = p_kind
	title = p_title


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.pill(UIStyle.WHITE, UIStyle.PINK_BORDER, 14, 5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	row.add_child(_title_label)
	# "+6" / "-12" que aparece un momento al lado del título cuando cambia.
	_delta_label = Label.new()
	_delta_label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	_delta_label.modulate.a = 0.0
	row.add_child(_delta_label)

	var color := UIStyle.AFFECTION if kind == Kind.AFFECTION else UIStyle.ANGER
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(84, 7)
	_bar.add_theme_stylebox_override("background", UIStyle.rounded(UIStyle.PINK_SOFT, 4, 0))
	_bar.add_theme_stylebox_override("fill", UIStyle.rounded(color, 4, 0))
	box.add_child(_bar)

	Mood.changed.connect(refresh)
	refresh()


func set_title(text: String) -> void:
	title = text
	if _title_label:
		_title_label.text = text


func refresh() -> void:
	var value := Mood.affection if kind == Kind.AFFECTION else Mood.anger
	_bar.value = value
	if _last_value >= 0.0:
		_show_delta(value - _last_value)
	_last_value = value
	if _title_label and kind == Kind.ANGER:
		_title_label.text = "%s %d" % [title, int(round(value))]


func _show_delta(delta: float) -> void:
	var amount := int(round(delta))
	if amount == 0:
		return
	# En el enojo, subir es malo (rojo) y bajar es bueno (verde). En el
	# cariño es al revés.
	var good := (amount < 0) if kind == Kind.ANGER else (amount > 0)
	_delta_label.text = ("+%d" if amount > 0 else "%d") % amount
	_delta_label.add_theme_color_override("font_color", Color("2e9e5b") if good else Color("d6334f"))
	_delta_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_delta_label, "modulate:a", 0.0, 0.8)
