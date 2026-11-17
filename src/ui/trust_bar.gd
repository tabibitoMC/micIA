class_name TrustBar
extends PanelContainer
## Barra de confianza a lo ancho: ícono de apretón de manos, "Confianza", una
## pista con perilla redonda y el nombre del nivel (más el estado temporal:
## Feliz, Enojada...).

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
	add_theme_stylebox_override("panel", UIStyle.soft_pill(Color(1, 1, 1, 0.94), Color("f6b6cb"), 999, 14, 7))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var icon := TextureRect.new()
	icon.texture = Icons.texture("handshake", Color("e0628f"), 72, 2.2)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	row.add_child(icon)

	var title := Label.new()
	title.text = "Confianza"
	title.add_theme_font_override("font", UIStyle.font(800))
	title.add_theme_font_size_override("font_size", 16)
	row.add_child(title)

	_thermo = Control.new()
	_thermo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thermo.custom_minimum_size = Vector2(70, 20)
	_thermo.draw.connect(_draw_thermometer)
	row.add_child(_thermo)

	_level_label = Label.new()
	_level_label.add_theme_font_override("font", UIStyle.font(700))
	_level_label.add_theme_font_size_override("font_size", 15)
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


## Pista redondeada con relleno degradado y una perilla redonda en el valor.
func _draw_thermometer() -> void:
	var s := _thermo.size
	var knob_r := s.y * 0.42
	var track := Rect2(knob_r, s.y * 0.32, s.x - knob_r * 2.0, s.y * 0.36)
	_thermo.draw_style_box(UIStyle.rounded(Color("fbe3ee"), int(track.size.y / 2.0), 0), track)
	var t := clampf(Relationship.trust / 100.0, 0.0, 1.0)
	var knob_x := track.position.x + track.size.x * t
	# Relleno: celeste -> rosa -> fucsia, por tramos.
	var steps := 24
	var cold := Color("a9b8f5")
	var mid := Color("f48fb1")
	var hot := Color("e0458f")
	for i in steps:
		var x0 := track.position.x + track.size.x * i / steps
		var x1 := track.position.x + track.size.x * (i + 1) / steps
		if x0 >= knob_x:
			break
		var k := float(i) / steps
		var color := cold.lerp(mid, k * 2.0) if k < 0.5 else mid.lerp(hot, (k - 0.5) * 2.0)
		_thermo.draw_rect(Rect2(x0, track.position.y + 1, minf(x1, knob_x) - x0, track.size.y - 2), color)
	# Perilla
	var center := Vector2(knob_x, s.y / 2.0)
	_thermo.draw_circle(center + Vector2(0, 1.5), knob_r, Color(0.6, 0.3, 0.5, 0.18))
	_thermo.draw_circle(center, knob_r, Color.WHITE)
	_thermo.draw_circle(center, knob_r - 2.5, cold.lerp(hot, t))
