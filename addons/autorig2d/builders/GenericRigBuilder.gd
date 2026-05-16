# GenericRigBuilder.gd
extends IRigBuilder
class_name GenericRigBuilder

# Dependency injection for hierarchy builder
var hierarchy_builder

func _init(hb: SkeletonHierarchyBuilder = null):
	hierarchy_builder = hb

# Helper: acepta seeds en formato legacy [Vector2,...] o en formato enriquecido [{"pos":Vector2, "role":"..."}]
func _seed_point_at(seeds, part_name, idx) -> Variant:
	if not seeds.has(part_name):
		return null
	var arr = seeds[part_name]
	if idx >= arr.size():
		return null
	var item = arr[idx]
	if typeof(item) == TYPE_DICTIONARY and item.has("pos"):
		return item.pos
	if item is Vector2:
		return item
	return null # ensure we only return Vector2 or null

var skeleton: Skeleton2D

# Construir un rig completo usando una jerarquía genérica
func build_complete_rig(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2, all_polygons: Array, part_order: Array, hierarchy_name: String = "humanoid") -> Dictionary:
	print("\n🦴 Iniciando construcción del esqueleto genérico...")

	skeleton = Skeleton2D.new()
	skeleton.name = "AutoRigSkeleton"

	# Obtener la jerarquía especificada
	var hierarchy = {}
	if hierarchy_builder:
		hierarchy = hierarchy_builder.get_hierarchy(hierarchy_name)

	if hierarchy.is_empty():
		print("⚠️ No se encontró la jerarquía '%s', usando la humanoid por defecto" % hierarchy_name)
		hierarchy = _get_default_humanoid_hierarchy()

	# 1. Crear estructura base anatómica
	var bones := _create_bone_nodes_generic(origins, seeds, hierarchy)

	# 2. Construir la jerarquía completa y determinar polígonos activos
	var active_polygons = _build_hierarchy_generic(skeleton, bones, origins, all_polygons, hierarchy)

	# 3. Mantener posiciones absolutas para alinear con atlas
	var rig_offset = Vector2.ZERO

	# 4. Ahora que la jerarquía es estable, posicionar los huesos
	_pose_bones_generic(skeleton, seeds, rig_offset, hierarchy)

	# 5. Desplazar los polígonos activos para que coincidan con los huesos centrados
	for poly in active_polygons:
		poly.position -= rig_offset

	# 6. Establecer la pose de descanso final
	_set_bone_rests_recursive(skeleton)

	# 7. Aplicar IK avanzado (TwoBoneIK para extremidades)
	_apply_advanced_ik(skeleton, hierarchy)

	print("✅ Esqueleto construido con %d huesos" % bones.size())
	return {"skeleton": skeleton, "polygons": active_polygons}

# --- IK Integration ---
const SimpleTwoBoneIK = preload("res://addons/autorig2d/core/ik/SimpleTwoBoneIK.gd")
const AutoIKTarget = preload("res://addons/autorig2d/core/ik/AutoIKTarget.gd")

func _apply_advanced_ik(skeleton: Skeleton2D, hierarchy: Dictionary):
	print("⚙️ Aplicando IK avanzado...")
	
	# Recorrer la jerarquía buscando 'limbs'
	for bone_name in hierarchy.keys():
		var data = hierarchy[bone_name]
		# Soporte tanto para Dictionary (legacy/default) como para BoneHierarchy (objeto)
		var b_type = "standard"
		if typeof(data) == TYPE_DICTIONARY:
			b_type = data.get("bone_type", "standard")
		elif data is Object and "bone_type" in data:
			b_type = data.bone_type
			
		if b_type == "limb":
			_create_limb_ik(skeleton, bone_name, data, hierarchy)

func _create_limb_ik(skeleton: Skeleton2D, bone_name: String, data, hierarchy: Dictionary):
	# Un 'limb' típico comienza en bone_name (ej: left_arm) y tiene un hijo (ej: left_hand)
	# Necesitamos identificar: Hueso 1 (arm), Hueso 2 (hand/forearm)
	var bone1_node = skeleton.find_child(bone_name)
	if not bone1_node: return
	
	# Buscar el segundo hueso (el primer hijo definido en la jerarquía)
	var children_names = []
	if typeof(data) == TYPE_DICTIONARY:
		children_names = data.get("children", [])
	elif data is Object and "children" in data:
		children_names = data.children
		
	if children_names.is_empty(): return
	
	var bone2_name = children_names[0]
	var bone2_node = skeleton.find_child(bone2_name)
	if not bone2_node: return
	
	print("  - Creando IK para extremidad: %s -> %s" % [bone_name, bone2_name])
	
	# Crear el nodo IK
	var ik = SimpleTwoBoneIK.new()
	ik.name = "IK_" + bone_name
	skeleton.add_child(ik)
	ik.owner = skeleton.owner
	
	# Configurar rutas
	ik.bone1_path = ik.get_path_to(bone1_node)
	ik.bone2_path = ik.get_path_to(bone2_node)
	
	# Crear Target
	var target = AutoIKTarget.new()
	target.name = "Target_" + bone_name
	# Posicionar target en la punta del hueso 2 (o donde termina)
	# Asumimos que el hueso 2 apunta hacia su hijo o tiene una longitud
	var tip_pos = bone2_node.global_position + Vector2.from_angle(bone2_node.global_rotation) * bone2_node.get_length()
	
	# Si el hueso 2 tiene hijos, usar la posición del hijo como punta
	if bone2_node.get_child_count() > 0:
		var child = bone2_node.get_child(0)
		if child is Bone2D:
			tip_pos = child.global_position
			
	target.global_position = tip_pos
	skeleton.add_child(target)
	target.owner = skeleton.owner
	
	ik.target_node = target
	
	# Configurar flip si es necesario (heurística simple basada en nombre)
	if "right" in bone_name:
		ik.flip_bend = true # A veces necesario para brazos derechos


# Obtener la jerarquía humanoid por defecto
func _get_default_humanoid_hierarchy() -> Dictionary:
	var HIERARCHY_MAP := {
		"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"],
		"head": [], "left_arm": ["left_hand"], "right_arm": ["right_hand"], "left_leg": ["left_foot"], "right_leg": ["right_foot"]
	}

	var hierarchy = {}

	# Crear la estructura básica
	for part_name in HIERARCHY_MAP.keys():
		hierarchy[part_name] = {
			"name": part_name,
			"parent": "",
			"children": HIERARCHY_MAP[part_name]
		}

	# Establecer las relaciones padre-hijo
	for part_name in HIERARCHY_MAP.keys():
		for child_name in HIERARCHY_MAP[part_name]:
			if hierarchy.has(child_name):
				hierarchy[child_name].parent = part_name

	return hierarchy

# Crear nodos de huesos de forma genérica con estructura anatómica
func _create_bone_nodes_generic(origins: Dictionary, seeds: Dictionary, hierarchy: Dictionary) -> Dictionary:
	var all_bones := {}

	# Crear estructura basada en partes con polígonos
	_create_anatomical_skeleton(origins, seeds, all_bones)

	# Posicionar y orientar huesos usando seeds y origins
	_position_bones_from_seeds(origins, seeds, all_bones)

	return all_bones

# Crear estructura esquelética basada en partes con polígonos
func _create_anatomical_skeleton(origins: Dictionary, seeds: Dictionary, all_bones: Dictionary) -> void:
	for part_name in origins.keys():
		if not seeds.has(part_name):
			continue
		# Crear un solo bone por parte
		var bone := Bone2D.new()
		bone.name = part_name
		all_bones[bone.name] = bone

# Posicionar huesos usando seeds y origins para consistencia
# ESTA FUNCION YA NO SE USA DIRECTAMENTE, LA LOGICA SE MUEVE A _pose_bones_generic
func _position_bones_from_seeds(origins: Dictionary, seeds: Dictionary, all_bones: Dictionary) -> void:
	pass

# Construir la jerarquía de forma genérica
func _build_hierarchy_generic(skeleton: Skeleton2D, bones: Dictionary, origins: Dictionary, all_polygons: Array, hierarchy: Dictionary) -> Array:
	var active_polygons = all_polygons

	# Conectar según la jerarquía personalizada
	for bone_name in hierarchy.keys():
		var bone_data = hierarchy[bone_name]
		var parent_name = ""
		
		if typeof(bone_data) == TYPE_DICTIONARY:
			parent_name = bone_data.get("parent", "")
		elif bone_data is Object and "parent" in bone_data:
			parent_name = bone_data.parent


		if not parent_name.is_empty() and bones.has(bone_name) and bones.has(parent_name):
			var bone = bones[bone_name]
			var parent = bones[parent_name]

			# Solo conectar si no está ya conectado
			if bone.get_parent() == null:
				parent.add_child(bone)

	# Añadir todas las raíces al esqueleto
	for b in bones.values():
		if b is Bone2D and b.get_parent() == null:
			skeleton.add_child(b)

	return active_polygons

# Posicionar los huesos de forma genérica (CORREGIDO: Respetando jerarquía)
func _pose_bones_generic(node: Node, seeds: Dictionary, rig_offset: Vector2, hierarchy: Dictionary, parent_global_transform: Transform2D = Transform2D()):
	if node is Bone2D:
		var bone: Bone2D = node
		var part_name = bone.name
		
		# 1. Determinar la Transform Global deseada para este hueso
		var desired_global_pos = Vector2.ZERO
		var desired_global_rot = 0.0
		var length = 50.0
		
		# Intentar usar semillas
		if seeds.has(part_name):
			var part_seeds = seeds[part_name]
			if part_seeds.size() >= 1:
				var p0 = _seed_point_at(seeds, part_name, 0)
				if p0 is Vector2:
					desired_global_pos = p0
			
			if part_seeds.size() >= 2:
				var p0 = _seed_point_at(seeds, part_name, 0)
				var p1 = _seed_point_at(seeds, part_name, 1)
				if p0 is Vector2 and p1 is Vector2:
					length = p0.distance_to(p1)
					desired_global_rot = (p1 - p0).angle()
		
		# Si no hay semillas, usar posición actual (que venía de origins) o default
		else:
			desired_global_pos = bone.position # Asumimos que esto era global temporalmente
		
		# Aplicar offset del rig
		desired_global_pos -= rig_offset
		
		# 2. Convertir a Local Space del padre
		# Si tiene padre (Bone2D), usamos parent_global_transform
		# Si no tiene padre (es hijo de Skeleton2D), su transform es local al Skeleton, que asumimos en (0,0)
		
		var local_pos = desired_global_pos
		var local_rot = desired_global_rot
		
		if bone.get_parent() is Bone2D:
			# Transformar posición global a local del padre
			local_pos = parent_global_transform.affine_inverse() * desired_global_pos
			local_rot = desired_global_rot - parent_global_transform.get_rotation()
			
		# 3. Aplicar al hueso
		bone.position = local_pos
		bone.rotation = local_rot
		bone.length = length
		
		# 4. Calcular mi nueva global transform para pasar a los hijos
		var my_global_transform = parent_global_transform * bone.transform
		
		# Recursión
		for child in node.get_children():
			_pose_bones_generic(child, seeds, rig_offset, hierarchy, my_global_transform)
			
	else:
		# Si es el Skeleton2D (raíz), su global es Identity (o su transform actual)
		var current_global = Transform2D()
		if node is Node2D:
			current_global = node.global_transform # Debería ser Identity si no está en escena
			
		for child in node.get_children():
			_pose_bones_generic(child, seeds, rig_offset, hierarchy, current_global)

func _get_seed_pos(seed) -> Vector2:
	if typeof(seed) == TYPE_DICTIONARY and seed.has("pos"):
		return seed.pos
	return seed

func _snap_angle_if_near(angle: float) -> float:
	# snapping configurable: if angle cerca 0°, ±90°, ±180° dentro de 15°
	var deg = rad_to_deg(angle)
	var thresholds = [0.0, 90.0, 180.0, -90.0, -180.0]
	for t in thresholds:
		if abs(deg - t) <= 15:
			return deg_to_rad(t)
	return angle

func _set_bone_rests_recursive(node: Node):
	if node is Bone2D:
		node.rest = node.transform
	for child in node.get_children():
		_set_bone_rests_recursive(child)
