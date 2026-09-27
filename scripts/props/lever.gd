class_name Lever
extends StaticBody2D
## A one-shot lever (Phase 15): Carl pulls it with the Interact key, and it tells whatever the level
## connected to it. It is the second kind of interactable, after the treasure chest, and uses the
## same generic parts: an Interactable child ("Pull Lever", one_shot) that Carl's
## InteractionController finds, prompts for ("E: Pull Lever", whatever the Interact key is) and
## uses. Carl knows nothing about levers.
##
## Pulling it:
## 1. shows it pulled (the handle over to the other side, the knob green instead of red);
## 2. its one_shot Interactable turns itself off, so the prompt goes away and it can never be pulled
##    again in this live level (it does not toggle back);
## 3. emits `activated`, once.
##
## What a pull does is not the lever's business: the level connects `activated` to something, in
## the level scene (a signal connection made in the editor), for example a ControlledDoor's open().
## So one lever script serves any level; it never looks anything up by path and knows nothing about
## doors, stairs, chests, the inventory or saving.
##
## Nothing about it is saved. A retry, Return to Title or Continue reloads the level, and the lever
## is back up (not pulled), like everything else on the floor since its checkpoint.
##
## It is solid (layer `world`, like the walls and the chest): place it under the level's
## NavigationRegion2D (for example NavigationRegion2D/Props) so paths go around it.

## Emitted once, when Carl pulls it.
signal activated

var _is_active := false

@onready var interactable: Interactable = $Interactable
@onready var inactive_look: Node2D = $InactiveLook
@onready var active_look: Node2D = $ActiveLook


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_show_state()


## True once it has been pulled.
func is_active() -> bool:
	return _is_active


func _on_interacted(_interactor: Node2D) -> void:
	if _is_active:
		return
	_is_active = true
	_show_state()
	activated.emit()


func _show_state() -> void:
	inactive_look.visible = not _is_active
	active_look.visible = _is_active
