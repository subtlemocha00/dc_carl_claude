class_name MeleeAttack
extends ActionPerformer
## A short-range attack. Each use damages the Hurtboxes inside a circle placed `reach`
## pixels from this node in the attack direction (all of them, or only the nearest
## `max_targets`), then waits `cooldown` seconds.
## Carl's Fists, the Gelatinous Blob's touch and Donut's Scratch all use this node with
## different numbers.
## - The Blob and Donut call attack() themselves.
## - Fists (scenes/actions/fists.tscn) is a MeleeAttack used as an ActionPerformer: Carl
##   calls perform() when he uses a slot holding Fists. A future melee weapon is another
##   such scene with its own numbers.
## - The Baseball Bat (scenes/actions/baseball_bat.tscn, Phase 9) is one too, with the two
##   optional extras: walls block it (blocking_layers) and it knocks back (knockback_distance).
##   Every other MeleeAttack leaves both off, so it works exactly as before Phase 9.

## Emitted every time the attack is used, with how many Hurtboxes it damaged.
signal performed(direction: Vector2, hit_count: int)

@export var damage: int = 10
## Distance from this node to the centre of the hit circle. 0 = centred on the attacker.
@export var reach: float = 24.0
@export var hit_radius: float = 18.0
## Minimum seconds between two uses.
@export var cooldown: float = 0.4
## Physics layers of the Hurtboxes this attack may damage. The attacker's own Hurtbox
## is on a different layer, which is what stops an attacker from hitting itself.
@export_flags_2d_physics var target_layers: int = 0
## How many Hurtboxes one use may damage, nearest to the hit circle's centre first.
## 0 = every Hurtbox in the circle (Fists). The Blob's touch and Donut's Scratch use 1.
@export var max_targets: int = 0
## Physics layers that block the attack (Phase 9): a Hurtbox is not hit if one of these lies on
## the straight line from the attacker's centre to the Hurtbox's centre, so a long swing never
## reaches through a wall. 0 = no check (Fists, the Blob's touch and Scratch, as before).
@export_flags_2d_physics var blocking_layers: int = 0
## Knockback (Phase 9): each Hurtbox the attack damages (without killing) is pushed this many
## pixels in the attack direction, if its actor has a KnockbackReceiver. 0 = no knockback.
@export var knockback_distance: float = 0.0
## How long that push lasts (seconds).
@export var knockback_duration: float = 0.3
## Briefly draws the hit circle when the attack is used (placeholder feedback).
@export var show_flash: bool = true
@export var flash_color: Color = Color(1, 1, 1, 0.45)
@export var flash_duration: float = 0.1

# The cooldown is counted in physics ticks, not seconds, so it is exact and repeatable.
var _cooldown_ticks_left := 0
var _flash_time_left := 0.0
var _flash_center := Vector2.ZERO
var _hit_shape := CircleShape2D.new()


func _physics_process(delta: float) -> void:
	if _cooldown_ticks_left > 0:
		_cooldown_ticks_left -= 1
	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		if _flash_time_left <= 0.0:
			queue_redraw()


func can_attack() -> bool:
	return _cooldown_ticks_left == 0


## Uses the attack toward `direction` (a unit vector, or zero for an attack centred on
## the attacker). Returns how many Hurtboxes were damaged, or -1 if still cooling down.
func attack(direction: Vector2) -> int:
	if not can_attack():
		return -1
	_cooldown_ticks_left = maxi(1, roundi(cooldown * Engine.physics_ticks_per_second))
	var targets := find_targets(direction)
	var knockback := get_knockback(direction)
	for hurtbox in targets:
		hurtbox.take_hit(damage, knockback)
	if show_flash:
		_flash_center = direction * reach
		_flash_time_left = flash_duration
		queue_redraw()
	performed.emit(direction, targets.size())
	return targets.size()


## ActionPerformer: attacks toward `direction`. Returns false while cooling down.
func perform(direction: Vector2) -> bool:
	return attack(direction) >= 0


## The push an attack toward `direction` gives each target, or null when this attack does not
## knock back (knockback_distance 0, or an attack centred on the attacker, which has no direction).
func get_knockback(direction: Vector2) -> Knockback:
	var knockback := Knockback.new(direction, knockback_distance, knockback_duration)
	return null if knockback.is_empty() else knockback


## Returns the hittable Hurtboxes the attack would damage now, without attacking: those inside
## the hit circle, limited to the nearest `max_targets` if that is set.
func find_targets(direction: Vector2) -> Array[Hurtbox]:
	var center := global_position + direction * reach
	_hit_shape.radius = hit_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _hit_shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = target_layers
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var targets: Array[Hurtbox] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var hurtbox := result["collider"] as Hurtbox
		if hurtbox != null and hurtbox.can_be_hit() and hurtbox not in targets and not _is_blocked(hurtbox):
			targets.append(hurtbox)
	if max_targets > 0 and targets.size() > max_targets:
		targets.sort_custom(func(a: Hurtbox, b: Hurtbox) -> bool:
			return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
		targets.resize(max_targets)
	return targets


## True if something on blocking_layers (a wall) is between the attacker and `hurtbox`.
func _is_blocked(hurtbox: Hurtbox) -> bool:
	if blocking_layers == 0:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, hurtbox.global_position, blocking_layers)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _draw() -> void:
	if _flash_time_left > 0.0:
		draw_circle(_flash_center, hit_radius, flash_color)
