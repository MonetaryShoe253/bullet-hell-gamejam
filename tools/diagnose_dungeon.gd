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
	var max_span_seen := 0
	var worst_seed := -1
	var examples: Array[String] = []

	for s in range(seed_count):
		var gen := DungeonGenerator.new()
		gen.generate(s)

		# Overlap check: any two distinct room rects that intersect.
		for i in gen.rooms.size():
			for j in range(i + 1, gen.rooms.size()):
				if gen.rooms[i].intersects(gen.rooms[j]):
					overlap_count += 1
					if examples.size() < 10:
						examples.append("seed %d: rooms overlap %s / %s" % [s, gen.rooms[i], gen.rooms[j]])
		if gen.stairs_room.size != Vector2i.ZERO:
			for r: Rect2i in gen.rooms:
				if r != gen.boss_room and gen.stairs_room.intersects(r):
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

	print("seeds checked: %d" % seed_count)
	print("room-rect overlaps: %d" % overlap_count)
	print("abnormally wide exit spans (> corridor_width+2): %d" % wide_span_count)
	print("max span width seen: %d (seed %d)" % [max_span_seen, worst_seed])
	print("--- examples ---")
	for e in examples:
		print(e)

	quit(0)
