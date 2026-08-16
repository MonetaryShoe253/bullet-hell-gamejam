extends SceneTree
## Ad-hoc diagnostic: quantifies how often room exit spans come out abnormally
## wide (a symptom of two rooms ending up flush / overlapping) across many
## seeds. Headless-safe - pure grid logic, no rendering.
##
## Usage: godot --headless --path . --script res://tools/diagnose_dungeon.gd -- [seed_count]

func _initialize() -> void:
	var seed_count := 300
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seed_count = int(args[0])

	var wide_span_count := 0
	var overlap_count := 0
	var boss_multi_entrance_count := 0
	var max_span_seen := 0
	var worst_seed := -1
	var examples: Array[String] = []

	for s in range(seed_count):
		var gen := DungeonGenerator.new()
		gen.generate(s)

		# Overlap check: actual floor-cell overlap, not bounding-rect
		# intersection - rooms can be non-rectangular now (see
		# _vary_room_shapes()), so two rects can legitimately overlap on
		# paper while their real floor never touches.
		for i in gen.rooms.size():
			for j in range(i + 1, gen.rooms.size()):
				if _floor_overlaps(gen, gen.rooms[i], gen.rooms[j]):
					overlap_count += 1
					if examples.size() < 10:
						examples.append("seed %d: rooms overlap %s / %s" % [s, gen.rooms[i], gen.rooms[j]])
		if gen.stairs_room.size != Vector2i.ZERO:
			for r: Rect2i in gen.rooms:
				if r != gen.boss_room and _floor_overlaps(gen, gen.stairs_room, r):
					overlap_count += 1
					if examples.size() < 10:
						examples.append("seed %d: stairs_room overlaps %s" % [s, r])

		for room: Rect2i in gen.rooms:
			for span: Array in gen.get_room_exits(room):
				if span.size() > max_span_seen:
					max_span_seen = span.size()
					worst_seed = s
				if span.size() > gen.corridor_width + 2:
					wide_span_count += 1
					if examples.size() < 20:
						examples.append("seed %d: room %s has a %d-wide exit span starting at %s"
								% [s, room, span.size(), span[0]])

		if gen.boss_room.size != Vector2i.ZERO:
			var north_y: int = gen.boss_room.position.y - 1
			var non_stairs_spans := 0
			for span: Array in gen.get_room_exits(gen.boss_room):
				if span[0].y != north_y:
					non_stairs_spans += 1
			if non_stairs_spans > 1:
				boss_multi_entrance_count += 1
				if examples.size() < 25:
					examples.append("seed %d: boss room has %d non-stairs entrances" % [s, non_stairs_spans])

	print("seeds checked: %d" % seed_count)
	print("floor-overlap rooms: %d" % overlap_count)
	print("abnormally wide exit spans (> corridor_width+2): %d" % wide_span_count)
	print("boss rooms with >1 entrance: %d" % boss_multi_entrance_count)
	print("max span width seen: %d (seed %d)" % [max_span_seen, worst_seed])
	print("--- examples ---")
	for e in examples:
		print(e)

	quit(0)


## True if `a` and `b` share any actual FLOOR cell - not just overlapping
## bounding rects, which rooms cut by _vary_room_shapes() can do harmlessly
## (an L-shaped room's rect overlaps the notch it cut out of itself, etc).
func _floor_overlaps(gen: DungeonGenerator, a: Rect2i, b: Rect2i) -> bool:
	var overlap: Rect2i = a.intersection(b)
	if overlap.size == Vector2i.ZERO:
		return false
	for x in range(overlap.position.x, overlap.end.x):
		for y in range(overlap.position.y, overlap.end.y):
			if gen.grid.has(Vector2i(x, y)):
				return true
	return false
