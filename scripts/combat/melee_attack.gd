class_name MeleeAttack
extends Node2D
## A short-range attack. Each use damages every Hurtbox inside a circle placed `reach`
## pixels from this node in the attack direction, then waits `cooldown` seconds.
## Carl's Fists and the Gelatinous Blob's touch both use this node with different numbers.
## Later, weapons or items can supply these values instead of the scene.

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
	for hurtbox in targets:
		hurtbox.take_hit(damage)
	if show_flash:
		_flash_center = direction * reach
		_flash_time_left = flash_duration
		queue_redraw()
	performed.emit(direction, targets.size())
	return targets.size()


## Returns the hittable Hurtboxes currently inside the hit circle, without attacking.
func find_targets(direction: Vector2) -> Array[Hurtbox]:
	_hit_shape.radius = hit_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _hit_shape
	query.transform = Transform2D(0.0, global_position + direction * reach)
	query.collision_mask = target_layers
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var targets: Array[Hurtbox] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var hurtbox := result["collider"] as Hurtbox
		if hurtbox != null and hurtbox.can_be_hit() and hurtbox not in targets:
			targets.append(hurtbox)
	return targets


func _draw() -> void:
	if _flash_time_left > 0.0:
		draw_circle(_flash_center, hit_radius, flash_color)
