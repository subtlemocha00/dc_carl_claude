class_name Knockback
extends RefCounted
## A push that comes with a hit (Phase 9): which way, how far and for how long. An attack that
## knocks back creates one and passes it with its damage to Hurtbox.take_hit(). The Hurtbox hands
## it to its actor's KnockbackReceiver, if the actor has one; actors without one (Carl, Donut)
## are never pushed.
## Only the Baseball Bat knocks back so far (its MeleeAttack's knockback_distance). Another
## weapon just sets its own distance and duration: nothing else changes.

## The unit direction of the push: the direction of the attack.
var direction: Vector2
## How far the push moves the target when nothing is in the way (pixels).
var distance: float
## How long the push lasts (seconds). The target does nothing else meanwhile.
var duration: float


func _init(push_direction: Vector2, push_distance: float, push_duration: float) -> void:
	direction = push_direction.normalized()
	distance = push_distance
	duration = push_duration


## True if this push would move anything at all.
func is_empty() -> bool:
	return direction == Vector2.ZERO or distance <= 0.0 or duration <= 0.0
