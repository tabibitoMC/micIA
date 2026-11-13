class_name PhotoPicker
extends Node
## Abre el selector de archivos del sistema para elegir una foto.
##
## Usa el diálogo nativo cuando existe (Android, Windows, Linux con portal);
## si no, el diálogo propio de Godot.

signal photo_chosen(image: Image)
signal failed(message: String)

var _dialog: FileDialog


func _ready() -> void:
	_dialog = FileDialog.new()
	_dialog.title = "Elige una foto"
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imágenes"])
	_dialog.use_native_dialog = true
	_dialog.file_selected.connect(_on_file_selected)
	add_child(_dialog)


func open() -> void:
	if OS.get_name() == "Android":
		# Necesario solo si el sistema cae al diálogo de Godot.
		OS.request_permissions()
	_dialog.popup_centered_ratio(0.9)


func _on_file_selected(path: String) -> void:
	var image := ImageUtils.load_any(path)
	if image == null or image.is_empty():
		failed.emit("No pude abrir esa imagen.")
		return
	photo_chosen.emit(image)
