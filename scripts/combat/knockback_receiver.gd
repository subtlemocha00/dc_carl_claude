class_name KnockbackReceiver
extends Node
## Lets a CharacterBody2D be knocked back by hits (Phase 9). Add it to the actor as a child named
## "KnockbackReceiver" and set the actor's Hurtbox.knockback_receiver to it; the Hurtbox then
## passes it the Knockback of every hit that damages the actor without killing it.
## - The push moves the body with move_and_slide(), so walls (and other bodies) stop it like any
##   other movement: it never passes through a wall or teleports.
## - It is fast at first and slows down to a stop: tick i of n moves distance * (n - i) / (1 + ... + n)
##   pixels, so an unobstructed push covers exactly `distance` in `duration`.
## - The push is counted in physics ticks and only moves when the actor calls step() from its
##   _physics_process(), so it freezes with the game (the action menu, GAME OVER).
## - A new push replaces one still going on. stop() ends it at once (the actor died).
## The actor decides what it does meanwhile: enemies do nothing else (Enemy.update_knockback()).
## Enemies have one; Carl and Donut do not, so nothing can knock them back.

## The body the push moves. Empty = the parent.
@export var body: CharacterBody2D

var _direction := Vector2.ZERO
var _distance := 0.0
var _ticks_total := 0
var _ticks_done := 0


func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody2D
	if body == null:
		push_error("KnockbackReceiver '%s' needs a CharacterBody2D (its parent or `body`)." % get_path())


## Starts `knockback`, replacing any push still going on.
func apply(knockback: Knockback) -> void:
	if knockback == null or knockback.is_empty() or body == null:
		return
	_direction = knockback.direction
	_distance = knockback.distance
	_ticks_total = maxi(1, roundi(knockback.duration * Engine.physics_ticks_per_second))
	_ticks_done = 0


## True while a push is going on.
func is_active() -> bool:
	return _ticks_done < _ticks_total


## Moves the body one physics tick of the push. Returns false, moving nothing, when there is no
## push. Call it once per physics tick, from the actor's _physics_process().
func step() -> bool:
	if not is_active():
		return false
	var n := _ticks_total
	var step_distance := _distance * float(n - _ticks_done) / (n * (n + 1) / 2.0)
	body.velocity = _direction * step_distance * Engine.physics_ticks_per_second
	body.move_and_slide()
	_ticks_done += 1
	if not is_active():
		body.velocity = Vector2.ZERO
	return true


## Ends the push at once.
func stop() -> void:
	_ticks_done = _ticks_total
	if body != null:
		body.velocity = Vector2.ZERO
