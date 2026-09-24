extends Control
## Placeholder title screen. Pressing Enter (the ui_confirm_game action) starts the game.

## First level scene loaded when the game starts.
@export_file("*.tscn") var start_scene_path: String = "res://scenes/levels/surface.tscn"

@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	# The game version lives in Project Settings > Application > Config > Version,
	# so it only has to be changed in one place.
	var game_version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var engine_version: String = Engine.get_version_info()["string"]
	version_label.text = "Version %s  |  Godot %s" % [game_version, engine_version]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_confirm_game"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(start_scene_path)
