class_name ControlledDoor
extends StaticBody2D
## A door opened by a mechanism (Phase 15), not by Carl directly: it has no Interactable. It starts
## closed. Something in the level calls open() (for example a Lever's `activated` signal, connected
## to it in the level scene), and it stays open for the rest of that live level: it never closes.
##
## - Closed: drawn as a barred iron door, and solid: its collision shape is on `world`, like the
##   walls, so it stops Carl, Donut and the enemies, projectiles stop at it (a stone, a Blast Bomb,
##   which then explodes in front of it), line of sight and blasts do not pass through it, and no
##   Interactable behind it can be used through it. Nothing about it is special-cased elsewhere:
##   it is simply one more solid body on `world`.
## - open(): drawn open (only the frame and the threshold left), and its collision shape is
##   switched off, so everything passes through the doorway. Calling it again does nothing; it
##   never damages or pushes anything (nothing can stand inside a closed door).
##
## Its shape is 64 x 32 px: exactly a two-tile gap in a one-tile-thick wall. Rotate it 90 degrees
## for a gap in a vertical wall.
##
## Navigation: the level's navigation mesh is baked once, when the level loads, from its
## NavigationRegion2D's children. Place the door outside that region (a "Doors" node at the level's
## root), so the mesh includes the doorway and Donut can follow Carl through once it is
## open. Opening does not rebake anything. So the door must close off a dead end (a side room with
## no other way in): then no path ever leads through the doorway while it is closed, because
## nothing Donut or an enemy follows can be behind it.
##
## Nothing about it is saved: a retry, Return to Title or Continue reloads the level with the door
## closed again.

## Emitted once, when it opens.
signal opened

var _is_open := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var closed_look: Node2D = $ClosedLook
@onready var open_look: Node2D = $OpenLook


func _ready() -> void:
	_show_state()


## Opens the door for good. Safe to call any number of times, from anywhere (a signal, a physics
## callback): only the first call does something.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	# Deferred: a shape cannot be switched off while the physics engine is reporting contacts, and
	# open() may be called from such a callback. It takes effect at the end of this frame.
	collision_shape.set_deferred(&"disabled", true)
	_show_state()
	opened.emit()


func is_open() -> bool:
	return _is_open


## True while the door's collision shape is active (it blocks bodies, projectiles and rays).
func is_blocking() -> bool:
	return not collision_shape.disabled


func _show_state() -> void:
	closed_look.visible = not _is_open
	open_look.visible = _is_open
