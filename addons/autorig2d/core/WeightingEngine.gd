# WeightingEngine.gd
extends RefCounted

# ==============================================================================
## Sistema de Asignación de Pesos - Corregido: usa clear_bones() + add_bone()
# ==============================================================================

func assign_weights_to_polygons(polygons: Array, skeleton: Skeleton2D):
	print("\n⚖️ Asignando pesos a polígonos...")
	var bones = _get_all_bones(skeleton)
	var bone_names_list := []
	for b in bones:
		bone_names_list.append(b.name)
	print("  🔍 Huesos disponibles: %s" % [bone_names_list])

	for poly in polygons:
		_assign_weights_to_polygon(poly, bones, skeleton)

	print("✅ Pesos asignados a %d polígonos" % polygons.size())

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
	var associated_bones = _find_associated_bones(part_name, bones)
	if associated_bones.is_empty():
		print("  ⚠️ No se encontraron huesos asociados para: ", part_name)
		return

	# Asegurarse que el polygon tiene asignado el skeleton antes de añadir bones
	if not poly.skeleton or str(poly.skeleton).strip_edges() == "":
		print("  ⚠️ Polygon '%s' no tiene property 'skeleton' asignada. Saltando." % poly.name)
		return

	_setup_polygon_skinning(poly, skeleton, associated_bones)


func _find_associated_bones(part_name: String, bones: Array) -> Array:
	var found_bones := []
	
	if part_name.ends_with("_overlap"):
		var overlap_base_name = part_name.rsplit("_overlap", true, 1)[0]
		
		var unique_parts := {}
		for bone in bones:
			var bone_part_name := ""
			if bone.name.find("_bone_") != -1:
				bone_part_name = bone.name.rsplit("_bone_", true, 1)[0]
			elif bone.name.find("_spine_") != -1:
				bone_part_name = bone.name.rsplit("_spine_", true, 1)[0]
			elif not bone.name.is_empty():
				bone_part_name = bone.name
			
			if not bone_part_name.is_empty() and not unique_parts.has(bone_part_name):
				unique_parts[bone_part_name] = true

		for part in unique_parts.keys():
			if overlap_base_name.find(part) != -1:
				var main_bone_for_part = _find_associated_bone(part, bones)
				if main_bone_for_part and not found_bones.has(main_bone_for_part):
					found_bones.append(main_bone_for_part)
		
		if not found_bones.is_empty():
			print("  - Overlap '%s' asociado con: %s" % [part_name, found_bones.map(func(b): return b.name)])
			return found_bones

	var single_bone = _find_associated_bone(part_name, bones)
	if single_bone:
		found_bones.append(single_bone)
	return found_bones


func _find_associated_bone(part_name: String, bones: Array) -> Bone2D:
	# Prefer exact-match part_name + "_bone_0" etc / fallback por substring
	for bone in bones:
		# intentar coincidencia exacta para root bone del part
		if bone.name == part_name or bone.name.find(part_name + "_bone") == 0:
			return bone
	# fallback: buscar cualquier bone que contenga el part_name
	for bone in bones:
		if bone.name.find(part_name) != -1:
			return bone
	return null

func _setup_polygon_skinning(poly: Polygon2D, skeleton: Skeleton2D, main_bones: Array):
	# Build bone chain: opcionalmente añadir padre, luego main bone y descendientes
	var bone_chain := []
	var added_bones := {}

	for main_bone in main_bones:
		# incluir padre inmediato para transiciones suaves
		var parent_bone = main_bone.get_parent()
		if parent_bone and parent_bone is Bone2D and not added_bones.has(parent_bone):
			bone_chain.append(parent_bone)
			added_bones[parent_bone] = true
		
		# incluir main_bone y todos sus hijos directos
		if not added_bones.has(main_bone):
			bone_chain.append(main_bone)
			added_bones[main_bone] = true

		for child in main_bone.get_children():
			if child is Bone2D and not added_bones.has(child):
				bone_chain.append(child)
				added_bones[child] = true


	# Preparar arrays
	var num_vertices = poly.polygon.size()
	if num_vertices == 0:
		print("  ⚠️ Polygon '%s' no tiene vértices." % poly.name)
		return

	var bone_paths := []
	var weight_arrays := []
	for b in bone_chain:
		# NodePath desde el poly hacia el bone
		var bp = poly.get_path_to(b)
		bone_paths.append(bp)
		var arr := PackedFloat32Array()
		arr.resize(num_vertices)
		weight_arrays.append(arr)

	# Calcular pesos por hueso usando caída Gaussiana sobre la distancia al segmento
	var world_to_poly_local = poly.get_global_transform().affine_inverse()
	for bi in range(bone_chain.size()):
		var bone = bone_chain[bi]
		var bone_start_world = bone.to_global(Vector2.ZERO)
		var bone_end_world: Vector2
		if bone.length < 0.001:
			# fallback: pequeño segmento orientativo para bones sin longitud
			var bbox = _compute_polygon_bbox(poly.polygon)
			var diag = bbox.size.length()
			var fallback_len = max(12.0, diag * 0.08)
			bone_end_world = bone.to_global(Vector2(fallback_len, 0))
		else:
			bone_end_world = bone.to_global(Vector2(bone.length, 0))

		var bone_start_local = world_to_poly_local * bone_start_world
		var bone_end_local = world_to_poly_local * bone_end_world

		var bone_len_local = max(1.0, (bone_end_local - bone_start_local).length())
		var sigma = max(8.0, bone_len_local * 0.5)
		var denom = 2.0 * sigma * sigma

		for vi in range(num_vertices):
			var vertex = poly.polygon[vi]
			var closest = Geometry2D.get_closest_point_to_segment(vertex, bone_start_local, bone_end_local)
			var dist = vertex.distance_to(closest)
			var w = exp(-(dist * dist) / denom)
			weight_arrays[bi][vi] = w

	# Para cada vértice, seleccionar top N influences y normalizar
	var max_influences = 3
	var final_weights_per_bone := []
	for bi in range(bone_chain.size()):
		var arr := PackedFloat32Array()
		arr.resize(num_vertices)
		final_weights_per_bone.append(arr)

	for vi in range(num_vertices):
		# recolectar pares (idx, weight)
		var influences := []
		for bi in range(bone_chain.size()):
			influences.append({"i": bi, "w": weight_arrays[bi][vi]})
		# ordenar descendente por peso
		influences.sort_custom(func(a, b):
			if a.w < b.w:
				return 1
			elif a.w > b.w:
				return -1
			return 0
		)
		# sumar top-N
		var total = 0.0
		for k in range(min(max_influences, influences.size())):
			total += influences[k].w
		if total <= 0.0:
			# fallback: asignar al primer hueso principal
			var main_index = -1
			if not main_bones.is_empty():
				main_index = bone_chain.find(main_bones[0])
			if main_index == -1:
				main_index = 0 # fallback al primer hueso en la cadena si todo falla
			
			if final_weights_per_bone.size() > main_index and final_weights_per_bone[main_index].size() > vi:
				final_weights_per_bone[main_index][vi] = 1.0
			continue
		for k in range(min(max_influences, influences.size())):
			var idx = influences[k].i
			final_weights_per_bone[idx][vi] = influences[k].w / total

	# Ahora asignar al Polygon2D usando la API: clear_bones() + add_bone(path, weights)
	# Esto es más robusto que asignar poly.bones directamente.
	poly.clear_bones()
	for bi in range(bone_chain.size()):
		# comprobar si el arreglo de pesos para este bone contiene algo útil (sum > 0)
		var sum_w = 0.0
		for vi in range(num_vertices):
			sum_w += final_weights_per_bone[bi][vi]
		if sum_w <= 0.0:
			# omitimos bones que no influyen en ningún vértice
			continue
		# preparar PackedFloat32Array de pesos
		var weights = final_weights_per_bone[bi]
		# add_bone acepta (NodePath, PackedFloat32Array)
		poly.add_bone(bone_paths[bi], weights)

	# Log
	var used_bone_names := []
	for b in bone_chain:
		used_bone_names.append(b.name)
	print("  ✅ '%s' conectado a esqueleto y pesos distribuidos entre: %s" % [poly.name, used_bone_names])


# Helper: compute polygon bbox (returns Rect2)
func _compute_polygon_bbox(points: PackedVector2Array) -> Rect2:
	if points.size() == 0:
		return Rect2(0, 0, 0, 0)
	var r = Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	return r
