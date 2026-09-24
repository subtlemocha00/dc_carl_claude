extends Area2D
## Stairs that load another level scene when Carl walks onto them.
## The collision mask only detects the "player" physics layer, so Donut and enemies cannot trigger them.

## Level scene to load when Carl steps onto the stairs.
@export_file("*.tscn") var destination_scene_path: String
## Spawn point (a Marker2D under the destination level's SpawnPoints node) where Carl arrives.
## Leave empty to keep Carl's position from the destination level scene.
@export var destination_spawn_point: StringName = &""

var _is_transitioning := false
# Physics frames to wait before reacting. Bodies already standing on the stairs when the
# level starts are reported during the first physics frame. Ignoring them means Carl has to
# step off and back on, so arriving on top of stairs can never bounce him straight back.
var _frames_until_armed := 2


func _ready() -> void:
	if not ResourceLoader.exists(destination_scene_path):
		push_error("Stairs '%s' has an invalid destination_scene_path: '%s'." % [get_path(), destination_scene_path])
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	_frames_until_armed -= 1
	if _frames_until_armed <= 0:
		set_physics_process(false)


func _on_body_entered(_body: Node2D) -> void:
	if _frames_until_armed > 0 or _is_transitioning:
		return
	_is_transitioning = true
	# Scenes cannot be swapped while the physics engine is still reporting overlaps,
	# so the change is deferred until the current frame has finished.
	_change_level.call_deferred()


func _change_level() -> void:
	var level := (load(destination_scene_path) as PackedScene).instantiate()
	if level is Level:
		level.arrival_spawn_point = destination_spawn_point
	get_tree().change_scene_to_node(level)
