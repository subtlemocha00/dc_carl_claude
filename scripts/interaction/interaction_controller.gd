class_name InteractionController
extends Node2D
## Carl's side of world interaction (Phase 14): which Interactable he could use right now, the
## prompt that says so, and using it when the Interact key (the `interact` action, E by default) is
## pressed. It is a child of Carl (carl.tscn); its `user` is its parent. It knows nothing about what
## it interacts with: chests, and anything added later, are all Interactables.
##
## - Range: an Interactable counts when its position is within `interaction_range` (56 px, less
##   than two tiles) of Carl's centre and no wall (`blocking_layers`: `world`) lies on the straight
##   line between them. The object's own solid body (the Interactable's parent, like the chest) is
##   not a wall. Carl does not need to touch it: standing next to a chest, his centre is 22-30 px
##   from the chest's.
## - Several in range: the nearest. They are looked at in scene-tree order, and a later one only
##   wins if it is nearer by more than TIE_TOLERANCE, so two at (practically) the same distance
##   always give the one earlier in the tree. One key press uses exactly one.
## - Prompt: "<key>: <prompt_text>" above the chosen one ("E: Open Chest"). The key is named by
##   ControlBindings.get_key_label(), like every other key hint, so a rebound Interact key shows
##   itself ("Q: Open Chest"); it refreshes when a binding changes (ControlBindings.HINT_GROUP). It
##   is hidden while nothing is in range, while the game is paused (the action menu, the pause menu,
##   the Settings screen, GAME OVER) and once Carl is down.
## - Input: only the key press event itself uses something, never a key that is merely held down.
##   Every menu takes every key event while it is open, and the game is paused then (this node too),
##   so the Interact key never gets here through a menu, key capture in Settings or GAME OVER, and
##   a key still held when a menu closes can never use anything.
## - It stops for good when its user's Health dies (Carl down).

## Two candidates whose distances differ by no more than this (px) count as equally near.
const TIE_TOLERANCE := 0.5

## How far from Carl's centre an Interactable's position may be (px).
@export var interaction_range: float = 56.0
## What stops interaction through it (a ray from Carl to the Interactable): walls.
@export_flags_2d_physics var blocking_layers: int = 1

## The Interactable the prompt is shown for, or null.
var current: Interactable

var _stopped := false

@onready var user: Node2D = get_parent() as Node2D
@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	add_to_group(ControlBindings.HINT_GROUP)
	var health := user.get_node_or_null(^"Health") as Health
	if health != null:
		health.died.connect(_on_user_died)
	_show_prompt(null)


func _physics_process(_delta: float) -> void:
	_show_prompt(find_interactable())


func _notification(what: int) -> void:
	# Nothing can be used while the game is paused, so the prompt goes away until play resumes
	# (the next physics tick shows it again).
	if what == NOTIFICATION_PAUSED and is_node_ready():
		_show_prompt(null)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact"):
		return
	var target := find_interactable()
	if target == null:
		return
	get_viewport().set_input_as_handled()
	target.interact(user)
	_show_prompt(find_interactable())


## The Interactable Carl would use now (the nearest one in range and in reach), or null.
func find_interactable() -> Interactable:
	if _stopped or user == null or not is_inside_tree():
		return null
	var best: Interactable = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var candidate := node as Interactable
		if candidate == null or not candidate.can_interact(user):
			continue
		var distance := user.global_position.distance_to(candidate.global_position)
		if distance > interaction_range or distance >= best_distance - TIE_TOLERANCE:
			continue
		if _is_blocked(candidate):
			continue
		best = candidate
		best_distance = distance
	return best


## The prompt on screen now ("E: Open Chest"), or "" when none is shown.
func get_prompt_text() -> String:
	return prompt_label.text if prompt_label.visible else ""


## Shows the current keys (SettingsManager calls this on the hint group after a binding changes).
func refresh_control_hints() -> void:
	_show_prompt(current if is_instance_valid(current) else null)


## True if a wall stands between Carl and `candidate`.
func _is_blocked(candidate: Interactable) -> bool:
	if blocking_layers == 0:
		return false
	var query := PhysicsRayQueryParameters2D.create(user.global_position, candidate.global_position, blocking_layers)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	# The object the Interactable belongs to (its parent) may itself be solid, like a chest: its own
	# body is not a wall. Anything else on the blocking layers is.
	return hit.get("collider") != candidate.get_parent()


func _show_prompt(target: Interactable) -> void:
	current = target
	if target == null:
		prompt_label.visible = false
		return
	prompt_label.text = "%s: %s" % [ControlBindings.get_key_label(&"interact"), target.prompt_text]
	prompt_label.reset_size()
	# The label ignores Carl's transform (top_level), so it stays put above the object.
	var anchor := target.global_position + target.prompt_offset
	prompt_label.global_position = anchor - Vector2(prompt_label.size.x / 2.0, prompt_label.size.y)
	prompt_label.visible = true


func _on_user_died() -> void:
	_stopped = true
	_show_prompt(null)
