# IPolygonGenerator.gd - Interface for Polygon Generators
extends RefCounted
class_name IPolygonGenerator

# Abstract method for generating polygons from atlas and seeds
func generate_body_part_polygons(atlas_image: Image, atlas_texture: ImageTexture, seeds: Dictionary, polygon_epsilon: float) -> Dictionary:
	push_error("generate_body_part_polygons() must be implemented in subclass")
	return {}