# IHierarchyBuilder.gd - Interface for Hierarchy Builders
extends RefCounted
class_name IHierarchyBuilder

# Abstract methods for hierarchy management
func get_hierarchy(name: String) -> Dictionary:
	push_error("get_hierarchy() must be implemented in subclass")
	return {}

func create_custom_hierarchy(name: String) -> bool:
	push_error("create_custom_hierarchy() must be implemented in subclass")
	return false

func get_available_hierarchies() -> Array[String]:
	push_error("get_available_hierarchies() must be implemented in subclass")
	return []

func get_current_hierarchy() -> Dictionary:
	push_error("get_current_hierarchy() must be implemented in subclass")
	return {}