extends SceneTree
## One-off capture of the reworked game-over screen. See capture_wing_theme.gd
## for the technique notes (real window required, no --headless).

var _frame := 0


func _process(_delta: float) -> bool:
	_frame += 1

	if _frame == 1:
		var scene: Node = load("res://scenes/UI/game_over.tscn").instantiate()
		root.add_child(scene)

	if _frame == 6:
		var img: Image = root.get_texture().get_image()
		img.save_png("user://capture_gameover.png")
		print("capture: saved %s" % ProjectSettings.globalize_path("user://capture_gameover.png"))
		quit()

	return false
