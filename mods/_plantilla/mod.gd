extends MicMod
## PLANTILLA DE MOD — cópiala para crear el tuyo:
##   1. Copia esta carpeta y cámbiale el nombre (sin "_" al inicio), p. ej. mods/mi_mod/
##   2. Edita mod_info() y rellena solo los métodos que necesites.
##   3. Abre/ejecuta el proyecto: el mod se carga solo.
## Documentación completa: mods/README.md


func mod_info() -> Dictionary:
	return {
		"name": "Mi mod",
		"version": "1.0",
		"author": "",
		"description": "",
	}


## Registrar contenido (personajes, ropa, personalidades, regalos, juegos).
func on_register() -> void:
	pass


## La interfaz ya existe: agregar botones, paneles, conexiones...
func on_ready() -> void:
	pass


## Antes de enviar tu mensaje a la IA.
func on_user_message(text: String) -> String:
	return text


## Texto extra para el prompt de sistema.
func extra_system_prompt() -> String:
	return ""


## Cada respuesta de ella.
func on_reply(reply: AIReply) -> void:
	pass


## Cuando tocas el avatar.
func on_avatar_touched(point: Vector2) -> void:
	pass


## Cuando se guardan los Ajustes.
func on_settings_changed() -> void:
	pass
