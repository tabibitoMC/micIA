class_name PhoneActions
extends RefCounted
## Cosas que ella puede hacer en el teléfono cuando él se lo pide:
## abrir YouTube, buscar en internet, abrir mapas o apps, poner alarmas...
##
## Ninguna API de IA controla el teléfono: la IA solo contesta en su JSON
## el campo "telefono" ({"accion": "alarma", "hora": 7, ...}) y es esta
## clase la que lo ejecuta, con enlaces (OS.shell_open) o con Intents de
## Android (JavaClassWrapper + el plugin AndroidRuntime de Godot 4.4+).
## Por eso funciona igual con Groq y con Gemini.
##
## Las alarmas usan las apps de reloj del sistema (AlarmClock.ACTION_SET_ALARM),
## que necesitan el permiso com.android.alarm.permission.SET_ALARM, y abrir
## apps instaladas necesita android.permission.QUERY_ALL_PACKAGES (los dos
## están en export_presets.cfg).

const ACTIONS := ["youtube", "buscar", "abrir_url", "maps", "musica", "abrir_app",
	"alarma", "temporizador", "llamar", "camara", "ajustes"]

## Nombres comunes de apps → paquete de Android.
const APPS := {
	"youtube": "com.google.android.youtube",
	"youtube music": "com.google.android.apps.youtube.music",
	"whatsapp": "com.whatsapp",
	"telegram": "org.telegram.messenger",
	"instagram": "com.instagram.android",
	"facebook": "com.facebook.katana",
	"messenger": "com.facebook.orca",
	"tiktok": "com.zhiliaoapp.musically",
	"twitter": "com.twitter.android",
	"x": "com.twitter.android",
	"spotify": "com.spotify.music",
	"netflix": "com.netflix.mediaclient",
	"discord": "com.discord",
	"gmail": "com.google.android.gm",
	"chrome": "com.android.chrome",
	"maps": "com.google.android.apps.maps",
	"google maps": "com.google.android.apps.maps",
	"google": "com.google.android.googlequicksearchbox",
	"play store": "com.android.vending",
	"tienda": "com.android.vending",
	"fotos": "com.google.android.apps.photos",
	"google fotos": "com.google.android.apps.photos",
	"calendario": "com.google.android.calendar",
	"reloj": "com.google.android.deskclock",
	"calculadora": "com.google.android.calculator",
	"drive": "com.google.android.apps.docs",
	"twitch": "tv.twitch.android.app",
	"reddit": "com.reddit.frontpage",
	"pinterest": "com.pinterest",
	"duolingo": "com.duolingo",
	"uber": "com.ubercab",
	"steam": "com.valvesoftware.android.steam.community",
}

## Si la app no está instalada, se abre su web.
const APP_WEBS := {
	"com.google.android.youtube": "https://www.youtube.com",
	"com.whatsapp": "https://web.whatsapp.com",
	"com.instagram.android": "https://www.instagram.com",
	"com.facebook.katana": "https://www.facebook.com",
	"com.zhiliaoapp.musically": "https://www.tiktok.com",
	"com.twitter.android": "https://x.com",
	"com.spotify.music": "https://open.spotify.com",
	"com.netflix.mediaclient": "https://www.netflix.com",
	"com.google.android.gm": "https://mail.google.com",
	"com.google.android.apps.maps": "https://maps.google.com",
	"com.reddit.frontpage": "https://www.reddit.com",
}


## Ejecuta la acción. Devuelve un texto corto para el chat ("Abriendo YouTube")
## o, si no se pudo, uno que empieza con "No pude".
static func perform(data: Dictionary) -> String:
	var action := str(data.get("accion", "")).strip_edges().to_lower()
	var query := str(data.get("consulta", "")).strip_edges()
	match action:
		"youtube":
			if query.is_empty():
				return _open_app_or_web("com.google.android.youtube", "YouTube")
			return _open_url("https://www.youtube.com/results?search_query=" + query.uri_encode(), "Buscando «%s» en YouTube" % query)
		"buscar":
			if query.is_empty():
				return "No pude buscar: no me dijo qué."
			return _open_url("https://www.google.com/search?q=" + query.uri_encode(), "Buscando «%s»" % query)
		"abrir_url":
			var url := str(data.get("url", query)).strip_edges()
			if not url.begins_with("https://") and not url.begins_with("http://"):
				if url.is_empty() or url.contains(" "):
					return "No pude abrir la página: la dirección no es válida."
				url = "https://" + url
			return _open_url(url, "Abriendo " + url.trim_prefix("https://").trim_prefix("http://").left(40))
		"maps":
			if query.is_empty():
				return _open_app_or_web("com.google.android.apps.maps", "Mapas")
			return _open_url("https://www.google.com/maps/search/?api=1&query=" + query.uri_encode(), "Buscando «%s» en el mapa" % query)
		"musica":
			if query.is_empty():
				return _open_app_or_web("com.spotify.music", "Spotify")
			return _open_url("https://music.youtube.com/search?q=" + query.uri_encode(), "Buscando «%s» en YouTube Music" % query)
		"abrir_app":
			return _open_named_app(str(data.get("app", query)))
		"alarma":
			return _set_alarm(int(data.get("hora", -1)), int(data.get("minuto", 0)), str(data.get("mensaje", "")))
		"temporizador":
			return _set_timer(int(data.get("segundos", 0)), str(data.get("mensaje", "")))
		"llamar":
			var number := str(data.get("numero", query)).strip_edges()
			var digits := ""
			for c in number:
				if c in "+0123456789":
					digits += c
			if digits.length() < 3:
				return "No pude marcar: el número no es válido."
			# Solo abre el marcador con el número: llamar lo decide él.
			return _open_url("tel:" + digits, "Marcando " + digits)
		"camara":
			return _start_intent("intent:#Intent;action=android.media.action.STILL_IMAGE_CAMERA;end", "Abriendo la cámara")
		"ajustes":
			return _start_intent("intent:#Intent;action=android.settings.SETTINGS;end", "Abriendo los ajustes")
	return ""


static func is_android() -> bool:
	return OS.get_name() == "Android"


static func _open_url(url: String, done: String) -> String:
	var error := OS.shell_open(url)
	return done if error == OK else "No pude abrir eso en este dispositivo."


static func _open_named_app(name: String) -> String:
	var key := name.strip_edges().to_lower()
	if key.is_empty():
		return "No pude abrir la app: no me dijo cuál."
	var package := str(APPS.get(key, ""))
	if package.is_empty() and key.count(".") >= 2 and not key.contains(" "):
		package = key
	if package.is_empty():
		package = _find_installed_app(key)
	if package.is_empty():
		return "No pude abrir «%s»: no la encontré en el teléfono." % name
	return _open_app_or_web(package, name.capitalize())


static func _open_app_or_web(package: String, label: String) -> String:
	if is_android():
		var started := _start_intent(
			"intent:#Intent;action=android.intent.action.MAIN;category=android.intent.category.LAUNCHER;launchFlags=0x10200000;package=%s;end" % package,
			"Abriendo " + label)
		if not started.begins_with("No pude"):
			return started
	if APP_WEBS.has(package):
		return _open_url(APP_WEBS[package], "Abriendo " + label)
	if is_android():
		return _open_url("market://details?id=" + package, "%s no está instalada: abriendo la tienda" % label)
	return "No pude abrir %s en este dispositivo." % label


static func _set_alarm(hour: int, minute: int, message: String) -> String:
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return "No pude poner la alarma: la hora no es válida."
	if not is_android():
		return "No pude poner la alarma: eso solo funciona en Android."
	var label := message.strip_edges().left(60)
	if label.is_empty():
		label = str(Settings.get_value("companion_name"))
	var uri := "intent:#Intent;action=android.intent.action.SET_ALARM;launchFlags=0x10000000;i.android.intent.extra.alarm.HOUR=%d;i.android.intent.extra.alarm.MINUTES=%d;S.android.intent.extra.alarm.MESSAGE=%s;B.android.intent.extra.alarm.SKIP_UI=true;end" % [
		hour, minute, label.uri_encode()]
	return _start_intent(uri, "Alarma puesta a las %02d:%02d" % [hour, minute])


static func _set_timer(seconds: int, message: String) -> String:
	if seconds <= 0 or seconds > 24 * 3600:
		return "No pude poner el temporizador: el tiempo no es válido."
	if not is_android():
		return "No pude poner el temporizador: eso solo funciona en Android."
	var label := message.strip_edges().left(60)
	if label.is_empty():
		label = str(Settings.get_value("companion_name"))
	var uri := "intent:#Intent;action=android.intent.action.SET_TIMER;launchFlags=0x10000000;i.android.intent.extra.alarm.LENGTH=%d;S.android.intent.extra.alarm.MESSAGE=%s;B.android.intent.extra.alarm.SKIP_UI=true;end" % [
		seconds, label.uri_encode()]
	var minutes := seconds / 60
	var text := ("Temporizador de %d min" % minutes) if seconds % 60 == 0 else ("Temporizador de %d s" % seconds)
	return _start_intent(uri, text)


## Lanza un Intent descrito como URI "intent:#Intent;...;end".
## Con Intent.parseUri los extras van con su tipo (i. = int, S. = texto,
## B. = booleano), así no hay dudas de qué versión de putExtra usar.
static func _start_intent(uri: String, done: String) -> String:
	if not is_android():
		return "No pude hacerlo: eso solo funciona en Android."
	var activity: Variant = _activity()
	if activity == null:
		return "No pude hacerlo: Android no me dejó acceder al sistema."
	var intent_class: Variant = JavaClassWrapper.wrap("android.content.Intent")
	if intent_class == null:
		return "No pude hacerlo: Android no me dejó acceder al sistema."
	var intent: Variant = intent_class.parseUri(uri, 0)
	if intent == null or _java_failed():
		return "No pude hacerlo (Intent inválido)."
	# Si ninguna app sabe hacerlo, startActivity fallaría.
	var component: Variant = intent.resolveActivity(activity.getPackageManager())
	if component == null:
		return "No pude hacerlo: no hay ninguna app en el teléfono que sepa hacerlo."
	activity.startActivity(intent)
	if _java_failed():
		return "No pude hacerlo: Android lo rechazó."
	return done


## Busca entre las apps instaladas una cuyo nombre visible contenga el texto.
static func _find_installed_app(name: String) -> String:
	if not is_android():
		return ""
	var activity: Variant = _activity()
	if activity == null:
		return ""
	var pm: Variant = activity.getPackageManager()
	var apps: Variant = pm.getInstalledApplications(0)
	if apps == null or _java_failed():
		return ""
	var count := int(apps.size())
	for i in count:
		var info: Variant = apps.get(i)
		if info == null:
			continue
		var label := str(info.loadLabel(pm).toString()).to_lower()
		if label == name or (name.length() >= 4 and label.contains(name)):
			# JavaClassWrapper no lee campos (packageName), pero toString()
			# da "ApplicationInfo{1a2b3c com.ejemplo.app}".
			var package := str(info.toString()).trim_suffix("}").get_slice(" ", 1)
			if not package.is_empty() and pm.getLaunchIntentForPackage(package) != null:
				return package
	return ""


static func _activity() -> Variant:
	if not Engine.has_singleton("AndroidRuntime"):
		return null
	return Engine.get_singleton("AndroidRuntime").getActivity()


## Godot 4.4+ guarda la última excepción de Java en vez de cerrar la app.
static func _java_failed() -> bool:
	if JavaClassWrapper.has_method("get_exception"):
		var exception: Variant = JavaClassWrapper.get_exception()
		if exception != null:
			push_warning("PhoneActions: " + str(exception))
			return true
	return false
