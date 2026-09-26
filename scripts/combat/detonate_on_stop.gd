class_name DetonateOnStop
extends Node
## Makes its parent Projectile explode when it stops (Phase 12): the thrown Blast Bomb
## (scenes/projectiles/blast_bomb.tscn) is an ordinary Projectile with this child.
## A Projectile stops, and emits `stopped`, exactly once: on hitting a target it may hurt (an
## enemy), on hitting a wall, or after flying its full distance. This listens for that one signal
## and puts one `explosion_scene` (an AreaDamage) where the projectile stopped, then detonates it.
## So the bomb explodes once, whatever made it stop, and the explosion, not the bomb, does the
## damage (the bomb's own Projectile.damage is 0).
## The explosion is added to the projectile's parent (the level's Actors), so it stays after the
## projectile is removed, and it gets the projectile's `source`, so it never hurts whoever threw it.

## Emitted with the explosion and the Hurtboxes it damaged, right after it detonated.
signal exploded(explosion: AreaDamage, targets: Array[Hurtbox])

## Pulls the blast this many pixels back from a wall the projectile stopped against, so its
## centre is in front of the wall, never on or in it: the wall then shields what is behind it.
const WALL_CLEARANCE := 2.0

## Scene whose root node is an AreaDamage.
@export var explosion_scene: PackedScene

@onready var projectile: Projectile = get_parent() as Projectile


func _ready() -> void:
	if projectile == null:
		push_error("DetonateOnStop '%s' must be the child of a Projectile." % get_path())
		return
	projectile.stopped.connect(_on_projectile_stopped)


func _on_projectile_stopped(collider: Object) -> void:
	var node := explosion_scene.instantiate()
	var explosion := node as AreaDamage
	if explosion == null:
		push_error("The explosion_scene of '%s' must have an AreaDamage root." % get_path())
		node.free()
		return
	var origin := projectile.global_position
	# Stopped by a wall (a body, not a Hurtbox): step back out of its face.
	if collider != null and not collider is Hurtbox:
		origin -= projectile.direction * WALL_CLEARANCE
	explosion.source = projectile.source
	projectile.get_parent().add_child(explosion)
	explosion.global_position = origin
	# Draw it here at once, not sliding over from wherever the node was created.
	explosion.reset_physics_interpolation()
	var targets := explosion.detonate()
	exploded.emit(explosion, targets)
