class_name FloorEntry
extends RefCounted
## A floor checkpoint: what Carl had when he entered a level.
## - GameState keeps the current floor's FloorEntry in memory; retrying after GAME OVER
##   restores it.
## - SaveManager writes the same FloorEntry to disk, so Continue after quitting restores exactly
##   what a retry would.
## Nothing about the level itself is kept (positions, enemies, collected pickups): loading the
## level again recreates it as authored.

## The level scene. It is always one of FloorRegistry's floors.
var scene_path: String
var carl_health: int
var carl_max_health: int
## From Inventory.get_snapshot().
var inventory: Dictionary
## The action in each slot (slot name -> ActionDefinition). Empty slots are left out.
var action_slots: Dictionary[StringName, ActionDefinition] = {}
