"""Recorta animaciones de hojas de sprites con fondo de color sólido.

1. Quita el color de fondo de cada hoja (lo vuelve transparente) y guarda un PNG nuevo.
2. Dentro de cada caja (x0, y0, x1, y1) detecta los frames por componentes conectados:
   ignora textos y corchetes (manchas pequeñas o líneas) y une las piezas de un mismo
   dibujo que se superponen en horizontal.
3. Genera un SpriteFrames (.tres) donde TODOS los frames comparten el mismo lienzo
   (vía AtlasTexture.margin): pies abajo y centro de masa del cuerpo al centro.
   Así el personaje no "tiembla" aunque cada recorte tenga distinto tamaño.

Uso:
  python3 tools/slice_sheet.py tools/quico_sheet.json            # genera todo
  python3 tools/slice_sheet.py tools/quico_sheet.json --preview DIR  # + PNG de revisión
"""
import json
import re
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

TOLERANCE = 24
MIN_SPRITE_H = 22      # un componente más bajo que esto no forma un frame por sí solo
MIN_SPRITE_PIXELS = 150
LINE_RATIO = 6.0       # ancho/alto a partir del cual una mancha baja se considera línea


# Colores exactos que también se tratan como fondo (líneas guía de la hoja).
# Se configuran por hoja con "erase_colors"; ojo de no incluir colores del personaje.
ERASE_COLORS: set = set()


def is_bg(px, bg):
    return tuple(px[:3]) in ERASE_COLORS or all(abs(a - b) <= TOLERANCE for a, b in zip(px[:3], bg))


LINE_MIN_RUN = 18      # largo mínimo de una línea fina (corchetes, cuadrícula) a borrar


def _erase_thin_lines(mask, w, h):
    """Borra líneas de 1-2 px de grosor (corchetes y cuadrícula de la hoja) que si no
    se pegarían a los dibujos. Un píxel es de línea si a 3 px a ambos lados
    perpendiculares hay fondo; se borran tramos de LINE_MIN_RUN o más."""
    def on(x, y):
        return 0 <= x < w and 0 <= y < h and mask[y * w + x]

    erase = []
    for y in range(h):  # horizontales
        run = []
        for x in range(w + 1):
            if x < w and on(x, y) and not on(x, y - 3) and not on(x, y + 3):
                run.append((x, y))
            else:
                if len(run) >= LINE_MIN_RUN:
                    erase += run
                run = []
    for x in range(w):  # verticales
        run = []
        for y in range(h + 1):
            if y < h and on(x, y) and not on(x - 3, y) and not on(x + 3, y):
                run.append((x, y))
            else:
                if len(run) >= LINE_MIN_RUN:
                    erase += run
                run = []
    for x, y in erase:
        for d in (-1, 0, 1):  # incluye el grosor de la línea
            for ex, ey in ((x, y + d), (x + d, y)):
                if on(ex, ey):
                    mask[ey * w + ex] = 0


def components(px, bg, box):
    """Componentes conectados (8 vecinos) de píxeles que no son fondo dentro de `box`."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    mask = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if not is_bg(px[x0 + x, y0 + y], bg):
                mask[y * w + x] = 1
    _erase_thin_lines(mask, w, h)
    comps = []
    for start in range(w * h):
        if mask[start] != 1:
            continue
        mask[start] = 2
        q = deque([start])
        cx0 = cy0 = 10**9
        cx1 = cy1 = -1
        n = 0
        while q:
            i = q.popleft()
            y, x = divmod(i, w)
            n += 1
            cx0, cx1, cy0, cy1 = min(cx0, x), max(cx1, x), min(cy0, y), max(cy1, y)
            for dy in (-1, 0, 1):
                ny = y + dy
                if 0 <= ny < h:
                    for dx in (-1, 0, 1):
                        nx = x + dx
                        if 0 <= nx < w and mask[ny * w + nx] == 1:
                            mask[ny * w + nx] = 2
                            q.append(ny * w + nx)
        comps.append([x0 + cx0, y0 + cy0, x0 + cx1 + 1, y0 + cy1 + 1, n])
    return comps


SPLIT_WIDTH_RATIO = 1.5   # un frame así de más ancho que la mediana es sospechoso
SPLIT_MAX_PIXELS = 3      # ...y se divide si tiene una columna con estos píxeles o menos


def _split_touching(px, bg, frames):
    """Separa dos dibujos vecinos que se tocan (p. ej. pie con pie): divide los frames
    anormalmente anchos por la columna casi vacía del punto de contacto."""
    if len(frames) < 3:
        return frames
    widths = sorted(f[2] - f[0] for f in frames)
    median = widths[len(widths) // 2]
    out = []
    for f in frames:
        x0, y0, x1, y1 = f
        if x1 - x0 <= SPLIT_WIDTH_RATIO * median:
            out.append(f)
            continue
        lo, hi = x0 + (x1 - x0) // 5, x1 - (x1 - x0) // 5  # solo el 60% central
        counts = [(sum(1 for y in range(y0, y1) if not is_bg(px[x, y], bg)), x) for x in range(lo, hi)]
        n, cut = min(counts)
        if n > SPLIT_MAX_PIXELS:
            out.append(f)  # cuerpo ancho de verdad (tendido, escoba...): no dividir
            continue
        for a, b in ((x0, cut), (cut + 1, x1)):
            ys = [y for y in range(y0, y1) if any(not is_bg(px[x, y], bg) for x in range(a, b))]
            out.append([a, ys[0], b, ys[-1] + 1])
    return out


BOX_PAD = 60  # px que se busca FUERA de la caja para no cortar escobas, brazos o pies


def find_frames(img, bg, box, anchor="mass"):
    px = img.load()
    # Se analiza una zona algo mayor que la caja: un dibujo cuyo centro cae dentro
    # de la caja se conserva COMPLETO aunque sobresalga (p. ej. la punta de una escoba).
    # Los dibujos de filas vecinas tienen su centro fuera y se descartan.
    x0, y0, x1, y1 = box
    padded = (max(0, x0 - BOX_PAD), max(0, y0 - BOX_PAD),
              min(img.width, x1 + BOX_PAD), min(img.height, y1 + BOX_PAD))
    comps = components(px, bg, padded)

    def centered_in_box(c):
        cx, cy = (c[0] + c[2]) / 2, (c[1] + c[3]) / 2
        return x0 <= cx < x1 and y0 <= cy < y1

    def is_line(c):
        cw, ch = c[2] - c[0], c[3] - c[1]
        return ch < MIN_SPRITE_H and cw / max(ch, 1) > LINE_RATIO

    big = [c for c in comps
           if c[3] - c[1] >= MIN_SPRITE_H and c[4] >= MIN_SPRITE_PIXELS and centered_in_box(c)]
    small = [c for c in comps if c not in big and not is_line(c)
             and not (c[3] - c[1] >= MIN_SPRITE_H and c[4] >= MIN_SPRITE_PIXELS)]

    # Unir componentes grandes que se superponen en horizontal (piezas del mismo dibujo).
    big.sort(key=lambda c: c[0])
    frames = []
    for c in big:
        # Unir solo si la superposición es real (>30% del más angosto): dibujos vecinos
        # muy juntos pueden rozarse con un pie o una mano sin ser el mismo frame.
        overlap = (min(frames[-1][2], c[2]) - c[0]) if frames else 0
        min_w = min(frames[-1][2] - frames[-1][0], c[2] - c[0]) if frames else 1
        if frames and overlap > 0.3 * min_w:
            f = frames[-1]
            f[0], f[1], f[2], f[3] = min(f[0], c[0]), min(f[1], c[1]), max(f[2], c[2]), max(f[3], c[3])
        else:
            frames.append(c[:4])
    # Piezas pequeñas (manos, zapatos sueltos) se suman si caen dentro de un frame.
    for c in small:
        for f in frames:
            if c[0] < f[2] and c[2] > f[0] and c[1] < f[3] and c[3] > f[1]:
                f[0], f[1], f[2], f[3] = min(f[0], c[0]), min(f[1], c[1]), max(f[2], c[2]), max(f[3], c[3])
                break

    frames = _split_touching(px, bg, frames)

    result = []
    for fx0, fy0, fx1, fy1 in frames:
        total = sx = 0
        # "mass": centro de masa de todo el dibujo. "feet": solo el 20% inferior
        # (útil cuando el personaje sostiene objetos largos, como una escoba).
        ys = range(fy0, fy1) if anchor == "mass" else range(fy1 - max(4, (fy1 - fy0) // 5), fy1)
        for y in ys:
            for x in range(fx0, fx1):
                if not is_bg(px[x, y], bg):
                    total += 1
                    sx += x - fx0
        result.append({"rect": (fx0, fy0, fx1 - fx0, fy1 - fy0), "cx": sx / total})
    return result


def remove_background(src, bg):
    out = src.copy()
    opx = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if is_bg(opx[x, y], bg):
                opx[x, y] = (0, 0, 0, 0)
    return out


def main(cfg_path, preview_dir=None):
    cfg = json.loads(Path(cfg_path).read_text())
    root = Path(cfg_path).resolve().parent.parent
    bg = tuple(cfg["background"])
    ERASE_COLORS.update(tuple(c) for c in cfg.get("erase_colors", []))

    sources, clean = {}, {}
    for sid, s in cfg["sheets"].items():
        sources[sid] = Image.open(root / s["source"]).convert("RGBA")
        clean[sid] = remove_background(sources[sid], bg)
        clean[sid].save(root / s["output"])

    anims = []
    for a in cfg["animations"]:
        # "box": una caja; "boxes": varias cajas cuyos frames se concatenan en orden.
        found = [f for box in a.get("boxes", [a.get("box")]) for f in find_frames(sources[a["sheet"]], bg, box, a.get("anchor", "mass"))]
        frames = [found[i] for i in a["frames"]] if "frames" in a else found
        for f in frames:
            f["sheet"] = a["sheet"]
        anims.append((a, frames, found))
        print(f"{a['name']:>14}: {len(frames):2d} frames (detectados {len(found)})")

    all_frames = [f for _, fs, _ in anims for f in fs]
    half_w = max(max(f["cx"], f["rect"][2] - f["cx"]) for f in all_frames)
    canvas_w = int(half_w * 2) + 2
    canvas_h = max(f["rect"][3] for f in all_frames)

    sheet_ids = list(cfg["sheets"])
    # Conservar el UID que Godot le haya asignado al archivo: otros recursos lo referencian.
    out_path = root / cfg["output_tres"]
    uid = ""
    if out_path.exists():
        m = re.search(r'uid="(uid://[^"]+)"', out_path.read_text().split("\n", 1)[0])
        uid = f' uid="{m.group(1)}"' if m else ""
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(all_frames) + len(sheet_ids) + 1} format=3{uid}]', ""]
    for sid in sheet_ids:
        lines.append(f'[ext_resource type="Texture2D" path="res://{cfg["sheets"][sid]["output"]}" id="{sid}"]')
    lines.append("")
    n = 0
    anim_entries = []
    for a, fs, _ in anims:
        frame_entries = []
        for f in fs:
            n += 1
            x, y, w, h = f["rect"]
            mx = round(canvas_w / 2 - f["cx"])
            lines += [f'[sub_resource type="AtlasTexture" id="f{n}"]', f'atlas = ExtResource("{f["sheet"]}")',
                      f"region = Rect2({x}, {y}, {w}, {h})",
                      f"margin = Rect2({mx}, {canvas_h - h}, {canvas_w - w}, {canvas_h - h})", ""]
            frame_entries.append(f'{{\n"duration": 1.0,\n"texture": SubResource("f{n}")\n}}')
        anim_entries.append(
            "{\n\"frames\": [" + ", ".join(frame_entries) + "],\n"
            f"\"loop\": {'true' if a.get('loop') else 'false'},\n"
            f"\"name\": &\"{a['name']}\",\n\"speed\": {float(a.get('speed', 12))}\n}}")
    lines += ["[resource]", "animations = [" + ", ".join(anim_entries) + "]", ""]
    (root / cfg["output_tres"]).write_text("\n".join(lines))
    print(f"lienzo {canvas_w}x{canvas_h} -> {cfg['output_tres']}")

    if preview_dir:
        # Una fila por animación: todos los frames DETECTADOS, numerados; los usados en verde.
        cols = max(len(found) for _, _, found in anims)
        out = Image.new("RGBA", (cols * canvas_w, len(anims) * canvas_h), (230, 230, 230, 255))
        d = ImageDraw.Draw(out)
        for r, (a, fs, found) in enumerate(anims):
            used = {id(f) for f in fs}
            for c, f in enumerate(found):
                x, y, w, h = f["rect"]
                ox, oy = c * canvas_w + round(canvas_w / 2 - f["cx"]), r * canvas_h + canvas_h - h
                out.alpha_composite(clean[a["sheet"]].crop((x, y, x + w, y + h)), (ox, oy))
                d.text((c * canvas_w + 2, r * canvas_h + 12), str(c), fill=(0, 140, 0) if id(f) in used else (200, 0, 0))
            d.text((2, r * canvas_h + 1), a["name"], fill=(0, 0, 255))
            d.line((0, (r + 1) * canvas_h - 1, cols * canvas_w, (r + 1) * canvas_h - 1), fill=(255, 0, 0))
        out.save(Path(preview_dir) / "preview.png")


if __name__ == "__main__":
    args = sys.argv[1:]
    preview = args[args.index("--preview") + 1] if "--preview" in args else None
    main(args[0], preview)
