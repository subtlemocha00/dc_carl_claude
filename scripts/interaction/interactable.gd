class_name Interactable
extends Node2D
## Something in the world Carl can use with the Interact key (Phase 14). Today that is the treasure
## chest; later it could be a switch, a door, a shrine or someone to talk to.
##
## To make an object interactable, give it an Interactable child (a Node2D with this script), set
## `prompt_text` ("Open Chest") and connect `interacted` to what the object does. Nothing else is needed: Carl's InteractionController finds every Interactable in the
## level (they join the `interactables` group), picks the nearest one in range, shows
## "<Interact key>: <prompt_text>" above it and calls interact() when the Interact key is pressed.
## Neither Carl nor the controller ever knows what kind of object it is.
##
## - Its position is the point Carl's distance is measured to: put it at the object's centre. The
##   prompt appears `prompt_offset` from it.
## - `enabled` false hides it from Carl: no prompt, and interact() does nothing.
## - A `one_shot` Interactable turns itself off on its first use, so it can never be used twice (the
##   chest). Otherwise the object decides, for example by setting `enabled`.
## - An object that can only be used sometimes (a locked door, say) can extend this script and
##   override can_interact().
## Nothing here is saved. Reloading the level (a retry, Continue) builds it again as authored.

## Emitted when `interactor` (Carl) uses it.
signal interacted(interactor: Node2D)

## The group every Interactable joins; InteractionController searches it.
const GROUP := &"interactables"

## What the prompt says after the key: "E: Open Chest".
@export var prompt_text: String = "Interact"
## False: Carl can neither see nor use it.
@export var enabled: bool = true
## True: the first use turns it off for good (for this live level).
@export var one_shot: bool = false
## Where the prompt's bottom centre goes, relative to this node.
@export var prompt_offset: Vector2 = Vector2(0, -24)


func _ready() -> void:
	add_to_group(GROUP)


## True if `interactor` may use it now.
func can_interact(_interactor: Node2D) -> bool:
	return enabled and is_inside_tree()


## Uses it. Returns false (and does nothing) if it cannot be used now.
func interact(interactor: Node2D) -> bool:
	if not can_interact(interactor):
		return false
	if one_shot:
		enabled = false
	interacted.emit(interactor)
	return true
