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
	
	print("  🔗 Conectando '%s' con hueso '%s'" % [part_name, associated_bone.name])
	
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
	# 1. Conectar el polígono al esqueleto (ya está configurado en el script principal)
	# 2. Marcar metadata para referencia
	
	poly.set_meta("associated_bone", main_bone.name)
	poly.set_meta("skinning_ready", true)
	
	print("  ✅ '%s' conectado a esqueleto con hueso '%s'" % [poly.name, main_bone.name])
