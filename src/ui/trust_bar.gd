class_name TrustBar
extends PanelContainer
## Barra superior tipo termómetro: nivel de confianza, nombre del nivel y el
## estado temporal actual (Feliz, Enojada, Lasciva...).

const STATE_COLORS := {
	"feliz": Color("ffc857"),
	"triste": Color("7aa7e0"),
	"enojada": Color("ef5a6f"),
	"dolida": Color("9b8ec9"),
	"distante": Color("8fb3c9"),
	"lasciva": Color("e0458f"),
}

var _thermo: Control
var _level_label: Label
var _state_chip: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.pill(UIStyle.WHITE, UIStyle.PINK_BORDER, 14, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var title := Label.new()
	title.text = "Confianza"
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	row.add_child(title)

	_thermo = Control.new()
	_thermo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thermo.custom_minimum_size = Vector2(80, 18)
	_thermo.draw.connect(_draw_thermometer)
	row.add_child(_thermo)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	row.add_child(_level_label)

	_state_chip = Label.new()
	_state_chip.add_theme_font_size_override("font_size", 12)
	_state_chip.add_theme_color_override("font_color", UIStyle.WHITE)
	row.add_child(_state_chip)

	Relationship.changed.connect(refresh)
	Relationship.state_changed.connect(func(_s: String): refresh())
	refresh()


func refresh() -> void:
	_level_label.text = Relationship.trust_label()
	var state := Relationship.state
	_state_chip.visible = state != "normal"
	if _state_chip.visible:
		var color: Color = STATE_COLORS.get(state, UIStyle.PINK)
		_state_chip.text = "%s %d" % [Relationship.state_label(), Relationship.state_remaining]
		_state_chip.add_theme_stylebox_override("normal", UIStyle.pill(color, color.darkened(0.2), 8, 1))
	_thermo.queue_redraw()


## Tubo redondeado con degradado frío -> cálido y un bulbo a la izquierda.
func _draw_thermometer() -> void:
	var s := _thermo.size
	var bulb_r := s.y * 0.5
	var tube := Rect2(bulb_r, s.y * 0.25, s.x - bulb_r, s.y * 0.5)
	var bg := UIStyle.rounded(UIStyle.PINK_SOFT, int(tube.size.y / 2), 0)
	_thermo.draw_style_box(bg, tube)

	var t := clampf(Relationship.trust / 100.0, 0.0, 1.0)
	var fill_end := tube.position.x + tube.size.x * t
	var steps := 24
	var cold := Color("8ec5ff")
	var mid := Color("f48fb1")
	var hot := Color("e0458f")
	for i in steps:
		var x0 := tube.position.x + tube.size.x * i / steps
		var x1 := tube.position.x + tube.size.x * (i + 1) / steps
		if x0 >= fill_end:
			break
		var k := float(i) / steps
		var color := cold.lerp(mid, k * 2.0) if k < 0.5 else mid.lerp(hot, (k - 0.5) * 2.0)
		_thermo.draw_rect(Rect2(x0, tube.position.y + 2, minf(x1, fill_end) - x0, tube.size.y - 4), color)
	# Bulbo
	var bulb_color := cold.lerp(hot, t)
	_thermo.draw_circle(Vector2(bulb_r, s.y / 2), bulb_r, UIStyle.WHITE)
	_thermo.draw_circle(Vector2(bulb_r, s.y / 2), bulb_r - 2.5, bulb_color)
	# Marcas de los niveles
	for level in Relationship.TRUST_LEVELS:
		var x := tube.position.x + tube.size.x * float(level[0]) / 100.0
		if x > tube.position.x + 2:
			_thermo.draw_line(Vector2(x, tube.position.y), Vector2(x, tube.end.y), Color(1, 1, 1, 0.8), 1.5)
