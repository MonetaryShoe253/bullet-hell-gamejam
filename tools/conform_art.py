#!/usr/bin/env python
"""Force every sprite in the game onto one pixel grid and one palette.

See docs/art_spec.md for the rules this enforces and tools/art_manifest.json
for the per-group targets.

    python tools/conform_art.py audit      # what is out of spec right now
    python tools/conform_art.py conform    # rewrite assets to spec
    python tools/conform_art.py verify     # exit 1 if anything is out of spec
    python tools/conform_art.py scenes     # check .tscn scales are integral

conform is idempotent: originals are copied to assets/_source/ on first touch
and every run re-derives from there, so tweaking the palette or a target size
and re-running never compounds damage.
"""

import argparse
import json
import os
import re
import shutil
import sys
from collections import deque

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  python -m pip install Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tools", "art_manifest.json")

# The camera is at zoom 3 on a 1920x1080 viewport, so one texel must occupy a
# whole number of world units for the pixel grid to survive to the screen.
CAMERA_ZOOM = 3


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

def load_palette(path):
    """Parse a GIMP .gpl into [(name, (r, g, b)), ...]."""
    entries = []
    with open(path) as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            match = re.match(r"^\s*(\d+)\s+(\d+)\s+(\d+)\s*(\S*)", line)
            if match:
                rgb = (int(match[1]), int(match[2]), int(match[3]))
                entries.append((match[4] or "?", rgb))
    if not entries:
        raise SystemExit("no colours parsed from %s" % path)
    return entries


def srgb_to_lab(rgb):
    """CIE L*a*b* under D65. Nearest-colour in Lab beats nearest in RGB by a
    lot -- RGB distance happily maps a mid-grey onto a saturated brown."""
    out = []
    for value in rgb:
        value /= 255.0
        out.append(value / 12.92 if value <= 0.04045
                   else ((value + 0.055) / 1.055) ** 2.4)
    r, g, b = out
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    def f(t):
        return t ** (1.0 / 3.0) if t > 0.008856 else (7.787 * t) + (16.0 / 116.0)

    fx, fy, fz = f(x), f(y), f(z)
    return (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


class Palette:
    def __init__(self, entries):
        self.entries = entries
        self.labs = [srgb_to_lab(c) for _, c in entries]
        self.rgbs = [c for _, c in entries]
        self.by_ramp = {}
        for index, (name, _) in enumerate(entries):
            ramp = name.rsplit("_", 1)[0] if "_" in name else name
            self.by_ramp.setdefault(ramp, []).append(index)
        self._cache = {}

    def indices_for(self, ramp=None, exclude=None):
        if ramp is not None:
            allowed = list(self.by_ramp.get("INK", []))
            allowed += self.by_ramp.get(ramp, [])
            if not allowed:
                raise SystemExit("unknown ramp %r; have %s"
                                 % (ramp, sorted(self.by_ramp)))
        else:
            allowed = list(range(len(self.entries)))
        for name in (exclude or []):
            if name not in self.by_ramp:
                raise SystemExit("unknown ramp %r; have %s"
                                 % (name, sorted(self.by_ramp)))
            drop = set(self.by_ramp[name])
            allowed = [i for i in allowed if i not in drop]
        if not allowed:
            raise SystemExit("every colour excluded")
        return allowed

    def snap(self, rgb, allowed):
        key = (rgb, id(allowed))
        hit = self._cache.get(key)
        if hit is not None:
            return hit
        target = srgb_to_lab(rgb)
        best, best_dist = None, None
        for index in allowed:
            lab = self.labs[index]
            dist = ((target[0] - lab[0]) ** 2
                    + (target[1] - lab[1]) ** 2
                    + (target[2] - lab[2]) ** 2)
            if best_dist is None or dist < best_dist:
                best, best_dist = index, dist
        result = self.rgbs[best]
        self._cache[key] = result
        return result


# ---------------------------------------------------------------------------
# Image steps
# ---------------------------------------------------------------------------

def threshold_alpha(image, cut):
    """Pixel art has no semi-transparent pixels. At 3x zoom a soft edge
    shimmers as the sprite moves."""
    alpha = image.getchannel("A").point(lambda a: 255 if a >= cut else 0)
    image.putalpha(alpha)
    return image


def despeckle(image, min_pixels, min_fraction):
    """Drop opaque islands that are too small to be part of the subject.

    AI-generated sprites routinely carry stray detached fragments -- lettuce.png
    has a loose grey bar sitting below the sprite. Left alone they land inside
    the content bbox and shove the real sprite off-centre when it gets re-padded.

    The threshold is relative to the largest island as well as absolute, because
    "too small to matter" scales with the sprite: 40 stray pixels are noise on a
    128px icon and a whole feature on a 16px bullet.
    """
    if min_pixels <= 1 and min_fraction <= 0:
        return image, 0, 0
    width, height = image.size
    pixels = image.load()
    seen = [[False] * width for _ in range(height)]
    blobs = []
    for start_y in range(height):
        for start_x in range(width):
            if seen[start_y][start_x] or pixels[start_x, start_y][3] == 0:
                continue
            blob, queue = [], deque([(start_x, start_y)])
            seen[start_y][start_x] = True
            while queue:
                x, y = queue.popleft()
                blob.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if (0 <= nx < width and 0 <= ny < height
                            and not seen[ny][nx]
                            and pixels[nx, ny][3] != 0):
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            blobs.append(blob)
    if not blobs:
        return image, 0, 0
    biggest = max(len(b) for b in blobs)
    cutoff = max(min_pixels, biggest * min_fraction)
    dropped_blobs = dropped_px = 0
    for blob in blobs:
        if len(blob) < cutoff:
            dropped_blobs += 1
            dropped_px += len(blob)
            for x, y in blob:
                pixels[x, y] = (0, 0, 0, 0)
    return image, dropped_blobs, dropped_px


def key_background(image, tolerance, fringe_passes=2):
    """Flood the flat background in from the image border and make it clear.

    Image generators hand back an opaque canvas, so generated art arrives with
    no alpha at all. Keying from the BORDER rather than by exact colour match
    means a magenta backdrop can be knocked out without also punching holes in
    any magenta that happens to be inside the subject, and it tolerates the
    slight gradient a model puts in a "flat" background.
    """
    width, height = image.size
    pixels = image.load()
    edge = []
    for x in range(width):
        edge += [pixels[x, 0][:3], pixels[x, height - 1][:3]]
    for y in range(height):
        edge += [pixels[0, y][:3], pixels[width - 1, y][:3]]
    ref = max(set(edge), key=edge.count)

    def near(colour):
        return (abs(colour[0] - ref[0]) + abs(colour[1] - ref[1])
                + abs(colour[2] - ref[2])) <= tolerance

    queue = deque()
    seen = [[False] * width for _ in range(height)]
    for x in range(width):
        for y in (0, height - 1):
            if not seen[y][x] and near(pixels[x, y][:3]):
                seen[y][x] = True
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if not seen[y][x] and near(pixels[x, y][:3]):
                seen[y][x] = True
                queue.append((x, y))
    cleared = 0
    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        cleared += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (0 <= nx < width and 0 <= ny < height and not seen[ny][nx]
                    and near(pixels[nx, ny][:3])):
                seen[ny][nx] = True
                queue.append((nx, ny))

    # De-fringe. A hard flood leaves a one or two pixel ring of pixels that are
    # part subject, part key colour -- JPEG ringing widens it further. Those
    # survive the flood, then snap to whatever palette entry is nearest, which
    # for a magenta key is the VIOLET ramp: every generated prop comes out
    # wearing a purple halo. Only pixels that both touch transparency and still
    # lean toward the key colour are removed, so the subject is not eroded.
    loose = tolerance * 2
    for _ in range(fringe_passes):
        doomed = []
        for y in range(height):
            for x in range(width):
                if pixels[x, y][3] == 0:
                    continue
                touches_clear = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if (0 <= nx < width and 0 <= ny < height
                            and pixels[nx, ny][3] == 0):
                        touches_clear = True
                        break
                if not touches_clear:
                    continue
                colour = pixels[x, y][:3]
                if (abs(colour[0] - ref[0]) + abs(colour[1] - ref[1])
                        + abs(colour[2] - ref[2])) <= loose:
                    doomed.append((x, y))
        if not doomed:
            break
        for x, y in doomed:
            pixels[x, y] = (0, 0, 0, 0)
            cleared += 1
    return image, cleared


def content_bbox(image):
    return image.getchannel("A").point(lambda a: 255 if a else 0).getbbox()


def snap_to_palette(image, palette, ramp, exclude=None):
    allowed = palette.indices_for(ramp, exclude)
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = palette.snap((r, g, b), allowed) + (255,)
    return image


def _resize(image, size):
    """Downscale by dominant colour, upscale by nearest.

    Do NOT average on the way down. Averaging blends the subject with its own
    outline and produces colours that exist nowhere in the source: the player's
    #F7912C orange hoodie plus its near-black outline averages to a muddy brown,
    which then snaps to WOOD_2 instead of GOLD_3, and #F8C7B0 skin averages to
    a grey. Taking the most common colour in each source block instead keeps
    hue and saturation intact and keeps edges hard.

    Assumes the image has already been snapped to the palette, so "most common"
    is a vote between a small number of real colours rather than a tie between
    thousands of near-duplicates.
    """
    target_w, target_h = size
    src_w, src_h = image.size
    if target_w >= src_w and target_h >= src_h:
        return image.resize(size, Image.NEAREST)

    src = image.load()
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    dst = out.load()
    for y in range(target_h):
        y0 = (y * src_h) // target_h
        y1 = max(y0 + 1, ((y + 1) * src_h) // target_h)
        for x in range(target_w):
            x0 = (x * src_w) // target_w
            x1 = max(x0 + 1, ((x + 1) * src_w) // target_w)
            votes = {}
            clear = 0
            for sy in range(y0, y1):
                for sx in range(x0, x1):
                    pixel = src[sx, sy]
                    if pixel[3] == 0:
                        clear += 1
                    else:
                        votes[pixel] = votes.get(pixel, 0) + 1
            # A block only becomes transparent if transparency actually wins,
            # so thin limbs and antennae survive instead of eroding away.
            if not votes or clear > sum(votes.values()):
                continue
            dst[x, y] = max(votes.items(), key=lambda kv: kv[1])[0]
    return out


def fit_canvas(image, canvas, mode, anchor):
    if mode == "keep" or canvas is None:
        return image
    target = tuple(canvas)

    if mode == "scale_canvas":
        return _resize(image, target)

    if mode != "trim_pad":
        raise SystemExit("unknown fit mode %r" % mode)

    box = content_bbox(image)
    if box is None:
        return Image.new("RGBA", target, (0, 0, 0, 0))
    content = image.crop(box)

    scale = min(target[0] / content.width, target[1] / content.height)
    new_size = (max(1, round(content.width * scale)),
                max(1, round(content.height * scale)))
    content = _resize(content, new_size)

    out = Image.new("RGBA", target, (0, 0, 0, 0))
    x = (target[0] - content.width) // 2
    y = (target[1] - content.height) if anchor == "bottom" \
        else (target[1] - content.height) // 2
    out.paste(content, (x, y))
    return out


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

def iter_group_files(group):
    import glob as globlib
    found = []
    for pattern in group["glob"].split(","):
        pattern = pattern.strip()
        found += globlib.glob(os.path.join(ROOT, pattern), recursive=True)
    seen, out = set(), []
    for path in sorted(found):
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        if rel not in seen and os.path.isfile(path):
            seen.add(rel)
            out.append(rel)
    return out


def load_manifest():
    with open(MANIFEST) as handle:
        manifest = json.load(handle)
    palette = Palette(load_palette(os.path.join(ROOT, manifest["palette"])))
    return manifest, palette


def claimed_files(manifest):
    """rel path -> group, first group wins so specific globs can precede the
    broad unused_pack catch-all."""
    owner = {}
    for group in manifest["groups"]:
        for rel in iter_group_files(group):
            owner.setdefault(rel, group)
    return owner


def source_path(manifest, rel):
    return os.path.join(ROOT, manifest["source_dir"], rel)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def measure(path, palette):
    image = Image.open(path).convert("RGBA")
    colours = image.getcolors(1 << 20)
    opaque = {c for _, c in (colours or []) if c[3] == 255}
    soft = sum(n for n, c in (colours or []) if 0 < c[3] < 255)
    off = 0
    if colours:
        known = set(palette.rgbs)
        off = sum(n for n, c in colours if c[3] and c[:3] not in known)
    total = sum(n for n, c in (colours or []) if c[3])
    return {
        "size": image.size,
        "colours": len(colours) if colours else -1,
        "opaque_colours": len(opaque),
        "soft_alpha_px": soft,
        "off_palette_pct": (100.0 * off / total) if total else 0.0,
    }


def cmd_audit(manifest, palette, args):
    owner = claimed_files(manifest)
    print("Camera zoom %dx on 1920x1080  ->  native %dx%d, 1 texel = %d screen px\n"
          % (CAMERA_ZOOM, 1920 // CAMERA_ZOOM, 1080 // CAMERA_ZOOM, CAMERA_ZOOM))
    header = "%-22s %5s %-11s %-11s %7s %7s  %s"
    print(header % ("group", "n", "size", "target", "colours", "off-pal", "status"))
    print("-" * 92)

    for group in manifest["groups"]:
        files = [f for f in iter_group_files(group) if owner.get(f) is group]
        if not files:
            continue
        sizes, colours, offs, soft = set(), [], [], 0
        for rel in files:
            stats = measure(os.path.join(ROOT, rel), palette)
            sizes.add(stats["size"])
            colours.append(stats["opaque_colours"])
            offs.append(stats["off_palette_pct"])
            soft += stats["soft_alpha_px"]

        canvas = group.get("canvas")
        target = "%dx%d" % tuple(canvas) if canvas else "keep"
        size_text = ("%dx%d" % sizes.pop() if len(sizes) == 1
                     else "%d sizes" % len(sizes))
        worst_off = max(offs)
        if group.get("conform", True) is False:
            status = "audit only"
        elif worst_off < 0.5 and soft == 0 and (
                not canvas or size_text == target):
            status = "ok"
        else:
            flags = []
            if canvas and size_text != target:
                flags.append("resize")
            if worst_off >= 0.5:
                flags.append("palette")
            if soft:
                flags.append("soft-alpha")
            status = "needs " + "+".join(flags)

        print(header % (group["name"], len(files), size_text, target,
                        "%d-%d" % (min(colours), max(colours)),
                        "%.0f%%" % worst_off, status))

    unclaimed = []
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, "assets")):
        for name in filenames:
            if not name.lower().endswith(".png"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, name),
                                  ROOT).replace("\\", "/")
            if rel.startswith("assets/_source/") or rel.startswith("assets/palette/"):
                continue
            if rel not in owner:
                unclaimed.append(rel)
    if unclaimed:
        print("\n%d PNG(s) not covered by the manifest:" % len(unclaimed))
        for rel in unclaimed[:15]:
            print("   ", rel)
        if len(unclaimed) > 15:
            print("    ... and %d more" % (len(unclaimed) - 15))
    return 0


def cmd_conform(manifest, palette, args):
    owner = claimed_files(manifest)
    alpha_cut = manifest.get("alpha_cut", 128)
    speck = manifest.get("despeckle", 0)
    speck_fraction = manifest.get("despeckle_fraction", 0.0)
    changed = skipped = 0

    for group in manifest["groups"]:
        if group.get("conform", True) is False:
            continue
        if args.only and args.only != group["name"]:
            continue
        files = [f for f in iter_group_files(group) if owner.get(f) is group]
        if not files:
            continue
        print("\n== %s (%d files) -> %s" % (
            group["name"], len(files),
            "%dx%d" % tuple(group["canvas"]) if group.get("canvas") else "keep size"))

        for rel in files:
            live = os.path.join(ROOT, rel)
            master = source_path(manifest, rel)
            # First touch: the current file becomes the immutable master.
            if not os.path.exists(master):
                os.makedirs(os.path.dirname(master), exist_ok=True)
                shutil.copy2(live, master)

            image = Image.open(master).convert("RGBA")
            before = image.size
            if group.get("key_background"):
                image, keyed = key_background(
                    image, group.get("key_tolerance", 40),
                    group.get("key_fringe_passes", 2))
                if keyed:
                    print("   %-52s keyed out %d background px" % (rel, keyed))
            # Order matters. Alpha and palette are resolved at SOURCE
            # resolution, then the dominant-colour downscale votes between
            # real palette colours. Snapping after a downscale instead lets
            # blended edge pixels pick colours the artwork never contained.
            image = threshold_alpha(image, alpha_cut)
            image, gone_n, gone_px = despeckle(
                image,
                group.get("despeckle", speck),
                group.get("despeckle_fraction", speck_fraction))
            image = snap_to_palette(image, palette, group.get("ramp"),
                                    group.get("exclude_ramps"))
            image = fit_canvas(image, group.get("canvas"),
                               group.get("fit", "keep"),
                               group.get("anchor", "center"))

            if gone_n:
                print("   %-52s despeckle dropped %d island(s), %d px"
                      % (rel, gone_n, gone_px))
            if args.dry_run:
                print("   [dry] %-52s %s -> %s" % (rel, before, image.size))
                skipped += 1
                continue
            image.save(live)
            changed += 1
            if before != image.size:
                print("   %-52s %s -> %s" % (rel, before, image.size))

    print("\n%d file(s) %s. Masters in %s/"
          % (changed or skipped,
             "would be rewritten" if args.dry_run else "rewritten",
             manifest["source_dir"]))
    if not args.dry_run:
        print("Godot will re-import on next editor focus.")
    return 0


def cmd_verify(manifest, palette, args):
    owner = claimed_files(manifest)
    problems = []
    for group in manifest["groups"]:
        if group.get("conform", True) is False:
            continue
        files = [f for f in iter_group_files(group) if owner.get(f) is group]
        canvas = tuple(group["canvas"]) if group.get("canvas") else None
        for rel in files:
            stats = measure(os.path.join(ROOT, rel), palette)
            if canvas and stats["size"] != canvas:
                problems.append("%s: size %s, spec says %s"
                                % (rel, stats["size"], canvas))
            if stats["off_palette_pct"] > 0.01:
                problems.append("%s: %.1f%% of pixels are off-palette"
                                % (rel, stats["off_palette_pct"]))
            if stats["soft_alpha_px"]:
                problems.append("%s: %d semi-transparent pixels"
                                % (rel, stats["soft_alpha_px"]))
    if problems:
        print("ART SPEC VIOLATIONS (%d):" % len(problems))
        for line in problems[:40]:
            print("  -", line)
        if len(problems) > 40:
            print("  ... and %d more" % (len(problems) - 40))
        return 1
    print("All conformed assets match docs/art_spec.md.")
    return 0


# ---------------------------------------------------------------------------
# Scene scale check
# ---------------------------------------------------------------------------

NODE_RE = re.compile(r'^\[node name="([^"]+)"(?:\s+type="([^"]+)")?'
                     r'(?:[^\]]*?\s+parent="([^"]*)")?[^\]]*\]')
SCALE_RE = re.compile(r"^scale = Vector2\(([-\d.e+]+),\s*([-\d.e+]+)\)")
DRAWS_RE = re.compile(r"^(texture|sprite_frames) = ")


def scan_scene(path):
    """Cumulative scale of every texture-drawing node in one .tscn."""
    nodes, order = {}, []
    current = None
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            match = NODE_RE.match(line)
            if match:
                name, ntype, parent = match[1], match[2] or "", match[3]
                key = name if parent in (None, "") else (
                    name if parent == "." else parent + "/" + name)
                current = {"key": key, "name": name, "type": ntype,
                           "parent": None if parent in (None, "") else
                                     ("" if parent == "." else parent),
                           "scale": (1.0, 1.0), "draws": False}
                nodes[key] = current
                order.append(key)
                continue
            if current is None:
                continue
            scale = SCALE_RE.match(line)
            if scale:
                current["scale"] = (float(scale[1]), float(scale[2]))
            elif DRAWS_RE.match(line):
                current["draws"] = True

    root = order[0] if order else None

    def cumulative(key):
        node = nodes[key]
        sx, sy = node["scale"]
        parent = node["parent"]
        if parent is None:
            return sx, sy
        pkey = root if parent == "" else parent
        if pkey in nodes and pkey != key:
            px, py = cumulative(pkey)
            return sx * px, sy * py
        return sx, sy

    out = []
    for key in order:
        if nodes[key]["draws"]:
            out.append((key, nodes[key]["type"], cumulative(key)))
    return out


def cmd_scenes(manifest, palette, args):
    bad = 0
    print("Texture-drawing nodes whose cumulative scale is not an integer.")
    print("(A non-integer scale means one texel lands on a fractional number "
          "of screen\npixels, so neighbouring texels render at different "
          "sizes.)\n")
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, "scenes")):
        for name in sorted(filenames):
            if not name.endswith(".tscn"):
                continue
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, ROOT).replace("\\", "/")
            for key, ntype, (sx, sy) in scan_scene(path):
                ok = (abs(sx - round(sx)) < 1e-4 and abs(sy - round(sy)) < 1e-4
                      and round(sx) >= 1 and abs(sx - sy) < 1e-4)
                if not ok:
                    bad += 1
                    print("  %-58s %-18s scale=(%.4g, %.4g)  texel=%.3g screen px"
                          % (rel, key.split("/")[-1] + " [" + (ntype or "?") + "]",
                             sx, sy, sx * CAMERA_ZOOM))
    if bad == 0:
        print("  none -- every drawing node is on an integer scale.")
    else:
        print("\n%d node(s) off the pixel grid." % bad)
    return 1 if (bad and args.strict) else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    subs = parser.add_subparsers(dest="cmd", required=True)
    subs.add_parser("audit")
    conform = subs.add_parser("conform")
    conform.add_argument("--dry-run", action="store_true")
    conform.add_argument("--only", help="limit to one manifest group")
    subs.add_parser("verify")
    scenes = subs.add_parser("scenes")
    scenes.add_argument("--strict", action="store_true",
                        help="exit non-zero if any node is off-grid")
    args = parser.parse_args()

    manifest, palette = load_manifest()
    return {
        "audit": cmd_audit, "conform": cmd_conform,
        "verify": cmd_verify, "scenes": cmd_scenes,
    }[args.cmd](manifest, palette, args)


if __name__ == "__main__":
    sys.exit(main())
