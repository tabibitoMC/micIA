class_name ImageUtils
extends RefCounted
## Utilidades para cargar, reducir y guardar imágenes (fotos y generadas).

const PHOTOS_DIR := "user://photos"
const GENERATED_DIR := "user://generated"


## Carga una imagen desde una ruta. Si Image.load falla (por ejemplo rutas
## especiales de Android), lee los bytes y detecta el formato.
static func load_any(path: String) -> Image:
	var image := Image.new()
	if image.load(path) == OK:
		return image
	var bytes := FileAccess.get_file_as_bytes(path)
	return from_bytes(bytes)


## Detecta PNG / JPG / WEBP por sus primeros bytes.
static func from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12:
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		err = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = image.load_webp_from_buffer(bytes)
	return image if err == OK else null


## Reduce la imagen para que su lado mayor no pase de max_side píxeles.
static func shrink(image: Image, max_side: int) -> Image:
	var copy := image.duplicate() as Image
	var longest := maxi(copy.get_width(), copy.get_height())
	if longest > max_side:
		var factor := float(max_side) / longest
		copy.resize(int(copy.get_width() * factor), int(copy.get_height() * factor), Image.INTERPOLATE_BILINEAR)
	if copy.get_format() != Image.FORMAT_RGB8 and copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	return copy


## Data URL JPEG en base64 para enviar a la API de visión.
static func to_jpeg_data_url(image: Image, quality := 0.85) -> String:
	var rgb := image.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var jpg := rgb.save_jpg_to_buffer(quality)
	return "data:image/jpeg;base64," + Marshalls.raw_to_base64(jpg)


## Guarda la imagen en una carpeta de user:// y devuelve la ruta.
static func save_to(dir: String, image: Image) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%d_%d.jpg" % [dir, Time.get_unix_time_from_system(), randi() % 10000]
	var rgb := image.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	if rgb.save_jpg(path, 0.9) != OK:
		return ""
	return path


static func texture_from_path(path: String) -> Texture2D:
	var image := load_any(path)
	return ImageTexture.create_from_image(image) if image else null
