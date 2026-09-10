#!/usr/bin/env python
"""Draw the kitchen tileset procedurally, straight onto the atlas layout that
DungeonRenderer already expects.

Why code and not a generator model: every cell edge here has to line up with
its neighbours pixel-exactly, and the plain-floor variants have to tile against
themselves in any arrangement. Diffusion models do not do seams. Commercial
kitchen surfaces -- quarry tile and grout, stainless panels, rivets, vent slats
-- are regular geometry, which is the one thing code draws better than a model.

The layout is dictated by scenes/dungeon/dungeon_renderer.gd:

      col0     col1     col2     col3     col4     col5
row0  cvx_NW   N-wall   N-wall   N-wall   N-wall   cvx_NE
row1  W-wall   flr NW   flr N    flr N    flr NE   E-wall
row2  W-wall   flr W    floor    floor    flr E    E-wall
row3  W-wall   flr SW   flr S    flr S    flr SE   E-wall
row4  cvx_SW   S-wall   S-wall   S-wall   S-wall   cvx_SE
row5  ccv_NW   S-wall   S-wall   ccv_NE   ccv_NW   ccv_NE
(8,7) SOLID_ROCK

"N-wall" means a wall cell with floor to its SOUTH, i.e. the face you look at
across the top of a room. "flr N" means a floor cell with a wall to its north.

    python tools/make_kitchen_tileset.py            # write the atlas
    python tools/make_kitchen_tileset.py --preview  # + a labelled 6x zoom
    python tools/make_kitchen_tileset.py --check    # verify seams and palette

Value structure is deliberate and is a readability decision, not a taste one:
dark warm floor, mid cool-grey walls, so the warm saturated sprites and
projectiles read against both. The floor is NOT red -- docs/art_spec.md
reserves the SAUCE ramp for enemy-owned things, and a red floor would bury
enemy bullets.
"""

import argparse
import os
import re
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  python -m pip install Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE = os.path.join(ROOT, "assets", "palette", "wingpunk40.gpl")
OUT = os.path.join(ROOT, "assets", "Dungeon", "kitchen_tileset.png")

TILE = 16
ATLAS_TILES = 10          # the TileSetAtlasSource in dungeon.tscn is 10x10
QUARRY = 8                # quarry tiles are 8x8, so 2x2 per game tile
SOLID_ROCK = (8, 7)


# ---------------------------------------------------------------------------

def load_palette():
    colours = {}
    with open(PALETTE) as handle:
        for line in handle:
            match = re.match(r"^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)", line)
            if match:
                colours[match[4]] = (int(match[1]), int(match[2]), int(match[3]), 255)
    if not colours:
        sys.exit("no colours parsed from %s" % PALETTE)
    return colours


P = load_palette()

# Named roles, so the look can be retuned in one place.
GROUT = P["INK_0"]
FLOOR_A = P["WOOD_0"]        # quarry tile, dark warm
FLOOR_B = P["INK_1"]         # alternating tile, very slightly cooler
BEVEL = P["INK_2"]           # 1px lip on each quarry tile
GREASE_DARK = P["INK_1"]     # a worn/stained quarry tile
TRIM = P["GOLD_0"]           # muted brass trim, ties the steel to the theme
WALL_DARK = P["STEEL_0"]     # panel seam and shaded side
WALL_BODY = P["STEEL_1"]     # stainless panel face
WALL_LIT = P["STEEL_2"]      # top rim catching the light
OUTLINE = P["INK_0"]
SHADOW = P["INK_1"]          # wall shadow cast onto the floor
VOID = P["INK_0"]
VOID_SPECK = P["INK_1"]


def tile():
    return Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))


def rect(img, x0, y0, x1, y1, colour):
    """Inclusive rectangle fill, clipped to the tile."""
    px = img.load()
    for y in range(max(0, y0), min(TILE - 1, y1) + 1):
        for x in range(max(0, x0), min(TILE - 1, x1) + 1):
            px[x, y] = colour


def dot(img, x, y, colour):
    if 0 <= x < TILE and 0 <= y < TILE:
        img.load()[x, y] = colour


# ---------------------------------------------------------------------------
# Floor
# ---------------------------------------------------------------------------

def floor_base(variant):
    """Quarry tile with a continuous grout grid.

    The checker phase is derived from CELL-LOCAL coordinates, never from the
    cell's position in the atlas. That is what makes the pattern
    placement-independent, and it is not optional: DungeonRenderer scatters the
    two plain-floor variants across the map with a spatial hash, so a given
    atlas cell can land on any map coordinate. Phase baked from atlas position
    would break the checker apart wherever two different variants met.

    Cell-local phase works because the pattern's period (2 quarry tiles = 16px)
    divides the tile size exactly: every cell draws A B / B A, so a run of
    cells reads A B A B horizontally and A B A B vertically no matter how they
    are shuffled.
    """
    img = tile()
    rect(img, 0, 0, TILE - 1, TILE - 1, FLOOR_A)
    for qy in range(0, TILE, QUARRY):
        for qx in range(0, TILE, QUARRY):
            face = FLOOR_A if ((qx // QUARRY) + (qy // QUARRY)) % 2 == 0 else FLOOR_B
            rect(img, qx, qy, qx + QUARRY - 1, qy + QUARRY - 1, face)
    # A 1px lip inside the top and left of each quarry tile. Without this the
    # two floor colours are close enough in value that the floor reads as flat
    # squares rather than as laid tile.
    for qy in range(0, TILE, QUARRY):
        for qx in range(0, TILE, QUARRY):
            rect(img, qx + 1, qy + 1, qx + QUARRY - 1, qy + 1, BEVEL)
            rect(img, qx + 1, qy + 1, qx + 1, qy + QUARRY - 1, BEVEL)

    # Grout: one pixel on the top and left of every quarry tile.
    for n in range(0, TILE, QUARRY):
        rect(img, n, 0, n, TILE - 1, GROUT)
        rect(img, 0, n, TILE - 1, n, GROUT)

    if variant == 1:
        # Wear is a VALUE SHIFT on one quarry tile, never an added mark. Any
        # variant repeats across the map; a distinct little shape then reads as
        # a stamp printed at regular intervals, whereas a darker tile reads as
        # texture. An earlier draft put a 3px grease pool here and the whole
        # floor visibly gridded up.
        rect(img, QUARRY + 2, QUARRY + 2, TILE - 1, TILE - 1, GREASE_DARK)
        rect(img, QUARRY + 1, QUARRY + 1, TILE - 1, QUARRY + 1, BEVEL)
        rect(img, QUARRY + 1, QUARRY + 1, QUARRY + 1, TILE - 1, BEVEL)
    return img


def floor(variant, wall_n=False, wall_s=False, wall_w=False, wall_e=False):
    """Floor cell, plus contact shadow on whichever sides meet a wall."""
    img = floor_base(variant)
    if wall_n:
        rect(img, 0, 0, TILE - 1, 1, SHADOW)
        rect(img, 0, 0, TILE - 1, 0, OUTLINE)
    if wall_s:
        rect(img, 0, TILE - 1, TILE - 1, TILE - 1, SHADOW)
    if wall_w:
        rect(img, 0, 0, 1, TILE - 1, SHADOW)
        rect(img, 0, 0, 0, TILE - 1, OUTLINE)
    if wall_e:
        rect(img, TILE - 1, 0, TILE - 1, TILE - 1, SHADOW)
    return img


# ---------------------------------------------------------------------------
# Walls -- stainless panelling
# ---------------------------------------------------------------------------

def panel(seam_axis="v"):
    """Plain stainless panel with seams, before any edge lighting."""
    img = tile()
    rect(img, 0, 0, TILE - 1, TILE - 1, WALL_BODY)
    # One seam per tile. Two (every 8px) doubles the vertical line density and
    # makes a whole room's worth of wall read as noise behind the bullets.
    if seam_axis == "v":
        rect(img, 0, 0, 0, TILE - 1, WALL_DARK)
    else:
        rect(img, 0, 0, TILE - 1, 0, WALL_DARK)
    return img


def _rivets(img, y):
    for x in (5, 11):
        dot(img, x, y, WALL_LIT)
        dot(img, x, y + 1, WALL_DARK)


def _vent(img, y0):
    for y in range(y0, min(y0 + 5, TILE), 2):
        rect(img, 5, y, TILE - 5, y, WALL_DARK)


def north_wall(variant):
    """Wall cell with floor to the SOUTH: the face you look at across the top
    of a room. Lit rim along the top, dark contact line at the bottom where it
    meets the floor."""
    img = panel("v")
    rect(img, 0, 0, TILE - 1, 0, WALL_LIT)      # 1px top rim, not 2
    rect(img, 0, 1, TILE - 1, 1, WALL_DARK)     # under-rim shade
    rect(img, 0, 11, TILE - 1, 11, TRIM)        # muted brass chair rail
    rect(img, 0, 12, TILE - 1, 12, WALL_DARK)
    rect(img, 0, TILE - 1, TILE - 1, TILE - 1, OUTLINE)
    # Variants 0 and 1 are both plain: with four variants scattered by spatial
    # hash, giving every one a detail puts a rivet or vent on every tile.
    if variant == 2:
        _rivets(img, 4)
    elif variant == 3:
        _vent(img, 4)
    return img


def south_wall(variant):
    """Wall cell with floor to the NORTH: the bottom edge of a room, seen as
    the wall's top surface. Lit along the top where the floor light reaches."""
    img = panel("v")
    rect(img, 0, 0, TILE - 1, 0, OUTLINE)
    rect(img, 0, 1, TILE - 1, 1, WALL_LIT)
    rect(img, 0, 2, TILE - 1, TILE - 1, WALL_BODY)
    rect(img, 0, 2, 0, TILE - 1, WALL_DARK)
    if variant == 2:
        _rivets(img, 6)
    elif variant == 3:
        _vent(img, 5)
    return img


def side_wall(variant, floor_side):
    """Wall cell with floor to the east ('e') or west ('w')."""
    img = panel("h")
    if floor_side == "e":
        rect(img, TILE - 1, 0, TILE - 1, TILE - 1, OUTLINE)
        rect(img, TILE - 3, 0, TILE - 2, TILE - 1, WALL_LIT)
    else:
        rect(img, 0, 0, 0, TILE - 1, OUTLINE)
        rect(img, 1, 0, 2, TILE - 1, WALL_LIT)
    if variant == 2:
        for y in (4, 10):
            dot(img, 6 if floor_side == "e" else 9, y, WALL_DARK)
    return img


def convex(corner):
    """Outer corner: two wall faces meeting, floor diagonally outside."""
    img = panel("v")
    top = corner in ("nw", "ne")
    left = corner in ("nw", "sw")
    if top:
        rect(img, 0, 0, TILE - 1, 0, WALL_LIT)
        rect(img, 0, 1, TILE - 1, 1, WALL_DARK)
        # Continue the chair rail through the corner, else the line stops dead
        # at every room corner.
        rect(img, 0, 11, TILE - 1, 11, TRIM)
        rect(img, 0, 12, TILE - 1, 12, WALL_DARK)
    else:
        rect(img, 0, TILE - 1, TILE - 1, TILE - 1, OUTLINE)
    if left:
        rect(img, 0, 0, 0, TILE - 1, WALL_DARK)
    else:
        rect(img, TILE - 1, 0, TILE - 1, TILE - 1, WALL_DARK)
    return img


def concave(corner):
    """Inner corner: floor wraps around the outside of the wall block."""
    img = panel("v")
    rect(img, 0, 0, TILE - 1, 0, WALL_LIT)
    rect(img, 0, 1, TILE - 1, 1, WALL_DARK)
    rect(img, 0, 11, TILE - 1, 11, TRIM)
    rect(img, 0, 12, TILE - 1, 12, WALL_DARK)
    rect(img, 0, TILE - 1, TILE - 1, TILE - 1, OUTLINE)
    if corner == "nw":
        rect(img, 0, 0, 1, TILE - 1, WALL_DARK)
    else:
        rect(img, TILE - 2, 0, TILE - 1, TILE - 1, WALL_DARK)
    return img


# ---------------------------------------------------------------------------
# Props (PropLayer, drawn over the floor)
#
# dungeon_map.gd paints these from hardcoded atlas coordinates that all sit
# OUTSIDE the 6x6 terrain block. They must exist or the level-exit hatch and the
# lock-down shutter render as nothing -- which is exactly what happened when the
# medieval atlas was swapped out for this one.
#
# Every prop keeps a TRANSPARENT background: it sits on the floor rather than
# punching a hole in it. None carry collision; they are scenery.
# ---------------------------------------------------------------------------

def exit_hatch():
    """PROP_LADDER (9,3). Marks the start room and, more importantly, the
    stairs cell -- the "climb to the next level" trigger. It is the only visual
    signal the player gets that a level is finished, so it is drawn bright and
    high contrast rather than as another grey kitchen fitting: an open floor
    hatch with warm light coming up the shaft."""
    img = tile()
    rect(img, 1, 1, 14, 14, OUTLINE)            # frame
    rect(img, 2, 2, 13, 13, WALL_DARK)
    rect(img, 2, 2, 13, 2, WALL_LIT)            # lit top rim of the frame
    rect(img, 2, 2, 2, 13, WALL_LIT)
    rect(img, 4, 4, 11, 12, OUTLINE)            # the open shaft
    # Ladder rungs receding into warm light from below.
    rect(img, 5, 6, 10, 6, P["GOLD_2"])
    rect(img, 5, 9, 10, 9, P["GOLD_3"])
    rect(img, 5, 11, 10, 11, P["GOLD_4"])
    rect(img, 4, 12, 11, 12, P["GOLD_4"])
    return img


def gate_slats(variant):
    """PROP_GATE (6,6) and (7,6). A roller shutter dropped across a doorway
    while the room is locked.

    Drawn as HORIZONTAL slats on purpose. dungeon_map.gd rotates the tile by
    TRANSPOSE|FLIP_H for openings in vertical walls, which turns the slats
    vertical -- and a vertical slat is what correctly bars a horizontal
    passage, so one drawing serves both orientations. Full bleed to every edge
    so consecutive cells in a span join up.
    """
    img = tile()
    # Deliberately darker than the wall panels (WALL_DARK base, not WALL_BODY).
    # A shutter drawn in the same values as the surrounding wall just reads as
    # more wall; this has to say "closed, kill the room to open it".
    for y in range(0, TILE, 3):
        rect(img, 0, y, TILE - 1, y, WALL_BODY)
        rect(img, 0, y + 1, TILE - 1, y + 1, WALL_DARK)
        rect(img, 0, y + 2, TILE - 1, y + 2, OUTLINE)
    # Amber hazard band. Survives the 90 degree rotation applied to openings in
    # vertical walls -- it just becomes a vertical band.
    rect(img, 0, 6, TILE - 1, 6, P["GOLD_1"])
    rect(img, 0, 7, TILE - 1, 7, P["GOLD_2"])
    rect(img, 0, 8, TILE - 1, 8, OUTLINE)
    x = 4 if variant == 0 else 11
    for y in (1, 13):
        dot(img, x, y, WALL_LIT)
    return img


def wall_lamp(variant):
    """PROP_TORCH (0,9) and (1,9). Wall-mounted heat lamp, two flicker frames.
    Currently unused by dungeon_map.gd, but the constant points here, so the
    cell is drawn rather than left as a trap for whoever wires it up."""
    img = tile()
    rect(img, 5, 2, 10, 3, WALL_DARK)           # bracket
    rect(img, 7, 4, 8, 5, WALL_BODY)
    glow = 6 if variant == 0 else 7
    rect(img, 5, 6, 10, glow, P["GOLD_2"])
    rect(img, 6, 6, 9, glow - 1, P["GOLD_3"])
    rect(img, 7, 6, 8, 6, P["GOLD_4"])
    return img


def stock_pot():
    """PROP_CANDLE (5,9). Small floor-standing warmer flanking the start room
    and the shop counter."""
    img = tile()
    rect(img, 4, 7, 11, 13, OUTLINE)
    rect(img, 5, 8, 10, 12, WALL_BODY)
    rect(img, 5, 8, 10, 8, WALL_LIT)
    rect(img, 6, 9, 9, 11, P["GOLD_2"])         # contents catching the light
    rect(img, 7, 5, 8, 6, P["CREAM_2"])         # steam
    dot(img, 8, 4, P["CREAM_1"])
    return img


def bone_pile(variant):
    """PROP_BONES, four corners of the boss arena. Chicken bones rather than
    skeletons -- the medieval pack's leftovers were the theme break this whole
    tileset exists to remove."""
    img = tile()
    layouts = [
        [(3, 9, 9, 9), (5, 12, 11, 12)],
        [(4, 7, 10, 7), (3, 11, 8, 11), (9, 10, 12, 10)],
        [(5, 8, 12, 8), (4, 12, 9, 12)],
        [(3, 10, 8, 10), (7, 13, 13, 13), (9, 7, 12, 7)],
    ]
    for x0, y0, x1, y1 in layouts[variant % len(layouts)]:
        rect(img, x0, y0, x1, y1, P["CREAM_2"])
        dot(img, x0, y0 - 1, P["CREAM_3"])      # knuckle ends
        dot(img, x1, y0 - 1, P["CREAM_3"])
        dot(img, x0, y0 + 1, P["CREAM_1"])
        dot(img, x1, y0 + 1, P["CREAM_1"])
    return img


def supply_crate(variant):
    """PROP_CHESTS, the shop's stock behind the counter."""
    img = tile()
    if variant == 0:                            # wooden crate
        rect(img, 2, 5, 13, 13, OUTLINE)
        rect(img, 3, 6, 12, 12, P["WOOD_2"])
        rect(img, 3, 6, 12, 6, P["WOOD_3"])
        rect(img, 3, 9, 12, 9, P["WOOD_1"])
    elif variant == 1:                          # steel cooler
        rect(img, 2, 4, 13, 13, OUTLINE)
        rect(img, 3, 5, 12, 12, WALL_BODY)
        rect(img, 3, 5, 12, 6, WALL_LIT)
        rect(img, 6, 8, 9, 9, WALL_DARK)
    else:                                       # cardboard box of wings
        rect(img, 2, 6, 13, 13, OUTLINE)
        rect(img, 3, 7, 12, 12, P["WOOD_3"])
        rect(img, 4, 4, 11, 6, P["GOLD_3"])
        rect(img, 5, 3, 10, 4, P["GOLD_4"])
    return img


def counter_ware(variant):
    """PROP_WARES, goods laid out on the shop counter."""
    img = tile()
    if variant == 0:                            # sauce bottle
        rect(img, 6, 4, 9, 13, OUTLINE)
        rect(img, 7, 5, 8, 12, P["SAUCE_2"])
        rect(img, 7, 5, 7, 12, P["SAUCE_3"])
        rect(img, 7, 2, 8, 4, WALL_DARK)
    elif variant == 1:                          # paper cup
        rect(img, 5, 5, 10, 13, OUTLINE)
        rect(img, 6, 6, 9, 12, P["CREAM_2"])
        rect(img, 6, 6, 9, 7, P["SAUCE_2"])
        rect(img, 6, 8, 6, 12, P["CREAM_3"])
    elif variant == 2:                          # wing box
        rect(img, 3, 7, 12, 13, OUTLINE)
        rect(img, 4, 8, 11, 12, P["SAUCE_1"])
        rect(img, 4, 8, 11, 8, P["CREAM_2"])
        rect(img, 5, 5, 10, 7, P["GOLD_3"])
        dot(img, 6, 4, P["GOLD_4"])
        dot(img, 9, 4, P["GOLD_4"])
    else:                                       # condiment jar
        rect(img, 5, 6, 10, 13, OUTLINE)
        rect(img, 6, 7, 9, 12, P["GOLD_2"])
        rect(img, 6, 7, 9, 7, P["GOLD_4"])
        rect(img, 5, 4, 10, 5, WALL_DARK)
    return img


def solid_rock():
    """Everything outside the rooms. Near-black so it reads as absence."""
    img = tile()
    rect(img, 0, 0, TILE - 1, TILE - 1, VOID)
    for x, y in ((2, 3), (11, 6), (6, 12), (14, 13), (9, 1)):
        dot(img, x, y, VOID_SPECK)
    return img


# ---------------------------------------------------------------------------

def build():
    size = TILE * ATLAS_TILES
    atlas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    placed = {}

    def put(col, row, img):
        atlas.paste(img, (col * TILE, row * TILE))
        placed[(col, row)] = img

    # Row 0 / 4 / 5 -- walls
    put(0, 0, convex("nw"))
    for i, col in enumerate((1, 2, 3, 4)):
        put(col, 0, north_wall(i))
    put(5, 0, convex("ne"))

    put(0, 4, convex("sw"))
    for i, col in enumerate((1, 2, 3, 4)):
        put(col, 4, south_wall(i))
    put(5, 4, convex("se"))

    put(0, 5, concave("nw"))
    put(1, 5, south_wall(4))
    put(2, 5, south_wall(5 % 4))
    put(3, 5, concave("ne"))
    put(4, 5, concave("nw"))
    put(5, 5, concave("ne"))

    # Columns 0 / 5 on the floor rows -- side walls
    for i, row in enumerate((1, 2, 3)):
        put(0, row, side_wall(i, "e"))
        put(5, row, side_wall(i, "w"))

    # The 4x3 floor block
    for row, (wn, ws) in zip((1, 2, 3),
                             ((True, False), (False, False), (False, True))):
        for col, (ww, we) in zip((1, 2, 3, 4),
                                 ((True, False), (False, False),
                                  (False, False), (False, True))):
            variant = 1 if col == 3 else 0
            put(col, row, floor(variant,
                                wall_n=wn, wall_s=ws, wall_w=ww, wall_e=we))

    put(*SOLID_ROCK, solid_rock())

    # Props, at the coordinates dungeon_map.gd hardcodes.
    put(9, 3, exit_hatch())                             # PROP_LADDER
    put(6, 6, gate_slats(0))                            # PROP_GATE
    put(7, 6, gate_slats(1))
    put(0, 9, wall_lamp(0))                             # PROP_TORCH
    put(1, 9, wall_lamp(1))
    put(5, 9, stock_pot())                              # PROP_CANDLE
    for i, (c, r) in enumerate([(4, 6), (7, 7), (8, 6), (5, 6)]):
        put(c, r, bone_pile(i))                         # PROP_BONES
    for i, (c, r) in enumerate([(0, 8), (2, 8), (4, 8)]):
        put(c, r, supply_crate(i))                      # PROP_CHESTS
    for i, (c, r) in enumerate([(6, 8), (7, 8), (8, 8), (9, 8)]):
        put(c, r, counter_ware(i))                      # PROP_WARES
    return atlas, placed


# ---------------------------------------------------------------------------

def referenced_prop_cells():
    """Every atlas coordinate dungeon_map.gd paints onto PropLayer.

    Parsed from the source rather than duplicated here, so the check cannot
    quietly drift out of date. These live outside the 6x6 terrain block, which
    is exactly why swapping the tileset silently blanked the level-exit hatch
    and the lock-down shutter.
    """
    path = os.path.join(ROOT, "scenes", "dungeon", "dungeon_map.gd")
    text = open(path, encoding="utf-8").read()
    cells = {}
    for m in re.finditer(r"^const (PROP_\w+)\s*(?::[^=]*)?:?=\s*(.+)$", text, re.M):
        name, value = m.group(1), m.group(2)
        found = re.findall(r"Vector2i\((\d+),\s*(\d+)\)", value)
        for cx, cy in found:
            cells.setdefault((int(cx), int(cy)), name)
    return cells


def check(atlas):
    """Seams and palette. The floor grid must be continuous across every
    horizontal and vertical join inside the 4x3 floor block."""
    allowed = {c[:3] for c in P.values()}
    bad_colour = set()
    for pixel in atlas.getdata():
        if pixel[3] and pixel[:3] not in allowed:
            bad_colour.add(pixel[:3])

    px = atlas.load()
    seam_errors = []
    # (col, row) -> which sides carry a deliberate wall shadow over the grout
    walled = {}
    for row, (wn, ws) in zip((1, 2, 3), ((1, 0), (0, 0), (0, 1))):
        for col, (ww, we) in zip((1, 2, 3, 4), ((1, 0), (0, 0), (0, 0), (0, 1))):
            walled[(col, row)] = (wn, ws, ww, we)

    for (col, row), (wn, ws, ww, we) in walled.items():
        ox, oy = col * TILE, row * TILE
        for y in range(TILE):
            for x in range(TILE):
                if x % QUARRY and y % QUARRY:
                    continue                      # not a grout position
                if (wn and y <= 1) or (ws and y >= TILE - 1):
                    continue                      # shadow legitimately covers it
                if (ww and x <= 1) or (we and x >= TILE - 1):
                    continue
                if px[ox + x, oy + y][:3] != GROUT[:3]:
                    seam_errors.append(
                        "cell (%d,%d) grout broken at local (%d,%d)"
                        % (col, row, x, y))

    # Placement independence: every floor tile must share one checker phase,
    # because the renderer can drop any variant on any map cell.
    phases = set()
    for (col, row) in walled:
        ox, oy = col * TILE, row * TILE
        phases.add(px[ox + 4, oy + 4][:3])
    if len(phases) != 1:
        seam_errors.append("floor variants disagree on checker phase: %s"
                           % sorted(phases))

    # Any cell dungeon_map.gd paints must actually contain art.
    prop_cells = referenced_prop_cells()
    empty_props = []
    for (col, row), name in sorted(prop_cells.items()):
        region = atlas.crop((col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE))
        if not any(p[3] for p in region.getdata()):
            empty_props.append("%s at (%d,%d)" % (name, col, row))

    print("palette: %s" % ("OK -- all pixels on wingpunk40" if not bad_colour
                           else "FAIL, off-palette: %s" % sorted(bad_colour)[:6]))
    if empty_props:
        print("props:   FAIL -- dungeon_map.gd paints these, atlas is blank there:")
        for line in empty_props:
            print("   -", line)
    else:
        print("props:   OK -- all %d cells dungeon_map.gd paints are drawn"
              % len(prop_cells))
    if seam_errors:
        print("seams: FAIL (%d)" % len(seam_errors))
        for line in seam_errors[:10]:
            print("   -", line)
    else:
        print("seams: OK -- grout grid is continuous across every floor join")
    return not bad_colour and not seam_errors and not empty_props


def preview(atlas, placed):
    """6x zoom: the 6x6 terrain block in its real arrangement, then every prop
    laid out in rows beneath it."""
    zoom = 6
    pad = 2
    step = TILE * zoom + pad
    terrain = [(c, r) for (c, r) in placed if c < 6 and r < 6]
    props = sorted(set(placed) - set(terrain))
    prop_rows = (len(props) + 5) // 6
    out = Image.new("RGBA", (step * 6 + pad, step * (6 + 1 + prop_rows) + pad),
                    (20, 18, 20, 255))
    for (col, row) in terrain:
        img = placed[(col, row)].resize((TILE * zoom, TILE * zoom), Image.NEAREST)
        out.paste(img, (pad + col * step, pad + row * step))
    for i, cell in enumerate(props):
        img = placed[cell].resize((TILE * zoom, TILE * zoom), Image.NEAREST)
        # Props are transparent by design; composite them over the backdrop
        # instead of copying their alpha into it, or the preview shows holes.
        out.paste(img, (pad + (i % 6) * step, pad + (7 + i // 6) * step), img)
    path = os.path.join(ROOT, "docs", "tileset", "kitchen_tileset_preview.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    print("preview:", os.path.relpath(path, ROOT))


def room_mock(placed):
    """Paint a small room the way DungeonRenderer would, so the seams can be
    judged in context rather than tile by tile."""
    w, h = 14, 9
    img = Image.new("RGBA", (w * TILE, h * TILE), (0, 0, 0, 255))
    for y in range(h):
        for x in range(w):
            if y == 0 or x == 0 or x == w - 1 or y == h - 1:
                cell = (8, 7)
            elif y == 1:
                cell = (0, 0) if x == 1 else ((5, 0) if x == w - 2
                                              else (1 + (x % 4), 0))
            elif y == h - 2:
                cell = (0, 4) if x == 1 else ((5, 4) if x == w - 2
                                              else (1 + (x % 4), 4))
            elif x == 1:
                cell = (0, 1 + (y % 3))
            elif x == w - 2:
                cell = (5, 1 + (y % 3))
            else:
                row = 1 if y == 2 else (3 if y == h - 3 else 2)
                col = 1 if x == 2 else (4 if x == w - 3 else 2 + (x % 2))
                cell = (col, row)
            if cell in placed:
                img.paste(placed[cell], (x * TILE, y * TILE))
    path = os.path.join(ROOT, "docs", "tileset", "kitchen_tileset_room.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(path)
    print("room mock:", os.path.relpath(path, ROOT), "(at the game's 3x zoom)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    atlas, placed = build()
    atlas.save(OUT)
    print("wrote %s  (%dx%d, %d tiles drawn)"
          % (os.path.relpath(OUT, ROOT), atlas.width, atlas.height, len(placed)))
    print("NOTE: Godot serves the cached .ctex, not this PNG.")
    print("      Re-import before testing:  godot --headless --path . --import")
    if args.preview:
        preview(atlas, placed)
        room_mock(placed)
    if args.check:
        return 0 if check(atlas) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
