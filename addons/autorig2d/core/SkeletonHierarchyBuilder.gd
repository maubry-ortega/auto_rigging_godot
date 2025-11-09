# SkeletonHierarchyBuilder.gd
extends RefCounted
class_name SkeletonHierarchyBuilder

# Estructura de datos para representar una jerarquía de huesos
class BoneHierarchy:
	var name: String
	var parent: String = ""
	var children: Array[String]
	var bone_type: String = "standard"  # standard, spine, limb, etc.
	var auto_generate: bool = true  # Si se genera automáticamente o es definido por el usuario
	var length: float = 50.0  # Longitud predeterminada
	var angle: float = 0.0  # Ángulo predeterminado
	
	func _init(n: String, p: String = ""):
		name = n
		parent = p
		children = []

# Almacenamiento de jerarquías predefinidas y personalizadas
var predefined_hierarchies: Dictionary = {}
var custom_hierarchies: Dictionary = {}
var current_hierarchy_name: String = ""

func _init():
	# Cargar jerarquías predefinidas
	_load_predefined_hierarchies()

# Cargar jerarquías predefinidas (humanoide, cuadrúpedo, etc.)
func _load_predefined_hierarchies():
	# Jerarquía humanoide (la que ya tienes)
	var humanoid = _create_humanoid_hierarchy()
	predefined_hierarchies["humanoid"] = humanoid
	
	# Podríamos añadir más jerarquías predefinidas
	# predefined_hierarchies["quadruped"] = _create_quadruped_hierarchy()
	# predefined_hierarchies["bird"] = _create_bird_hierarchy()

# Crear la jerarquía humanoide existente
func _create_humanoid_hierarchy() -> Dictionary:
	var hierarchy = {}
	
	# Torso
	hierarchy["torso"] = BoneHierarchy.new("torso")
	
	# Cabeza
	hierarchy["head"] = BoneHierarchy.new("head", "torso")
	hierarchy["torso"].children.append("head")
	
	# Brazo izquierdo
	hierarchy["left_arm"] = BoneHierarchy.new("left_arm", "torso")
	hierarchy["torso"].children.append("left_arm")
	
	hierarchy["left_hand"] = BoneHierarchy.new("left_hand", "left_arm")
	hierarchy["left_arm"].children.append("left_hand")
	
	# Brazo derecho
	hierarchy["right_arm"] = BoneHierarchy.new("right_arm", "torso")
	hierarchy["torso"].children.append("right_arm")
	
	hierarchy["right_hand"] = BoneHierarchy.new("right_hand", "right_arm")
	hierarchy["right_arm"].children.append("right_hand")
	
	# Pierna izquierda
	hierarchy["left_leg"] = BoneHierarchy.new("left_leg", "torso")
	hierarchy["torso"].children.append("left_leg")
	
	hierarchy["left_foot"] = BoneHierarchy.new("left_foot", "left_leg")
	hierarchy["left_leg"].children.append("left_foot")
	
	# Pierna derecha
	hierarchy["right_leg"] = BoneHierarchy.new("right_leg", "torso")
	hierarchy["torso"].children.append("right_leg")
	
	hierarchy["right_foot"] = BoneHierarchy.new("right_foot", "right_leg")
	hierarchy["right_leg"].children.append("right_foot")
	
	return hierarchy

# Obtener una jerarquía específica
func get_hierarchy(name: String) -> Dictionary:
	if custom_hierarchies.has(name):
		return custom_hierarchies[name]
	elif predefined_hierarchies.has(name):
		return predefined_hierarchies[name]
	else:
		return {}

# Crear una nueva jerarquía personalizada
func create_custom_hierarchy(name: String) -> bool:
	if name.is_empty():
		push_error("El nombre de la jerarquía no puede estar vacío")
		return false
		
	if custom_hierarchies.has(name):
		push_error("Ya existe una jerarquía con ese nombre")
		return false
	
	custom_hierarchies[name] = {}
	current_hierarchy_name = name
	return true

# Añadir un hueso a la jerarquía actual
func add_bone_to_current_hierarchy(bone_name: String, parent_name: String = "") -> bool:
	if current_hierarchy_name.is_empty():
		push_error("No hay una jerarquía seleccionada")
		return false
		
	if bone_name.is_empty():
		push_error("El nombre del hueso no puede estar vacío")
		return false
	
	var hierarchy = custom_hierarchies[current_hierarchy_name]
	
	if hierarchy.has(bone_name):
		push_error("Ya existe un hueso con ese nombre")
		return false
	
	var bone = BoneHierarchy.new(bone_name, parent_name)
	hierarchy[bone_name] = bone
	
	# Actualizar la lista de hijos del padre si existe
	if not parent_name.is_empty() and hierarchy.has(parent_name):
		if parent_name not in hierarchy[parent_name].children:
			hierarchy[parent_name].children.append(bone_name)
	
	return true

# Eliminar un hueso de la jerarquía actual
func remove_bone_from_current_hierarchy(bone_name: String) -> bool:
	if current_hierarchy_name.is_empty():
		push_error("No hay una jerarquía seleccionada")
		return false
	
	var hierarchy = custom_hierarchies[current_hierarchy_name]
	
	if not hierarchy.has(bone_name):
		push_error("No existe un hueso con ese nombre")
		return false
	
	# Eliminar el hueso de la lista de hijos de su padre
	var parent_name = hierarchy[bone_name].parent
	if not parent_name.is_empty() and hierarchy.has(parent_name):
		hierarchy[parent_name].children.erase(bone_name)
	
	# Eliminar el hueso y todos sus descendientes
	_remove_bone_and_children(hierarchy, bone_name)
	
	return true

# Eliminar un hueso y todos sus descendientes
func _remove_bone_and_children(hierarchy: Dictionary, bone_name: String):
	if not hierarchy.has(bone_name):
		return
	
	# Primero eliminar todos los hijos
	var children = hierarchy[bone_name].children.duplicate()
	for child_name in children:
		_remove_bone_and_children(hierarchy, child_name)
	
	# Luego eliminar el hueso
	hierarchy.erase(bone_name)

# Modificar el padre de un hueso
func change_bone_parent(bone_name: String, new_parent_name: String) -> bool:
	if current_hierarchy_name.is_empty():
		push_error("No hay una jerarquía seleccionada")
		return false
	
	var hierarchy = custom_hierarchies[current_hierarchy_name]
	
	if not hierarchy.has(bone_name):
		push_error("No existe un hueso con ese nombre")
		return false
	
	# Verificar que el nuevo padre no sea un descendiente del hueso
	if _is_descendant(hierarchy, new_parent_name, bone_name):
		push_error("El nuevo padre no puede ser un descendiente del hueso")
		return false
	
	# Eliminar el hueso de la lista de hijos de su padre actual
	var old_parent_name = hierarchy[bone_name].parent
	if not old_parent_name.is_empty() and hierarchy.has(old_parent_name):
		hierarchy[old_parent_name].children.erase(bone_name)
	
	# Actualizar el padre
	hierarchy[bone_name].parent = new_parent_name
	
	# Añadir el hueso a la lista de hijos del nuevo padre
	if not new_parent_name.is_empty() and hierarchy.has(new_parent_name):
		if bone_name not in hierarchy[new_parent_name].children:
			hierarchy[new_parent_name].children.append(bone_name)
	
	return true

# Verificar si un hueso es descendiente de otro
func _is_descendant(hierarchy: Dictionary, potential_descendant: String, ancestor: String) -> bool:
	if potential_descendant.is_empty() or ancestor.is_empty():
		return false
	
	if not hierarchy.has(potential_descendant):
		return false
	
	var current = potential_descendant
	while not current.is_empty():
		if current == ancestor:
			return true
		
		if not hierarchy.has(current):
			break
			
		current = hierarchy[current].parent
	
	return false

# Obtener la lista de jerarquías disponibles
func get_available_hierarchies() -> Array[String]:
	var result: Array[String] = []
	
	for name in predefined_hierarchies.keys():
		result.append(name)
	
	for name in custom_hierarchies.keys():
		result.append(name)
	
	return result

# Guardar la jerarquía actual en un archivo
func save_current_hierarchy_to_file(file_path: String) -> bool:
	if current_hierarchy_name.is_empty():
		push_error("No hay una jerarquía seleccionada")
		return false
	
	if not custom_hierarchies.has(current_hierarchy_name):
		push_error("No existe la jerarquía actual")
		return false
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("No se pudo abrir el archivo para escritura")
		return false
	
	var hierarchy = custom_hierarchies[current_hierarchy_name]
	
	# Convertir la jerarquía a un formato que se pueda guardar
	var data = {
		"name": current_hierarchy_name,
		"bones": {}
	}
	
	for bone_name in hierarchy.keys():
		var bone = hierarchy[bone_name]
		data["bones"][bone_name] = {
			"parent": bone.parent,
			"children": bone.children,
			"bone_type": bone.bone_type,
			"auto_generate": bone.auto_generate,
			"length": bone.length,
			"angle": bone.angle
		}
	
	file.store_string(JSON.stringify(data))
	file.close()
	
	return true

# Cargar una jerarquía desde un archivo
func load_hierarchy_from_file(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("No se pudo abrir el archivo para lectura")
		return false
	
	var json_String = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_String)
	if data == null:
		push_error("Error al parsear el archivo JSON")
		return false
	
	if not data.has("name") or not data.has("bones"):
		push_error("Formato de archivo inválido")
		return false
	
	var hierarchy_name = data.name
	if hierarchy_name.is_empty():
		push_error("El nombre de la jerarquía no puede estar vacío")
		return false
	
	# Crear la nueva jerarquía
	create_custom_hierarchy(hierarchy_name)
	
	# Cargar los huesos
	var bones_data = data.bones
	for bone_name in bones_data.keys():
		var bone_data = bones_data[bone_name]
		
		var bone = BoneHierarchy.new(bone_name, bone_data.get("parent", ""))
		var loaded_children = bone_data.get("children", [])
		bone.children.clear() # Clear existing array
		for child_name in loaded_children:
			bone.children.append(child_name)
		bone.bone_type = bone_data.get("bone_type", "standard")
		bone.auto_generate = bone_data.get("auto_generate", true)
		bone.length = bone_data.get("length", 50.0)
		bone.angle = bone_data.get("angle", 0.0)
		
		custom_hierarchies[hierarchy_name][bone_name] = bone
	
	return true

# Validar una jerarquía (verificar que no haya ciclos, etc.)
func validate_hierarchy(hierarchy_name: String) -> bool:
	var hierarchy = get_hierarchy(hierarchy_name)
	
	if hierarchy.is_empty():
		push_error("No existe la jerarquía especificada")
		return false
	
	# Verificar que no haya ciclos
	for bone_name in hierarchy.keys():
		if _is_descendant(hierarchy, bone_name, bone_name):
			push_error("Se detectó un ciclo en la jerarquía")
			return false
	
	return true

# Obtener la jerarquía actual
func get_current_hierarchy() -> Dictionary:
	if current_hierarchy_name.is_empty():
		return {}
	
	return get_hierarchy(current_hierarchy_name)
