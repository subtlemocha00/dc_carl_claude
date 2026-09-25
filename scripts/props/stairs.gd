extends Area2D
## Stairs down: they load the next level scene when Carl walks onto them.
## Dungeon progression only goes down (GAME_SPEC.md section 10), so no level has stairs that
## lead back to the Surface or to a shallower floor. Carl arrives wherever the next level
## scene places him.
## The collision mask only detects the "player" physics layer, so Donut and enemies cannot trigger them.

## Level scene to load when Carl steps onto the stairs.
@export_file("*.tscn") var destination_scene_path: String

var _is_transitioning := false
# Physics frames to wait before reacting. Bodies already standing on the stairs when the
# level starts are reported during the first physics frame. Ignoring them means Carl has to
# step off and back on, so a level whose spawn point is on its stairs never skips itself.
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
	# The change waited for the end of the physics step, and something in that same step may
	# have frozen the game: Carl reaching the stairs and being killed in one tick means GAME OVER.
	# A frozen game never changes level (Phase 10 fix): going on would open the next floor still
	# paused, with no GAME OVER screen, and save its checkpoint with Carl at 0 HP, which cannot be
	# loaded. The retry reloads this level, stairs included.
	if get_tree().paused:
		return
	get_tree().change_scene_to_file(destination_scene_path)
