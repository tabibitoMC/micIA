class_name ImageProvider
extends RefCounted
## Base de los proveedores de imágenes. Cada uno implementa generate().
##
## Para agregar otro servicio: crear un script que extienda ImageProvider y
## añadirlo a la lista de ImageGenerator._providers().


## Nombre visible (para los mensajes de error).
func display_name() -> String:
	return "?"


## ¿Tiene lo necesario para funcionar (claves, etc.)?
func is_configured() -> bool:
	return true


## Devuelve {"bytes": PackedByteArray} si salió bien o {"error": String}.
func generate(_web: WebRequest, _prompt: String) -> Dictionary:
	return {"error": "No implementado."}
