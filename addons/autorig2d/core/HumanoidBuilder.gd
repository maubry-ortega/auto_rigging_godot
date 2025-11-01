extends RefCounted

const HIERARCHY_MAP := {
	"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"],
	"head": [], "left_arm": [], "right_arm": [], "left_leg": [], "right_leg": []
}

func build_complete_rig(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2, all_polygons: Array) -> Dictionary:
	print("\n🦴 Iniciando construcción del esqueleto...")
	
	var skeleton := Skeleton2D.new()
	skeleton.name = "AutoRigSkeleton"

	var bones := _create_bones(origins, seeds, atlas_size)
	
	var active_polygons = _build_skeleton_hierarchy(skeleton, bones, origins, all_polygons, origins.keys())

	_set_bone_rests_recursive(skeleton)

	print("✅ Esqueleto construido con %d huesos" % bones.size())
	return {"skeleton": skeleton, "polygons": active_polygons}


func _create_bones(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2) -> Dictionary:
	var all_bones := {}
	for part_name in origins.keys():
		if seeds.has(part_name):
			var part_raw_points = seeds[part_name]
			var part_bones := []
			var previous_bone: Bone2D = null

			for i in range(0, part_raw_points.size(), 2):
				if i + 1 < part_raw_points.size():
					var start_point = part_raw_points[i]
					var end_point = part_raw_points[i+1]

					var bone := Bone2D.new()
					bone.name = "%s_bone_%d" % [part_name, i / 2]
					bone.position = start_point
					var diff = end_point - start_point
					bone.rotation = diff.angle()
					bone.length = diff.length()

					if previous_bone:
						previous_bone.add_child(bone)
						print("  🔗 %s → %s (cadena interna)" % [bone.name, previous_bone.name])
					
					part_bones.append(bone)
					all_bones[bone.name] = bone
					previous_bone = bone
					print("  🦴 Hueso creado: %s en %s" % [bone.name, bone.position])
			
				if not part_bones.is_empty():
					all_bones[part_name] = part_bones[0]
				else:
					var bone := Bone2D.new()
					bone.name = "%s_bone_0" % part_name
					bone.position = origins[part_name]
					bone.length = 10
					all_bones[bone.name] = bone
					all_bones[part_name] = bone
					print("  🦴 Hueso creado: %s en %s (fallback)" % [bone.name, bone.position])
	return all_bones


func _build_skeleton_hierarchy(skeleton: Skeleton2D, bones: Dictionary, origins: Dictionary, all_polygons: Array, part_order: Array) -> Array:
	var active_polygons := []
	var mesh_groups := {} # Maps polygon_node -> list of part_names
	var polygon_map := {} # Maps part_name -> polygon_node

	# First, add all root bones to the skeleton so they are in the tree for parenting
	for part_name in part_order:
		if bones.has(part_name):
			var root_bone_of_part = bones[part_name]
			if root_bone_of_part.get_parent() == null:
				skeleton.add_child(root_bone_of_part)

	# Determine mesh groups based on polygon containment, respecting order
	for part_name in part_order:
		if not origins.has(part_name): continue

		var origin_point = origins[part_name]
		var found_parent_mesh = false

		# Check if it belongs to an already established mesh group
		for poly_node in active_polygons:
			if Geometry2D.is_point_in_polygon(origin_point - poly_node.position, poly_node.polygon):
				mesh_groups[poly_node].append(part_name)
				polygon_map[part_name] = poly_node
				found_parent_mesh = true
				break
		
		if not found_parent_mesh:
			# This part establishes a new mesh group
			var part_poly = null
			for poly in all_polygons:
				if poly.name == part_name:
					part_poly = poly
					break
			
			if part_poly:
				active_polygons.append(part_poly)
				mesh_groups[part_poly] = [part_name]
				polygon_map[part_name] = part_poly

	# Chain bones within each mesh group
	for poly_node in mesh_groups.keys():
		var parts_in_group = mesh_groups[poly_node]
		if parts_in_group.size() > 1:
			for i in range(parts_in_group.size() - 1):
				var parent_part = parts_in_group[i]
				var child_part = parts_in_group[i+1]

				if bones.has(parent_part) and bones.has(child_part):
					var parent_bone_root = bones[parent_part]
					var child_bone_root = bones[child_part]
					
					var last_bone_in_chain = parent_bone_root
					while last_bone_in_chain.get_child_count() > 0:
						last_bone_in_chain = last_bone_in_chain.get_child(0)

					if child_bone_root.get_parent() == skeleton:
						skeleton.remove_child(child_bone_root)
						last_bone_in_chain.add_child(child_bone_root)
						print("  🔗 %s → %s (misma malla)" % [child_bone_root.name, last_bone_in_chain.name])

	# Reparent based on HIERARCHY_MAP for inter-mesh connections
	for parent_name in HIERARCHY_MAP.keys():
		if not bones.has(parent_name): continue
		var parent_bone = bones[parent_name]
		for child_name in HIERARCHY_MAP[parent_name]:
			if bones.has(child_name):
				var child_bone = bones[child_name]
				if child_bone.get_parent() == skeleton:
					skeleton.remove_child(child_bone)
					parent_bone.add_child(child_bone)
					print("  🔗 %s → %s (jerarquía)" % [child_name, parent_name])
	
	return active_polygons

func _set_bone_rests_recursive(node: Node):
	if node is Bone2D:
		node.rest = node.transform
	for child in node.get_children():
		_set_bone_rests_recursive(child)
