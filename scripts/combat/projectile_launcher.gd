class_name ProjectileLauncher
extends ActionPerformer
## Fires one projectile each time it is used. It creates a `projectile_scene` at its user's
## position and launches it in the given direction. The projectile then flies and hits things by
## itself (see Projectile), so neither the launcher nor its user knows anything about its flight.
## Nothing is used up: the only limit is the cooldown. It is used by:
## - Carl's Slingshot (scenes/actions/slingshot.tscn): Carl calls perform() with his facing
##   direction when he uses its slot;
## - the Spitting Blob's SpitLauncher (Phase 7): the enemy calls perform() with the direction to
##   Carl, and sets itself as the user.
## Whom a projectile can hurt is set in its own scene (Projectile.target_layers), so the same
## launcher serves both sides. A future ranged weapon is another scene with this node and its
## own numbers and projectile.

## Emitted every time a projectile is fired.
signal fired(projectile: Projectile)

## Scene whose root node is a Projectile.
@export var projectile_scene: PackedScene
## Minimum seconds between two shots. Holding the key fires once per cooldown.
@export var cooldown: float = 0.6

# The cooldown is counted in physics ticks, like MeleeAttack's, so it is exact and pauses with
# the game.
var _cooldown_ticks_left := 0


func _physics_process(_delta: float) -> void:
	if _cooldown_ticks_left > 0:
		_cooldown_ticks_left -= 1


func can_fire() -> bool:
	return _cooldown_ticks_left == 0


## ActionPerformer: fires a projectile toward `direction`. Returns false, firing nothing, while
## cooling down.
func perform(direction: Vector2) -> bool:
	if not can_fire() or user == null or direction == Vector2.ZERO:
		return false
	var node := projectile_scene.instantiate()
	var projectile := node as Projectile
	if projectile == null:
		push_error("The projectile_scene of '%s' must have a Projectile root." % name)
		node.free()
		return false
	# The projectile belongs to the level, next to its user, not to the user itself: once
	# fired it flies straight on, whatever the user does next.
	projectile.source = user
	user.get_parent().add_child(projectile)
	# It starts at the user's centre, so even a target right in front of the user is hit.
	projectile.launch(user.global_position, direction)
	_cooldown_ticks_left = maxi(1, roundi(cooldown * Engine.physics_ticks_per_second))
	fired.emit(projectile)
	return true
