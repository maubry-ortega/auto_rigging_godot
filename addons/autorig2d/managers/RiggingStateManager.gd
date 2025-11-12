# RiggingStateManager.gd - Singleton Manager for Rigging State with Observer Pattern
extends "res://addons/autorig2d/patterns/ISubject.gd"

class_name RiggingStateManager

# Singleton instance
static var _instance: RiggingStateManager = null

# Properties to hold the state of the rigging process
var loaded_image_path: String = ""
var part_data: Dictionary = {}
var part_names: Array[String] = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"]
var seed_data: Dictionary = {}
var current_part_name: String = ""
var current_seed_name: String = ""
var current_polygon_points: PackedVector2Array = PackedVector2Array()
var current_bone_data: Dictionary = {}
var adding_seeds: bool = false
var polygon_epsilon: float = 0.1

# Hierarchy properties
var current_hierarchy_name: String = "humanoid"
var custom_hierarchies: Dictionary = {}
var hierarchy_data: Dictionary = {}

# Observer list
var _observers: Array = []

# Private constructor for Singleton
func _init():
	if _instance != null:
		push_error("RiggingStateManager is a singleton and cannot be instantiated directly")
		return
	_instance = self
	_initialize_defaults()

# Get singleton instance
static func get_instance() -> RiggingStateManager:
	if _instance == null:
		_instance = RiggingStateManager.new()
	return _instance

func _initialize_defaults():
	for part_name in part_names:
		part_data[part_name] = {"parent": ""}

# Observer pattern implementation
func attach(observer) -> void:
	if observer not in _observers:
		_observers.append(observer)

func detach(observer) -> void:
	_observers.erase(observer)

func notify(data = null) -> void:
	for observer in _observers:
		if observer and observer.has_method("update"):
			observer.update(self, data)

# State management methods
func add_part_name(name: String) -> bool:
	var clean_name = name.strip_edges().to_lower().replace(" ", "_")

	if clean_name.is_empty():
		push_warning("Part name cannot be empty.")
		return false

	if clean_name in part_names:
		push_warning("Part '%s' already exists." % clean_name)
		return false

	part_names.append(clean_name)
	part_data[clean_name] = {"parent": ""}
	notify({"type": "part_added", "part_name": clean_name})
	return true

# Hierarchy methods
func set_current_hierarchy(name: String):
	current_hierarchy_name = name
	notify({"type": "hierarchy_changed", "hierarchy_name": name})

func get_current_hierarchy() -> String:
	return current_hierarchy_name

func save_hierarchy_data(name: String, data: Dictionary):
	custom_hierarchies[name] = data
	notify({"type": "hierarchy_saved", "hierarchy_name": name})

func load_hierarchy_data(name: String) -> Dictionary:
	if custom_hierarchies.has(name):
		return custom_hierarchies[name]
	return {}

func get_available_hierarchies() -> Array[String]:
	var result: Array[String] = ["humanoid"]

	for name in custom_hierarchies.keys():
		if name not in result:
			result.append(name)

	return result

# Seed management
func add_seed(part_name: String, position: Vector2):
	if not seed_data.has(part_name):
		seed_data[part_name] = []
	seed_data[part_name].append(position)
	notify({"type": "seed_added", "part_name": part_name, "position": position})

func clear_seeds_for_part(part_name: String):
	if seed_data.has(part_name):
		seed_data[part_name].clear()
		notify({"type": "seeds_cleared", "part_name": part_name})

# Reset state
func reset():
	loaded_image_path = ""
	seed_data.clear()
	current_part_name = ""
	adding_seeds = false
	notify({"type": "state_reset"})