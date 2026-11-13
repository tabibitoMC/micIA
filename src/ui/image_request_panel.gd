class_name ImageRequestPanel
extends PanelContainer
## Ventana para pedir una imagen: descripción + elegir servicio.
## Si el servicio elegido falla, ImageGenerator prueba el otro solo.

signal requested(prompt: String, provider: String)
signal closed

var _prompt: TextEdit


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "Generar imagen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Describe la imagen (en inglés sale mejor). Ella la verá y te dirá qué le parece."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	box.add_child(hint)

	_prompt = TextEdit.new()
	_prompt.placeholder_text = "anime style, a cat sleeping on a sunny window..."
	_prompt.custom_minimum_size = Vector2(0, 110)
	_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt.add_theme_stylebox_override("normal", UIStyle.rounded(UIStyle.WHITE, 16, 10))
	_prompt.add_theme_stylebox_override("focus", UIStyle.rounded(UIStyle.WHITE, 16, 10))
	_prompt.add_theme_color_override("font_color", UIStyle.PLUM)
	_prompt.add_theme_color_override("font_placeholder_color", UIStyle.PLUM_DIM)
	box.add_child(_prompt)

	var cloudflare := Button.new()
	cloudflare.text = "Cloudflare (rápida)"
	cloudflare.custom_minimum_size = Vector2(0, 46)
	UIStyle.style_button(cloudflare, UIStyle.ButtonKind.CTA)
	cloudflare.pressed.connect(_request.bind(ImageGenerator.PROVIDER_CLOUDFLARE))
	box.add_child(cloudflare)

	var horde := Button.new()
	horde.text = "Comunitaria (AI Horde)"
	horde.custom_minimum_size = Vector2(0, 46)
	horde.pressed.connect(_request.bind(ImageGenerator.PROVIDER_HORDE))
	box.add_child(horde)

	var close := Button.new()
	close.text = "Cerrar"
	UIStyle.style_button(close, UIStyle.ButtonKind.FLAT)
	close.pressed.connect(func(): closed.emit())
	box.add_child(close)


func _request(provider: String) -> void:
	var text := _prompt.text.strip_edges()
	if text.is_empty():
		_prompt.grab_focus()
		return
	_prompt.text = ""
	requested.emit(text, provider)
