extends Node
## Autoloaded as GameState. Holds the state of the current run: whatever must survive level
## changes during one playthrough. It lives only in memory; SaveManager (the other autoload)
## writes its floor checkpoint to disk and reads it back. GameState itself never touches files.
##
## It holds:
## - Carl's hit points (the current level keeps them up to date);
## - Carl's inventory: his innate actions (Fists) and how many of each item he carries;
## - which W/A/S/D slot holds which of those actions;
## - the floor-entry state (a FloorEntry): what Carl had when he entered the current level.
##   After GAME OVER, retrying the level restores it; Continue on the title screen starts from it.
## It only stores state. The rules that use it live in the level, Carl, the HUD and the menu.
##
## Test scripts compile before autoloads exist, so they reach this node with
## root.get_node("GameState"). Scripts that tests preload therefore do not name GameState
## directly: the level passes its values to Carl, the HUD and the action menu.

## Carl's maximum HP at the start of a run (GAME_SPEC.md section 5).
const NEW_RUN_CARL_MAX_HEALTH := 100
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
## Actions Carl always has, with no quantity. Nothing else may be innate.
const INNATE_ACTIONS: Array[ActionDefinition] = [FISTS]

var carl_health: int
var carl_max_health: int
## Carl's actions and item quantities. The only place a quantity is stored.
var inventory := Inventory.new()
## Which action each W/A/S/D slot holds. It only accepts actions in `inventory`.
var action_slots := ActionSlots.new(inventory)
## Recorded by each level when it starts. Null until then.
var floor_entry: FloorEntry


func _init() -> void:
	start_new_run()


## Resets everything for a new game: full health, only Fists (in slot D), slots W, A and S
## empty, no items.
func start_new_run() -> void:
	carl_max_health = NEW_RUN_CARL_MAX_HEALTH
	carl_health = carl_max_health
	# The Inventory and ActionSlots are reset in place rather than replaced, so every
	# reference to them stays valid.
	inventory.reset(INNATE_ACTIONS)
	action_slots.clear_all()
	action_slots.assign(FISTS, ActionSlots.SLOT_D)
	floor_entry = null


## Starts a run from a saved checkpoint (Continue): exactly its HP, inventory and slot layout.
## The caller then loads `checkpoint.scene_path`.
func continue_from(checkpoint: FloorEntry) -> void:
	start_new_run()
	floor_entry = checkpoint
	action_slots.clear_all()
	restore_floor_entry()


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
	floor_entry.inventory = inventory.get_snapshot()
	floor_entry.action_slots = action_slots.get_layout()


## Puts Carl's HP and inventory back to what they were when he entered the current level.
## Items picked up since then are gone again, and items used since then are back. A slot
## holding an item Carl no longer has becomes empty (ActionSlots does this by itself).
## The slot layout is otherwise the player's latest choice, but a slot that is empty now gets
## back what it held at floor entry. So a potion slot that emptied when the last potion was
## drunk holds the potion again once the retry returns it.
func restore_floor_entry() -> void:
	carl_health = floor_entry.carl_health
	carl_max_health = floor_entry.carl_max_health
	inventory.restore_snapshot(floor_entry.inventory)
	action_slots.fill_empty_slots(floor_entry.action_slots)
