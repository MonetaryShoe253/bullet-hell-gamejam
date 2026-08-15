extends SceneTree
##
## Screenshot harness for the dungeon generator.
##
## Reads the rendered viewport straight back out of GPU memory instead of
## going through any OS-level screen capture, so it can never grab the wrong
## window. Must run WITHOUT --headless: the dummy rendering backend makes
## get_texture() return null.
##
## Usage:
##   godot --path . --script res://tools/capture_dungeon.gd -- <seed> <out.png>
##   godot --path . --script res://tools/capture_dungeon.gd -- <seed> <out.png> <zoom> <tile_x> <tile_y>
##
## The five-argument form overrides the scene's fit-to-map camera and frames a
## specific tile at a specific zoom, for looking at how individual pieces join.
##

const TARGET_SCENE := "res://scenes/dungeon/dungeon.tscn"

var _frame := 0
var _out_path := "user://dungeon_capture.png"
var _seed := 12345
var _zoom := 0.0
var _focus := Vector2i.ZERO


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_seed = int(args[0])
	if args.size() > 1:
		_out_path = args[1]
	if args.size() > 4:
		_zoom = float(args[2])
		_focus = Vector2i(int(args[3]), int(args[4]))


func _process(_delta: float) -> bool:
	_frame += 1

	if _frame == 1:
		var scene: Node = load(TARGET_SCENE).instantiate()
		scene.set("use_random_seed", false)
		scene.set("fixed_seed", _seed)
		if _zoom > 0.0:
			scene.set("fit_camera_to_map", false)
		root.add_child(scene)
		if _zoom > 0.0:
			scene.camera.zoom = Vector2.ONE * _zoom
			scene.camera.position = Vector2(_focus * scene.tile_layer.tile_set.tile_size)

	# Give _ready(), the camera fit and the tilemap's own internal update a
	# few frames to settle before reading pixels back.
	if _frame == 8:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out_path)
		print("capture: saved %s" % ProjectSettings.globalize_path(_out_path))
		quit()

	return false
