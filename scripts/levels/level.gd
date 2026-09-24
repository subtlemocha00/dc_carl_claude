class_name Level
extends Node2D
## Root script of every level scene. It:
## - places Carl and Donut at the spawn point they arrived through (chosen by the Stairs
##   that loaded this level);
## - connects the HUD to Carl's health;
## - handles the temporary Phase 2 game over: when Carl dies, the level restarts after a
##   short delay with everything, including Carl's health, reset. A later save/checkpoint
##   phase only needs to replace _on_carl_died().

@export var carl: Node2D
@export var donut: Node2D
@export var hud: CanvasLayer
## Seconds between Carl dying and the level restarting.
@export var restart_delay: float = 2.0
## Where Donut appears relative to Carl's spawn point.
@export var donut_spawn_offset: Vector2 = Vector2(-48, 16)

## Name of the Marker2D under SpawnPoints where Carl arrives. The Stairs that load a
## level set this before the level enters the scene tree. Empty means Carl and Donut keep
## their positions from the level scene, which is also where Carl restarts after dying.
var arrival_spawn_point: StringName = &""


func _ready() -> void:
	if arrival_spawn_point != &"":
		_place_actors_at_spawn(arrival_spawn_point)
	hud.show_health(carl.health)
	carl.health.died.connect(_on_carl_died)


func _place_actors_at_spawn(spawn_name: StringName) -> void:
	var spawn := get_node_or_null(NodePath("SpawnPoints/" + spawn_name)) as Marker2D
	if spawn == null:
		push_error("Level '%s' has no spawn point named '%s'." % [name, spawn_name])
		return
	carl.teleport_to(spawn.global_position)
	donut.global_position = spawn.global_position + donut_spawn_offset
	donut.reset_physics_interpolation()


func _on_carl_died() -> void:
	# If the level is freed before the timer ends, the connection is removed automatically.
	get_tree().create_timer(restart_delay).timeout.connect(_restart)


func _restart() -> void:
	get_tree().reload_current_scene()
