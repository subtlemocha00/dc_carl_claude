class_name FloorRegistry
extends RefCounted
## Every level a checkpoint can be saved on, by stable id.
## A save file stores the id, never a scene path. Loading a save can therefore only ever open
## one of these scenes, however the file was edited. A new floor needs one line here.

const FLOORS: Dictionary[StringName, Dictionary] = {
	&"surface": {"name": "The Surface", "scene": "res://scenes/levels/surface.tscn"},
	&"floor_01": {"name": "Floor 1", "scene": "res://scenes/levels/floor_01.tscn"},
	&"floor_02": {"name": "Floor 2", "scene": "res://scenes/levels/floor_02.tscn"},
	&"floor_03": {"name": "Floor 3", "scene": "res://scenes/levels/floor_03.tscn"},
	&"floor_04": {"name": "Floor 4", "scene": "res://scenes/levels/floor_04.tscn"},
	&"floor_05": {"name": "Floor 5", "scene": "res://scenes/levels/floor_05.tscn"},
	&"floor_06": {"name": "Floor 6", "scene": "res://scenes/levels/floor_06.tscn"},
	&"floor_07": {"name": "Floor 7", "scene": "res://scenes/levels/floor_07.tscn"},
}


static func has_floor(floor_id: StringName) -> bool:
	return FLOORS.has(floor_id)


## The scene of `floor_id`, or "" for an unknown id.
static func get_scene_path(floor_id: StringName) -> String:
	return FLOORS[floor_id]["scene"] if FLOORS.has(floor_id) else ""


## The name shown to the player, for example "Floor 2". "" for an unknown id.
static func get_display_name(floor_id: StringName) -> String:
	return FLOORS[floor_id]["name"] if FLOORS.has(floor_id) else ""


## The id of the level at `scene_path`, or &"" if it is not a registered floor.
static func get_floor_id(scene_path: String) -> StringName:
	for floor_id in FLOORS:
		if FLOORS[floor_id]["scene"] == scene_path:
			return floor_id
	return &""
