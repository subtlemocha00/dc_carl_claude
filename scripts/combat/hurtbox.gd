class_name Hurtbox
extends Area2D
## The area where an actor can be hit.
## Attacks find Hurtboxes by physics layer ("player_hurtbox" or "enemy_hurtbox") and call
## take_hit(). The damage is passed on to the actor's Health, and a hit that knocks back (Phase 9,
## the Baseball Bat) passes its Knockback on to the actor's KnockbackReceiver, if it has one.

## The Health that receives damage from hits on this area.
@export var health: Health
## Receives the push of hits that knock back. Empty = this actor is never knocked back (Carl,
## Donut). Enemies set it.
@export var knockback_receiver: KnockbackReceiver


func can_be_hit() -> bool:
	return health != null and not health.is_dead()


## Applies a hit and returns the damage actually dealt. `knockback` (optional) pushes the actor,
## but only if the hit really hurt it and it is still alive: death comes first.
func take_hit(damage: int, knockback: Knockback = null) -> int:
	if not can_be_hit():
		return 0
	var dealt := health.take_damage(damage)
	if knockback != null and dealt > 0 and knockback_receiver != null and not health.is_dead():
		knockback_receiver.apply(knockback)
	return dealt
