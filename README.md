# micIA

Proyecto personal de una asistente / amiga con IA. No lo voy a comercializar ni a publicar en tiendas: es de uso personal y está hecho con vibe coding, porque no es un proyecto serio. Si quieres clonarlo, adelante.

- **Motor:** Godot 4.7 (GDScript; funciona también con el editor "mono"/.NET)
- **IA:** API de Mistral (plan gratuito)
- **Plataformas:** Android (APK) y Linux ARM64 (consolas tipo Anbernic)

## Estado

| Fase | Qué incluye | Estado |
|---|---|---|
| 1 | Chat con Mistral, respuestas JSON (texto + emoción + acción), memoria, personalidades, enojo/afecto, bloqueo, regalos, voz (TTS del sistema) | ✅ |
| 2 | Avatar 3D (VRM) con expresiones | ⏳ (por ahora hay una cara 2D provisional) |
| 3 | Animaciones, moverse por la interfaz y tocar botones | ⏳ |
| 4 | Enviarle fotos, generar imágenes | ⏳ |
| Futuro | Personalidad adaptativa según cómo la tratas | base lista (`Mood.recent_treatment`) |

## Estructura

```
src/
  app/      main.tscn + main.gd   → pantalla principal; solo conecta las piezas
  core/     settings.gd (autoload Settings), json_store.gd
  ai/       brain.gd              → arma la conversación y llama a Mistral
            mistral_client.gd     → HTTP a /v1/chat/completions
            ai_reply.gd           → valida el JSON que devuelve la IA
            prompt_builder.gd     → construye el prompt de sistema
            personalities.gd      → catálogo de personalidades
  state/    memory.gd (autoload Memory) → historial y recuerdos
            mood.gd   (autoload Mood)   → enojo, afecto, bloqueo, registro de trato
            gifts.gd                    → catálogo de regalos
  voice/    voice.gd              → texto a voz del sistema
  avatar/   avatar.gd             → contrato común de avatares
            avatar_2d.gd          → cara 2D provisional
  ui/       chat_view, mood_bar, settings_panel, gift_panel, ui_style
assets/     íconos y (más adelante) el modelo VRM
```

Las reglas que sigue el código:
- **La IA solo propone; el código decide.** Mistral devuelve un JSON con emoción, acción y cuánto cambiar el enojo o el afecto; `AIReply` lo valida y `Mood` aplica los límites.
- **Cada pieza emite señales y no conoce la interfaz.** `main.gd` es el único que las conecta.
- **Todo avatar implementa `Avatar`** (`set_emotion`, `play_action`, `set_talking`), así el 2D se cambia por el 3D sin tocar el resto.

## Cómo probar en PC

1. Abre la carpeta con Godot 4.7 → **Importar** → selecciona `project.godot`.
2. Pulsa ▶ (F5).
3. En **Ajustes**, pega tu API key de Mistral ([console.mistral.ai](https://console.mistral.ai) → API Keys) y guarda.

Para no escribir la clave cada vez en PC, también puedes crear `config.json` en la raíz (está en `.gitignore`, no se sube):
```json
{ "api_key": "TU_CLAVE", "user_name": "Nick" }
```

Los datos (ajustes, historial, ánimo) se guardan en `user://`. En Windows es `%APPDATA%\Godot\app_userdata\micIA`.

## Exportar

Primero: **Editor → Gestionar plantillas de exportación → Descargar**.

### Android (APK)
1. Instala **JDK 17** y el **Android SDK** (lo más fácil es con Android Studio).
2. Godot → **Editor → Configuración del editor → Exportar → Android**: pon la ruta del SDK y del JDK.
3. **Proyecto → Exportar → Añadir… → Android**.
4. En **Permisos**, marca **Internet**. Sin esto la app no puede hablar con Mistral.
5. **Exportar proyecto** → `micia.apk` → instálalo en el teléfono.

### Linux ARM64 (consola)
1. **Proyecto → Exportar → Añadir… → Linux**.
2. **Arquitectura: arm64**.
3. Exporta y copia el ejecutable a la consola (junto al `.pck`, si no marcaste "embed PCK").
4. Para tener voz, la consola necesita `speech-dispatcher`. Sin él, la app funciona igual, pero sin voz.

> Si la exportación da problemas con el editor mono/.NET, usa el Godot 4.7 normal (no .NET). El proyecto es solo GDScript, así que funciona igual.
