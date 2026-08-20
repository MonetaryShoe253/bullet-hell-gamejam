class_name PlayerStatsTab
extends Control

var _player: Player

@onready var max_health_label: Label = %MaxHealthLabel
@onready var damage_label: Label = %DamageLabel
@onready var move_speed_label: Label = %MoveSpeedLabel
@onready var fire_rate_label: Label = %FireRateLabel
@onready var dash_cooldown_label: Label = %DashCooldownLabel
@onready var projectile_range_label: Label = %ProjectileRangeLabel


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func setup(player: Player) -> void:
	_player = player


## Reads StatsComponent's getters fresh each call, so it always reflects
## whatever's changed since the last refresh - upgrades bought, gear
## equipped, abilities swapped.
func refresh() -> void:
	if _player == null:
		return

	var stats := _player.stats

	max_health_label.text = "Max Health: %.0f" % stats.get_max_health()
	damage_label.text = "Damage: %.1f" % stats.get_damage()
	move_speed_label.text = "Move Speed: %.0f" % stats.get_move_speed()
	fire_rate_label.text = "Fire Rate: %.2fs" % stats.get_fire_rate()
	dash_cooldown_label.text = "Dash Cooldown: %.2fs" % stats.get_dash_cooldown()
	projectile_range_label.text = "Range: %.0f" % stats.get_projectile_range()


## TabContainer sets a tab's own `visible` true/false as the active tab
## changes, and Godot's visibility_changed also fires when an ancestor's
## visibility changes - so this alone catches both "menu just opened while
## this was already the active tab" and "switched to this tab while the menu
## was already open", with nothing needed from the parent menu to wire it up.
func _on_visibility_changed() -> void:
	if visible:
		refresh()
