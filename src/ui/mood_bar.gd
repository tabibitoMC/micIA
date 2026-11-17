class_name MoodBar
extends PanelContainer
## Píldora del encabezado: un círculo rosa con ícono blanco (corazón o carita
## enojada), el título y una barrita. Se actualiza sola con Mood.
## Cuando el valor cambia aparece un momento "+X" / "-X" junto al título.

enum Kind { AFFECTION, ANGER }

const BADGE_SIZE := 38.0

var kind := Kind.AFFECTION
var title := ""

var _title_label: Label
var _bar: Control
var _delta_label: Label
var _value := 0.0
var _last_value := -1.0


func _init(p_kind: Kind = Kind.AFFECTION, p_title := "") -> void:
	kind = p_kind
	title = p_title


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.soft_pill(Color(1, 1, 1, 0.94), Color("f6b6cb"), 999, 6, 5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	# Círculo rosa con el ícono.
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Icons.texture("heart-fill" if kind == Kind.AFFECTION else "angry", Color.WHITE, 96, 2.4)
	badge.draw.connect(func():
		var c := badge.size / 2.0
		badge.draw_circle(c, BADGE_SIZE / 2.0, Color("f7a8c4"))
		badge.draw_circle(c, BADGE_SIZE / 2.0 - 2.0, Color("ef7aa5"))
		var s := BADGE_SIZE * 0.56
		badge.draw_texture_rect(icon, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false))
	row.add_child(badge)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_override("font", UIStyle.font(800))
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.add_theme_color_override("font_color", UIStyle.PLUM)
	title_row.add_child(_title_label)
	_delta_label = Label.new()
	_delta_label.add_theme_font_override("font", UIStyle.font(800))
	_delta_label.add_theme_font_size_override("font_size", 15)
	_delta_label.modulate.a = 0.0
	title_row.add_child(_delta_label)

	# Barrita (solo la del cariño va siempre; la del enojo aparece si hay enojo).
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(110, 7)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)

	Mood.changed.connect(refresh)
	refresh()


func set_title(text: String) -> void:
	title = text
	if _title_label:
		_title_label.text = text


func refresh() -> void:
	_value = Mood.affection if kind == Kind.AFFECTION else Mood.anger
	if _last_value >= 0.0:
		_show_delta(_value - _last_value)
	_last_value = _value
	if kind == Kind.ANGER:
		_title_label.text = "%s %d" % [title, int(round(_value))]
		_bar.visible = _value >= 1.0
	_bar.queue_redraw()


func _draw_bar() -> void:
	var s := _bar.size
	var track := UIStyle.rounded(Color("fde3ec"), int(s.y / 2.0), 0)
	_bar.draw_style_box(track, Rect2(Vector2.ZERO, s))
	var fill_width := s.x * clampf(_value / 100.0, 0.0, 1.0)
	if fill_width >= s.y:
		var color := Color("ef6b9a") if kind == Kind.AFFECTION else Color("ef5a6f")
		_bar.draw_style_box(UIStyle.rounded(color, int(s.y / 2.0), 0), Rect2(Vector2.ZERO, Vector2(fill_width, s.y)))


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
