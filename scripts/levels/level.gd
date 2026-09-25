class_name Level
extends Node2D
## Root script of every level scene. When the level starts it:
## - gives Carl the run's state from GameState (his HP, inventory and W/A/S/D action slots),
##   and keeps GameState's copy of his HP up to date from then on;
## - gives Donut her HP from GameState the same way (Phase 8). If it is 0 she starts the level
##   downed, and gets up after her usual recovery time;
## - records the floor-entry state in GameState (Carl's HP, inventory and slot layout, and
##   Donut's HP, on entering this level) and saves it as the persistent checkpoint. This is the
##   one place checkpoints are written, so every floor, including future ones, gets one on
##   entry, and nothing during play (damage, pickups, potions, death) ever writes the save;
## - connects the HUD and the action menu;
## - adds the pause menu (Phase 10). Every level gets the same one from here, so no floor scene
##   needs its own, and no floor has pause logic of its own.
##
## GAME OVER: when Carl dies, the game freezes (the scene tree is paused) and stays that way.
## Pressing Enter on the GAME OVER screen retries: GameState goes back to the floor-entry
## state and the level is loaded again, which also puts its enemies and pickups back as they
## started. Donut being downed never causes GAME OVER; only Carl does.
##
## Leaving through the pause menu (Phase 10) never saves: the save keeps the checkpoint written
## when Carl entered this floor, so everything since (damage, items found or used, enemies
## killed) is dropped, exactly as if the window had been closed.
## - Return to Title loads the title screen in this same process. The level and everything in
##   it (enemies, projectiles, pushes, menus) is removed with it, and the title screen clears
##   what GameState still held of the run, so Continue reads the checkpoint from disk.
## - Quit Game closes the game.

const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

@export var carl: Node2D
@export var donut: Node2D
@export var hud: CanvasLayer
@export var action_menu: CanvasLayer

var pause_menu: CanvasLayer


func _ready() -> void:
	carl.health.set_health(GameState.carl_health, GameState.carl_max_health)
	carl.health.health_changed.connect(GameState.store_carl_health)
	carl.health.died.connect(_on_carl_died)
	carl.inventory = GameState.inventory
	carl.action_slots = GameState.action_slots
	donut.start_with_health(GameState.donut_health, GameState.donut_max_health)
	donut.health.health_changed.connect(GameState.store_donut_health)
	# A retry or Continue records and saves this again, which is harmless: GameState was just
	# set back to exactly these values.
	GameState.record_floor_entry(scene_file_path)
	SaveManager.save_checkpoint(GameState.floor_entry)

	hud.show_health(carl.health)
	hud.show_donut_health(donut.health)
	hud.show_action_slots(GameState.action_slots, GameState.inventory)
	hud.retry_requested.connect(_on_retry_requested)
	action_menu.setup(GameState.inventory, GameState.action_slots)

	pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.return_to_title_requested.connect(_on_return_to_title_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)
	add_child(pause_menu)


func _on_carl_died() -> void:
	# Freeze gameplay: Carl, Donut and the enemies stop. The HUD keeps running while the game
	# is paused, so its GAME OVER screen can still react to Enter.
	get_tree().paused = true


func _on_retry_requested() -> void:
	GameState.restore_floor_entry()
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.floor_entry.scene_path)


func _on_return_to_title_requested() -> void:
	# Unpause first: change_scene_to_file() takes this level out of the tree at once, so no
	# tick of it runs unpaused, and get_tree() would be null after it.
	get_tree().paused = false
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))


func _on_quit_requested() -> void:
	# Nothing is saved on the way out; the game stays paused until it closes.
	get_tree().quit()
