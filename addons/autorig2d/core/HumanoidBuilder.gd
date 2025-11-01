extends RefCounted

const HIERARCHY_MAP := {
	"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"],
	"head": [], "left_arm": [], "right_arm": [], "left_leg": [], "right_leg": []
}

func build_complete_rig(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2, all_polygons: Array, part_order: Array) -> Dictionary:
	print("\n\ud83e\udd84 Iniciando construcción del esqueleto...")
	
	var skeleton := Skeleton2D.new()
	skeleton.name = "AutoRigSkeleton"

	# 1. Create bone nodes, without transforms yet
	var bones := _create_bone_nodes(part_order, seeds)
	
	# 2. Build the full hierarchy
	var active_polygons = _build_hierarchy(skeleton, bones, origins, all_polygons, part_order)

	# 3. Now that hierarchy is stable, pose the bones
	_pose_bones(skeleton, seeds)

	# 4. Center the rig based on the torso position
	var rig_offset = Vector2.ZERO
	if origins.has("torso"):
		rig_offset = origins["torso"]
	elif not origins.is_empty():
		var first_part_origin = origins[origins.keys()[0]]
		rig_offset = first_part_origin

	skeleton.position = -rig_offset
	for poly in active_polygons:
		poly.position -= rig_offset

	# 5. Set the final rest pose
	_set_bone_rests_recursive(skeleton)

	print("✅ Esqueleto construido con %d huesos" % len(bones))
	return {"skeleton": skeleton, "polygons": active_polygons}

func _create_bone_nodes(part_order: Array, seeds: Dictionary) -> Dictionary:
	var all_bones := {}
	for part_name in part_order:
		if seeds.has(part_name):
			var part_raw_points = seeds[part_name]
			for i in range(0, part_raw_points.size(), 2):
				if i + 1 < part_raw_points.size():
					var bone := Bone2D.new()
					var bone_index = i / 2
					bone.name = "%s_bone_%d" % [part_name, bone_index]
					all_bones[bone.name] = bone
					if bone_index == 0:
						all_bones[part_name] = bone # Map part name to its root bone
	return all_bones

func _build_hierarchy(skeleton: Skeleton2D, bones: Dictionary, origins: Dictionary, all_polygons: Array, part_order: Array) -> Array:
	var active_polygons := []
	var mesh_groups := {} # Maps polygon_node -> list of part_names
	var all_polygons_map = {}
	for poly in all_polygons:
		all_polygons_map[poly.name] = poly

	# 1. Build intra-part chains
	for part_name in part_order:
		var i = 0
		while true:
			var p_name = "%s_bone_%d" % [part_name, i]
			var c_name = "%s_bone_%d" % [part_name, i + 1]
			if bones.has(p_name) and bones.has(c_name):
					bones[p_name].add_child(bones[c_name])
			else:
				break
			i += 1

	# 2. Add all root bones to skeleton
	for part_name in part_order:
		if bones.has(part_name):
			var root_bone = bones[part_name]
			if root_bone.get_parent() == null:
				skeleton.add_child(root_bone)

	# 3. Determine mesh groups and build inter-part hierarchy
	for part_name in part_order:
		if not origins.has(part_name): continue
		var origin_point = origins[part_name]
		var found_parent_mesh = false

		for poly_node in active_polygons:
			if Geometry2D.is_point_in_polygon(origin_point - poly_node.position, poly_node.polygon):
				mesh_groups[poly_node].append(part_name)
				found_parent_mesh = true
				break
		
		if not found_parent_mesh and all_polygons_map.has(part_name):
			var part_poly = all_polygons_map[part_name]
			active_polygons.append(part_poly)
			mesh_groups[part_poly] = [part_name]

	# 4. Chain bones within each mesh group
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
						print("  \ud83d\udd17 %s \u2192 %s (misma malla)" % [child_bone_root.name, last_bone_in_chain.name])

	# 5. Reparent based on HIERARCHY_MAP
	for parent_name in HIERARCHY_MAP.keys():
		if not bones.has(parent_name): continue
		var parent_bone = bones[parent_name]
		for child_name in HIERARCHY_MAP[parent_name]:
			if bones.has(child_name):
				var child_bone = bones[child_name]
				if child_bone.get_parent() == skeleton:
					skeleton.remove_child(child_bone)
					parent_bone.add_child(child_bone)
					print("  \ud83d\udd17 %s \u2192 %s (jerarqu\u00eda)" % [child_name, parent_name])
	
	return active_polygons

func _pose_bones(node: Node, seeds: Dictionary):
	if node is Bone2D:
		var bone: Bone2D = node
		var name_parts = bone.name.rsplit("_bone_", true, 1)
		if name_parts.size() == 2:
			var part_name = name_parts[0]
			var bone_index = name_parts[1].to_int()
			
			if seeds.has(part_name):
				var part_raw_points = seeds[part_name]
				var seed_index = bone_index * 2
				if seed_index + 1 < part_raw_points.size():
					var start_point = part_raw_points[seed_index]
					var end_point = part_raw_points[seed_index + 1]
					
					var parent = bone.get_parent()
					# The seed points are in the skeleton's coordinate space (atlas space).
					# We need to convert them to be local to the bone's parent.
					var local_start = parent.to_local(start_point)
					var local_end = parent.to_local(end_point)
					
					bone.position = local_start
					var diff = local_end - local_start
					bone.rotation = diff.angle()
					bone.length = diff.length()
					print("  \ud83e\udd84 Hueso pose\u00eddo: %s en %s" % [bone.name, bone.position])

	for child in node.get_children():
		_pose_bones(child, seeds)

func _set_bone_rests_recursive(node: Node):
	if node is Bone2D:
		node.rest = node.transform
	for child in node.get_children():
		_set_bone_rests_recursive(child)
