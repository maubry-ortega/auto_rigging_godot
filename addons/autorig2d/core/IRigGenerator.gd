# IRigGenerator.gd - Interface for Rig Generators
extends RefCounted
class_name IRigGenerator

# Abstract methods that must be implemented by concrete generators
func generate_preview() -> void:
	push_error("generate_preview() must be implemented in subclass")

func generate_weights() -> void:
	push_error("generate_weights() must be implemented in subclass")

func set_current_hierarchy(hierarchy_name: String) -> void:
	push_error("set_current_hierarchy() must be implemented in subclass")

func get_current_hierarchy() -> String:
	push_error("get_current_hierarchy() must be implemented in subclass")
	return ""

func get_hierarchy_builder():
	push_error("get_hierarchy_builder() must be implemented in subclass")