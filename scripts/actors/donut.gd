extends CharacterBody2D
## Donut, Carl's AI-controlled companion. The player never controls her directly.
## - She follows Carl, using the level's navigation mesh to walk around walls. She is a separate
##   body in the level, not a child of Carl, so she never simply copies his movement.
## - Phase 8: she has Health (60 HP) and a Hurtbox on player_hurtbox, the player's side, so
##   enemy attacks can hurt her and Carl's attacks (which only look for enemy_hurtbox) never do.
##   Enemies may choose her as their target (see Enemy); she is in the "party" group with Carl.
## - Scratch: whenever an enemy is within reach (about 42 px from her centre), she scratches the
##   nearest one for 10 damage, at most once a second. She never walks toward enemies to do it:
##   following Carl always comes first.
## - At 0 HP she is DOWNED, not dead: she lies still, greyed out with a "DOWNED" label, does not
##   follow or scratch, and enemies ignore her. After `down_time` seconds of play she gets up
##   with `recovery_health` HP and carries on. The countdown runs in physics ticks, so it stops
##   while the game is paused (the action menu, GAME OVER). Carl going down ends the run;
##   Donut going down never does.

const HURT_FLASH_COLOR := Color(1.0, 0.45, 0.45)
const DOWN_COLOR := Color(0.5, 0.5, 0.5, 0.9)

## The node Donut follows. Each level scene sets this to its Carl instance.
@export var follow_target: Node2D
## Top speed in pixels per second. Slightly faster than Carl so she can catch up.
@export var move_speed: float = 200.0
## Donut stops when she is this close to Carl (pixels).
@export var stop_distance: float = 60.0
## Donut runs at full speed when she is at least this far from Carl (pixels).
## Between stop_distance and this distance she slows down, so she settles in smoothly.
@export var full_speed_distance: float = 100.0
## Seconds of play Donut stays downed before she gets up again.
@export var down_time: float = 6.0
## HP Donut has when she gets up again.
@export var recovery_health: int = 30

## Physics ticks left until a downed Donut gets up.
var _down_ticks_left := 0
var _hurt_flash_tween: Tween

@onready var health: Health = $Health
@onready var scratch: MeleeAttack = $Scratch
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
## Her drawn shapes (body, ears, eyes). Tinted and turned on her side while she is downed.
@onready var look: Node2D = %Look
@onready var downed_label: Label = %DownedLabel


func _ready() -> void:
	if follow_target == null:
		push_warning("Donut has no follow_target set, so she will stay still.")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_downed)
	downed_label.visible = false


## Sets Donut's HP when a level starts, from the run's state. At 0 HP she starts the level
## downed, with a fresh recovery countdown.
func start_with_health(current: int, maximum: int) -> void:
	if current > 0:
		health.set_health(current, maximum)
	else:
		health.set_down(maximum)


func is_downed() -> bool:
	return health.is_dead()


## Seconds of play left before a downed Donut gets up (0 when she is not downed).
func get_recovery_time_left() -> float:
	return float(_down_ticks_left) / Engine.physics_ticks_per_second if is_downed() else 0.0


func _physics_process(_delta: float) -> void:
	if is_downed():
		_count_down_recovery()
		return
	var speed := _get_follow_speed()
	if speed > 0.0:
		velocity = _get_path_direction() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	# Scratch whatever enemy is already within reach; its cooldown limits how often.
	if scratch.can_attack() and not scratch.find_targets(Vector2.ZERO).is_empty():
		scratch.attack(Vector2.ZERO)


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


## Counts one tick toward getting up. It holds while Carl is down: in a level that is GAME OVER,
## where the game is paused anyway, and she gets up only after a retry reloads the floor.
func _count_down_recovery() -> void:
	var carl_health := follow_target.get_node_or_null(^"Health") as Health if follow_target != null else null
	if carl_health != null and carl_health.is_dead():
		return
	_down_ticks_left -= 1
	if _down_ticks_left <= 0:
		_recover()


func _on_damaged(_amount: int) -> void:
	if is_downed():
		return
	if _hurt_flash_tween != null:
		_hurt_flash_tween.kill()
	look.modulate = HURT_FLASH_COLOR
	_hurt_flash_tween = create_tween()
	_hurt_flash_tween.tween_property(look, "modulate", Color.WHITE, 0.25)


## Health reached 0: Donut lies down where she is. A new countdown starts every time.
func _on_downed() -> void:
	_down_ticks_left = maxi(1, roundi(down_time * Engine.physics_ticks_per_second))
	velocity = Vector2.ZERO
	if _hurt_flash_tween != null:
		_hurt_flash_tween.kill()
	look.modulate = DOWN_COLOR
	look.rotation = PI / 2.0
	downed_label.visible = true


func _recover() -> void:
	_down_ticks_left = 0
	health.revive(recovery_health)
	look.modulate = Color.WHITE
	look.rotation = 0.0
	downed_label.visible = false
