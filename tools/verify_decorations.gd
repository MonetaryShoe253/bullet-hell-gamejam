extends SceneTree
## Asserts that no decoration sprite overlaps a wall tile.
##
## Drives DungeonGenerator + DungeonDecorator directly rather than loading the
## whole dungeon scene, so it needs no player, shop, music or rendering. For
## every "Decoration" sprite it converts the drawn rectangle back into tile
## coordinates and checks every tile it covers is real floor.
##
## This is the check that the footprint-aware placement in DungeonDecorator
## actually holds. Eyeballing a screenshot catches a prop sitting on top of a
## wall and misses the one-tile overhang, which is the common case.
##
##   godot --headless --path . --script res://tools/verify_decorations.gd
##
## Exits non-zero if any prop clips a wall.

const SEEDS := 40
const TILE := 16
const MAP_SIZE := Vector2i(260, 180)

var _frame := 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false

	# A TileSet with a 16px grid is all the decorator needs from the layer --
	# it only ever calls map_to_local().
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)

	var total := 0
	var clipping := 0
	var offenders: Dictionary = {}
	var wall_backed_ok := 0
	# Same props, same cells, but measured with the OLD alignment (sprite
	# centred on the tile, offset zero) so the fix can be shown rather than
	# asserted.
	var legacy_clipping := 0
	var per_room: Array[int] = []

	for i in SEEDS:
		var world := Node2D.new()
		root.add_child(world)
		var layer := TileMapLayer.new()
		layer.tile_set = tile_set
		world.add_child(layer)
		var gameplay := Node2D.new()
		world.add_child(gameplay)

		var gen := DungeonGenerator.new()
		gen.map_size = MAP_SIZE
		gen.generate(2000 + i, 1)

		var decorator := DungeonDecorator.new(world, layer, gameplay)
		decorator.scatter(gen)

		var found := 0
		for sprite in world.get_children():
			if not (sprite is Sprite2D and sprite.name.begins_with("Decoration")):
				continue
			total += 1
			found += 1
			var rect := _tile_rect(sprite, layer)
			var bad := false
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					if not gen.grid.has(Vector2i(x, y)):
						bad = true
			if bad:
				clipping += 1
				var key: String = sprite.texture.resource_path.get_file()
				offenders[key] = int(offenders.get(key, 0)) + 1
			elif _touches_wall_above(gen, rect):
				wall_backed_ok += 1
			var legacy := _tile_rect_centred(sprite, layer)
			for x in range(legacy.position.x, legacy.end.x):
				for y in range(legacy.position.y, legacy.end.y):
					if not gen.grid.has(Vector2i(x, y)):
						legacy_clipping += 1
						x = legacy.end.x
						break
		per_room.append(found)
		world.free()

	var avg := 0.0
	for n in per_room:
		avg += n
	avg /= float(max(1, per_room.size()))

	print("seeds                     : %d" % SEEDS)
	print("decorations placed        : %d  (avg %.1f per dungeon)" % [total, avg])
	print("backed onto a wall        : %d" % wall_backed_ok)
	print("CLIPPING A WALL           : %d" % clipping)
	print("  ...same props, old centred alignment: %d would clip (%.0f%%)"
		% [legacy_clipping, 100.0 * legacy_clipping / float(max(1, total))])
	if clipping > 0:
		print("offenders                 : %s" % offenders)
		quit(1)
		return true
	if total == 0:
		print("\nFAIL - nothing was placed at all, the test proves nothing.")
		quit(1)
		return true
	print("\nPASS - every decoration sits entirely on floor tiles.")
	quit(0)
	return true


## True when the row directly above the sprite is solid rock, i.e. the prop is
## actually leaning on a wall rather than floating in the room.
func _touches_wall_above(gen: DungeonGenerator, rect: Rect2i) -> bool:
	for x in range(rect.position.x, rect.end.x):
		if gen.grid.has(Vector2i(x, rect.position.y - 1)):
			return false
	return true


## What the rectangle would have been before the fix: sprite centred on the
## tile, no offset. Used only to quantify the improvement.
func _tile_rect_centred(sprite: Sprite2D, layer: TileMapLayer) -> Rect2i:
	var size: Vector2 = sprite.texture.get_size()
	var top_left: Vector2 = sprite.position - size / 2.0
	var a := layer.local_to_map(top_left + Vector2(0.5, 0.5))
	var b := layer.local_to_map(top_left + size - Vector2(0.5, 0.5))
	return Rect2i(a, b - a + Vector2i.ONE)


## The sprite's drawn rectangle, in tile coordinates. Sampled a half pixel
## inside each corner so an edge landing exactly on a tile boundary is not
## counted as occupying the next tile along.
func _tile_rect(sprite: Sprite2D, layer: TileMapLayer) -> Rect2i:
	var size: Vector2 = sprite.texture.get_size()
	var top_left: Vector2 = sprite.position + sprite.offset - size / 2.0
	var a := layer.local_to_map(top_left + Vector2(0.5, 0.5))
	var b := layer.local_to_map(top_left + size - Vector2(0.5, 0.5))
	return Rect2i(a, b - a + Vector2i.ONE)
