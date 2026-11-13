class_name JsonStore
extends RefCounted
## Utilidades para leer y guardar datos JSON en disco (normalmente en user://).


## Lee un archivo JSON. Devuelve `fallback` si no existe, no se puede leer
## o su contenido no es del mismo tipo que `fallback`.
static func load_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null or typeof(data) != typeof(fallback):
		return fallback
	return data


static func save_json(path: String, data: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true
