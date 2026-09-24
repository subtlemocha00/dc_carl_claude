class_name ActionRegistry
extends RefCounted
## Every action and item in the game, by its stable id (ActionDefinition.id).
## Save files store only these ids. Loading a save turns them back into definitions through
## this list, and an id that is not here is treated as unknown. A new item needs one line here.

const ACTIONS: Dictionary[StringName, ActionDefinition] = {
	&"fists": preload("res://resources/actions/fists.tres"),
	&"small_health_potion": preload("res://resources/actions/small_health_potion.tres"),
}


## The action with `action_id`, or null for an unknown id.
static func find(action_id: StringName) -> ActionDefinition:
	return ACTIONS.get(action_id)
