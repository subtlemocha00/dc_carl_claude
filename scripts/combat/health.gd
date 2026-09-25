class_name Health
extends Node
## Tracks an actor's hit points and announces damage and death with signals.
## Add it as a child named "Health" to anything that can be hurt.
## All damage goes through take_damage(), so armor, resistances or invulnerability
## can later be added in this one place.
## "Dead" means 0 HP. For Carl and enemies that is final. Donut is only downed at 0 HP: she
## comes back later through revive(), and may even start a level at 0 HP (set_down()).

signal health_changed(current: int, maximum: int)
## Emitted with the amount actually removed (never more than the health that was left).
signal damaged(amount: int)
## Emitted once each time health reaches 0 (again after a revive()).
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


## Sets the hit points to 0 directly, for an actor that starts a level already down (Donut
## entering a floor at 0 HP). It is not damage, so `damaged` is not emitted, but `died` is, so
## the actor reacts exactly as if it had just been knocked down.
func set_down(maximum: int) -> void:
	var was_dead := is_dead()
	max_health = maxi(1, maximum)
	current_health = 0
	health_changed.emit(current_health, max_health)
	if not was_dead:
		died.emit()


## Brings a dead actor back with `amount` HP (at least 1, at most max_health). Donut uses this
## when she recovers from being downed. Does nothing if the actor is not dead.
func revive(amount: int) -> void:
	if not is_dead():
		return
	current_health = clampi(amount, 1, max_health)
	health_changed.emit(current_health, max_health)


## Restores up to `amount` health, never above max_health, and returns how much was restored.
## Does nothing once the actor is dead: healing cannot bring it back (only revive() can).
func heal(amount: int) -> int:
	if is_dead() or amount <= 0:
		return 0
	var applied := mini(amount, max_health - current_health)
	if applied == 0:
		return 0
	current_health += applied
	health_changed.emit(current_health, max_health)
	return applied


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
