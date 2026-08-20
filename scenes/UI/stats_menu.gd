class_name StatsMenu
extends Control

var _player: Player

@onready var close_button: Button = %CloseButton

@onready var damage_label: Label = $MarginContainer/MainVBox/StatsContainer/DamageLabel
@onready var fire_rate_label: Label = $MarginContainer/MainVBox/StatsContainer/FireRateLabel
@onready var health_label: Label = $MarginContainer/MainVBox/StatsContainer/HealthLabel
@onready var speed_label: Label = $MarginContainer/MainVBox/StatsContainer/SpeedLabel
@onready var projectile_range_label: Label = $MarginContainer/MainVBox/StatsContainer/ProjectileRangeLabel
@onready var dash_cooldown_label: Label = $MarginContainer/MainVBox/StatsContainer/DashCooldownLabel


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	hide()


func setup(player: Player) -> void:
	_player = player


## Reads StatsComponent's getters fresh each call, so it always reflects
## whatever's changed since the last refresh - upgrades bought, gear
## equipped, abilities swapped.
func refresh() -> void:
	if _player == null:
		return

	var stats := _player.stats

	damage_label.text = "DAMAGE: %.1f" % stats.get_damage()
	fire_rate_label.text = "FIRE RATE: %.2fs" % stats.get_fire_rate()
	health_label.text = "HEALTH: %.0f" % stats.get_max_health()
	speed_label.text = "SPEED: %.0f" % stats.get_move_speed()
	projectile_range_label.text = "PROJECTILE RANGE: %.0f" % stats.get_projectile_range()
	dash_cooldown_label.text = "DASH COOLDOWN: %.2fs" % stats.get_dash_cooldown()


## Refreshes on show() as well as being called directly, so "every time the
## menu is opened" holds even before this is wired into anything else.
func _on_visibility_changed() -> void:
	if visible:
		refresh()
