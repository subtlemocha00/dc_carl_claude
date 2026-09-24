class_name Level
extends Node2D
## Root script of every level scene. When the level starts it:
## - gives Carl the run's state from GameState (his HP, inventory and W/A/S/D action slots),
##   and keeps GameState's copy of his HP up to date from then on;
## - records the floor-entry state in GameState: Carl's HP and inventory on entering this level;
## - connects the HUD and the action menu.
##
## GAME OVER: when Carl dies, the game freezes (the scene tree is paused) and stays that way.
## Pressing Enter on the GAME OVER screen retries: GameState goes back to the floor-entry
## state and the level is loaded again, which also puts its enemies and pickups back as they
## started.

@export var carl: Node2D
@export var hud: CanvasLayer
@export var action_menu: CanvasLayer


func _ready() -> void:
	carl.health.set_health(GameState.carl_health, GameState.carl_max_health)
	carl.health.health_changed.connect(GameState.store_carl_health)
	carl.health.died.connect(_on_carl_died)
	carl.inventory = GameState.inventory
	carl.action_slots = GameState.action_slots
	# A retry records this again, which is harmless: GameState was just set back to the
	# values recorded the first time.
	GameState.record_floor_entry(scene_file_path)

	hud.show_health(carl.health)
	hud.show_action_slots(GameState.action_slots, GameState.inventory)
	hud.retry_requested.connect(_on_retry_requested)
	action_menu.setup(GameState.inventory, GameState.action_slots)


func _on_carl_died() -> void:
	# Freeze gameplay: Carl, Donut and the enemies stop. The HUD keeps running while the game
	# is paused, so its GAME OVER screen can still react to Enter.
	get_tree().paused = true


func _on_retry_requested() -> void:
	GameState.restore_floor_entry()
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.floor_entry.scene_path)
