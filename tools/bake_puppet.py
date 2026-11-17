#!/usr/bin/env python3
"""Convierte un modelo de Inochi2D (.inx / .inp) al formato .puppet de micIA.

Uso:
    python3 tools/bake_puppet.py MiModelo.inx assets/puppets/mimodelo.puppet [--scale 0.5]

Inochi Creator (gratis, https://inochi2d.com) es el programa para armar tu
propia VTuber 2D: dibujas las capas (PSD), las importas, les pones mallas,
parámetros y físicas, y exportas el .inx / .inp. Este script lo deja listo
para la app.

Qué hace:
  - Lee el árbol de nodos, los parámetros y las texturas.
  - Rellena los puntos clave vacíos de cada parámetro (igual que Inochi2D).
  - Reduce las texturas (--scale) y rellena el color de los bordes
    transparentes para que no salgan halos.
  - Escribe un único archivo: JSON + deformaciones en binario + texturas WebP.

Soporta lo que usa un modelo "clásico" de Inochi2D: Part, Composite, Node,
SimplePhysics, máscaras, mezclas Normal/Multiply/ClipToLower y parámetros de
1 o 2 ejes. No soporta MeshGroup (modelos de Inochi Creator 0.8+ que lo usen).

Necesita: pip install pillow numpy
"""
import argparse
import io
import json
import struct
import sys

import numpy as np
from PIL import Image

MAGIC = b"MICPUP1\0"
VALUE_DEFAULTS = {"transform.s.x": 1.0, "transform.s.y": 1.0, "opacity": 1.0}


def read_inx(path):
    data = open(path, "rb").read()
    if data[:8] != b"TRNSRTS\0":
        sys.exit("No parece un archivo de Inochi2D (.inx/.inp).")
    pos = 8
    (length,) = struct.unpack(">I", data[pos:pos + 4])
    pos += 4
    puppet = json.loads(data[pos:pos + length])
    pos += length
    textures = []
    if data[pos:pos + 8] == b"TEX_SECT":
        pos += 8
        (count,) = struct.unpack(">I", data[pos:pos + 4])
        pos += 4
        for _ in range(count):
            (length,) = struct.unpack(">I", data[pos:pos + 4])
            pos += 5  # longitud + byte de formato
            textures.append(Image.open(io.BytesIO(data[pos:pos + length])).convert("RGBA"))
            pos += length
    return puppet, textures


# --- Texturas -----------------------------------------------------------------

def _blur(channel, radius):
    # Desenfoque barato: reducir y volver a ampliar (PIL no desenfoca en modo F).
    image = Image.fromarray(channel, mode="F")
    small = (max(1, image.width // radius), max(1, image.height // radius))
    return np.asarray(image.resize(small, Image.BOX).resize(image.size, Image.BILINEAR))


def prepare_texture(image, scale):
    """Reduce la textura y extiende el color hacia las zonas transparentes."""
    rgba = np.asarray(image).astype(np.float32) / 255.0
    alpha = rgba[..., 3]
    # Inochi2D suele guardar el color ya multiplicado por el alfa. Se detecta:
    # con alfa multiplicado, ningún canal supera al alfa.
    semi = (alpha > 0.05) & (alpha < 0.6)
    straight = bool(semi.any()) and float((rgba[..., :3].max(axis=-1)[semi] > alpha[semi] + 0.02).mean()) > 0.02
    premult = rgba[..., :3] * alpha[..., None] if straight else rgba[..., :3]
    if scale != 1.0:
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        alpha_small = np.asarray(Image.fromarray(alpha, mode="F").resize(size, Image.BOX))
        channels = [np.asarray(Image.fromarray(np.ascontiguousarray(premult[..., c]), mode="F").resize(size, Image.BOX)) for c in range(3)]
        alpha = np.clip(alpha_small, 0.0, 1.0)
        premult = np.stack(channels, axis=-1)
    # Alfa casi nulo = transparente del todo (evita velos en los bordes).
    alpha = np.where(alpha < 0.012, 0.0, alpha).astype(np.float32)
    safe = np.maximum(alpha, 1e-4)[..., None]
    color = np.clip(premult / safe, 0.0, 1.0)
    # Relleno multi-escala: de lo más difuso a lo más fino.
    fill = np.zeros_like(color)
    for radius in (48, 16, 6, 2, 1):
        blurred_alpha = _blur(np.ascontiguousarray(alpha), radius)
        valid = blurred_alpha > 1e-3
        for c in range(3):
            blurred = _blur(np.ascontiguousarray(premult[..., c]), radius)
            fill[..., c] = np.where(valid, blurred / np.maximum(blurred_alpha, 1e-3), fill[..., c])
    solid = (alpha > 0.02)[..., None]
    color = np.where(solid, color, np.clip(fill, 0.0, 1.0))
    out = np.concatenate([color, alpha[..., None]], axis=-1)
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), mode="RGBA")


def encode_webp(image, quality):
    buffer = io.BytesIO()
    image.save(buffer, format="WEBP", quality=quality, method=6, exact=True)
    return buffer.getvalue()


# --- Parámetros: relleno de puntos clave (port de reInterpolate de Inochi2D) ---

def reinterpolate(values, is_set, axis_points, default):
    """values[x][y] -> np.array; rellena los puntos no definidos."""
    x_count, y_count = len(axis_points[0]), len(axis_points[1])
    valid = [[bool(is_set[x][y]) for y in range(y_count)] for x in range(x_count)]
    valid_count = sum(sum(col) for col in valid)
    total = x_count * y_count
    if valid_count == 0:
        return [[default.copy() for _ in range(y_count)] for _ in range(x_count)]
    if valid_count == total:
        return values

    state = {"y_major": False}
    newly_set = [[False] * y_count for _ in range(x_count)]
    interp_distance = [[0.0] * y_count for _ in range(x_count)]
    commit = []

    def major_count():
        return y_count if state["y_major"] else x_count

    def minor_count():
        return x_count if state["y_major"] else y_count

    def idx(maj, mnr):
        return (mnr, maj) if state["y_major"] else (maj, mnr)

    def is_valid(maj, mnr):
        x, y = idx(maj, mnr)
        return valid[x][y]

    def is_newly(maj, mnr):
        x, y = idx(maj, mnr)
        return newly_set[x][y]

    def get(maj, mnr):
        x, y = idx(maj, mnr)
        return values[x][y]

    def put(maj, mnr, value):
        x, y = idx(maj, mnr)
        values[x][y] = value

    def mark(maj, mnr):
        x, y = idx(maj, mnr)
        newly_set[x][y] = True
        commit.append((x, y))

    def axis_point(mnr):
        return axis_points[0][mnr] if state["y_major"] else axis_points[1][mnr]

    def interpolate_1d(second_pass):
        state["y_major"] = second_pass
        detected = False
        for i in range(major_count()):
            count = minor_count()
            left = 0
            while left < count and not is_valid(i, left):
                left += 1
            if left >= count:
                continue
            while True:
                while left < count - 1 and is_valid(i, left + 1):
                    left += 1
                if left >= count - 1:
                    break
                right = left + 1
                while right < count and not is_valid(i, right):
                    right += 1
                if right >= count:
                    break
                for m in range(left + 1, right):
                    t = (axis_point(m) - axis_point(left)) / (axis_point(right) - axis_point(left))
                    value = get(i, left) * (1.0 - t) + get(i, right) * t
                    if second_pass and is_newly(i, m):
                        if not detected:
                            commit.clear()
                        put(i, m, (value + get(i, m)) * 0.5)
                        commit.append(idx(i, m))
                        detected = True
                    if not detected:
                        put(i, m, value)
                        mark(i, m)
                left = right

    def extrapolate_corners():
        if x_count <= 1 or y_count <= 1:
            return

        def corner(bx, by, ox, oy):
            base = values[bx][by]
            values[bx + ox][by + oy] = base + (values[bx + ox][by] - base) + (values[bx][by + oy] - base)
            commit.append((bx + ox, by + oy))

        for x in range(x_count - 1):
            for y in range(y_count - 1):
                a, b, c, d = valid[x][y], valid[x + 1][y], valid[x][y + 1], valid[x + 1][y + 1]
                if a and b and c and not d:
                    corner(x, y, 1, 1)
                elif a and b and not c and d:
                    corner(x + 1, y, -1, 1)
                elif a and not b and c and d:
                    corner(x, y + 1, 1, -1)
                elif not a and b and c and d:
                    corner(x + 1, y + 1, -1, -1)

    def extend_and_intersect(second_pass):
        state["y_major"] = second_pass
        detected = False

        def set_or_average(maj, mnr, value, origin):
            nonlocal detected
            min_dist = abs(axis_point(mnr) - origin)
            x, y = idx(maj, mnr)
            if second_pass and newly_set[x][y]:
                if not detected:
                    commit.clear()
                maj_dist = interp_distance[x][y]
                frac = min_dist / (min_dist + maj_dist * maj_dist / min_dist)
                values[x][y] = value * (1.0 - frac) + values[x][y] * frac
                commit.append((x, y))
                detected = True
            if not detected:
                values[x][y] = value
                interp_distance[x][y] = min_dist
                newly_set[x][y] = True
                commit.append((x, y))

        for i in range(major_count()):
            count = minor_count()
            j = 0
            while j < count and not is_valid(i, j):
                j += 1
            if j >= count:
                continue
            value, origin = get(i, j), axis_point(j)
            for k in range(j):
                set_or_average(i, k, value, origin)
            j = count - 1
            while j >= 0 and not is_valid(i, j):
                j -= 1
            value, origin = get(i, j), axis_point(j)
            for k in range(j + 1, count):
                set_or_average(i, k, value, origin)

    for _ in range(total * 4):
        for x, y in commit:
            if not valid[x][y]:
                valid[x][y] = True
                valid_count += 1
        commit.clear()
        if valid_count >= total:
            break
        newly_set = [[False] * y_count for _ in range(x_count)]
        interpolate_1d(False)
        interpolate_1d(True)
        if commit:
            continue
        extrapolate_corners()
        if commit:
            continue
        extend_and_intersect(False)
        extend_and_intersect(True)
    return values


# --- Conversión ---------------------------------------------------------------

def bake(source, target, scale, quality):
    puppet, textures = read_inx(source)
    nodes = []
    index_of = {}

    def walk(node, parent, composite):
        kind = node["type"]
        if kind == "MeshGroup":
            sys.exit("Este modelo usa MeshGroup, que la app todavía no soporta.")
        index = len(nodes)
        index_of[node["uuid"]] = index
        transform = node["transform"]
        entry = {
            "name": node["name"].strip("\0 "),
            "type": {"Part": "part", "Composite": "composite", "SimplePhysics": "physics"}.get(kind, "node"),
            "parent": parent,
            "enabled": node.get("enabled", True),
            "t": transform["trans"][:2],
            "r": transform["rot"],
            "s": transform["scale"],
            "z": node.get("zsort", 0.0),
            "lock": node.get("lockToRoot", False),
            "composite": composite,
        }
        nodes.append(entry)
        if kind == "Part":
            mesh = node["mesh"]
            origin = mesh.get("origin", [0.0, 0.0])
            verts = np.array(mesh["verts"], dtype=np.float32).reshape(-1, 2) - np.array(origin, dtype=np.float32)
            entry.update({
                "tex": node["textures"][0],
                "blend": node.get("blend_mode", "Normal"),
                "opacity": node.get("opacity", 1.0),
                "mask_threshold": node.get("mask_threshold", 0.5),
                "masks": [{"uuid": m["source"], "mode": m["mode"]} for m in (node.get("masks") or [])],
                "verts": [round(float(v), 3) for v in verts.reshape(-1)],
                "uvs": [round(float(v), 5) for v in mesh["uvs"]],
                "indices": mesh["indices"],
            })
        elif kind == "Composite":
            entry.update({"blend": node.get("blend_mode", "Normal"), "opacity": node.get("opacity", 1.0)})
        elif kind == "SimplePhysics":
            entry["physics"] = {
                "param_uuid": node["param"],
                "model": node.get("model_type", "Pendulum"),
                "map": node.get("map_mode", "AngleLength"),
                "gravity": node.get("gravity", 1.0),
                "length": node.get("length", 100.0),
                "frequency": node.get("frequency", 1.0),
                "angle_damping": node.get("angle_damping", 0.5),
                "length_damping": node.get("length_damping", 0.5),
                "output_scale": node.get("output_scale", [1.0, 1.0]),
            }
        inner = index if kind == "Composite" else composite
        for child in node.get("children", []):
            walk(child, index, inner)

    walk(puppet["nodes"], -1, -1)

    # Máscaras: uuid -> índice. ClipToLower = recortar a lo ya dibujado dentro
    # del composite (las partes normales del mismo grupo).
    for index, node in enumerate(nodes):
        if node["type"] != "part":
            continue
        masks = [{"node": index_of[m["uuid"]], "dodge": m["mode"] != "Mask"} for m in node.pop("masks") if m["uuid"] in index_of]
        if node["blend"] == "ClipToLower":
            for other_index, other in enumerate(nodes):
                if other["type"] == "part" and other["composite"] == node["composite"] and other["composite"] >= 0 and other["blend"] != "ClipToLower":
                    masks.append({"node": other_index, "dodge": False})
            node["blend"] = "Normal"
        node["masks"] = masks
        # Un composite en Multiply se aproxima multiplicando cada hijo.
        if node["composite"] >= 0 and nodes[node["composite"]]["blend"] == "Multiply":
            node["blend"] = "Multiply"

    # Parámetros y deformaciones.
    blob = bytearray()
    params = []
    param_index = {}
    for source_param in puppet["param"]:
        axes = source_param["axis_points"]
        if len(axes) < 2 or not axes[1]:
            axes = [axes[0], [0.0]]
        entry = {
            "name": source_param["name"].strip("\0 "),
            "vec2": source_param["is_vec2"],
            "min": source_param["min"],
            "max": source_param["max"],
            "defaults": source_param["defaults"],
            "axes": axes,
            "bindings": [],
        }
        param_index[source_param["uuid"]] = len(params)
        params.append(entry)
        for binding in source_param["bindings"]:
            if binding["node"] not in index_of:
                continue
            node_index = index_of[binding["node"]]
            target_name = binding["param_name"]
            x_count, y_count = len(axes[0]), len(axes[1])
            if target_name == "deform":
                vertex_count = len(nodes[node_index]["verts"]) // 2
                zero = np.zeros((vertex_count, 2), dtype=np.float32)
                grid = [[np.array(binding["values"][x][y], dtype=np.float32).reshape(-1, 2) if binding["isSet"][x][y] else zero.copy()
                         for y in range(y_count)] for x in range(x_count)]
                grid = reinterpolate(grid, binding["isSet"], axes, zero)
                offsets = []
                for x in range(x_count):
                    column = []
                    for y in range(y_count):
                        value = grid[x][y].astype("<f4")
                        if float(np.abs(value).max()) < 0.01:
                            column.append(-1)
                        else:
                            column.append(len(blob))
                            blob.extend(value.tobytes())
                    offsets.append(column)
                entry["bindings"].append({"node": node_index, "target": "deform", "offsets": offsets})
            else:
                default = np.float32(VALUE_DEFAULTS.get(target_name, 0.0))
                grid = [[np.float32(binding["values"][x][y]) if binding["isSet"][x][y] else default for y in range(y_count)] for x in range(x_count)]
                grid = reinterpolate(grid, binding["isSet"], axes, default)
                entry["bindings"].append({
                    "node": node_index,
                    "target": target_name.replace("transform.", ""),
                    "values": [[round(float(grid[x][y]), 5) for y in range(y_count)] for x in range(x_count)],
                })

    for node in nodes:
        if node["type"] == "physics":
            node["physics"]["param"] = param_index.get(node["physics"].pop("param_uuid"), -1)

    meta = puppet.get("meta", {})
    physics = puppet.get("physics", {})
    header = {
        "meta": {key: meta.get(key) for key in ("name", "artist", "rigger", "copyright", "licenseURL", "contact")},
        "pixels_per_meter": physics.get("pixelsPerMeter", 1000.0),
        "gravity": physics.get("gravity", 9.8),
        "nodes": nodes,
        "params": params,
    }
    encoded = [encode_webp(prepare_texture(texture, scale), quality) for texture in textures]
    header_bytes = json.dumps(header, separators=(",", ":")).encode("utf-8")
    with open(target, "wb") as out:
        out.write(MAGIC)
        out.write(struct.pack("<I", len(header_bytes)))
        out.write(header_bytes)
        out.write(struct.pack("<I", len(blob)))
        out.write(blob)
        out.write(struct.pack("<I", len(encoded)))
        for texture in encoded:
            out.write(struct.pack("<I", len(texture)))
            out.write(texture)
    print("%s: %d nodos, %d parámetros, %d texturas, %.1f MB" % (
        target, len(nodes), len(params), len(encoded),
        (len(header_bytes) + len(blob) + sum(len(t) for t in encoded)) / 1e6))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--scale", type=float, default=0.5, help="reducción de las texturas (0.5 = mitad)")
    parser.add_argument("--quality", type=int, default=92, help="calidad WebP (1-100)")
    arguments = parser.parse_args()
    bake(arguments.source, arguments.target, arguments.scale, arguments.quality)
