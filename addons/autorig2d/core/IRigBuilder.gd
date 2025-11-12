# IRigBuilder.gd - Interface for Rig Builders
extends RefCounted
class_name IRigBuilder

# Abstract method for building complete rigs
func build_complete_rig(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2, all_polygons: Array, part_order: Array, hierarchy_name: String) -> Dictionary:
	push_error("build_complete_rig() must be implemented in subclass")
	return {}