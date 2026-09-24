extends CharacterBody2D
## Gelatinous Blob (GAME_SPEC.md section 12): a slow, fairly tough Floor 1 enemy that hurts
## Carl by touching him. It waits until Carl comes within detection_range, then oozes
## straight toward him. Straight-line pursuit is enough for the open Floor 1 room.

## Multiplying the colours by more than 1 briefly brightens the blob when it is hit.
const HIT_FLASH_COLOR := Color(2.2, 2.2, 2.2)

## The actor the blob hunts. Each level sets this to Carl.
@export var target: Node2D
## Movement speed in pixels per second (Carl walks at 180).
@export var move_speed: float = 55.0
## The blob starts chasing when its target comes this close (pixels).
@export var detection_range: float = 220.0
## Once chasing, the blob only gives up when its target is farther away than this (pixels).
@export var chase_range: float = 320.0
## Seconds the blob takes to fade away after dying.
@export var death_fade_time: float = 0.5

var _is_chasing := false
var _hit_flash_tween: Tween

@onready var health: Health = $Health
@onready var contact_attack: MeleeAttack = $ContactAttack
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar_fill: Node2D = %HealthBarFill


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	if target == null:
		push_warning("Gelatinous Blob '%s' has no target set, so it will stay still." % name)


func _physics_process(_delta: float) -> void:
	velocity = _get_chase_direction() * move_speed
	move_and_slide()
	# Touching Carl hurts him; the contact attack's cooldown limits how often.
	if contact_attack.can_attack() and not contact_attack.find_targets(Vector2.ZERO).is_empty():
		contact_attack.attack(Vector2.ZERO)


func _get_chase_direction() -> Vector2:
	if target == null:
		return Vector2.ZERO
	var distance := global_position.distance_to(target.global_position)
	if distance <= detection_range:
		_is_chasing = true
	elif distance > chase_range:
		_is_chasing = false
	if not _is_chasing:
		return Vector2.ZERO
	return global_position.direction_to(target.global_position)


func _on_damaged(_amount: int) -> void:
	if _hit_flash_tween != null:
		_hit_flash_tween.kill()
	modulate = HIT_FLASH_COLOR
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar_fill.scale.x = float(current) / float(maximum)


func _on_died() -> void:
	# A dead blob stops moving and attacking at once. Its Health refuses further hits.
	set_physics_process(false)
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
