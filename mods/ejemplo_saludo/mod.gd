extends MicMod
## Mod de ejemplo (desactivado por el archivo "disabled" de esta carpeta;
## bórralo para probarlo). Agrega un botón "Saludo" que hace que ella salude
## sin gastar peticiones a la IA, y un regalo nuevo.


func mod_info() -> Dictionary:
	return {"name": "Ejemplo: saludo", "version": "1.0", "author": "micIA", "description": "Botón que la hace saludar."}


func on_register() -> void:
	api.register_gift("galleta", {"label": "Galleta", "anger_relief": 15.0, "affection": 2.0})


func on_ready() -> void:
	api.add_side_button("Saludo", _on_greet, SideButton.Icon.HEART)


func _on_greet() -> void:
	api.say("¡Hola! ¿Me llamabas?", "feliz", "saludar")
