class_name ActionPerformer
extends Node2D
## Base class for the node that carries out an action: the root of an
## ActionDefinition.performer_scene. Carl adds one as his child for each action in his slots
## and calls perform() each time a slot holding that action is used.
## Subclasses override perform() and keep their own state, such as a cooldown. Moving an
## action to another slot keeps the same performer, so it never resets that state.


## Carries out the action toward `direction` (Carl's facing direction, a unit vector).
## Returns false if the action could not happen right now, for example during a cooldown.
func perform(_direction: Vector2) -> bool:
	push_error("'%s' does not override ActionPerformer.perform()." % name)
	return false
