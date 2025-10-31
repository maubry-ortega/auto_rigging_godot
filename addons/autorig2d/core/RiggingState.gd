
# RiggingState.gd
extends Resource

class_name RiggingState

# Properties to hold the state of the rigging process
@export var loaded_image_path: String = ""
@export var part_data: Dictionary = {}
@export var part_names: Array[String] = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"]
@export var seed_data: Dictionary = {}
@export var current_part_name: String = ""
@export var current_seed_name: String = ""
@export var current_polygon_points: PackedVector2Array = PackedVector2Array()
@export var current_bone_data: Dictionary = {}
@export var adding_seeds: bool = false
@export var polygon_epsilon: float = 0.1

# You can add methods here to manipulate the state, e.g., add_part, update_seed, etc.

func _init():
	pass

func add_part_name(name: String) -> bool:
	var clean_name = name.strip_edges().to_lower().replace(" ", "_")
	
	if clean_name.is_empty():
		push_warning("El nombre de la parte no puede estar vacío.")
		return false
		
	if clean_name in part_names:
		push_warning("La parte '%s' ya existe." % clean_name)
		return false
	
	part_names.append(clean_name)
	# Potentially emit a signal here if other parts of the system need to react immediately
	# For now, assume UI will observe changes to part_names array
	return true
