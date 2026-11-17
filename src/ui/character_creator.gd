class_name CharacterCreator
extends PanelContainer
## Creador de personajes: nombre, quién es, apariencia, personalidad,
## "stats" (temperamento, cariño, paciencia, voz) y su modelo.
##
## Modelos compatibles:
##  - Imagen PNG/WebP/JPG de cuerpo entero (mejor con fondo transparente; si
##    el fondo es de un solo color se quita solo). Se anima con
##    AvatarIllustrated. Para que parpadee y mueva la boca se marcan con
##    toques los ojos, la boca y la barbilla.
##  - Marioneta .puppet (Inochi2D convertido con tools/bake_puppet.py).
##  - Archivo de personaje .micia (lo crea "Exportar" para compartirlo).
##
## Se guardan en user://custom_characters/<id>/ (ver Characters.load_custom).

signal created(character_id: String)
signal closed

const MARK_STEPS := ["el ojo de la IZQUIERDA (de la pantalla)", "el ojo de la DERECHA", "la BOCA", "la BARBILLA (donde empieza el cuello)"]
## Parte de arriba de la imagen que se muestra para marcar la cara.
const MARK_CROP := 0.42

var _name: LineEdit
var _identity: TextEdit
var _appearance: TextEdit
var _personality: OptionButton
var _personality_text: TextEdit
var _temper: HSlider
var _affection: HSlider
var _patience: HSlider
var _pitch: HSlider
var _adult: CheckButton
var _model_label: Label
var _status: Label
var _mark_box: VBoxContainer
var _mark_hint: Label
var _mark_view: TextureRect
var _dialog: FileDialog

var _image: Image
var _puppet_bytes := PackedByteArray()
var _marks: Array = []
var _crop_top := 0
var _crop_height := 1


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	var title := Label.new()
	title.text = "Crear personaje"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	form.add_child(title)

	_label(form, "Nombre")
	_name = LineEdit.new()
	_name.placeholder_text = "Ej. Sakura"
	form.add_child(_name)

	_label(form, "¿Quién es? (edad, a qué se dedica, gustos, historia)")
	_identity = _text(form, "Ej. Una mujer de 34 años, dulce y protectora, chef de pastelería; le encantan las plantas y el té...", 90)

	_label(form, "Apariencia en inglés (para sus fotos)")
	_appearance = _text(form, "Ej. anime woman, wavy brown shoulder-length hair, amber eyes, cream blouse, gold necklace", 70)

	_label(form, "Personalidad base")
	_personality = OptionButton.new()
	for id in Personalities.ids():
		if not str(id).begins_with("custom_"):
			_personality.add_item(Personalities.fetch(id)["label"])
			_personality.set_item_metadata(_personality.item_count - 1, id)
	form.add_child(_personality)
	_label(form, "Cómo es y cómo habla (opcional, se suma a la base)")
	_personality_text = _text(form, "Ej. Habla con calma y cariño, le dice \"cielo\", es un poco celosa...", 70)

	_label(form, "Stats")
	_temper = _slider(form, "Temperamento (se enoja fácil)", 0.5, 1.6, 1.0)
	_affection = _slider(form, "Cariño (se encariña rápido)", 0.5, 1.6, 1.0)
	_patience = _slider(form, "Paciencia (cuánto aguanta antes de bloquearte)", 50.0, 98.0, 80.0)
	_pitch = _slider(form, "Tono de voz (grave ↔ aguda)", 0.7, 1.4, 1.0)

	_adult = CheckButton.new()
	_adult.text = "Es adulta (permite romance)"
	_adult.button_pressed = true
	form.add_child(_adult)

	_label(form, "Modelo")
	var pick_image := Button.new()
	pick_image.text = "Elegir imagen de cuerpo entero (PNG/WebP)"
	pick_image.pressed.connect(_pick.bind(["*.png, *.webp, *.jpg, *.jpeg ; Imágenes"]))
	form.add_child(pick_image)
	var pick_file := Button.new()
	pick_file.text = "Elegir archivo de personaje (.micia / .puppet)"
	pick_file.pressed.connect(_pick.bind(["*.micia, *.puppet ; Personajes"]))
	form.add_child(pick_file)
	_model_label = Label.new()
	_model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_model_label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	_model_label.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	_model_label.text = "Sin modelo: usará la ilustración de Mireya."
	form.add_child(_model_label)

	# Marcar ojos, boca y barbilla tocando la imagen.
	_mark_box = VBoxContainer.new()
	_mark_box.visible = false
	form.add_child(_mark_box)
	_mark_hint = Label.new()
	_mark_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mark_box.add_child(_mark_hint)
	_mark_view = TextureRect.new()
	_mark_view.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_mark_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_mark_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_mark_view.gui_input.connect(_on_mark_input)
	_mark_view.draw.connect(_draw_marks)
	_mark_box.add_child(_mark_view)
	var redo := Button.new()
	redo.text = "Volver a marcar"
	UIStyle.style_button(redo, UIStyle.ButtonKind.FLAT)
	redo.pressed.connect(func(): _marks.clear(); _update_mark_hint())
	_mark_box.add_child(redo)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	form.add_child(_status)

	var save := Button.new()
	save.text = "Crear y cambiar a ella"
	save.custom_minimum_size = Vector2(0, 48)
	UIStyle.style_button(save, UIStyle.ButtonKind.CTA)
	save.pressed.connect(_save)
	form.add_child(save)
	var export := Button.new()
	export.text = "Exportar el personaje actual (.micia)"
	export.pressed.connect(_export_current)
	form.add_child(export)
	var close := Button.new()
	close.text = "Cerrar"
	UIStyle.style_button(close, UIStyle.ButtonKind.FLAT)
	close.pressed.connect(func(): closed.emit())
	form.add_child(close)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.file_selected.connect(_on_file_selected)
	add_child(_dialog)


func _label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	parent.add_child(label)


func _text(parent: Control, placeholder: String, height: float) -> TextEdit:
	var edit := TextEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, height)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.add_theme_stylebox_override("normal", UIStyle.rounded(UIStyle.WHITE, 16, 10))
	edit.add_theme_stylebox_override("focus", UIStyle.rounded(UIStyle.WHITE, 16, 10))
	edit.add_theme_color_override("font_color", UIStyle.PLUM)
	edit.add_theme_color_override("font_placeholder_color", UIStyle.PLUM_DIM)
	parent.add_child(edit)
	return edit


func _slider(parent: Control, text: String, min_value: float, max_value: float, value: float) -> HSlider:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", UIStyle.PLUM_DIM)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = (max_value - min_value) / 20.0
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 30)
	var refresh := func(v: float): label.text = "%s: %s" % [text, str(snappedf(v, 0.01))]
	slider.value_changed.connect(refresh)
	refresh.call(value)
	parent.add_child(slider)
	return slider


## Deja el formulario vacío (llamar antes de mostrarlo).
func reset() -> void:
	_name.text = ""
	_identity.text = ""
	_appearance.text = ""
	_personality_text.text = ""
	_image = null
	_puppet_bytes = PackedByteArray()
	_marks.clear()
	_mark_box.visible = false
	_model_label.text = "Sin modelo: usará la ilustración de Mireya."
	_status.text = ""


func _pick(filters: Array) -> void:
	_dialog.filters = PackedStringArray(filters)
	if OS.get_name() == "Android":
		OS.request_permissions()
	_dialog.popup_centered_ratio(0.9)


func _on_file_selected(path: String) -> void:
	var lower := path.to_lower()
	if lower.ends_with(".micia"):
		_import_micia(path)
	elif lower.ends_with(".puppet"):
		_puppet_bytes = FileAccess.get_file_as_bytes(path)
		_image = null
		_mark_box.visible = false
		_model_label.text = "Marioneta: %s" % path.get_file()
	else:
		var image := ImageUtils.load_any(path)
		if image == null or image.is_empty():
			_show("No pude abrir esa imagen.", true)
			return
		_set_image(image)
		_model_label.text = "Imagen: %s (%dx%d)" % [path.get_file(), _image.get_width(), _image.get_height()]


## Prepara la imagen: tamaño razonable, fondo transparente y recorte.
func _set_image(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	if image.get_height() > 3072:
		image.resize(int(image.get_width() * 3072.0 / image.get_height()), 3072, Image.INTERPOLATE_LANCZOS)
	if not image.detect_alpha():
		_remove_flat_background(image)
	var used := image.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		image = image.get_region(used.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	_image = image
	_puppet_bytes = PackedByteArray()
	_marks.clear()
	_crop_top = 0
	_crop_height = int(_image.get_height() * MARK_CROP)
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(_image)
	atlas.region = Rect2(0, _crop_top, _image.get_width(), _crop_height)
	_mark_view.texture = atlas
	_mark_box.visible = true
	_update_mark_hint()


## Fondo de un solo color (el de las esquinas) -> transparente.
static func _remove_flat_background(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var corners := [image.get_pixel(1, 1), image.get_pixel(w - 2, 1), image.get_pixel(1, h - 2), image.get_pixel(w - 2, h - 2)]
	var bg: Color = corners[0]
	for c in corners:
		if (c as Color).to_rgba32() != bg.to_rgba32() and Vector3(c.r - bg.r, c.g - bg.g, c.b - bg.b).length() > 0.08:
			return
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var d := Vector3(c.r - bg.r, c.g - bg.g, c.b - bg.b).length()
			if d < 0.18:
				c.a = clampf((d - 0.08) / 0.1, 0.0, 1.0)
				image.set_pixel(x, y, c)


func _update_mark_hint() -> void:
	if _marks.size() < MARK_STEPS.size():
		_mark_hint.text = "Para que parpadee y hable: toca %s. (Paso %d de %d; puedes saltarlo.)" % [MARK_STEPS[_marks.size()], _marks.size() + 1, MARK_STEPS.size()]
	else:
		_mark_hint.text = "¡Cara lista! Ya puede parpadear, sonreír y mover la boca."
	_mark_view.queue_redraw()


func _on_mark_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT or _marks.size() >= MARK_STEPS.size():
		return
	var scale := _view_scale()
	_marks.append(Vector2(mouse.position.x / scale, mouse.position.y / scale + _crop_top))
	_update_mark_hint()


func _view_scale() -> float:
	return _mark_view.size.x / maxf(1.0, _image.get_width()) if _image else 1.0


func _draw_marks() -> void:
	var scale := _view_scale()
	var colors := [Color.CYAN, Color.CYAN, Color.MAGENTA, Color.YELLOW]
	for i in _marks.size():
		var p: Vector2 = (_marks[i] - Vector2(0, _crop_top)) * scale
		_mark_view.draw_circle(p, 6.0, colors[i])
		_mark_view.draw_arc(p, 9.0, 0.0, TAU, 20, Color.BLACK, 2.0)


## Calcula el "rig" de AvatarIllustrated a partir de los toques.
func _build_rig() -> Dictionary:
	var used := _image.get_used_rect()
	var top := float(used.position.y)
	var feet := float(used.end.y)
	var w := float(_image.get_width())
	var rig := {"top": top, "feet": feet, "fur_box": Vector4(w * 4.0, feet * 4.0, w * 4.0, feet * 4.0)}
	if _marks.size() < 4:
		var neck_y := top + (feet - top) * 0.2
		rig.merge({"neck": Vector2(w * 0.5, neck_y), "face": Vector2(w * 0.5, neck_y - (feet - top) * 0.07),
			"face_radius": (feet - top) * 0.06, "hair_line": neck_y - (feet - top) * 0.1,
			"chest_top": neck_y + (feet - top) * 0.05, "chest_bottom": neck_y + (feet - top) * 0.2,
			"skirt_top": top + (feet - top) * 0.66})
		return rig
	var eye_l: Vector2 = _marks[0]
	var eye_r: Vector2 = _marks[1]
	var mouth: Vector2 = _marks[2]
	var chin: Vector2 = _marks[3]
	if eye_l.x > eye_r.x:
		var t := eye_l
		eye_l = eye_r
		eye_r = t
	var d := maxf(eye_l.distance_to(eye_r), 10.0)
	var mid := (eye_l + eye_r) / 2.0
	var neck := chin + Vector2(0, d * 0.05)
	var skin := _sample(mid + Vector2(0, d * 0.2))
	var cheek := _sample(eye_l + Vector2(0, d * 0.4))
	rig.merge({
		"neck": neck,
		"face": mid + Vector2(0, d * 0.15),
		"face_radius": d * 1.06,
		"hair_line": mid.y - d * 0.3,
		"eyes": [eye_l, eye_r],
		"eye_half": [Vector2(d * 0.25, d * 0.13), Vector2(d * 0.24, d * 0.125)],
		"mouth": mouth,
		"mouth_width": d * 0.24,
		"cheeks": [eye_l + Vector2(-d * 0.02, d * 0.37), eye_r + Vector2(d * 0.02, d * 0.37)],
		"skin": skin,
		"lid_top": skin.darkened(0.06),
		"lid_bottom": cheek,
		"lash": Color8(30, 16, 22),
		"lips": _sample(mouth).darkened(0.1),
		"chest_top": neck.y + d * 0.9,
		"chest_bottom": neck.y + d * 3.9,
		"skirt_top": top + (feet - top) * 0.66,
	})
	return rig


func _sample(p: Vector2) -> Color:
	var x := clampi(int(p.x), 0, _image.get_width() - 1)
	var y := clampi(int(p.y), 0, _image.get_height() - 1)
	var c := _image.get_pixel(x, y)
	c.a = 1.0
	return c


func _save() -> void:
	var name_text := _name.text.strip_edges()
	if name_text.is_empty():
		_show("Ponle un nombre.", true)
		return
	var id := "custom_%d" % Time.get_unix_time_from_system()
	var dir := Characters.CUSTOM_DIR + "/" + id
	DirAccess.make_dir_recursive_absolute(dir)
	var data := {
		"format": "micia-character", "version": 1,
		"name": name_text,
		"identity": _identity.text.strip_edges(),
		"appearance": _appearance.text.strip_edges(),
		"personality_base": _personality.get_item_metadata(_personality.selected),
		"personality_text": _personality_text.text.strip_edges(),
		"temper": _temper.value, "affection": _affection.value, "patience": _patience.value,
		"voice_pitch": _pitch.value,
		"adult": _adult.button_pressed,
	}
	if _image:
		_image.save_webp(dir + "/image.webp", false, 0.92)
		data["illustration"] = "image.webp"
		data["rig"] = Characters.rig_to_json(_build_rig())
	elif not _puppet_bytes.is_empty():
		var file := FileAccess.open(dir + "/model.puppet", FileAccess.WRITE)
		file.store_buffer(_puppet_bytes)
		file.close()
		data["model"] = "model.puppet"
	JsonStore.save_json(dir + "/data.json", data)
	Characters.register_custom(id, data)
	_show("¡%s creada!" % name_text, false)
	created.emit(id)


## Carga un .micia (JSON con la imagen incluida) en el formulario.
func _import_micia(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or data.get("format") != "micia-character":
		_show("Ese archivo no es un personaje de micIA.", true)
		return
	_name.text = str(data.get("name", ""))
	_identity.text = str(data.get("identity", ""))
	_appearance.text = str(data.get("appearance", ""))
	_personality_text.text = str(data.get("personality_text", ""))
	for i in _personality.item_count:
		if _personality.get_item_metadata(i) == data.get("personality_base"):
			_personality.select(i)
	_temper.value = float(data.get("temper", 1.0))
	_affection.value = float(data.get("affection", 1.0))
	_patience.value = float(data.get("patience", 80.0))
	_pitch.value = float(data.get("voice_pitch", 1.0))
	_adult.button_pressed = bool(data.get("adult", true))
	if data.has("image_webp_base64"):
		var image := Image.new()
		if image.load_webp_from_buffer(Marshalls.base64_to_raw(str(data["image_webp_base64"]))) == OK:
			_set_image(image)
			var rig: Dictionary = Characters.rig_from_json(data.get("rig", {}))
			if rig.has("eyes"):
				_marks = [rig["eyes"][0], rig["eyes"][1], rig["mouth"], rig["neck"]]
				_update_mark_hint()
	_model_label.text = "Personaje importado: %s" % path.get_file()


## Guarda el personaje actual (si es creado) como .micia en Descargas.
func _export_current() -> void:
	var id := str(Settings.get_value("character"))
	var dir := Characters.CUSTOM_DIR + "/" + id
	if not FileAccess.file_exists(dir + "/data.json"):
		_show("Solo se pueden exportar los personajes que creaste aquí.", true)
		return
	var data: Dictionary = JsonStore.load_json(dir + "/data.json", {})
	if data.has("illustration"):
		data["image_webp_base64"] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(dir + "/" + str(data["illustration"])))
		data.erase("illustration")
	var folder := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var path := folder.path_join("%s.micia" % str(data.get("name", "personaje")).to_lower().replace(" ", "_"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		path = "user://%s.micia" % id
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_show("No pude guardar el archivo.", true)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	_show("Guardado en %s" % ProjectSettings.globalize_path(path), false)


func _show(text: String, error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UIStyle.ERROR_TEXT if error else Color("2a9d4b"))
