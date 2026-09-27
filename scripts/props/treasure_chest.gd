class_name TreasureChest
extends StaticBody2D
## A treasure chest (Phase 14), the first thing Carl uses with the Interact key. Standing next to
## it, Carl sees "E: Open Chest" (whatever the Interact key is). Opening it:
## 1. shows it open; its Interactable is one_shot, so it turns itself off: the chest can never be
##    opened again in this live level, and its prompt goes away;
## 2. puts each entry of `contents` in the level as an ordinary world pickup (item_pickup.tscn),
##    near the chest. Carl still has to walk over them: opening the chest gives him nothing by
##    itself, and only Carl can collect them, once (the pickup's own rules).
##
## `contents` is data, set per placed chest: stable item ids (ActionRegistry) and quantities, one
## pickup per entry, in order. Floor 7's chest holds {&"small_health_potion": 1, &"blast_bomb": 2}.
## An id that is not in ActionRegistry, or a quantity outside 1-999 (exactly 1 for a reusable
## item), is reported and left out; the other entries still appear. The id is only ever looked up
## in the registry, never used to load a file.
##
## Where the loot goes: the first free spots of LOOT_OFFSETS around the chest, in that order, so
## the same chest always puts the same loot in the same places. A spot is free when nothing on
## `world` overlaps a pickup there and no wall lies between it and the chest, so loot never lands
## in a wall or outside the room. The first two spots are side by side 82 px below the chest,
## farther than Carl can stand while opening it (InteractionController's 56 px + his 12 px body +
## the pickup's 12 px), so a pickup never lands on him and is never collected just by opening.
##
## Nothing about it is saved. A retry, Return to Title or Continue reloads the level: the chest is
## closed again, none of its loot lies around, and the inventory is back at the floor-entry
## checkpoint (anything collected from it since is taken back), so its loot can never be kept twice.
##
## It is solid (layer `world`, like the walls). Place it under the level's NavigationRegion2D (for
## example NavigationRegion2D/Props) so the navigation mesh routes Donut and the enemies around
## it, like the Terrain, and set `loot_parent` to the level's Pickups node.

## Emitted once, when it opens.
signal opened
## Emitted with the pickups once they are in the level (at the end of the frame it opened in).
signal loot_spawned(pickups: Array[ItemPickup])

const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/props/item_pickup.tscn")
## The most of one consumable a chest entry may hold (the save's own limit).
const MAX_QUANTITY := 999
## Where loot may go, relative to the chest, in order of preference: below it, then above it,
## then beside it.
const LOOT_OFFSETS: Array[Vector2] = [
	Vector2(-40, 72), Vector2(40, 72), Vector2(-40, -72), Vector2(40, -72), Vector2(-88, 0), Vector2(88, 0),
]
## How far from a wall a pickup's centre must be (its 12 px circle and a little room).
const LOOT_CLEARANCE := 14.0
const WORLD_LAYER := 1

## Stable item id -> quantity. One pickup per entry, in this order.
@export var contents: Dictionary[StringName, int] = {}
## Where the pickups are added (the level's Pickups node). Empty: next to the chest.
@export var loot_parent: Node

var _is_open := false

@onready var interactable: Interactable = $Interactable
@onready var closed_look: Node2D = $ClosedLook
@onready var open_look: Node2D = $OpenLook


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_show_state()


func is_open() -> bool:
	return _is_open


## The loot `contents` describes: [ActionDefinition, quantity] pairs in order. Entries that cannot
## be used are reported and left out.
func get_loot() -> Array:
	var loot := []
	for item_id: StringName in contents:
		var item := ActionRegistry.find(item_id)
		var quantity: int = contents[item_id]
		if item == null:
			push_error("TreasureChest '%s': '%s' is not an item id; it is left out." % [get_path(), item_id])
			continue
		var most := MAX_QUANTITY if item.consumable else 1
		if quantity < 1 or quantity > most:
			push_error("TreasureChest '%s': %d of '%s' is not a quantity it can hold (1-%d); it is left out." % [get_path(), quantity, item_id, most])
			continue
		loot.append([item, quantity])
	return loot


func _on_interacted(_interactor: Node2D) -> void:
	if _is_open:
		return
	_is_open = true
	_show_state()
	opened.emit()
	# Interaction may come from inside a physics step; pickups are Area2Ds, so they are added once
	# the frame's physics is over.
	_spawn_loot.call_deferred(get_loot())


func _spawn_loot(loot: Array) -> void:
	# The level may have been left in the same frame (Return to Title).
	if not is_inside_tree():
		return
	var parent := loot_parent if loot_parent != null else get_parent()
	var spots := _find_loot_spots(loot.size())
	var pickups: Array[ItemPickup] = []
	for i in loot.size():
		var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
		pickup.item = loot[i][0]
		pickup.quantity = loot[i][1]
		pickup.name = "%sLoot" % String(pickup.item.id).to_pascal_case()
		parent.add_child(pickup, true)
		pickup.global_position = spots[i]
		pickup.reset_physics_interpolation()
		pickups.append(pickup)
	loot_spawned.emit(pickups)


## The first `count` free spots of LOOT_OFFSETS. If there are not enough (a chest boxed in by
## walls: a level mistake, reported as an error), the rest go on the chest itself, where Carl can
## still reach them.
func _find_loot_spots(count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for offset in LOOT_OFFSETS:
		if spots.size() == count:
			break
		if _is_free_spot(global_position + offset):
			spots.append(global_position + offset)
	if spots.size() < count:
		push_error("TreasureChest '%s' has no free spot for all its loot; the rest lies on the chest." % get_path())
	while spots.size() < count:
		spots.append(global_position)
	return spots


func _is_free_spot(spot: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	circle.radius = LOOT_CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, spot)
	query.collision_mask = WORLD_LAYER
	query.exclude = [get_rid()]
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, spot, WORLD_LAYER, [get_rid()])
	return space.intersect_ray(ray).is_empty()


func _show_state() -> void:
	closed_look.visible = not _is_open
	open_look.visible = _is_open
