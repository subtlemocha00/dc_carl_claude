extends NavigationRegion2D
## Builds a level's navigation mesh (the walkable area used by Donut) when the level loads.
##
## The walkable area is the outline drawn on this node's NavigationPolygon.
## Walls are cut out of it automatically from the collision shapes of child nodes,
## such as the wall tiles of the Terrain TileMapLayer. Because the mesh is rebuilt on
## every load, editing a level's walls never leaves an outdated navigation mesh behind.


func _ready() -> void:
	# false = bake immediately on the main thread. Small levels take only milliseconds.
	bake_navigation_polygon(false)
