# Mods de micIA

Un mod es una carpeta con un archivo `mod.gd`. La app lo carga sola al iniciar.

```
mods/
  _plantilla/        ← plantilla (se ignora por empezar con "_")
  ejemplo_saludo/    ← ejemplo (desactivado por el archivo "disabled")
  mi_mod/
    mod.gd           ← obligatorio: "extends MicMod"
    (lo que quieras: escenas, imágenes, .vrm, otros scripts)
```

**Dónde se buscan:**
- `res://mods/` → dentro del proyecto. Se empaquetan en el APK y en el ejecutable.
- `user://mods/` → en el dispositivo, para agregar mods sin recompilar. En Linux suele estar en `~/.local/share/godot/app_userdata/micIA/mods/`.

**Desactivar un mod:** crea un archivo vacío llamado `disabled` dentro de su carpeta.

## Crear uno

1. Copia `_plantilla` como `mods/mi_mod/`.
2. Rellena `mod_info()` y los métodos que necesites (todos son opcionales).
3. Ejecuta el proyecto. En Ajustes → Mods aparece si se cargó, y los errores salen en el chat.

## Ganchos (métodos de `MicMod`)

| Método | Cuándo |
|---|---|
| `on_register()` | Al cargar, antes de la interfaz. Para `api.register_*`. |
| `on_ready()` | La interfaz existe. Para botones, paneles y conexiones. |
| `on_user_message(text) -> String` | Antes de enviar tu mensaje a la IA; puedes modificarlo. |
| `extra_system_prompt() -> String` | Texto que se añade al prompt de sistema. |
| `on_reply(reply: AIReply)` | Cada respuesta de ella (texto, emoción, acción, picante...). |
| `on_avatar_touched(point)` | Al tocar el avatar. |
| `on_settings_changed()` | Al guardar Ajustes. |

Como `MicMod` es un `Node`, también puedes usar `_process`, `Timer`, `HTTPRequest`, `WebSocketPeer`, etc.

## `api` (ModApi)

```gdscript
api.say("texto", "feliz", "saludar")       # ella habla (local, sin gastar IA)
api.post_event("descripción para la IA", "texto en el chat")  # ella reacciona con Mistral
api.system_message("aviso")
api.add_side_button("Mi botón", func(): ..., SideButton.Icon.HEART)
api.open_panel(mi_control)                 # ventana centrada; api.close_panel()
api.register_character("id", {...})        # mismo formato que src/characters/characters.gd
api.register_outfit("vita", {"id": "x", "label": "X", "model": "res://mods/mi_mod/x.vrm"})
api.register_personality("id", {...})      # formato de src/ai/personalities.gd
api.register_gift("id", {"label": "...", "anger_relief": 20.0, "affection": 3.0})
api.register_game("Nombre", preload("res://mods/mi_mod/mi_juego.gd"))  # extends MiniGame
api.load_data("mi_mod") / api.save_data("mi_mod", {...})
api.avatar / api.brain / api.chat / api.voice / api.room   # acceso directo
```

Autoloads disponibles en cualquier mod: `Settings`, `Memory`, `Mood`, `Relationship`, `Mods`.

## Idea: conectar con otro programa (p. ej. Minecraft)

Un mod puede abrir un `WebSocketPeer` o hacer peticiones `HTTPRequest` hacia un servidor o plugin del juego. Con `api.post_event(...)` le avisas a ella lo que pasa ("te mataron", "encontraste diamantes"), y en `on_reply` puedes mandar comandos de vuelta.
