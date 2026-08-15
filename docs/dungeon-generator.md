# Dungeon generator

BSP room-and-corridor generator, rendered with `Dungeon_Tileset.png` from the
2D Pixel Dungeon Asset Pack.

| File | Role |
| --- | --- |
| `scripts/dungeon_generator.gd` | Pure logic. Builds a set of floor cells; no `Node`, no scene, no tileset knowledge. |
| `scenes/dungeon/dungeon_map.gd` | Reads that set of cells and picks a tile for every cell, plus camera framing and the seed readout. |
| `scenes/dungeon/dungeon.tscn` | `TileMapLayer` (floor and walls) + `PropLayer` (room markers) + tileset + `Camera2D` + HUD. The project's main scene. |
| `tools/verify_dungeon.gd` | Batch invariant check over many seeds. Headless. |
| `tools/capture_dungeon.gd` | Screenshots a chosen seed for visual checks. Needs a real window. |

Press **R** in the running scene to regenerate. The seed is printed top-left, so
a layout worth keeping can be replayed by setting `use_random_seed = false` and
`fixed_seed` on the `Dungeon` node.

```
# check a batch of seeds
godot --headless --path . --script res://tools/verify_dungeon.gd -- 5000

# screenshot one seed, fitted to the map
godot --path . --script res://tools/capture_dungeon.gd -- 12345 out.png

# screenshot one seed at 6x zoom, centred on tile (51, 15)
godot --path . --script res://tools/capture_dungeon.gd -- 12345 out.png 6 51 15
```

`capture_dungeon.gd` must **not** run with `--headless`. Headless swaps in a
dummy renderer, and `get_viewport().get_texture()` returns null there — there
are no pixels to read back. The window flashes up briefly; that's expected.

## Special rooms

Three of the generated rooms get a job. They aren't generated separately — roles
are handed out to rooms that already exist, so a special room is never wedged
somewhere the BSP had no space for it.

```gdscript
var gen := DungeonGenerator.new()
gen.generate()

gen.player_spawn   # Vector2i cell, the centre of the start room
gen.start_room     # Rect2i
gen.shop_room      # Rect2i
gen.boss_room      # Rect2i
gen.kind_of(room)  # RoomKind.NORMAL / START / SHOP / BOSS, for any room in gen.rooms
```

`_assign_roles()` runs after the rooms are carved but *before* they are
connected, so the boss arena is already at full size when the corridors get
routed to its centre.

**Boss / end room** goes wherever there is the most floor to be had. The pick is
made on the largest *partition* and the room is then grown to fill it, rather
than taking whichever room happened to roll big — that's what makes the arena
reliably the largest space on the map instead of merely a likely candidate. It
averages about 285 cells against about 165 for the next largest room, and the
verifier asserts no other room ever beats it.

**Start room** is whichever room sits furthest from the boss, so clearing the
dungeon is a trip across the map rather than a walk next door.

**Shop room** maximises the *smaller* of its two distances to the start and the
boss, which lands it in the middle of the run instead of against either end.

Rooms come from disjoint BSP partitions, so no two rects are ever equal and
`kind_of()` can't be ambiguous. Roles are only assigned when there are at least
three rooms; the generator has produced at least six on every seed tested, and
the verifier fails below three.

### How they're marked

`PropLayer` is a second `TileMapLayer` drawn over the floor, carrying the asset
pack's own props: a ladder and candles on the spawn tile, a counter of chests
with wares laid out in front for the shop, and a gate on the arena's north wall
flanked by wall torches with bones scattered into the corners for the boss.

Every prop used has a transparent background in the atlas, so it sits on the
floor instead of punching a hole in it, and none of them carry a collision
polygon — they are scenery, not obstacles. Anything that would land outside its
room, or on a cell the cleanup passes turned into something else, is silently
dropped rather than drawn in the wrong place. Turn the whole layer off with
`show_room_props` on the `Dungeon` node.

## Reading the tileset

`Dungeon_Tileset.png` is 160×160, a 10×10 grid of 16px tiles. It is a hand-drawn
room rather than a complete autotile set, which shapes everything below.

The top-left 6×6 block is one worked example of a room, and that block *is* the
mapping:

```
		col 0        col 1..4              col 5
row 0   west wall    NORTH WALL            east wall
row 1   west wall    floor, north edge     east wall
row 2   west wall    floor, no edge        east wall
row 3   west wall    floor, south edge     east wall
row 4   corner SW    SOUTH WALL            corner SE
row 5   concave NW   south wall variants   concave NE
```

Two things about this are easy to get backwards:

**Walls are named for the direction they face, not for where they sit.** A
*north* wall is the one drawn *above* a floor cell, so it is the piece showing a
full tile of brick face. A *south* wall sits below the floor and only shows the
wall's top capping with rock underneath.

**The art has its neighbours baked in.** Floor tile (1,1) is drawn with shading
along its north and west edges; (5,4) is drawn as a corner. So choosing a tile is
just reading a cell's four neighbours and looking up the piece that matches —
there is no terrain/bitmask setup involved.

Outside all of that, tile **(8,7)** is a flat block of `#25131A` — pixel-for-pixel
the same near-black the artist baked into the wall tiles. That is what fills
everything beyond the wall ring, which is why the area outside the dungeon reads
as solid rock that lines up seamlessly with the walls instead of showing empty
viewport through it. `default_clear_color` in `project.godot` is set to the same
value so no sliver of grey can appear at the edges either.

### The corner the tileset doesn't have

There are four concave (inside-of-a-bend) corners, and the artist drew two:
floor-to-the-north-and-west at (0,5)/(4,5), and floor-to-the-north-and-east at
(3,5)/(5,5). Both sit *below* floor, so the wall's top capping only takes 7px and
there is room to draw the side wall's post in the same tile.

The mirrored pair — floor to the *south* plus floor to one side — has no art, and
can't have any: a north wall is a full-tile-tall brick face, leaving no room for
a post beside it. `_wall_atlas_coords()` falls through to the plain north wall
there. The face is the loud part of the silhouette and the floor beside it
carries its own edge shading, so the corner still reads as a corner.

If that ever needs to be exact, the fix is to draw two new tiles into the free
space in the atlas rather than to work around it in code.

## What the generator guarantees

The renderer never has to invent a tile, because `_clean_up()` carves away every
shape the tileset can't draw. It loops four passes to a fixed point; each pass
only ever *adds* floor, so it can't disconnect the dungeon and it always
terminates.

| Pass | Removes | Why |
| --- | --- | --- |
| `_carve_pinched_walls` | Wall one cell thick with floor on both sides; wall with no orthogonal floor but two floor diagonals | No double-sided wall tile; two diagonals both want the corner to face them |
| `_carve_diagonal_pinches` | Two floor regions touching corner to corner | Draws as an hourglass, and is a gap the player can sometimes squeeze through and sometimes not |
| `_widen_thin_floors` | Floor one cell thick | The art shades a north edge or a south edge, never both on one tile |
| `_carve_enclosed_pockets` | Rock completely walled in by floor | No freestanding pillar art, so a small pocket draws as a stray walled box in the middle of an arena |

`tools/verify_dungeon.gd` asserts all four independently, plus connectivity and
that the floor stays one cell clear of the map edge so its wall ring always lands
inside `map_size`. It re-derives the enclosed-rock check with its own flood fill
rather than calling the generator's, so a bug in one doesn't hide a bug in the
other.

For the special rooms it checks that all three exist, are three *different*
rooms, are made entirely of floor, that the spawn is a floor cell inside the
start room, that nothing outgrows the boss arena, and that `kind_of()` agrees
with the assignment. "Every cell is floor" plus the connectivity check is what
proves the player can actually walk from the spawn to each of them.

Passing 5000 seeds is the current bar. Run it after any change to the carving
passes or the tuning knobs — the failures it catches are typically one seed in a
thousand, which is exactly the kind that survives eyeballing screenshots and
turns up later in a playtest.

## Tuning knobs

Set these on `DungeonGenerator` before calling `generate()`, or on the `Dungeon`
node for the ones it forwards.

| Knob | Default | Notes |
| --- | --- | --- |
| `map_size` | `(60, 40)` | Floor is confined to a 1-cell inset so the wall ring fits inside it |
| `min_partition_size` | `12` | Keep ≥ `min_room_size + room_padding * 2` plus a margin |
| `min_room_size` | `7` | Bullet-hell arenas want generous space, not tiny rooms |
| `room_padding` | `1` | Gap between a room and its partition edge |
| `corridor_width` | `3` | Wide enough to dodge in while moving between rooms |

There is deliberately no maximum room size: a room fills a random amount of its
partition, so a large partition can produce a large arena. That, plus 3-wide
corridors, is why rooms often merge into bigger connected shapes rather than
staying as discrete boxes. If you want tighter, more separated rooms, cap `rw`
and `rh` in `_create_rooms()` and raise `room_padding` — both are layout taste,
not correctness, so they were left as they were.
