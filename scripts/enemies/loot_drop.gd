class_name LootDrop
extends Node
## A fixed item an enemy drops when it dies (Phase 12). Add a LootDrop as a child of an enemy
## placed in a level and set `item` and `quantity`: when that enemy's Health dies, an ordinary
## world pickup (scenes/props/item_pickup.tscn) for `quantity` of `item` appears where it died.
## Carl then has to walk over it, like any other pickup; the enemy's death gives him nothing by
## itself. Only Carl collects it (the pickup's own rule), and only once.
## The drop is deterministic: always this item, always this quantity. There are no chances,
## rarities or loot tables. Floor 6's south-west Gelatinous Blob carries Blast Bomb x2.
## Nothing about it is saved. A floor retry or Continue reloads the level, so the enemy is alive
## again with its LootDrop, no dropped pickup exists until it dies again, and the inventory goes
## back to the floor-entry state, so a drop can never be kept or collected twice through a retry.
## The enemy's scene is not changed: any enemy with a child named "Health" can carry one.

## Emitted with the pickup, once it is in the level.
signal dropped(pickup: ItemPickup)

const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/props/item_pickup.tscn")

## What the enemy drops.
@export var item: ActionDefinition
## How many (a reusable item needs only 1).
@export var quantity: int = 1

## The dropped pickup, once it exists (it frees itself when collected).
var pickup: ItemPickup

var _has_dropped := false

@onready var enemy: Node2D = get_parent() as Node2D


func _ready() -> void:
	var health := enemy.get_node_or_null(^"Health") as Health if enemy != null else null
	if health == null or item == null or quantity <= 0:
		push_error("LootDrop '%s' needs an item, a positive quantity and a parent with a Health." % get_path())
		return
	health.died.connect(_on_enemy_died)


## True once the drop has happened (or is about to, at the end of this frame).
func has_dropped() -> bool:
	return _has_dropped


func _on_enemy_died() -> void:
	if _has_dropped:
		return
	_has_dropped = true
	# The enemy usually dies inside a physics step (a hit, a blast). The pickup is an Area2D, so
	# it is added once that step is over, where the enemy died.
	_spawn_pickup.call_deferred(enemy.global_position)


func _spawn_pickup(death_position: Vector2) -> void:
	# The level may have been left in the same frame (Return to Title): then there is nothing
	# to drop into.
	if not is_inside_tree():
		return
	pickup = ITEM_PICKUP_SCENE.instantiate() as ItemPickup
	pickup.item = item
	pickup.quantity = quantity
	pickup.name = "%sDrop" % String(item.id).to_pascal_case()
	# Next to the enemy, in the level, not inside it: the enemy fades out and is removed.
	enemy.get_parent().add_child(pickup)
	pickup.global_position = death_position
	pickup.reset_physics_interpolation()
	dropped.emit(pickup)
