extends RefCounted

const HIERARCHY_MAP := {
	"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"],
	"head": [], "left_arm": [], "right_arm": [], "left_leg": [], "right_leg": []
}

func build_complete_rig(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2, all_polygons: Array, part_order: Array) -> Dictionary:
	print("\n🦴 Iniciando construcción del esqueleto...")
	
	var skeleton := Skeleton2D.new()
	skeleton.name = "AutoRigSkeleton"

	# 1. Create bone nodes, without transforms yet
	var bones := _create_bone_nodes(part_order, seeds)
	
	# 2. Build the full hierarchy and determine active polygons
	var active_polygons = _build_hierarchy(skeleton, bones, origins, all_polygons, part_order)

	# 3. Determine rig offset for centering
	var rig_offset = Vector2.ZERO
	if origins.has("torso"):
		rig_offset = origins["torso"]
	elif not origins.is_empty() and origins.has(part_order[0]):
		# Fallback to the first part in the creation order
		rig_offset = origins[part_order[0]]

	# 4. Now that hierarchy is stable, pose the bones
	_pose_bones(skeleton, seeds, rig_offset)

	# 5. Offset the active polygons to match the centered bones
	for poly in active_polygons:
		poly.position -= rig_offset

	# 6. Set the final rest pose
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
	var all_polygons_map = {}
	for poly in all_polygons:
		all_polygons_map[poly.name] = poly
	
	for part_name in part_order:
		if all_polygons_map.has(part_name):
			active_polygons.append(all_polygons_map[part_name])

	# 1. Build intra-part chains (e.g. part_bone_1 is child of part_bone_0)
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

	# 2. Build inter-part hierarchy based on creation order (simple chain)
	for i in range(1, part_order.size()):
		var parent_name = part_order[i - 1]
		var child_name = part_order[i]
		
		if bones.has(parent_name) and bones.has(child_name):
			var parent_root_bone = bones[parent_name]
			var child_root_bone = bones[child_name]
			
			# Find the last bone in the parent's chain
			var last_bone_in_chain = parent_root_bone
			while last_bone_in_chain.get_child_count() > 0:
				last_bone_in_chain = last_bone_in_chain.get_child(0)
			
			# Parent the child's root bone to the parent's last bone
			if child_root_bone.get_parent() == null:
				last_bone_in_chain.add_child(child_root_bone)

	# 3. Add all root bones (bones without parents) to the skeleton
	for part_name in part_order:
		if bones.has(part_name):
			var root_bone = bones[part_name]
			if root_bone.get_parent() == null:
				skeleton.add_child(root_bone)
	
	return active_polygons

func _pose_bones(node: Node, seeds: Dictionary, rig_offset: Vector2):
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
					
					# The skeleton node is at (0,0) in the GeneratedRigRoot.
					# The points need to be converted from canvas space to the final world space.
					var world_start = start_point - rig_offset
					var world_end = end_point - rig_offset

					var parent = bone.get_parent()
					var local_start = parent.to_local(world_start)
					var local_end = parent.to_local(world_end)
					
					bone.position = local_start
					var diff = local_end - local_start
					bone.rotation = diff.angle()
					bone.length = diff.length()
					print("  🦴 Hueso poseído: %s en %s" % [bone.name, bone.position])

	for child in node.get_children():
		_pose_bones(child, seeds, rig_offset)

func _set_bone_rests_recursive(node: Node):
	if node is Bone2D:
		node.rest = node.transform
	for child in node.get_children():
		_set_bone_rests_recursive(child)
