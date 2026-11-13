class_name MicMod
extends Node
## Base de todos los mods de micIA.
##
## Un mod es una carpeta dentro de mods/ (o user://mods/ en el dispositivo)
## con un archivo mod.gd que extiende MicMod. Copia mods/_plantilla para
## empezar. Todos los métodos son opcionales: implementa solo los que uses.
##
## Como es un Node, un mod también puede usar _process, Timers, HTTPRequest,
## WebSockets, etc. (por ejemplo para conectarse a otro programa).

## Acceso a la app. En on_register() solo sirven los api.register_*; el
## resto (chat, avatar, botones...) desde on_ready().
var api: ModApi


## Datos del mod (se muestran en Ajustes).
func mod_info() -> Dictionary:
	return {"name": "Mod sin nombre", "version": "1.0", "author": "", "description": ""}


## 1) Al cargar, ANTES de construir la interfaz. Aquí se registran personajes,
##    conjuntos de ropa, personalidades, regalos y juegos (api.register_*).
func on_register() -> void:
	pass


## 2) Cuando la interfaz ya existe. Aquí se agregan botones o paneles.
func on_ready() -> void:
	pass


## Antes de enviar tu mensaje a la IA. Devuelve el texto (modificado o no).
func on_user_message(text: String) -> String:
	return text


## Texto extra para el prompt de sistema (reglas o contexto de tu mod).
func extra_system_prompt() -> String:
	return ""


## Cada vez que llega una respuesta de ella (ya aplicada al ánimo).
func on_reply(_reply: AIReply) -> void:
	pass


## Cuando tocas el avatar (punto en coordenadas de pantalla).
func on_avatar_touched(_point: Vector2) -> void:
	pass


## Cuando se guardan los Ajustes.
func on_settings_changed() -> void:
	pass
