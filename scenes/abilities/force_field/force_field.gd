class_name ForceField
extends Area2D

var player: Player
var radius: float = 60.0
var contact_damage_multiplier: float = 0.6
var tick_damage_multiplier: float = 0.6

## How often the field cuts out per second, and how brief each cutout is -
## flicker_sharpness raised the waveform to this power, so a higher value
## keeps the field fully visible longer and only dips out for a shorter
## instant, rather than a slow fade in and out.
@export var flicker_frequency: float = 6.0
@export var flicker_sharpness: float = 6.0

const TICK_INTERVAL := 1.0

var _in_range: Dictionary = {}  # Node2D -> float, seconds since that enemy's last tick
var _time: float = 0.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _outer_ring: Polygon2D = $OuterRing
@onready var _inner_ring: Polygon2D = $InnerRing


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Additive blending gives both rings a glowing energy look, same trick
	# as the Damage Wave ribbon.
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_outer_ring.material = glow
	_inner_ring.material = glow


func activate(
	target_player: Player,
	contact_mult: float,
	tick_mult: float,
	field_radius: float
) -> void:
	player = target_player
	contact_damage_multiplier = contact_mult
	tick_damage_multiplier = tick_mult
	radius = field_radius

	(_collision_shape.shape as CircleShape2D).radius = radius
	_build_inner_ring()


func _physics_process(delta: float) -> void:
	global_position = player.global_position

	_time += delta
	_update_visibility()
	_update_outer_ring()
	_inner_ring.rotation += delta * 0.8

	for enemy in _in_range.keys().duplicate():
		if not is_instance_valid(enemy):
			_in_range.erase(enemy)
			continue

		_in_range[enemy] += delta
		if _in_range[enemy] < TICK_INTERVAL:
			continue
		_in_range[enemy] -= TICK_INTERVAL

		var hurt_box = enemy.get_node_or_null("Components/HurtBox")
		if hurt_box:
			hurt_box.take_damage(player.stats.get_damage() * tick_damage_multiplier)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return

	if not _in_range.has(body):
		_in_range[body] = 0.0

	var hurt_box = body.get_node_or_null("Components/HurtBox")
	if hurt_box:
		hurt_box.take_damage(player.stats.get_damage() * contact_damage_multiplier)


func _on_body_exited(body: Node2D) -> void:
	_in_range.erase(body)


## Field is fully visible ~95% of the time and briefly cuts out to near-
## nothing for a short instant, rather than a size pulse - applied to the
## whole node's modulate so both rings dip together.
##
## Raising a 0..1 sine to a power compresses it into a brief dip near the
## trough with a long flat "on" plateau in between - flicker_frequency sets
## how often that dip happens, flicker_sharpness how short it lasts (higher
## = briefer).
func _update_visibility() -> void:
	var raw := sin(_time * flicker_frequency) * 0.5 + 0.5
	var cutout := pow(1.0 - raw, flicker_sharpness)
	modulate.a = 1.0 - cutout


## Jittering ring rebuilt every frame - a thin band from `radius` inward,
## faded to transparent on the inner edge so it reads as an energy boundary
## rather than a solid disc.
func _update_outer_ring() -> void:
	var segments := 48
	var thickness := 6.0
	var base_color := _outer_ring.color

	var points := PackedVector2Array()
	var colors := PackedColorArray()

	for i in segments + 1:
		var angle := TAU * i / segments
		var jitter := sin(angle * 6.0 + _time * 3.0) * 2.0
		points.append(Vector2.RIGHT.rotated(angle) * (radius + jitter))
		colors.append(base_color)

	for i in segments + 1:
		var angle := TAU * (1.0 - float(i) / segments)
		var jitter := sin(angle * 6.0 + _time * 3.0) * 1.0
		points.append(Vector2.RIGHT.rotated(angle) * ((radius - thickness) + jitter))
		colors.append(Color(base_color.r, base_color.g, base_color.b, 0.0))

	_outer_ring.polygon = points
	_outer_ring.vertex_colors = colors


## Built once (not every frame, unlike the outer ring) - a slimmer dashed
## band sitting inside the outer one, spun continuously via _inner_ring's
## own rotation in _physics_process() rather than being recomputed, for a
## "spinning inner mechanism" look at negligible extra cost.
func _build_inner_ring() -> void:
	var segments := 24
	var dash_count := 12
	var inner_radius := radius * 0.75
	var thickness := 3.0
	var base_color := _inner_ring.color

	var points := PackedVector2Array()
	var colors := PackedColorArray()

	for i in segments + 1:
		var angle := TAU * i / segments
		var dash_visible := int(angle / (TAU / dash_count)) % 2 == 0
		points.append(Vector2.RIGHT.rotated(angle) * inner_radius)
		colors.append(Color(base_color.r, base_color.g, base_color.b, 1.0 if dash_visible else 0.0))

	for i in segments + 1:
		var angle := TAU * (1.0 - float(i) / segments)
		var dash_visible := int(angle / (TAU / dash_count)) % 2 == 0
		points.append(Vector2.RIGHT.rotated(angle) * (inner_radius - thickness))
		colors.append(Color(base_color.r, base_color.g, base_color.b, 1.0 if dash_visible else 0.0))

	_inner_ring.polygon = points
	_inner_ring.vertex_colors = colors
