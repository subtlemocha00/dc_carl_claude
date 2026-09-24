extends Node
## Autoloaded as GameState. Holds the state of the current run: whatever must survive level
## changes during one playthrough. It lives only in memory. Writing it to disk will be a
## future SaveManager's job, which can read and write these same values.
##
## It holds:
## - Carl's hit points (the current level keeps them up to date);
## - the actions Carl has, and which W/A/S/D slot holds each one;
## - the floor-entry state: what Carl had when he entered the current level. After GAME OVER,
##   retrying the level restores it.
## It only stores state. The rules that use it live in the level, Carl, the HUD and the menu.
##
## Test scripts compile before autoloads exist, so they reach this node with
## root.get_node("GameState"). Scripts that tests preload therefore do not name GameState
## directly: the level passes its values to Carl, the HUD and the action menu.

## Carl's maximum HP at the start of a run (GAME_SPEC.md section 5).
const NEW_RUN_CARL_MAX_HEALTH := 100
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")

var carl_health: int
var carl_max_health: int
## Every action Carl has, in the order the action menu lists them.
var available_actions: Array[ActionDefinition] = []
## Which action each W/A/S/D slot holds.
var action_slots := ActionSlots.new()
## Recorded by each level when it starts. Null until then.
var floor_entry: FloorEntry


func _init() -> void:
	start_new_run()


## Resets everything for a new game: full health, Fists in slot D, slots W, A and S empty.
func start_new_run() -> void:
	carl_max_health = NEW_RUN_CARL_MAX_HEALTH
	carl_health = carl_max_health
	# The array and the ActionSlots are reset in place rather than replaced, so every
	# reference to them stays valid.
	available_actions.clear()
	available_actions.append(FISTS)
	action_slots.clear_all()
	action_slots.assign(FISTS, ActionSlots.SLOT_D)
	floor_entry = null


## Keeps Carl's HP here up to date. Levels connect Carl's Health.health_changed to this.
func store_carl_health(current: int, maximum: int) -> void:
	carl_health = current
	carl_max_health = maximum


## Remembers what Carl has on entering the level `scene_path`.
func record_floor_entry(scene_path: String) -> void:
	floor_entry = FloorEntry.new()
	floor_entry.scene_path = scene_path
	floor_entry.carl_health = carl_health
	floor_entry.carl_max_health = carl_max_health


## Puts Carl's HP back to what it was when he entered the current level. The action slots
## are the player's current choice and stay as they are.
func restore_floor_entry() -> void:
	carl_health = floor_entry.carl_health
	carl_max_health = floor_entry.carl_max_health


## What Carl had when he entered a level. When pickups arrive, his inventory joins it.
class FloorEntry:
	## The level scene, which a retry loads again.
	var scene_path: String
	var carl_health: int
	var carl_max_health: int
