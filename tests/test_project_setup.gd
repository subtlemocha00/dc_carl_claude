extends "res://tests/support/game_test.gd"
## Phase 11: the project's own user-data folder and the Windows renderer.
## - User data: the project uses its own folder, "DC CARL" (Project Settings > Application >
##   Config > Use Custom User Dir / Custom User Dir Name), so it no longer shares
##   "Godot/app_userdata/Carl & Donut Dungeon Prototype" with the sibling project that has the
##   same name. In this process user:// really is that folder: the operating system's app-data
##   folder + "DC CARL" (for example %APPDATA%\DC CARL on Windows), and not the old shared one.
## - The player's save is still user://savegame.json, and SaveManager (like every game script)
##   names no absolute or per-user path: Godot decides where user:// is.
## - The test-save guard still refuses the player's save in a test run, and this test's own file
##   is inside the test folder, which is inside the new folder.
## - Renderer: still the Compatibility renderer. On Windows it runs through ANGLE
##   (driver.windows = "opengl3_angle"); every other platform keeps Godot's default driver, and
##   the fallbacks stay on. (The driver actually used is checked in a real window by
##   test_windowed_resolutions.gd; a headless run has none.)
## - Version 0.13.0 (Phase 13); the save format is still version 3, and the control settings have
##   their own format, version 1, in their own file, user://settings.json, in the same folder. The
##   autoloads are GameState, SaveManager and (Phase 13) SettingsManager, and nothing else. A test run
##   may not use the player's settings file either.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_project_setup.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const USER_DIR_NAME := "DC CARL"
## The folder this project shared with ../codex until Phase 11 (Godot's default for its name).
const OLD_SHARED_USER_DIR := "Godot/app_userdata/Carl & Donut Dungeon Prototype"
const WINDOWS_DRIVER_SETTING := "rendering/gl_compatibility/driver.windows"
## The other platforms' Compatibility driver settings, which Phase 11 leaves at Godot's defaults.
const OTHER_DRIVER_SETTINGS: Array[String] = [
	"rendering/gl_compatibility/driver",
	"rendering/gl_compatibility/driver.linuxbsd",
	"rendering/gl_compatibility/driver.macos",
	"rendering/gl_compatibility/driver.web",
	"rendering/gl_compatibility/driver.android",
	"rendering/gl_compatibility/driver.ios",
	"rendering/gl_compatibility/fallback_to_angle",
	"rendering/gl_compatibility/fallback_to_native",
]
## Text that would mean a script names a machine's own folders instead of user://.
const ABSOLUTE_PATH_MARKERS: Array[String] = ["appdata", "app_userdata", "roaming", "c:/", "c:\\", "/home/", "/users/", "library/application support"]


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_check_user_data_folder()
	_check_save_paths()
	_check_renderer_settings()
	_check_versions()
	finish()


func _check_user_data_folder() -> void:
	print("-- The project's own user-data folder")
	check(ProjectSettings.get_setting("application/config/use_custom_user_dir") == true, "Use Custom User Dir is on")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name") == USER_DIR_NAME,
			"Custom User Dir Name is \"DC CARL\"", str(ProjectSettings.get_setting("application/config/custom_user_dir_name")))
	var user_dir := OS.get_user_data_dir()
	print("OS.get_user_data_dir() = " + user_dir)
	check(user_dir == OS.get_data_dir().path_join(USER_DIR_NAME), "user:// is the app-data folder + \"DC CARL\"",
			"%s (app data: %s)" % [user_dir, OS.get_data_dir()])
	check(user_dir != OS.get_data_dir().path_join(OLD_SHARED_USER_DIR) and not user_dir.contains("app_userdata"),
			"user:// is not the folder shared with the sibling project", user_dir)
	check(ProjectSettings.globalize_path("user://") == user_dir + "/", "user:// resolves to that folder", ProjectSettings.globalize_path("user://"))


func _check_save_paths() -> void:
	print("-- Save paths")
	var saves := save_manager()
	var constants: Dictionary = saves.get_script().get_script_constant_map()
	check(constants["DEFAULT_SAVE_PATH"] == "user://savegame.json", "the player's save is still user://savegame.json", str(constants["DEFAULT_SAVE_PATH"]))
	check(ProjectSettings.globalize_path(constants["DEFAULT_SAVE_PATH"]) == OS.get_user_data_dir().path_join("savegame.json"),
			"so it lives in the DC CARL folder", ProjectSettings.globalize_path(constants["DEFAULT_SAVE_PATH"]))
	for script_path in _game_scripts("res://scripts"):
		var text := FileAccess.get_file_as_string(script_path).to_lower()
		var found := ABSOLUTE_PATH_MARKERS.filter(func(marker: String) -> bool: return text.contains(marker))
		check(found.is_empty(), "%s names no absolute or per-user folder" % script_path.get_file(), str(found))
	var settings := settings_manager()
	var settings_constants: Dictionary = settings.get_script().get_script_constant_map()
	check(settings_constants["DEFAULT_SETTINGS_PATH"] == "user://settings.json"
			and ProjectSettings.globalize_path(settings_constants["DEFAULT_SETTINGS_PATH"]) == OS.get_user_data_dir().path_join("settings.json"),
			"the player's control settings are user://settings.json, in the DC CARL folder, beside the save")
	check(not settings.is_settings_path_allowed(settings_constants["DEFAULT_SETTINGS_PATH"])
			and not settings.is_settings_path_allowed("user://test_saves/../settings.json"), "a test run may not use the player's settings")
	check(settings.settings_path == TEST_SAVE_FOLDER + "test_project_setup_settings.json" and settings.is_settings_path_allowed(settings.settings_path),
			"this test has its own settings file in the test folder", settings.settings_path)
	# The Phase 8 guard: a test run may use only files in the test folder, never the player's save.
	check(not saves.is_save_path_allowed(constants["DEFAULT_SAVE_PATH"]), "a test run may not use the player's save")
	check(not saves.is_save_path_allowed("user://test_saves/../savegame.json"), "nor reach it through the test folder")
	check(saves.save_path == TEST_SAVE_FOLDER + "test_project_setup.json" and saves.is_save_path_allowed(saves.save_path),
			"this test saves in its own file in the test folder", saves.save_path)
	check(ProjectSettings.globalize_path(TEST_SAVE_FOLDER) == OS.get_user_data_dir().path_join("test_saves") + "/",
			"the test folder is inside the DC CARL folder", ProjectSettings.globalize_path(TEST_SAVE_FOLDER))


func _check_renderer_settings() -> void:
	print("-- Renderer settings")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility"
			and ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility",
			"still the Compatibility renderer")
	check(ProjectSettings.get_setting(WINDOWS_DRIVER_SETTING) == "opengl3_angle", "Windows runs it through ANGLE (opengl3_angle)",
			str(ProjectSettings.get_setting(WINDOWS_DRIVER_SETTING)))
	for setting in OTHER_DRIVER_SETTINGS:
		check(ProjectSettings.get_setting(setting) == ProjectSettings.property_get_revert(setting),
				"%s is left at Godot's default (%s)" % [setting, ProjectSettings.property_get_revert(setting)], str(ProjectSettings.get_setting(setting)))
	# project.godot itself: the Windows driver is the only driver line.
	var driver_lines := Array(FileAccess.get_file_as_string("res://project.godot").split("\n")).filter(
			func(line: String) -> bool: return line.begins_with("gl_compatibility/"))
	check(driver_lines == ["gl_compatibility/driver.windows=\"opengl3_angle\""], "project.godot sets only the Windows driver", str(driver_lines))


func _check_versions() -> void:
	print("-- Versions")
	check(ProjectSettings.get_setting("application/config/version") == "0.13.0", "the game version is 0.13.0",
			str(ProjectSettings.get_setting("application/config/version")))
	check(save_manager().SAVE_VERSION == 3, "the save format is still version 3", str(save_manager().SAVE_VERSION))
	check(settings_manager().SETTINGS_VERSION == 1, "the settings format is version 1", str(settings_manager().SETTINGS_VERSION))
	var autoloads := Array(ProjectSettings.get_property_list()).map(func(property: Dictionary) -> String: return property["name"]).filter(
			func(setting: String) -> bool: return setting.begins_with("autoload/"))
	check(autoloads == ["autoload/GameState", "autoload/SaveManager", "autoload/SettingsManager"],
			"the autoloads are GameState, SaveManager and SettingsManager", str(autoloads))


## Every .gd file under `folder`.
func _game_scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for subfolder in DirAccess.get_directories_at(folder):
		found.append_array(_game_scripts(folder.path_join(subfolder)))
	return found
