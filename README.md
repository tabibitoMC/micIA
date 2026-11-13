# micIA

Proyecto personal de una asistente / amiga con IA. No lo voy a comercializar ni a publicar en tiendas: es de uso personal y está hecho con vibe coding, porque no es un proyecto serio. Si quieres clonarlo, adelante.

- **Motor:** Godot 4.7 (GDScript; funciona también con el editor "mono"/.NET)
- **IA:** API de Mistral (plan gratuito)
- **Plataformas:** Android (APK) y Linux ARM64 (consolas tipo Anbernic)

## Estado

| Fase | Qué incluye | Estado |
|---|---|---|
| 1 | Chat con Mistral, respuestas JSON (texto + emoción + acción), memoria, personalidades, enojo/afecto, bloqueo, regalos, voz (TTS del sistema) | ✅ |
| 2 | Avatar 3D (VRM) con expresiones, parpadeo, boca al hablar y gestos; interfaz pastel | ✅ (cara 2D como respaldo) |
| 3 | Animaciones, moverse por la interfaz y tocar botones | ⏳ |
| 4 | Enviarle fotos (las ve con visión de Mistral) y que ella genere imágenes/selfies | ✅ |
| Futuro | Personalidad adaptativa según cómo la tratas | base lista (`Mood.recent_treatment`) |

## Estructura

```
src/
  app/      main.tscn + main.gd   → pantalla principal; solo conecta las piezas
  core/     settings.gd (autoload Settings), json_store.gd, image_utils.gd
  ai/       brain.gd              → arma la conversación y llama a Mistral
            mistral_api.gd        → capa HTTP común (reintentos, errores)
            mistral_client.gd     → chat (/v1/chat/completions, con visión)
            image_generator.gd    → imágenes (Agents API + image_generation)
            ai_reply.gd           → valida el JSON que devuelve la IA
            prompt_builder.gd     → construye el prompt de sistema
            personalities.gd      → catálogo de personalidades
  state/    memory.gd (autoload Memory) → historial y recuerdos
            mood.gd   (autoload Mood)   → enojo, afecto, bloqueo, registro de trato
            gifts.gd                    → catálogo de regalos
  voice/    voice.gd              → texto a voz del sistema
  avatar/   avatar.gd             → contrato común de avatares
            avatar_3d.gd          → modelo VRM en un SubViewport transparente
            avatar_2d.gd          → cara 2D de respaldo (dispositivos lentos)
            vrm/vrm_expression_mixer.gd → mezcla expresiones (emoción + parpadeo + boca)
            vrm/vrm_body_poser.gd       → pose y gestos procedurales (sin archivos de animación)
  ui/       chat_view, mood_bar, side_button, block_card, room_background,
            settings_panel, gift_panel, photo_picker, image_viewer,
            ui_style (paleta y estilos)
addons/     godot-vrm y MToon (V-Sekai, MIT): importan los .vrm
assets/models/companion.vrm → el modelo de ella
```

Las reglas que sigue el código:
- **La IA solo propone; el código decide.** Mistral devuelve un JSON con emoción, acción y cuánto cambiar el enojo o el afecto; `AIReply` lo valida y `Mood` aplica los límites.
- **Cada pieza emite señales y no conoce la interfaz.** `main.gd` es el único que las conecta.
- **Todo avatar implementa `Avatar`** (`set_emotion`, `play_action`, `set_talking`), así el 2D se cambia por el 3D sin tocar el resto.

## Fotos e imágenes

- **Mandarle fotos:** botón "Foto". Lo que tengas escrito en la caja se envía como pie de foto. Ella la ve con un modelo con visión (`mistral-small-latest` la tiene).
- **Imágenes de ella:** cuando le pides un dibujo o una selfie, la IA llena el campo `imagen` y la app la genera con la herramienta `image_generation` de Mistral (agente creado automáticamente). Para que sus selfies se parezcan a ella, ajusta **"Su apariencia"** en Ajustes. No está confirmado que esta herramienta funcione en el plan gratuito; si no, verás el error en el chat.

## Cambiar el modelo

Reemplaza `assets/models/companion.vrm` por tu propio `.vrm` (VRoid Studio, VRoid Hub...) con el mismo nombre y vuelve a abrir el proyecto. Cualquier VRM humanoide sirve: las expresiones y los gestos se adaptan solos.

El modelo incluido es **Alicia Solid** (© DWANGO), el modelo de referencia oficial de VRM. Su licencia permite el uso personal; está en `assets/models/LICENSE_MODELO.txt`.

Si el 3D va lento (por ejemplo en la consola), en Ajustes apaga **Avatar 3D** y se usa la cara 2D.

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
