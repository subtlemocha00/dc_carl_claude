extends CharacterBody2D
## Carl, the player-controlled character.
## Moves with the move_* input actions (the arrow keys). W/A/S/D are action slots
## and are deliberately not read here.

## Movement speed in pixels per second.
@export var move_speed: float = 180.0

## Most recent non-zero movement direction (unit length). Carl keeps facing this way
## after the keys are released. Later phases aim actions in this direction.
var facing_direction: Vector2 = Vector2.DOWN

@onready var facing_indicator: Node2D = %FacingIndicator


func _ready() -> void:
	facing_indicator.rotation = facing_direction.angle()


func _physics_process(_delta: float) -> void:
	# get_vector() caps the length at 1, so diagonal movement is not faster than straight movement.
	var input_direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# move_and_slide() applies the physics time step itself, so the speed is in pixels
	# per second regardless of frame rate, and Carl slides along walls instead of sticking.
	velocity = input_direction * move_speed
	move_and_slide()

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction.normalized()
		facing_indicator.rotation = facing_direction.angle()
