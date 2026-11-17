# micIA

Proyecto personal de una asistente / amiga con IA. No lo voy a comercializar ni a publicar en tiendas: es de uso personal y está hecho con vibe coding, porque no es un proyecto serio. Si quieres clonarlo, adelante.

- **Motor:** Godot 4.7 (GDScript; funciona también con el editor "mono"/.NET)
- **IA:** API de Mistral (plan gratuito)
- **Plataformas:** Android (APK) y Linux ARM64 (consolas tipo Anbernic)

## Versión 2.0 — Groq + avatar 2D

- **IA:** Groq (`https://api.groq.com/openai/v1`). Chat con `openai/gpt-oss-120b`; las fotos van a `qwen/qwen3.8-27b`. La clave se pide al abrir la app (console.groq.com → Claves API).
- **Avatar:** marioneta 2D por capas estilo VTuber (`src/avatar/puppet/puppet.gd` + `src/avatar/avatar_puppet.gd`): físicas en pelo, orejas y cola, parpadeo, boca al hablar, emociones y gestos. Ya no hay avatar 3D ni addons de VRM.
- **Modelo:** `assets/puppets/aka.puppet` (Aka, de los ejemplos de Inochi2D, CC BY 4.0, seagetch).
- **Tu propio modelo:** ármalo en Inochi Creator (gratis), exporta el `.inx` y conviértelo:
  `python3 tools/bake_puppet.py MiModelo.inx assets/puppets/mimodelo.puppet` (alta calidad, 2 subdivisiones) y `python3 tools/bake_puppet.py MiModelo.inx assets/puppets/mimodelo_normal.puppet --subdivide 1` (calidad normal), y pon la primera ruta en `src/characters/characters.gd`. No soporta MeshGroup.
- **Brazos:** Aka tiene un solo dibujo de cada brazo (colgando), así que solo se mueven en ángulos pequeños, con física sutil; los gestos grandes se hacen con cuerpo, cabeza y cara. Para levantar los brazos de verdad hay que dibujar brazos aparte por pose (como en Live2D) en tu propio modelo.
- **Lugares:** dormitorio, sala, cocina y patio dibujados en 2D (`src/ui/room_background.gd`); en el dormitorio se acuesta a dormir.

> Las secciones de abajo que hablen de Mistral, VRM o habitaciones 3D describen la versión 1 y ya no aplican.

## Estado

| Fase | Qué incluye | Estado |
|---|---|---|
| 1 | Chat con Mistral, respuestas JSON (texto + emoción + acción), memoria, personalidades, enojo/afecto, bloqueo, regalos, voz (TTS del sistema) | ✅ |
| 2 | Avatar 3D (VRM) con expresiones, parpadeo, boca al hablar y gestos; interfaz pastel | ✅ (cara 2D como respaldo) |
| 3 | Camina por la pantalla, señala botones, cambia el fondo (día/atardecer/noche), pasea sola y te da la espalda al bloquearte | ✅ |
| 4 | Enviarle fotos (las ve con visión de Mistral) y que ella genere imágenes/selfies | ✅ |
| Extra | Tocarla: caricias en la cabeza (toques lentos) y golpes (toques rápidos); ella reacciona y la IA lo registra como trato | ✅ |
| Relación | Confianza (termómetro), rencor, estados temporales (feliz, triste, enojada, dolida, distante, lasciva), pareja, reacciones a comentarios subidos de tono según personalidad | ✅ |
| Minijuegos | Tres en raya, piedra-papel-tijera y ajedrez (Mistral elige entre jugadas legales y comenta) y ping-pong (IA local, Mistral comenta el resultado) | ✅ |
| Vestuario | Botón "Ropa": conjuntos por personaje (variantes de color o .vrm extra hechos en VRoid); ella se entera del cambio | ✅ |
| Mods | Carpeta `mods/` (y `user://mods/`) con ganchos y API para extender la app sin tocar el código principal; ver `mods/README.md` | ✅ |
| Lugares | Habitaciones 3D con muebles (KayKit, CC0): dormitorio, sala, cocina y patio con piscina. Ella va de un lugar a otro caminando, duerme en su cama, y tú puedes llevarla con el botón "Lugar" | ✅ |
| Personajes | Vita (adulta, CC0) y Alicia (solo amistad, sin romance ni +18) con datos separados | ✅ |

## Estructura

```
src/
  app/      main.tscn + main.gd   → pantalla principal; solo conecta las piezas
            interface_actions.gd  → lo que ella hace con la interfaz (caminar, señalar, cambiar fondo)
            touch_interactions.gd → caricias y golpes al tocarla
  core/     settings.gd (autoload Settings), json_store.gd, image_utils.gd, web_request.gd
  characters/ characters.gd       → catálogo de personajes (modelo, adulto o no, apariencia)
  ai/       brain.gd              → arma la conversación y llama a Mistral
            mistral_api.gd        → capa HTTP común (reintentos, errores)
            mistral_client.gd     → chat (/v1/chat/completions, con visión)
            image/                → generador de imágenes con proveedores (Cloudflare, AI Horde, Mistral)
            ai_reply.gd           → valida el JSON que devuelve la IA
            prompt_builder.gd     → construye el prompt de sistema
            personalities.gd      → catálogo de personalidades
  state/    memory.gd (autoload Memory) → historial y recuerdos
            mood.gd   (autoload Mood)   → enojo, afecto, bloqueo, registro de trato
            relationship.gd (autoload Relationship) → confianza, rencor, pareja, estados
            gifts.gd                    → catálogo de regalos
  voice/    voice.gd              → texto a voz del sistema
  avatar/   avatar.gd             → contrato común de avatares
            avatar_3d.gd          → modelo VRM en un SubViewport transparente
            avatar_2d.gd          → cara 2D de respaldo (dispositivos lentos)
            vrm/vrm_expression_mixer.gd → mezcla expresiones (emoción + parpadeo + boca)
            vrm/vrm_body_poser.gd       → pose y gestos procedurales (sin archivos de animación)
  ui/       chat_view, mood_bar, side_button, block_card, room_background,
            settings_panel, gift_panel, outfit_panel, image_request_panel, photo_picker, image_viewer,
            ui_style (paleta y estilos)
  environments/ environments.gd (catálogo de lugares) y room_3d.gd (construye cada habitación)
  games/    mini_game.gd (base), game_ai.gd (Mistral juega), game_panel.gd (menú)
            tic_tac_toe, rock_paper_scissors, ping_pong, chess/ (chess_rules + chess_game)
  mods/     mic_mod.gd (base), mod_api.gd (lo que un mod puede hacer), mod_loader.gd (autoload Mods)
mods/       tus mods (plantilla en mods/_plantilla, guía en mods/README.md)
assets/environment/ muebles KayKit (CC0)
addons/     godot-vrm y MToon (V-Sekai, MIT): importan los .vrm
assets/models/ → vita.vrm, alicia.vrm
```

Las reglas que sigue el código:
- **La IA solo propone; el código decide.** Mistral devuelve un JSON con emoción, acción y cuánto cambiar el enojo o el afecto; `AIReply` lo valida y `Mood` aplica los límites.
- **Cada pieza emite señales y no conoce la interfaz.** `main.gd` es el único que las conecta.
- **Todo avatar implementa `Avatar`** (`set_emotion`, `play_action`, `set_talking`), así el 2D se cambia por el 3D sin tocar el resto.

## Fotos e imágenes

- **Mandarle fotos:** botón "Foto". Lo que tengas escrito en la caja se envía como pie de foto. Ella la ve con un modelo con visión (`mistral-small-latest` la tiene).
- **Imágenes de ella:** cuando le pides un dibujo o una selfie, la IA llena el campo `imagen` y la app la genera probando en orden:
  1. **Cloudflare Workers AI** (FLUX Schnell, ~170 imágenes gratis al día). Pon tu Account ID y un API token en Ajustes.
  2. **AI Horde** (gratis, funciona sin cuenta; con cuenta propia va más rápido).
  3. **Mistral** (si tu plan lo incluye).
  Para que sus selfies se parezcan a ella, ajusta **"Su apariencia"** en Ajustes.
- **Generar tú una imagen:** botón lateral "Imagen". Escribes la descripción y eliges **Cloudflare** o **Comunitaria (AI Horde)**; si la elegida falla se usa la otra. La imagen se le envía a ella (visión de Mistral) para que la vea y opine.

## Relación y confianza

- **Confianza (0-100):** sube despacio si la tratas bien, baja rápido si no. Niveles: Desconocidos, Conocidos, Amigos, Confianza, Muy cercanos, Íntimos, Pareja.
- **Picante:** la IA califica cada mensaje tuyo de 0 a 3. Si pasa su límite actual, se ofende según su personalidad (tsundere insulta y bloquea, yandere te golpea y bloquea, dandere llora y se calla, kuudere se vuelve fría...), sube el rencor y baja la confianza.
- **Estados temporales:** duran unos mensajes. "Lasciva" se activa tras varios mensajes sugerentes con suficiente confianza y se pasa con 10 mensajes normales o si se enoja.
- **Pareja:** con confianza ≥ 90 puedes pedírselo y ella decide.
- **+18:** solo con el personaje adulto, con mucha confianza y con la opción activada en Ajustes. Alicia nunca tiene romance ni contenido sexual. Las imágenes generadas siempre son aptas para todo público.

## Agregar lugares o muebles

En `src/environments/environments.gd` cada lugar tiene colores, ventana y una lista de `props` (`[ruta del modelo, posición, giro, escala]`). Los muebles disponibles están en `assets/environment/`; hay más modelos gratis en los paquetes de KayKit (Furniture Bits, Restaurant Bits) y Kenney.

## Agregar ropa

En `src/characters/characters.gd`, cada personaje tiene `outfits`. Para un conjunto nuevo:
- **Solo color:** `{"id": "rojo", "label": "Rojo", "cloth": Color(1, 0.5, 0.5)}` (y opcional `"hair"`).
- **Otra ropa:** haz el mismo personaje en VRoid con otra vestimenta, expórtalo a `assets/models/vita_pijama.vrm` y agrega `{"id": "pijama", "label": "Pijama", "model": "res://assets/models/vita_pijama.vrm"}`.

## Cambiar el modelo

Reemplaza `assets/models/vita.vrm` por tu propio `.vrm` (VRoid Studio, VRoid Hub...) con el mismo nombre y vuelve a abrir el proyecto. Cualquier VRM humanoide sirve: las expresiones y los gestos se adaptan solos.

Modelos incluidos: **Vita** (muestra de VRoid Studio, licencia CC0) y **Alicia Solid** (© DWANGO, modelo de referencia de VRM, uso personal). Licencias en `assets/models/LICENSE_MODELO.txt`. Para añadir otro personaje, agrega su `.vrm` en `assets/models/` y una entrada en `src/characters/characters.gd`.

Si el 3D va lento (por ejemplo en la consola), en Ajustes apaga **Avatar 3D** y se usa la cara 2D.

## Primer inicio

Al abrir la app por primera vez aparece una pantalla de bienvenida que pide tu nombre, la API key de Mistral (obligatoria) y, opcionalmente, las de Cloudflare y AI Horde. Se guardan solo en el dispositivo (`user://settings.cfg`), nunca en el código. Se cambian después en Ajustes.

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

`export_presets.cfg` ya trae los presets **Android** (arm64, Android 16 / API 36 como objetivo, funciona desde Android 7) y **Linux ARM64**. La contraseña del keystore no se guarda en el repo: ponla en Proyecto → Exportar → Android → Keystore, o usa las variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD`.

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
