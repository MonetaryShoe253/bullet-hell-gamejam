class_name SecondLifeAbility
extends PassiveAbility

@export_category("Second Life")
@export var revive_health_percent: float = 0.5
@export var invincibility_duration: float = 2.0
@export var burst_scene: PackedScene = preload("res://scenes/abilities/second_life.tscn")


func equip(player: Player) -> void:
	player.health_component.about_to_die.connect(_on_about_to_die.bind(player))


func unequip(player: Player) -> void:
	var bound_callable := _on_about_to_die.bind(player)
	if player.health_component.about_to_die.is_connected(bound_callable):
		player.health_component.about_to_die.disconnect(bound_callable)


func _on_about_to_die(player: Player) -> void:
	player.health_component.revive(player.health_component.max_health * revive_health_percent)
	_play_burst(player)
	_consume(player)
	_grant_invincibility(player)


func _play_burst(player: Player) -> void:
	if burst_scene == null:
		return

	var burst: Node2D = burst_scene.instantiate()
	player.get_tree().current_scene.add_child(burst)
	burst.global_position = player.global_position
	# The burst scene animates and queue_free()s itself - nothing more to do here.


## A window of safety right after reviving, so whatever enemies are still
## crowding the player don't just kill them again on the very next hit.
## Timed independently of the burst visual, which is purely cosmetic.
func _grant_invincibility(player: Player) -> void:
	player.health_component.invulnerable = true
	await player.get_tree().create_timer(invincibility_duration).timeout
	if is_instance_valid(player):
		player.health_component.invulnerable = false


## One-shot: pulls itself out of whatever slot it's equipped in so it can't
## trigger again. unequip_at() calls unequip(player) on the way out, which
## drops the about_to_die connection - the slot is simply left empty rather
## than the ability going back into the backpack, since it's meant to be
## lost after use.
func _consume(player: Player) -> void:
	var index := player.passive_ability_component.slots.find(self)
	if index != -1:
		player.passive_ability_component.unequip_at(index)
