class_name HealAction
extends ActionPerformer
## Restores the user's hit points: what a Small Health Potion does.
## It only counts as used when it actually heals, so a potion is never wasted at full health.
## The healing itself goes through the user's Health node (the child named "Health", as
## every hurtable actor in this project has).

const FLASH_COLOR := Color(0.45, 1.0, 0.55, 0.85)

@export var heal_amount: int = 30
## Minimum seconds between two uses, so that one key press never uses several potions.
@export var cooldown: float = 1.0
## How long the placeholder green ring shows after a heal.
@export var flash_duration: float = 0.35

# The cooldown is counted in physics ticks, like MeleeAttack's, so it is exact and pauses
# with the game.
var _cooldown_ticks_left := 0
var _flash_time_left := 0.0


func _physics_process(delta: float) -> void:
	if _cooldown_ticks_left > 0:
		_cooldown_ticks_left -= 1
	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		if _flash_time_left <= 0.0:
			queue_redraw()


## Heals the user by heal_amount, never above their maximum. Returns false, doing nothing,
## while cooling down, or when the user is at full health or down.
func perform(_direction: Vector2) -> bool:
	var health := user.get_node_or_null(^"Health") as Health if user != null else null
	if _cooldown_ticks_left > 0 or health == null:
		return false
	if health.heal(heal_amount) == 0:
		return false
	_cooldown_ticks_left = maxi(1, roundi(cooldown * Engine.physics_ticks_per_second))
	_flash_time_left = flash_duration
	queue_redraw()
	return true


func _draw() -> void:
	if _flash_time_left > 0.0:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, FLASH_COLOR, 3.0)
