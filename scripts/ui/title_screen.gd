extends Control
## Placeholder title screen for the Phase 0 project foundation.
## It only displays text. Starting the game is added in a later phase.

@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	# The game version lives in Project Settings > Application > Config > Version,
	# so it only has to be changed in one place.
	var game_version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var engine_version: String = Engine.get_version_info()["string"]
	version_label.text = "Version %s  |  Godot %s" % [game_version, engine_version]
