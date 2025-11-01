extends RefCounted

# ==============================================================================
## Sistema de Asignación de Pesos - Versión Corregida
# ==============================================================================

func assign_weights_to_polygons(polygons: Array, skeleton: Skeleton2D):
	print("\n⚖️ Asignando pesos a polígonos...")
	
	var bones = _get_all_bones(skeleton)
	print("  🔍 Huesos disponibles: %s" % [bones.map(func(bone): return bone.name)])
	
	for poly in polygons:
		_assign_weights_to_polygon(poly, bones, skeleton)
	
	print("✅ Pesas asignados a %d polígonos" % polygons.size())

func _get_all_bones(skeleton: Skeleton2D) -> Array:
	var bones = []
	_collect_bones_recursive(skeleton, bones)
	return bones

func _collect_bones_recursive(node: Node, bones: Array):
	if node is Bone2D:
		bones.append(node)
	
	for child in node.get_children():
		_collect_bones_recursive(child, bones)

func _assign_weights_to_polygon(poly: Polygon2D, bones: Array, skeleton: Skeleton2D):
	var part_name = poly.name
	var associated_bone = _find_associated_bone(part_name, bones)
	
	if not associated_bone:
		print("  ⚠️ No se encontró hueso asociado para: ", part_name)
		print("    Buscando: '%s' en huesos: %s" % [part_name, bones.map(func(b): return b.name)])
		return
	
	# CONFIGURACIÓN DE SKINNING EN GODOT 4.X
	_setup_polygon_skinning(poly, skeleton, associated_bone)

func _find_associated_bone(part_name: String, bones: Array) -> Bone2D:
	# Buscar hueso que coincida exactamente con el nombre de la parte
	var target_bone_name = part_name + "_bone"
	
	for bone in bones:
		if bone.name == target_bone_name:
			return bone
	
	# Fallback: buscar por similitud (sin el _bone)
	for bone in bones:
		var bone_base_name = bone.name.rsplit("_bone_", true, 1)[0]
		if bone_base_name == part_name:
			return bone
	
	return null

func _setup_polygon_skinning(poly: Polygon2D, skeleton: Skeleton2D, main_bone: Bone2D):
	# 1. Find all bones in the chain starting from main_bone
	var bone_chain = [main_bone]
	var current_bone = main_bone
	while current_bone.get_child_count() > 0:
		# Assuming one child per bone in the chain
		current_bone = current_bone.get_child(0)
		if current_bone is Bone2D:
			bone_chain.append(current_bone)
		else:
			break # Should not happen in a clean chain

	# 2. For each vertex in the polygon, calculate weights for the bones in the chain
	var num_vertices = poly.polygon.size()
	var final_bone_paths = []
	var final_weights_arrays = []
	var world_to_poly_local = poly.get_global_transform().affine_inverse()

	for bone in bone_chain:
		final_bone_paths.append(poly.get_path_to(bone))
		var weights_for_bone = PackedFloat32Array()
		weights_for_bone.resize(num_vertices)
		
		# Get bone segment in polygon's local coordinates
		var bone_start_world = bone.get_global_position()
		var bone_end_world = bone.get_global_transform() * Vector2(bone.length, 0)
		var bone_start_local = world_to_poly_local * bone_start_world
		var bone_end_local = world_to_poly_local * bone_end_world

		for i in range(num_vertices):
			var vertex_pos = poly.polygon[i]
			
			# Find closest point on the bone segment to the vertex
			var closest_point = Geometry2D.get_closest_point_to_segment(vertex_pos, bone_start_local, bone_end_local)
			var distance = vertex_pos.distance_to(closest_point)
			
			# Simple inverse distance weighting (add a small epsilon to avoid division by zero)
			var weight = 1.0 / (distance * distance + 0.001)
			weights_for_bone[i] = weight
		
		final_weights_arrays.append(weights_for_bone)

	# 3. Normalize the weights for each vertex
	var normalized_weights_arrays = []
	for i in range(bone_chain.size()):
		var new_weights = PackedFloat32Array()
		new_weights.resize(num_vertices)
		normalized_weights_arrays.append(new_weights)

	for i in range(num_vertices):
		var total_weight = 0.0
		for j in range(bone_chain.size()):
			total_weight += final_weights_arrays[j][i]
		
		if total_weight > 0:
			for j in range(bone_chain.size()):
				normalized_weights_arrays[j][i] = final_weights_arrays[j][i] / total_weight
		else:
			# If total is zero (e.g., vertex is at 0 distance from all bones?), assign to first bone
			normalized_weights_arrays[0][i] = 1.0

	# 4. Create the final skinning data structure
	var skinning_data = []
	for i in range(bone_chain.size()):
		skinning_data.append([final_bone_paths[i], normalized_weights_arrays[i]])
		
	poly.bones = skinning_data
	
	var bone_names = bone_chain.map(func(b): return b.name)
	print("  ✅ '%s' conectado a esqueleto y pesos distribuidos entre: %s" % [poly.name, bone_names])
