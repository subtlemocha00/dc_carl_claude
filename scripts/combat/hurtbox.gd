class_name Hurtbox
extends Area2D
## The area where an actor can be hit.
## Attacks find Hurtboxes by physics layer ("player_hurtbox" or "enemy_hurtbox") and call
## take_hit(). The damage is passed on to the actor's Health.

## The Health that receives damage from hits on this area.
@export var health: Health


func can_be_hit() -> bool:
	return health != null and not health.is_dead()


## Applies a hit and returns the damage actually dealt.
func take_hit(damage: int) -> int:
	if not can_be_hit():
		return 0
	return health.take_damage(damage)
