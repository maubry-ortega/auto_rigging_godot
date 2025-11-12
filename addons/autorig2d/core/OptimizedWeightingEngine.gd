# OptimizedWeightingEngine.gd
extends RefCounted
class_name OptimizedWeightingEngine

# Usar WorkerThreadPool para procesamiento paralelo cuando hay muchos polígonos
func assign_weights_to_polygons(polygons: Array, skeleton: Skeleton2D) -> void:
    print("\n⚖️ Asignando pesos a polígonos (versión optimizada)...")
    var bones = _get_all_bones(skeleton)
    var bone_names_list := []
    for i in range(bones.size()):
        bone_names_list.append(bones[i].name)
    print("  🔍 Huesos disponibles: %s" % [bone_names_list])

    # Procesar polígonos en paralelo si hay muchos
    if polygons.size() > 4:
        _process_polygons_parallel(polygons, bones, skeleton)
    else:
        _process_polygons_sequential(polygons, bones, skeleton)

    print("✅ Pesos asignados a %d polígonos" % polygons.size())

func _process_polygons_parallel(polygons: Array, bones: Array, skeleton: Skeleton2D):
    var task_id = WorkerThreadPool.add_group_task(_process_single_polygon.bind(polygons, bones, skeleton), polygons.size())
    WorkerThreadPool.wait_for_group_task_completion(task_id)

# CORREGIDO: Nueva función para procesar polígonos individualmente
func _process_single_polygon(polygons: Array, bones: Array, skeleton: Skeleton2D, index: int):
    # Ensure the index is valid before accessing the array
    if index >= 0 and index < polygons.size():
        _assign_weights_to_polygon_optimized(polygons[index], bones, skeleton)

func _process_polygons_sequential(polygons: Array, bones: Array, skeleton: Skeleton2D):
    for poly in polygons:
        _assign_weights_to_polygon_optimized(poly, bones, skeleton)

# ---------------------------------------------------------
# Recolección de huesos (sin cambios)
# ---------------------------------------------------------
func _get_all_bones(skeleton: Skeleton2D) -> Array:
    var bones := []
    _collect_bones_recursive(skeleton, bones)
    return bones

func _collect_bones_recursive(node: Node, bones: Array) -> void:
    if node is Bone2D:
        bones.append(node)
    for j in range(node.get_child_count()):
        _collect_bones_recursive(node.get_child(j), bones)

# ---------------------------------------------------------
# Asignación por polígono (optimizada)
# ---------------------------------------------------------
func _assign_weights_to_polygon_optimized(poly: Polygon2D, bones: Array, skeleton: Skeleton2D) -> void:
    var part_name := poly.name
    var associated_bones := _find_associated_bones(part_name, bones)

    if associated_bones.is_empty():
        print("  ⚠️ No se encontraron huesos asociados para: %s" % part_name)
        return

    # Asegurar que poly.skeleton sea el NodePath al skeleton recibido
    var desired_path := poly.get_path_to(skeleton)
    if str(poly.skeleton) != str(desired_path):
        poly.skeleton = desired_path

    # Construir la cadena de huesos: main bone + sus descendientes
    var bone_chain := _get_bone_chain_for_part(part_name, associated_bones)
    if bone_chain.is_empty():
        print("  ⚠️ '%s' no tiene hueso/descendientes válidos." % part_name)
        return

    _setup_polygon_skinning_optimized(poly, bone_chain)

# ---------------------------------------------------------
# Generar bóveda de huesos a usar para una parte (sin cambios)
# ---------------------------------------------------------
func _get_bone_chain_for_part(part_name: String, main_bones: Array) -> Array:
    var chain := []
    var added := {}
    
    # Añadir cada main_bone, su padre si coincide por nombre, y todos los descendientes recursivamente
    for i in range(main_bones.size()):
        var bone = main_bones[i]
        if not bone or not (bone is Bone2D):
            continue

        # parent solo si contiene el part_name (evita incluir torso en brazo)
        var parent = bone.get_parent()
        if parent and parent is Bone2D and not added.has(parent):
            if parent.name.find(part_name) != -1:
                chain.append(parent)
                added[parent] = true

        if not added.has(bone):
            chain.append(bone)
            added[bone] = true

        _collect_bone_descendants(bone, chain, added)

    return chain

func _collect_bone_descendants(bone: Bone2D, chain: Array, added: Dictionary) -> void:
    for j in range(bone.get_child_count()):
        var child = bone.get_child(j)
        if child and child is Bone2D and not added.has(child):
            chain.append(child)
            added[child] = true
            _collect_bone_descendants(child, chain, added)

# ---------------------------------------------------------
# Asociación por nombre (parte -> hueso) (sin cambios)
# ---------------------------------------------------------
func _find_associated_bones(part_name: String, bones: Array) -> Array:
    var found_bones := []

    # overlap special-case
    if part_name.ends_with("_overlap"):
        var overlap_base = part_name.rsplit("_overlap", true, 1)[0]
        var unique_parts := {}
        for i in range(bones.size()):
            var bn = bones[i]
            var bone_part_name := ""
            if bn.name.find("_bone_") != -1:
                bone_part_name = bn.name.rsplit("_bone_", true, 1)[0]
            elif bn.name.find("_spine_") != -1:
                bone_part_name = bn.name.rsplit("_spine_", true, 1)[0]
            elif not bn.name.is_empty():
                bone_part_name = bn.name
            if bone_part_name != "" and not unique_parts.has(bone_part_name):
                unique_parts[bone_part_name] = true

        for key in unique_parts.keys():
            if overlap_base.find(key) != -1:
                var main_b = _find_associated_bone(key, bones)
                if main_b and not found_bones.has(main_b):
                    found_bones.append(main_b)

        if not found_bones.is_empty():
            var names := []
            for k in range(found_bones.size()):
                names.append(found_bones[k].name)
            print("  - Overlap '%s' asociado con: %s" % [part_name, names])
            return found_bones

    # normal
    var main_bone = _find_associated_bone(part_name, bones)
    if main_bone:
        found_bones.append(main_bone)
    return found_bones

func _find_associated_bone(part_name: String, bones: Array) -> Bone2D:
    # First try exact match
    for i in range(bones.size()):
        var bone = bones[i]
        if bone.name == part_name:
            return bone

    # Then try bone chains (upper/lower)
    for i in range(bones.size()):
        var bone = bones[i]
        if bone.name.begins_with(part_name + "_"):
            return bone

    # Fallback to contains
    for i in range(bones.size()):
        var bone = bones[i]
        if bone.name.find(part_name) != -1:
            return bone

    return null

# ---------------------------------------------------------
# Calcular pesos y asignar (versión optimizada)
# ---------------------------------------------------------
func _setup_polygon_skinning_optimized(poly: Polygon2D, bone_chain: Array) -> void:
    var num_vertices = poly.polygon.size()
    if num_vertices == 0:
        print("  ⚠️ Polygon '%s' no tiene vértices." % poly.name)
        return

    # Prepara rutas y arrays
    var bone_paths := []
    var weight_arrays := []
    for i in range(bone_chain.size()):
        var bone = bone_chain[i]
        bone_paths.append(poly.get_path_to(bone))
        var arr := PackedFloat32Array()
        arr.resize(num_vertices)
        weight_arrays.append(arr)

    var verts_world := []
    var poly_global = poly.get_global_transform()
    for vi in range(num_vertices):
        var local_v = poly.polygon[vi]
        verts_world.append(poly_global * local_v)
    
    var bbox = _compute_polygon_bbox(poly.polygon)
    var proximity_threshold = max(40.0, (bbox.size.length() * 0.5)) # px heuristic

    var usable_bone_indices := []
    for bi in range(bone_chain.size()):
        var bone = bone_chain[bi]
        var bone_start = bone.to_global(Vector2.ZERO)
        var bone_end = bone.to_global(Vector2(bone.length if bone.length > 0.001 else 15.0, 0))
        var min_dist = INF
        for vi in range(num_vertices):
            var d = Geometry2D.get_closest_point_to_segment(verts_world[vi], bone_start, bone_end).distance_to(verts_world[vi])
            if d < min_dist:
                min_dist = d
        if min_dist <= proximity_threshold:
            usable_bone_indices.append(bi)
    
    # if none usable, fallback to all
    if usable_bone_indices.size() == 0:
        for bi in range(bone_chain.size()):
            usable_bone_indices.append(bi)

    # Calcular pesos gaussianos en espacio local del polygon
    var world_to_local = poly.get_global_transform().affine_inverse()
    for idx_i in range(usable_bone_indices.size()):
        var bi = usable_bone_indices[idx_i]
        var bone = bone_chain[bi]
        var bone_start_world = bone.to_global(Vector2.ZERO)
        var bone_end_world = bone.to_global(Vector2(bone.length if bone.length > 0.001 else 15.0, 0))
        var bone_start_local = world_to_local * bone_start_world
        var bone_end_local = world_to_local * bone_end_world

        var bone_len = max(1.0, (bone_end_local - bone_start_local).length())
        var sigma = max(8.0, bone_len * 0.5)
        var denom = 2.0 * sigma * sigma

        for vi in range(num_vertices):
            var vertex = poly.polygon[vi]
            var closest = Geometry2D.get_closest_point_to_segment(vertex, bone_start_local, bone_end_local)
            var dist = vertex.distance_to(closest)
            weight_arrays[bi][vi] = exp(-(dist * dist) / denom)

    # Top-N influences y normalización (versión optimizada)
    var max_influences = 3
    var final_weights := []
    for i in range(bone_chain.size()):
        var arr := PackedFloat32Array()
        arr.resize(num_vertices)
        final_weights.append(arr)

    for vi in range(num_vertices):
        var influences := []
        for bi in range(bone_chain.size()):
            influences.append({"i": bi, "w": weight_arrays[bi][vi]})

        # Ordenar influences por peso descendente usando sort_custom (más eficiente)
        influences.sort_custom(func(a, b): return a.w > b.w)

        # total top-N
        var total = 0.0
        var topn = min(max_influences, influences.size())
        for k in range(topn):
            total += influences[k].w

        if total <= 0.0:
            final_weights[0][vi] = 1.0
            continue

        for k in range(topn):
            var idx = influences[k].i
            final_weights[idx][vi] = influences[k].w / total

    # Aplicar al Polygon2D
    poly.clear_bones()
    for bi in range(bone_chain.size()):
        var sum_w = 0.0
        var fw = final_weights[bi]
        for wi in range(fw.size()):
            sum_w += fw[wi]
        if sum_w <= 0.0001:
            continue
        poly.add_bone(bone_paths[bi], final_weights[bi])

    var used_names := []
    for i in range(bone_chain.size()):
        used_names.append(bone_chain[i].name)
    print("  ✅ '%s' conectado a esqueleto y pesos distribuidos entre: %s" % [poly.name, used_names])

# ---------------------------------------------------------
# Util (sin cambios)
# ---------------------------------------------------------
func _compute_polygon_bbox(points: PackedVector2Array) -> Rect2:
    if points.is_empty():
        return Rect2()
    var r = Rect2(points[0], Vector2.ZERO)
    for p in points:
        r = r.expand(p)
    return r