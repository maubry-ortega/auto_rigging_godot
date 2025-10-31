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
		var bone_base_name = bone.name.replace("_bone", "")
		if bone_base_name == part_name:
			return bone
	
	return null

func _setup_polygon_skinning(poly: Polygon2D, skeleton: Skeleton2D, main_bone: Bone2D):
	# En Godot 4, para asignar un polígono completo a un solo hueso,
	# el formato esperado es un array plano: [ruta_al_hueso, array_de_pesos].
	
	# 1. Obtener la ruta relativa desde el polígono hasta el hueso.
	#    Esto es crucial y requiere que ambos nodos estén en el árbol de la escena.
	var bone_path = poly.get_path_to(main_bone)

	# 2. Crear un array de pesos. Cada vértice tendrá un peso de 1.0 para este hueso.
	var vertex_count = poly.polygon.size()
	var weights = PackedFloat32Array()
	weights.resize(vertex_count)
	weights.fill(1.0)

	# 3. Crear la estructura de datos final y asignarla.
	var skinning_data = [bone_path, weights]
	poly.bones = skinning_data

	print("  ✅ '%s' conectado a esqueleto y pesos asignados al hueso '%s'" % [poly.name, main_bone.name])
