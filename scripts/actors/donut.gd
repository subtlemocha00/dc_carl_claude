extends CharacterBody2D
## Donut, Carl's AI-controlled companion.
## Phase 1: she only follows Carl, using the level's navigation mesh to walk around walls.
## She is a separate body in the level, not a child of Carl, so she never simply copies his movement.

## The node Donut follows. Each level scene sets this to its Carl instance.
@export var follow_target: Node2D
## Top speed in pixels per second. Slightly faster than Carl so she can catch up.
@export var move_speed: float = 200.0
## Donut stops when she is this close to Carl (pixels).
@export var stop_distance: float = 60.0
## Donut runs at full speed when she is at least this far from Carl (pixels).
## Between stop_distance and this distance she slows down, so she settles in smoothly.
@export var full_speed_distance: float = 100.0

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	if follow_target == null:
		push_warning("Donut has no follow_target set, so she will stay still.")


func _physics_process(_delta: float) -> void:
	var speed := _get_follow_speed()
	if speed > 0.0:
		velocity = _get_path_direction() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


## Returns 0 when Donut is close enough to Carl, full speed when she is far away,
## and a proportional speed in between.
func _get_follow_speed() -> float:
	if follow_target == null:
		return 0.0
	var distance := global_position.distance_to(follow_target.global_position)
	var speed_fraction := inverse_lerp(stop_distance, full_speed_distance, distance)
	return move_speed * clampf(speed_fraction, 0.0, 1.0)


## Direction toward the next corner of the navigation path to Carl.
func _get_path_direction() -> Vector2:
	if not _is_navigation_map_ready():
		return Vector2.ZERO
	navigation_agent.target_position = follow_target.global_position
	if navigation_agent.is_navigation_finished():
		return Vector2.ZERO
	return global_position.direction_to(navigation_agent.get_next_path_position())


func _is_navigation_map_ready() -> bool:
	# The NavigationServer builds the level's map during the first physics frame after
	# the level loads. Asking for a path before then fails, so wait for that first sync.
	return NavigationServer2D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0
