extends CharacterBody2D
## Carl, the player-controlled character.
## Moves with the move_* input actions (the arrow keys).
## Action slot W holds Fists, his default attack (GAME_SPEC.md section 5). Slots A/S/D stay
## empty until items and the inventory exist.

const HURT_FLASH_COLOR := Color(1.0, 0.35, 0.35)
const DOWN_COLOR := Color(0.45, 0.45, 0.45, 0.8)

## Movement speed in pixels per second.
@export var move_speed: float = 180.0

## Most recent non-zero movement direction (unit length). Carl keeps facing this way
## after the keys are released, and his attacks go this way.
var facing_direction: Vector2 = Vector2.DOWN

var _hurt_flash_tween: Tween

## Carl's hit points. The HUD and the level listen to its signals.
@onready var health: Health = $Health
@onready var fists: MeleeAttack = $Fists
@onready var facing_indicator: Node2D = %FacingIndicator
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	facing_indicator.rotation = facing_direction.angle()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


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

	# Holding W keeps punching; the Fists' cooldown limits how often.
	if Input.is_action_pressed(&"action_w"):
		fists.attack(facing_direction)


## Moves Carl instantly (used when a level places him at a spawn point) without the
## camera sliding over from his previous position.
func teleport_to(new_position: Vector2) -> void:
	global_position = new_position
	reset_physics_interpolation()
	camera.reset_smoothing()


func _on_damaged(_amount: int) -> void:
	if _hurt_flash_tween != null:
		_hurt_flash_tween.kill()
	modulate = HURT_FLASH_COLOR
	_hurt_flash_tween = create_tween()
	_hurt_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _on_died() -> void:
	# Carl stops reading input, so he can no longer move or attack.
	# What happens next (restarting the level) is decided by the level, not by Carl.
	set_physics_process(false)
	velocity = Vector2.ZERO
	if _hurt_flash_tween != null:
		_hurt_flash_tween.kill()
	modulate = DOWN_COLOR
