extends Node
## Autoload "Mods": busca y carga los mods.
##
## Carpetas (en este orden):
##   res://mods/<nombre>/mod.gd   -> van dentro del APK / ejecutable
##   user://mods/<nombre>/mod.gd  -> se agregan en el dispositivo sin recompilar
##
## Se ignoran las carpetas que empiezan con "_" (como _plantilla) y las que
## tienen un archivo llamado "disabled".

const MOD_DIRS := ["res://mods", "user://mods"]

var mods: Array[MicMod] = []
var errors: PackedStringArray = []
var _loaded := false
var _api: ModApi


## Paso 1: cargar mods y dejar que registren contenido (on_register).
## `api` ya está disponible, pero la interfaz todavía no existe.
func load_all(api: ModApi) -> void:
	if _loaded:
		return
	_loaded = true
	_api = api
	for base in MOD_DIRS:
		if not DirAccess.dir_exists_absolute(base):
			continue
		for folder in DirAccess.get_directories_at(base):
			if folder.begins_with("_"):
				continue
			var dir := "%s/%s" % [base, folder]
			if FileAccess.file_exists(dir + "/disabled"):
				continue
			_load_mod(dir, folder)


## Paso 2: la interfaz está lista (on_ready).
func app_ready() -> void:
	for mod in mods:
		mod.on_ready()


func info_list() -> PackedStringArray:
	var list: PackedStringArray = []
	for mod in mods:
		var info := mod.mod_info()
		list.append("%s %s" % [info.get("name", mod.name), info.get("version", "")])
	return list


# --- Ganchos (los llama la app) --------------------------------------------

func filter_user_message(text: String) -> String:
	for mod in mods:
		text = mod.on_user_message(text)
	return text


func extra_prompt() -> String:
	var parts: PackedStringArray = []
	for mod in mods:
		var extra := mod.extra_system_prompt()
		if not extra.is_empty():
			parts.append(extra)
	return "\n".join(parts)


func notify_reply(reply: AIReply) -> void:
	for mod in mods:
		mod.on_reply(reply)


func notify_touch(point: Vector2) -> void:
	for mod in mods:
		mod.on_avatar_touched(point)


func notify_settings_changed() -> void:
	for mod in mods:
		mod.on_settings_changed()


func _load_mod(dir: String, folder: String) -> void:
	var path := dir + "/mod.gd"
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return
	var script := load(path) as GDScript
	if script == null:
		errors.append("%s: no se pudo compilar mod.gd" % folder)
		return
	var instance: Object = script.new()
	if not instance is MicMod:
		errors.append("%s: mod.gd debe empezar con 'extends MicMod'" % folder)
		if instance is Node:
			instance.queue_free()
		return
	var mod := instance as MicMod
	mod.name = folder
	mod.api = _api
	add_child(mod)
	mods.append(mod)
	mod.on_register()
