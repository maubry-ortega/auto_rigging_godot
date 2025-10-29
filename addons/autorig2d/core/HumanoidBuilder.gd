extends RefCounted

# ==============================================================================
## Sistema de Construcción de Esqueleto - Versión Corregida
# ==============================================================================

func build_complete_rig(seeds: Dictionary, atlas_size: Vector2) -> Skeleton2D:
	print("\n🦴 Iniciando construcción del esqueleto...")
	
	# Crear el esqueleto principal
	var skeleton = Skeleton2D.new()
	skeleton.name = "AutoRigSkeleton"
	
	# Crear huesos basados en las semillas
	var bones = _create_bones_from_seeds(seeds, atlas_size)
	
	# Construir jerarquía del esqueleto
	_build_skeleton_hierarchy(skeleton, bones)
	
	print("✅ Esqueleto construido con %d huesos" % bones.size())
	return skeleton

func _create_bones_from_seeds(seeds: Dictionary, atlas_size: Vector2) -> Dictionary:
	var bones = {}
	
	for part_name in seeds.keys():
		var bone = Bone2D.new()
		bone.name = part_name + "_bone"
		
		# Usar la posición exacta de la semilla
		bone.position = Vector2(seeds[part_name])
		
		# Configurar propiedades del hueso
		bone.rest = Transform2D.IDENTITY
		
		bones[part_name] = bone
		print("  🦴 Hueso creado para '%s' en posición: %s" % [part_name, bone.position])
	
	return bones

func _build_skeleton_hierarchy(skeleton: Skeleton2D, bones: Dictionary):
	# DEFINIR JERARQUÍA HUMANOIDE CORRECTA
	var hierarchy = {
		"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"]
	}
	
	# Añadir TODOS los huesos directamente al skeleton primero
	for part_name in bones.keys():
		skeleton.add_child(bones[part_name])
		# El owner se asignará después cuando se añada a la escena
	
	# Luego construir jerarquía: conectar hijos al torso
	if bones.has("torso"):
		var torso_bone = bones["torso"]
		
		for child_name in hierarchy["torso"]:
			if bones.has(child_name):
				var child_bone = bones[child_name]
				# Re-parentear al torso
				skeleton.remove_child(child_bone)
				torso_bone.add_child(child_bone)
				print("  📍 %s → %s" % [child_name, "torso"])
