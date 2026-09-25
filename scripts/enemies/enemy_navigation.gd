class_name EnemyNavigation
extends NavigationAgent2D
## How an enemy finds its way (Phase 7). Add it to an enemy as a child named
## "NavigationAgent2D". The enemy calls get_move_direction(goal) every physics tick and moves
## its body that way with move_and_slide(); Enemy.navigate_toward() does exactly that.
## - It follows the level's navigation mesh, which level_navigation.gd bakes from the wall tiles
##   when the level loads. So an enemy walks around a wall to reach a goal behind it, instead of
##   pushing against the wall. The levels bake the mesh 14 px away from walls (agent_radius), so
##   every path has room for an enemy body up to 14 px in radius.
## - A goal the mesh cannot reach exactly (inside a wall, or right against one) is reached as
##   closely as the mesh allows; then the enemy stops there rather than pushing on.
## - Where there is no navigation mesh at all (a test arena without a level), it heads straight
##   for the goal, as enemies did before Phase 7. Walls still stop the body there.
## It only moves toward goals it is given. Deciding what the goal is (Carl, a firing position,
## away from Carl) is the enemy's job.


## The unit direction the enemy should move in now to get to `goal` (global position), or zero
## when it should stand still: it is as close as the mesh allows, or the level's navigation map
## is not built yet (it is built during the first physics frame after the level loads).
func get_move_direction(goal: Vector2) -> Vector2:
	var from := (get_parent() as Node2D).global_position
	if not has_navigation_mesh():
		return from.direction_to(goal)
	if not is_map_ready():
		return Vector2.ZERO
	# Setting the target asks for a new path. That is cheap on these small levels and keeps the
	# path up to date while the goal (usually Carl) moves.
	target_position = goal
	if is_navigation_finished():
		return Vector2.ZERO
	return from.direction_to(get_next_path_position())


## True when the enemy's world has a navigation mesh (every level has one).
func has_navigation_mesh() -> bool:
	return not NavigationServer2D.map_get_regions(get_navigation_map()).is_empty()


## True once the navigation map has been built at least once, so paths can be asked for.
func is_map_ready() -> bool:
	return NavigationServer2D.map_get_iteration_id(get_navigation_map()) > 0
