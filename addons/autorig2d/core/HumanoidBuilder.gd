extends RefCounted

# ==============================================================================
## Sistema de Construcción de Esqueleto - Versión Mejorada
# ==============================================================================

# Mapa de jerarquía (puedes expandirlo con más partes)
const HIERARCHY_MAP := {
	"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"],
	"head": [],
	"left_arm": [],
	"right_arm": [],
	"left_leg": [],
	"right_leg": []
}

func build_complete_rig(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2) -> Skeleton2D:
	print("\n🦴 Iniciando construcción del esqueleto...")
	
	var skeleton := Skeleton2D.new()
	skeleton.name = "AutoRigSkeleton"

	# Crear huesos desde los orígenes y las semillas
	var bones := _create_bones(origins, seeds, atlas_size)

	# Construir la jerarquía lógica
	_build_skeleton_hierarchy(skeleton, bones)

	print("✅ Esqueleto construido con %d huesos" % bones.size())
	return skeleton


func _create_bones(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2) -> Dictionary:
	var bones := {}
	for part_name in origins.keys():
		var bone := Bone2D.new()
		bone.name = "%s_bone" % part_name
		
		# La posición del hueso es el origen del polígono para mantener la alineación
		bone.position = origins[part_name]
		
		# Usar las semillas para definir la rotación y la longitud
		if seeds.has(part_name):
			var points = seeds[part_name]
			if points.size() >= 2:
				var start_point = points[0]
				var end_point = points[1]
				var diff = end_point - start_point
				bone.rotation = diff.angle()
				bone.length = diff.length()

		bone.rest = Transform2D(bone.rotation, Vector2.ZERO)
		
		bones[part_name] = bone
		print("  🦴 Hueso creado: %s en %s" % [bone.name, bone.position])
	return bones


func _build_skeleton_hierarchy(skeleton: Skeleton2D, bones: Dictionary):
	if not bones.has("torso"):
		push_warning("No hay torso definido; la jerarquía puede ser plana.")
	
	# Añadir primero todos los huesos como hijos del Skeleton2D
	for part_name in bones.keys():
		skeleton.add_child(bones[part_name])

	# Reparentar según el mapa jerárquico
	for parent_name in HIERARCHY_MAP.keys():
		if not bones.has(parent_name):
			continue
		var parent_bone = bones[parent_name]
		for child_name in HIERARCHY_MAP[parent_name]:
			if bones.has(child_name):
				var child_bone = bones[child_name]
				skeleton.remove_child(child_bone)
				parent_bone.add_child(child_bone)
				print("  🔗 %s_bone → %s_bone" % [child_name, parent_name])
