extends Area2D
## Stairs that load another level scene when Carl walks onto them.
## The collision mask only detects the "player" physics layer, so Donut cannot trigger them.

## Level scene to load when Carl steps onto the stairs.
@export_file("*.tscn") var destination_scene_path: String

var _is_transitioning := false


func _ready() -> void:
	if not ResourceLoader.exists(destination_scene_path):
		push_error("Stairs '%s' has an invalid destination_scene_path: '%s'." % [get_path(), destination_scene_path])
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	# Scenes cannot be swapped while the physics engine is still reporting overlaps,
	# so the change is deferred until the current frame has finished.
	get_tree().change_scene_to_file.call_deferred(destination_scene_path)
