extends Node

@export var fade_duration: float = 0.6

var dungeon_music := preload(
	"res://assets/audio/music/Turbo_Chase.wav"
)

var boss_music := preload(
	"res://assets/audio/music/Neon_Blitz.wav"
)

var dungeon_player: AudioStreamPlayer
var boss_player: AudioStreamPlayer

var _fade_tween: Tween


func _ready() -> void:
	dungeon_player = AudioStreamPlayer.new()
	boss_player = AudioStreamPlayer.new()

	add_child(dungeon_player)
	add_child(boss_player)

	dungeon_player.stream = dungeon_music
	boss_player.stream = boss_music

	dungeon_player.volume_db = 0.0
	boss_player.volume_db = -40.0

	print("Starting dungeon music")
	dungeon_player.play()


func play_boss_music() -> void:
	if boss_player.playing:
		return

	if _fade_tween:
		_fade_tween.kill()

	boss_player.volume_db = -40.0
	boss_player.play()

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)

	_fade_tween.tween_property(
		dungeon_player,
		"volume_db",
		-40.0,
		fade_duration
	)

	_fade_tween.tween_property(
		boss_player,
		"volume_db",
		0.0,
		fade_duration
	)


func play_dungeon_music() -> void:
	if _fade_tween:
		_fade_tween.kill()

	if not dungeon_player.playing:
		dungeon_player.volume_db = -40.0
		dungeon_player.play()

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)

	_fade_tween.tween_property(
		boss_player,
		"volume_db",
		-40.0,
		fade_duration
	)

	_fade_tween.tween_property(
		dungeon_player,
		"volume_db",
		0.0,
		fade_duration
	)

	_fade_tween.chain().tween_callback(
		boss_player.stop
	)
