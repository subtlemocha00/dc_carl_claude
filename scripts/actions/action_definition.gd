class_name ActionDefinition
extends Resource
## Data for one thing Carl can put in a W/A/S/D action slot: a weapon, a usable item, a spell,
## a tool... Each action is a .tres file in resources/actions/.
## What the action does lives in `performer_scene`, not in Carl's script, so adding an action
## never means editing Carl.

## Stable identifier for code and (later) save data. Never shown to the player, and never
## renamed once in use. Two definitions with the same id count as the same action.
@export var id: StringName
## Name shown in the action menu.
@export var display_name: String
## Shorter name for tight spaces (the HUD slot bar, pickup labels). Empty = display_name.
@export var short_name: String
## A sentence or two shown in the action menu.
@export_multiline var description: String
## Optional picture. The placeholder UI shows display_name instead, so this may stay empty.
@export var icon: Texture2D
## False for an action Carl has but cannot put in a slot.
@export var assignable: bool = true
## True for an item that is used up: each successful use removes one from Carl's inventory.
@export var consumable: bool = false
## Scene whose root node is an ActionPerformer. Carl instances it once and calls its
## perform() every time a slot holding this action is used.
@export var performer_scene: PackedScene


## short_name, or display_name when there is no short name.
func get_short_name() -> String:
	return short_name if not short_name.is_empty() else display_name
