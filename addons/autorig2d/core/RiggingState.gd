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

# Nuevas propiedades para jerarquías personalizadas
@export var current_hierarchy_name: String = "humanoid"
@export var custom_hierarchies: Dictionary = {}
@export var hierarchy_data: Dictionary = {}

func _init():
	for part_name in part_names:
		part_data[part_name] = {"parent": ""}

func add_part_name(name: String) -> bool:
	print("RiggingState: add_part_name called with: ", name)
	var clean_name = name.strip_edges().to_lower().replace(" ", "_")
	print("RiggingState: Cleaned name: ", clean_name)
	
	if clean_name.is_empty():
		push_warning("El nombre de la parte no puede estar vacío.")
		print("RiggingState: Cleaned name is empty, returning false.")
		return false
		
	if clean_name in part_names:
		push_warning("La parte '%s' ya existe." % clean_name)
		print("RiggingState: Part '%s' already exists, returning false." % clean_name)
		return false
	
	part_names.append(clean_name)
	part_data[clean_name] = {"parent": ""}
	print("RiggingState: Part '%s' added successfully, returning true." % clean_name)
	return true

# Establecer la jerarquía actual
func set_current_hierarchy(name: String):
	current_hierarchy_name = name

# Obtener la jerarquía actual
func get_current_hierarchy() -> String:
	return current_hierarchy_name

# Guardar datos de jerarquía personalizada
func save_hierarchy_data(name: String, data: Dictionary):
	custom_hierarchies[name] = data

# Cargar datos de jerarquía personalizada
func load_hierarchy_data(name: String) -> Dictionary:
	if custom_hierarchies.has(name):
		return custom_hierarchies[name]
	return {}

# Obtener todas las jerarquías disponibles
func get_available_hierarchies() -> Array[String]:
	var result: Array[String] = ["humanoid"]  # Siempre incluir la humanoid por defecto
	
	for name in custom_hierarchies.keys():
		if name not in result:
			result.append(name)
	
	return result
