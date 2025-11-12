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

	print("✅ Esqueleto construido con %d huesos" % bones.size())
	return {"skeleton": skeleton, "polygons": active_polygons}

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
func _position_bones_from_seeds(origins: Dictionary, seeds: Dictionary, all_bones: Dictionary) -> void:
	for part_name in origins.keys():
		if not all_bones.has(part_name) or not seeds.has(part_name):
			continue

		var bone = all_bones[part_name]
		var origin_pos = origins[part_name]
		bone.position = origin_pos

		var part_seeds = seeds[part_name]
		if part_seeds.size() >= 2:
			var start_pos = _seed_point_at(seeds, part_name, 0)
			var end_pos = _seed_point_at(seeds, part_name, 1)
			if start_pos is Vector2 and end_pos is Vector2:
				bone.length = start_pos.distance_to(end_pos)
				bone.rotation = (end_pos - start_pos).angle()
		else:
			bone.length = 50.0
			bone.rotation = 0.0

# Construir la jerarquía de forma genérica
func _build_hierarchy_generic(skeleton: Skeleton2D, bones: Dictionary, origins: Dictionary, all_polygons: Array, hierarchy: Dictionary) -> Array:
	var active_polygons = all_polygons

	# Conectar según la jerarquía personalizada
	for bone_name in hierarchy.keys():
		var bone_data = hierarchy[bone_name]
		var parent_name = bone_data.parent

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

# Posicionar los huesos de forma genérica
func _pose_bones_generic(node: Node, seeds: Dictionary, rig_offset: Vector2, hierarchy: Dictionary):
	if node is Bone2D:
		var bone: Bone2D = node

		# Ajustar posición por el offset del rig
		bone.position -= rig_offset

		# Set rest pose
		bone.rest = bone.transform

	for child in node.get_children():
		_pose_bones_generic(child, seeds, rig_offset, hierarchy)

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
