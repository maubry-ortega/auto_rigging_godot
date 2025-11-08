# HumanoidBuilder.gd
extends RefCounted

const HIERARCHY_MAP := {
	"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"],
	"head": [], "left_arm": [], "right_arm": [], "left_leg": [], "right_leg": []
}

# Helper: acepta seeds en formato legacy [Vector2,...] o en formato enriquecido [{"pos":Vector2, "role":"..."}]
func _seed_point_at(seeds, part_name, idx):
	if not seeds.has(part_name):
		return null
	var arr = seeds[part_name]
	if idx >= arr.size():
		return null
	var item = arr[idx]
	if typeof(item) == TYPE_DICTIONARY and item.has("pos"):
		return item.pos
	return item # assume Vector2

var skeleton: Skeleton2D

func build_complete_rig(origins: Dictionary, seeds: Dictionary, atlas_size: Vector2, all_polygons: Array, part_order: Array) -> Dictionary:
	print("\n🦴 Iniciando construcción del esqueleto...")
	
	skeleton = Skeleton2D.new()
	skeleton.name = "AutoRigSkeleton"

	# 1. Create bone nodes, without transforms yet
	var bones := _create_bone_nodes(part_order, seeds)
	
	# 2. Build the full hierarchy and determine active polygons
	var active_polygons = _build_hierarchy(skeleton, bones, origins, all_polygons, part_order)

	# 3. Determine rig offset for centering (prefer pelvis)
	var rig_offset = Vector2.ZERO
	if bones.has("pelvis") and bones["pelvis"]:
		rig_offset = bones["pelvis"].position if bones["pelvis"].position != null else Vector2.ZERO
	elif origins.has("torso"):
		rig_offset = origins["torso"]
	elif not origins.is_empty() and origins.has(part_order[0]):
		rig_offset = origins[part_order[0]]

	# 4. Now that hierarchy is stable, pose the bones
	_pose_bones(skeleton, seeds, rig_offset)

	# 5. Offset the active polygons to match the centered bones
	for poly in active_polygons:
		poly.position -= rig_offset

	# 6. Set the final rest pose
	_set_bone_rests_recursive(skeleton)

	print("✅ Esqueleto construido con %d huesos" % bones.size())
	return {"skeleton": skeleton, "polygons": active_polygons}

func _get_seed_pos(seed) -> Vector2:
	if typeof(seed) == TYPE_DICTIONARY and seed.has("pos"):
		return seed.pos
	return seed

func _create_bone_nodes(part_order: Array, seeds: Dictionary) -> Dictionary:
	var all_bones := {}
	var last_created_bone: Bone2D = null
	
	# 1. Creación de la pelvis (si aplica)
	if seeds.has("left_leg") and seeds.has("right_leg"):
		var left0 = _seed_point_at(seeds, "left_leg", 0)
		var right0 = _seed_point_at(seeds, "right_leg", 0)
		if left0 and right0:
			var pelvis_pos = left0.lerp(right0, 0.5)
			var pelvis := Bone2D.new()
			pelvis.name = "pelvis"
			pelvis.position = pelvis_pos
			all_bones["pelvis"] = pelvis

	# 2. Creación de cadenas de huesos para cada parte
	for part_name in part_order:
		if not seeds.has(part_name):
			continue

		var part_seeds = seeds[part_name]
		var pts = part_seeds.map(_get_seed_pos)

		# Heurística para el torso: si hay cabeza, se crea una espina dorsal
		if part_name == "torso" and seeds.has("head"):
			var head_pos = _seed_point_at(seeds, "head", 0)
			var pelvis_pos = all_bones["pelvis"].position if all_bones.has("pelvis") else (pts[0] if not pts.is_empty() else Vector2.ZERO)
			
			if pelvis_pos != Vector2.ZERO and head_pos:
				var prev_b: Bone2D = null
				for i in range(3):
					var b := Bone2D.new()
					b.name = "%s_spine_%d" % [part_name, i]
					b.position = pelvis_pos.lerp(head_pos, float(i) / 2.0) # Distribuido a lo largo de la espina
					all_bones[b.name] = b
					
					if prev_b:
						prev_b.add_child(b)
					prev_b = b
					last_created_bone = b
				
				# Alias para el torso
				if last_created_bone:
					all_bones[part_name] = last_created_bone
			continue

		# Default: crear huesos por pares de semillas
		for i in range(0, pts.size(), 2):
			if i + 1 < pts.size():
				var bone := Bone2D.new()
				var bone_index = int(i / 2)
				bone.name = "%s_bone_%d" % [part_name, bone_index]
				bone.position = pts[i]
				all_bones[bone.name] = bone
				last_created_bone = bone
				
				# Alias para la raíz de la parte
				if bone_index == 0:
					all_bones[part_name] = bone
				
	return all_bones

func _build_hierarchy(skeleton: Skeleton2D, bones: Dictionary, origins: Dictionary, all_polygons: Array, part_order: Array) -> Array:
	var active_polygons = all_polygons

	# 1. Conectar cadenas de huesos intra-parte (ej: arm_bone_0 -> arm_bone_1)
	for key in bones.keys():
		if key.find("_bone_") != -1:
			var part_name = key.rsplit("_bone_", true, 1)[0]
			var idx = int(key.rsplit("_bone_", true, 1)[1])
			var next_name = "%s_bone_%d" % [part_name, idx + 1]
			if bones.has(next_name) and bones[key].get_child_count() == 0: # Evitar reconexiones
				bones[key].add_child(bones[next_name])

	# 2. Conectar pelvis a la espina dorsal si ambos existen
	if bones.has("pelvis") and bones.has("torso_spine_0"):
		var pelvis = bones["pelvis"]
		var spine_root = bones["torso_spine_0"]
		if spine_root.get_parent() == null:
			pelvis.add_child(spine_root)

	# 3. Conectar extremidades y cabeza al torso/espina
	var torso_bone = null
	if bones.has("torso_spine_2"): # Último hueso de la espina
		torso_bone = bones["torso_spine_2"]
	elif bones.has("torso"): # Fallback al torso genérico
		torso_bone = bones["torso"]

	if torso_bone:
		for child_part in HIERARCHY_MAP["torso"]:
			if bones.has(child_part):
				var child_root = bones[child_part]
				if child_root.get_parent() == null:
					torso_bone.add_child(child_root)

	# 4. Parenting de último recurso basado en el orden (si algo quedó suelto)
	for i in range(1, part_order.size()):
		var parent_name = part_order[i - 1]
		var child_name = part_order[i]
		if bones.has(parent_name) and bones.has(child_name):
			var parent_root = bones[parent_name]
			var child_root = bones[child_name]
			if child_root.get_parent() == null:
				var last_descendant = parent_root
				while last_descendant.get_child_count() > 0:
					last_descendant = last_descendant.get_child(0)
				last_descendant.add_child(child_root)

	# 5. Añadir todas las raíces al esqueleto
	for b in bones.values():
		if b is Bone2D and b.get_parent() == null:
			skeleton.add_child(b)

	return active_polygons

func _pose_bones(node: Node, seeds: Dictionary, rig_offset: Vector2):
	if node is Bone2D:
		var bone: Bone2D = node
		# Si el bone tiene nombre con _bone_ intentamos usar seeds
		if bone.name.find("_bone_") != -1:
			var parts = bone.name.rsplit("_bone_", true, 1)
			if parts.size() == 2:
				var part_name = parts[0]
				var idx = int(parts[1])
				var start_point = _seed_point_at(seeds, part_name, idx * 2)
				var end_point = _seed_point_at(seeds, part_name, idx * 2 + 1)
				if start_point and end_point:
					var world_start = start_point - rig_offset
					var world_end = end_point - rig_offset
					var local_start: Vector2
					var local_end: Vector2
					var parent = bone.get_parent()
					if parent and parent is Bone2D:
						local_start = parent.to_local(world_start)
						local_end = parent.to_local(world_end)
					else:
						local_start = world_start
						local_end = world_end
					bone.position = local_start
					var diff = local_end - local_start
					var target_angle = diff.angle()
					# snapping anatómico (si está cerca de 0, 90, etc.)
					bone.rotation = target_angle
					bone.length = diff.length()
		# spine pattern: spine bones named torso_spine_i
		elif bone.name.find("_spine_") != -1:
			# si tiene posición ya pre-asignada en creación, respetar y suavizar
			var parent = bone.get_parent()
			if parent:
				bone.rotation = lerp_angle(bone.rotation, parent.rotation, 0.4)

	for child in node.get_children():
		_pose_bones(child, seeds, rig_offset)

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
