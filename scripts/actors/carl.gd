extends CharacterBody2D
## Carl, the player-controlled character.
## - The arrow keys (the move_* input actions) move him. W/A/S/D never do.
## - W/A/S/D are his four action slots (action_w, action_a, action_s, action_d). Holding a
##   slot's key uses the action in that slot toward his facing direction. Carl does not decide
##   which action is in which slot: he asks `action_slots`, the run's ActionSlots.
## - Each action is carried out by an ActionPerformer made from the action's performer_scene,
##   so new weapons and items need no changes to this script.

const HURT_FLASH_COLOR := Color(1.0, 0.35, 0.35)
const DOWN_COLOR := Color(0.45, 0.45, 0.45, 0.8)
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

## Movement speed in pixels per second.
@export var move_speed: float = 180.0

## Which action each W/A/S/D slot holds. Levels set this to GameState.action_slots.
## While it is null, every slot is empty.
var action_slots: ActionSlots:
	set(value):
		if action_slots != null:
			action_slots.changed.disconnect(_add_missing_performers)
		action_slots = value
		if action_slots != null:
			action_slots.changed.connect(_add_missing_performers)
			_add_missing_performers()

## Most recent non-zero movement direction (unit length). Carl keeps facing this way
## after the keys are released, and his actions go this way.
var facing_direction: Vector2 = Vector2.DOWN

var _hurt_flash_tween: Tween
## Carl's ActionPerformer for each action id. It is created when the action first appears in
## one of his slots, and kept if the action moves to another slot.
var _performers: Dictionary[StringName, ActionPerformer] = {}
## Input actions whose keys were already held when the game was unpaused, such as keys used
## in the action menu. They count as released until their key is let go, so one key press
## never works both in a menu and in the game.
var _held_before_unpause: Array[StringName] = []

## Carl's hit points. The HUD and the level listen to its signals.
@onready var health: Health = $Health
@onready var facing_indicator: Node2D = %FacingIndicator
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	facing_indicator.rotation = facing_direction.angle()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		_held_before_unpause.clear()
		for action: StringName in MOVE_ACTIONS + ActionSlots.SLOTS:
			if Input.is_action_pressed(action):
				_held_before_unpause.append(action)


func _physics_process(_delta: float) -> void:
	# Keys held since the last unpause count again once they have been let go.
	_held_before_unpause = _held_before_unpause.filter(Input.is_action_pressed)

	var input_direction := _get_move_input()
	# move_and_slide() applies the physics time step itself, so the speed is in pixels
	# per second regardless of frame rate, and Carl slides along walls instead of sticking.
	velocity = input_direction * move_speed
	move_and_slide()

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction.normalized()
		facing_indicator.rotation = facing_direction.angle()

	# Holding a slot's key keeps using its action; the action's own cooldown limits how often.
	for slot in ActionSlots.SLOTS:
		if _is_input_held(slot):
			_use_slot(slot)


## Moves Carl instantly without the camera sliding over from his previous position.
func teleport_to(new_position: Vector2) -> void:
	global_position = new_position
	reset_physics_interpolation()
	camera.reset_smoothing()


## The node that carries out `action` for Carl, or null if the action has never been in one
## of his slots.
func get_action_performer(action: ActionDefinition) -> ActionPerformer:
	return _performers.get(action.id)


## Uses the action in `slot` toward Carl's facing direction. An empty slot does nothing.
func _use_slot(slot: StringName) -> void:
	var action := action_slots.get_action(slot) if action_slots != null else null
	if action != null:
		_performers[action.id].perform(facing_direction)


## Creates a performer for every action in a slot that does not have one yet, so an action
## is ready from the first key press after it is assigned.
func _add_missing_performers() -> void:
	for slot in ActionSlots.SLOTS:
		var action := action_slots.get_action(slot)
		if action == null or _performers.has(action.id):
			continue
		var node := action.performer_scene.instantiate()
		var performer := node as ActionPerformer
		if performer == null:
			push_error("The performer_scene of action '%s' must have an ActionPerformer root." % action.id)
			node.free()
			continue
		add_child(performer)
		_performers[action.id] = performer


## The arrow keys as a direction. Its length is capped at 1, so diagonal movement is not
## faster than straight movement.
func _get_move_input() -> Vector2:
	var direction := Vector2(
			_get_input_strength(&"move_right") - _get_input_strength(&"move_left"),
			_get_input_strength(&"move_down") - _get_input_strength(&"move_up"))
	return direction.limit_length(1.0)


func _get_input_strength(action: StringName) -> float:
	return 0.0 if action in _held_before_unpause else Input.get_action_strength(action)


func _is_input_held(action: StringName) -> bool:
	return Input.is_action_pressed(action) and action not in _held_before_unpause


func _on_damaged(_amount: int) -> void:
	if _hurt_flash_tween != null:
		_hurt_flash_tween.kill()
	modulate = HURT_FLASH_COLOR
	_hurt_flash_tween = create_tween()
	_hurt_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _on_died() -> void:
	# Carl stops reading input, so he can no longer move or attack.
	# What happens next (GAME OVER) is decided by the level, not by Carl.
	set_physics_process(false)
	velocity = Vector2.ZERO
	if _hurt_flash_tween != null:
		_hurt_flash_tween.kill()
	modulate = DOWN_COLOR
