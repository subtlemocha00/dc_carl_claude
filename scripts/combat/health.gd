class_name Health
extends Node
## Tracks an actor's hit points and announces damage and death with signals.
## Add it as a child named "Health" to anything that can be hurt.
## All damage goes through take_damage(), so armor, resistances or invulnerability
## can later be added in this one place.

signal health_changed(current: int, maximum: int)
## Emitted with the amount actually removed (never more than the health that was left).
signal damaged(amount: int)
## Emitted once, when health first reaches 0.
signal died

@export var max_health: int = 100

var current_health: int


func _ready() -> void:
	current_health = max_health


func is_dead() -> bool:
	return current_health <= 0


## Sets the hit points directly, for example when a level gives Carl the HP he carried over
## from the previous level. This is not damage: only health_changed is emitted.
## `current` is kept between 1 and `maximum`, so the actor is alive afterwards.
func set_health(current: int, maximum: int) -> void:
	max_health = maxi(1, maximum)
	current_health = clampi(current, 1, max_health)
	health_changed.emit(current_health, max_health)


## Removes up to `amount` health and returns how much was actually removed.
## Does nothing once the actor is dead, so a dead actor cannot "die" twice.
func take_damage(amount: int) -> int:
	if is_dead() or amount <= 0:
		return 0
	var applied := mini(amount, current_health)
	current_health -= applied
	damaged.emit(applied)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()
	return applied
