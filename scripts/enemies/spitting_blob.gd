extends Enemy
## Spitting Blob (id spitting_blob, Phase 7): a ranged enemy. It never hurts Carl by touching
## him; it spits globs at him from a distance. Each tick, once Carl is within detection_range:
## - if Carl is in plain sight (no wall between them, see has_line_of_sight_to()) and at most
##   max_firing_distance away, it spits a glob straight at where he is now, as often as its
##   SpitLauncher's cooldown allows. It never spits at a Carl hidden behind a wall;
## - it moves along the navigation mesh: toward Carl while a wall hides him or he is farther
##   than preferred_max_distance, away from him while he is closer than preferred_min_distance,
##   and otherwise it stays put. So a hidden Carl makes it walk around the wall until it sees
##   him again.
## It gives up when Carl is farther than chase_range. The glob (scenes/projectiles/spit_glob.tscn)
## is a Projectile that only hurts player_hurtbox (Carl) and stops at walls; the SpitLauncher is
## the same ProjectileLauncher that fires Carl's Slingshot.
## While it is knocked back (Phase 9) it neither moves by itself nor spits
## (Enemy.update_knockback()). Its launcher's cooldown keeps counting meanwhile, so afterwards it
## spits at its usual pace: at most one glob, never a burst.

## While Carl is too close, it heads for a point this far behind itself, away from him (pixels).
const RETREAT_STEP := 48.0

## It backs away while Carl is closer than this (pixels).
@export var preferred_min_distance: float = 180.0
## It comes closer while Carl is farther away than this (pixels).
@export var preferred_max_distance: float = 280.0
## It spits only at a Carl in plain sight who is at most this far away (pixels).
@export var max_firing_distance: float = 320.0

@onready var spit_launcher: ProjectileLauncher = $SpitLauncher
@onready var mouth: Node2D = %Mouth


func _ready() -> void:
	super()
	spit_launcher.user = self


func _physics_process(_delta: float) -> void:
	if update_knockback():
		return
	if not update_activity():
		stop_moving()
		return
	var target_position := target.global_position
	var distance := global_position.distance_to(target_position)
	var in_sight := has_line_of_sight_to(target_position)
	mouth.rotation = global_position.direction_to(target_position).angle()
	if in_sight and distance <= max_firing_distance:
		# The launcher refuses while it is cooling down, so this spits at most once per cooldown.
		spit_launcher.perform(global_position.direction_to(target_position))

	if not in_sight or distance > preferred_max_distance:
		navigate_toward(target_position)
	elif distance < preferred_min_distance:
		navigate_toward(global_position + target_position.direction_to(global_position) * RETREAT_STEP)
	else:
		stop_moving()
