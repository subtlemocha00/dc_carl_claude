class_name Enemy
extends CharacterBody2D
## What every enemy has in common (Phase 7). An enemy scene's root script extends this and
## writes its own _physics_process() from these pieces:
## - update_activity(): chooses the party member the enemy is after, `target` (Phase 8). The
##   party is every node in the PARTY_GROUP group: Carl and Donut. A member is a valid target
##   while its Health is above 0, so a downed Donut (or a downed Carl) is never one.
##   - With no target, the enemy picks the nearest valid member within detection_range
##     (straight-line distance, so walls do not hide anyone, but enemies far away never notice
##     the party).
##   - It then keeps that target while it stays valid and within chase_range, even if the
##     other member is now a little closer, so it never flips between Carl and Donut.
##   - When the target is downed or gets farther than chase_range, the enemy drops it and
##     picks again the same way (possibly the other member, possibly nobody).
## - navigate_toward(goal) / stop_moving(): moves the body along the level's navigation mesh
##   (see EnemyNavigation), so it walks around walls instead of into them.
## - has_line_of_sight_to(point): whether a wall is in the way, for enemies that shoot.
## - hit flash, health bar, and dying (it stops, stops blocking, fades out and is removed).
## Attacks are separate nodes in each enemy scene: a MeleeAttack for a touch, a
## ProjectileLauncher for spit. They hurt whoever is on player_hurtbox (Carl and Donut), not
## only the target. The expected children are Health, Hurtbox, CollisionShape2D,
## NavigationAgent2D (an EnemyNavigation) and a unique HealthBarFill.

## Multiplying the colours by more than 1 briefly brightens an enemy when it is hit.
const HIT_FLASH_COLOR := Color(2.2, 2.2, 2.2)
## The group of the characters enemies hunt. carl.tscn and donut.tscn put themselves in it.
const PARTY_GROUP := &"party"

## Movement speed in pixels per second (Carl walks at 180).
@export var move_speed: float = 55.0
## The enemy picks a target among the party members this close (pixels).
@export var detection_range: float = 220.0
## Once it has a target, the enemy only gives up when the target is farther than this (pixels).
@export var chase_range: float = 320.0
## Physics layers that block the enemy's view: the "world" walls, which also stop projectiles.
@export_flags_2d_physics var sight_blocking_layers: int = 1
## Seconds the enemy takes to fade away after dying.
@export var death_fade_time: float = 0.5

## The party member the enemy is after (Carl or Donut), or null while it is idle. Chosen by
## update_activity(); it is not set in the level.
var target: Node2D

var _hit_flash_tween: Tween

@onready var health: Health = $Health
@onready var navigation: EnemyNavigation = $NavigationAgent2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar_fill: Node2D = %HealthBarFill


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)


## True while the enemy has a target, as last decided by update_activity().
func is_active() -> bool:
	return target != null


## Updates `target` (see the class description) and returns whether the enemy has one.
## Enemies call it once per physics tick.
func update_activity() -> bool:
	if target != null and (not is_valid_target(target)
			or global_position.distance_to(target.global_position) > chase_range):
		target = null
	if target == null:
		target = _find_nearest_party_member(detection_range)
	return target != null


## True if `member` can be hunted: a party member in the level whose Health is above 0.
func is_valid_target(member: Node2D) -> bool:
	if not is_instance_valid(member) or not member.is_inside_tree() or not member.is_in_group(PARTY_GROUP):
		return false
	var member_health := member.get_node_or_null(^"Health") as Health
	return member_health != null and not member_health.is_dead()


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


## The nearest valid party member at most `max_distance` away, or null. On an exact tie the one
## earlier in the scene tree wins, so the choice is always the same.
func _find_nearest_party_member(max_distance: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := max_distance
	for member in get_tree().get_nodes_in_group(PARTY_GROUP):
		var member_2d := member as Node2D
		if member_2d == null or not is_valid_target(member_2d):
			continue
		var distance := global_position.distance_to(member_2d.global_position)
		if distance <= nearest_distance and (nearest == null or distance < nearest_distance):
			nearest = member_2d
			nearest_distance = distance
	return nearest


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
	target = null
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
