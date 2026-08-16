extends SceneTree
##
## Live capture for the chicken-wing reskin: main menu, then a preview scene
## with the player, enemy, and both projectiles all placed on screen so every
## reskinned asset is visible in one shot without needing to fight through
## the dungeon generator to find them.
##
## Usage: godot --path . --script res://tools/capture_wing_theme.gd

const MenuScene := preload("res://scenes/UI/main_menu.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")
const SlimeScene := preload("res://scenes/enemies/slime/slime.tscn")
const PlayerBulletScene := preload("res://scenes/projectiles/playerbullet/playerbullet.tscn")
const EnemyBulletScene := preload("res://scenes/projectiles/enemybullet/enemybullet.tscn")

var _frame := 0
var _menu: Node


func _process(_delta: float) -> bool:
	_frame += 1

	if _frame == 1:
		_menu = MenuScene.instantiate()
		root.add_child(_menu)

	if _frame == 6:
		var img: Image = root.get_texture().get_image()
		img.save_png("user://capture_menu.png")
		print("capture: saved %s" % ProjectSettings.globalize_path("user://capture_menu.png"))
		_menu.queue_free()

	if _frame == 8:
		var preview := Node2D.new()
		root.add_child(preview)

		var cam := Camera2D.new()
		cam.zoom = Vector2(6, 6)
		cam.position = Vector2(0, 0)
		preview.add_child(cam)
		cam.make_current()

		var player: Node = PlayerScene.instantiate()
		player.position = Vector2(-60, 0)
		preview.add_child(player)

		var slime: Node = SlimeScene.instantiate()
		slime.position = Vector2(60, 0)
		preview.add_child(slime)

		var pbullet: Node = PlayerBulletScene.instantiate()
		pbullet.position = Vector2(-10, -40)
		pbullet.rotation = -PI / 2
		preview.add_child(pbullet)

		var ebullet: Node = EnemyBulletScene.instantiate()
		ebullet.position = Vector2(10, -40)
		ebullet.rotation = -PI / 2
		preview.add_child(ebullet)

	if _frame == 16:
		var img: Image = root.get_texture().get_image()
		img.save_png("user://capture_preview.png")
		print("capture: saved %s" % ProjectSettings.globalize_path("user://capture_preview.png"))
		quit()

	return false
