class_name Projectile
extends Node2D
## Something fired that flies in a straight line, such as a slingshot stone
## (scenes/projectiles/slingshot_stone.tscn). A ProjectileLauncher creates it and calls launch().
## From then on the projectile moves by itself. Each physics tick it checks the stretch it is
## about to fly along with a ray, and stops at the first thing on it:
## - a solid body on one of `blocking_layers`, such as a wall: the projectile stops there;
## - a Hurtbox on one of `target_layers` that can be hit: it deals `damage` once, then stops;
## - after flying `max_distance` pixels it stops by itself.
## Stopping removes it. Because each whole stretch is checked before moving, it cannot skip
## through a wall, hit something behind a wall, or hit more than one target. A target that
## moves onto the projectile between two ticks is hit too.
##
## Who it can hurt is decided by `target_layers`, like MeleeAttack. Carl's slingshot stones
## look for enemy_hurtbox only, so they never hurt Carl (player_hurtbox) or Donut (who has no
## Hurtbox). The projectile is not a physics body, so pickups and stairs, which only detect
## Carl's body, never notice it. Like every gameplay node it stops while the game is paused.

## Emitted once, when the projectile stops: with the Hurtbox or body it hit, or with null when
## it flew its full distance.
signal stopped(collider: Object)

## How many areas that cannot be hit (dying enemies) one tick's stretch may pass through.
const MAX_AREAS_PASSED_PER_TICK := 8

@export var damage: int = 10
## Flying speed in pixels per second.
@export var speed: float = 480.0
## The projectile disappears after flying this many pixels.
@export var max_distance: float = 320.0
## Physics layers of the Hurtboxes it may damage.
@export_flags_2d_physics var target_layers: int = 0
## Physics layers of the solid bodies that stop it (walls are on "world").
@export_flags_2d_physics var blocking_layers: int = 1

## The unit direction it flies in. Set by launch().
var direction := Vector2.ZERO

var _distance_flown := 0.0
var _is_flying := false


## Starts the flight from `from` (global position) toward `toward`. Call it after adding the
## projectile to the level.
func launch(from: Vector2, toward: Vector2) -> void:
	global_position = from
	direction = toward.normalized()
	rotation = direction.angle()
	# Start drawing here, not sliding over from wherever the node was created.
	reset_physics_interpolation()
	_is_flying = true


func get_distance_flown() -> float:
	return _distance_flown


func _physics_process(delta: float) -> void:
	if not _is_flying:
		return
	var step := minf(speed * delta, max_distance - _distance_flown)
	var next_position := global_position + direction * step
	var hit := _find_first_hit(global_position, next_position)
	if hit.is_empty():
		global_position = next_position
		_distance_flown += step
		if _distance_flown >= max_distance:
			_stop(null)
		return
	_distance_flown += global_position.distance_to(hit["position"])
	global_position = hit["position"]
	var hurtbox := hit["collider"] as Hurtbox
	if hurtbox != null:
		hurtbox.take_hit(damage)
	_stop(hit["collider"])


## The first thing between `from` and `to` that stops the projectile, as returned by
## intersect_ray() ({} if there is none). Hurtboxes that cannot be hit (a dying enemy) and any
## other areas are flown through.
func _find_first_hit(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, target_layers | blocking_layers)
	query.collide_with_areas = true
	# An enemy walking toward the projectile can step onto it between two ticks, so the next
	# stretch starts inside its Hurtbox. Rays normally ignore a shape they start in; this makes
	# them report it, so the projectile still hits that enemy instead of passing through it.
	query.hit_from_inside = true
	var space := get_world_2d().direct_space_state
	# Each pass either returns or excludes one more area, so a few passes are always enough
	# for one short stretch. The limit only guards against an endless loop.
	for pass_number in MAX_AREAS_PASSED_PER_TICK + 1:
		var result := space.intersect_ray(query)
		if result.is_empty() or not result["collider"] is Area2D:
			return result
		var hurtbox := result["collider"] as Hurtbox
		if hurtbox != null and hurtbox.can_be_hit() and (hurtbox.collision_layer & target_layers) != 0:
			return result
		# Look again past this area.
		var exclude := query.exclude
		exclude.append(result["rid"])
		query.exclude = exclude
	return {}


func _stop(collider: Object) -> void:
	_is_flying = false
	stopped.emit(collider)
	queue_free()
