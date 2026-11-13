class_name MoodBar
extends PanelContainer
## Píldora con una barrita (afecto o enojo). Se actualiza sola con Mood.

enum Kind { AFFECTION, ANGER }

var kind := Kind.AFFECTION
var title := ""

var _title_label: Label
var _bar: ProgressBar


func _init(p_kind: Kind = Kind.AFFECTION, p_title := "") -> void:
	kind = p_kind
	title = p_title


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.pill(UIStyle.WHITE, UIStyle.PINK_BORDER, 14, 5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	box.add_child(_title_label)

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
	_bar.value = Mood.affection if kind == Kind.AFFECTION else Mood.anger
