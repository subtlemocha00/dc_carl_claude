class_name Enemy
extends CharacterBody2D
## What every enemy has in common (Phase 7). An enemy scene's root script extends this and
## writes its own _physics_process() from these pieces:
## - update_activity(): whether it is after its target right now. It becomes active when the
##   target comes within detection_range and gives up when the target is farther than
##   chase_range (straight-line distance, so walls do not hide Carl, but enemies far away never
##   notice him). It also gives up on a target that is down (0 HP).
## - navigate_toward(goal) / stop_moving(): moves the body along the level's navigation mesh
##   (see EnemyNavigation), so it walks around walls instead of into them.
## - has_line_of_sight_to(point): whether a wall is in the way, for enemies that shoot.
## - hit flash, health bar, and dying (it stops, stops blocking, fades out and is removed).
## Attacks are separate nodes in each enemy scene: a MeleeAttack for a touch, a
## ProjectileLauncher for spit. The expected children are Health, Hurtbox, CollisionShape2D,
## NavigationAgent2D (an EnemyNavigation) and a unique HealthBarFill.

## Multiplying the colours by more than 1 briefly brightens an enemy when it is hit.
const HIT_FLASH_COLOR := Color(2.2, 2.2, 2.2)

## The actor the enemy hunts. Each level sets this to Carl.
@export var target: Node2D
## Movement speed in pixels per second (Carl walks at 180).
@export var move_speed: float = 55.0
## The enemy becomes active when its target comes this close (pixels).
@export var detection_range: float = 220.0
## Once active, the enemy only gives up when its target is farther away than this (pixels).
@export var chase_range: float = 320.0
## Physics layers that block the enemy's view: the "world" walls, which also stop projectiles.
@export_flags_2d_physics var sight_blocking_layers: int = 1
## Seconds the enemy takes to fade away after dying.
@export var death_fade_time: float = 0.5

var _is_active := false
var _hit_flash_tween: Tween

@onready var health: Health = $Health
@onready var navigation: EnemyNavigation = $NavigationAgent2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar_fill: Node2D = %HealthBarFill


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	if target == null:
		push_warning("Enemy '%s' has no target set, so it will stay still." % name)


## True while the enemy is after its target, as last decided by update_activity().
func is_active() -> bool:
	return _is_active


## Updates and returns whether the enemy is after its target (see the class description).
## Enemies call it once per physics tick.
func update_activity() -> bool:
	if target == null or _is_target_down():
		_is_active = false
		return false
	var distance := global_position.distance_to(target.global_position)
	if distance <= detection_range:
		_is_active = true
	elif distance > chase_range:
		_is_active = false
	return _is_active


## Moves this tick toward `goal` (global position) along the navigation mesh, at move_speed.
func navigate_toward(goal: Vector2) -> void:
	velocity = navigation.get_move_direction(goal) * move_speed
	move_and_slide()


func stop_moving() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


## True if no wall (sight_blocking_layers) is between the enemy's centre and `point`.
## Donut, other enemies and Carl's body do not block the view.
func has_line_of_sight_to(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, point, sight_blocking_layers)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _is_target_down() -> bool:
	var target_health := target.get_node_or_null(^"Health") as Health
	return target_health != null and target_health.is_dead()


func _on_damaged(_amount: int) -> void:
	if _hit_flash_tween != null:
		_hit_flash_tween.kill()
	modulate = HIT_FLASH_COLOR
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar_fill.scale.x = float(current) / float(maximum)


func _on_died() -> void:
	# A dead enemy stops moving and attacking at once. Its Health refuses further hits.
	set_physics_process(false)
	_is_active = false
	velocity = Vector2.ZERO
	# Stop blocking Carl. Physics shapes must not be switched off in the middle of a
	# physics step, so this is deferred to the end of the frame.
	body_shape.set_deferred("disabled", true)
	if _hit_flash_tween != null:
		_hit_flash_tween.kill()
	modulate = Color.WHITE
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, death_fade_time)
	fade.tween_callback(queue_free)
