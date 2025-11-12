# ICoordinateManager.gd - Interface for Coordinate Managers
extends RefCounted
class_name ICoordinateManager

# Abstract methods for coordinate transformations
func ui_to_canvas(ui_pos: Vector2) -> Vector2:
	push_error("ui_to_canvas() must be implemented in subclass")
	return Vector2.ZERO

func canvas_to_ui(canvas_pos: Vector2) -> Vector2:
	push_error("canvas_to_ui() must be implemented in subclass")
	return Vector2.ZERO

func canvas_to_world(canvas_pos: Vector2) -> Vector2:
	push_error("canvas_to_world() must be implemented in subclass")
	return Vector2.ZERO

func world_to_canvas(world_pos: Vector2) -> Vector2:
	push_error("world_to_canvas() must be implemented in subclass")
	return Vector2.ZERO