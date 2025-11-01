extends Node

var _rigging_state: RiggingState
var generator
var HumanoidBuilder
var WeightingEngine
var coordinate_manager

func initialize(rigging_state: RiggingState, gen, hb, we, coord_manager):
	_rigging_state = rigging_state
	generator = gen
	HumanoidBuilder = hb
	WeightingEngine = we
	coordinate_manager = coord_manager

var _generated_rig_root: Node2D = null
var _generated_skeleton: Skeleton2D = null
var _generated_polygons: Array[Polygon2D] = []
 
func on_generate_preview_pressed():
	if _rigging_state.loaded_image_path.is_empty():
		push_error("Carga un atlas primero.")
		return
	if _rigging_state.seed_data.is_empty():
		push_error("Agrega al menos una semilla.")
		return

	var atlas_image = Image.load_from_file(_rigging_state.loaded_image_path)
	if not atlas_image:
		push_error("Error cargando la imagen del atlas desde la ruta: " + _rigging_state.loaded_image_path)
		return
	var atlas_texture = ImageTexture.create_from_image(atlas_image)

	var generation_result = generator.generate_body_part_polygons(atlas_image, atlas_texture, _rigging_state.seed_data, _rigging_state.polygon_epsilon)
	if generation_result.is_empty() or not generation_result.has("polygons") or generation_result.polygons.is_empty():
		push_error("No se generaron polígonos.")
		return

	var polygons = generation_result.polygons
	var origins = generation_result.origins

	var tree = get_tree()
	if not is_instance_valid(tree):
		push_error("RigGenerator is not in a scene tree.")
		return

	var root = tree.edited_scene_root
	if not is_instance_valid(root):
		push_error("No hay escena abierta en el editor.")
		return

	_generated_rig_root = Node2D.new()
	_generated_rig_root.name = "GeneratedRigRoot"
	root.add_child(_generated_rig_root)
	_generated_rig_root.owner = root

	var rig_build_result = HumanoidBuilder.new().build_complete_rig(origins, _rigging_state.seed_data, atlas_image.get_size(), polygons, _rigging_state.seed_data.keys())
	_generated_skeleton = rig_build_result["skeleton"]
	var active_polygons = rig_build_result["polygons"]
	_generated_rig_root.add_child(_generated_skeleton)
	_generated_skeleton.owner = root

	_assign_bone_ownership(_generated_skeleton, root)

	# Primero añadir los polígonos a la escena
	_generated_polygons = []
	for poly in active_polygons:
		_generated_rig_root.add_child(poly)
		poly.owner = root
		# Ahora que ambos nodos están en el árbol, podemos obtener la ruta de forma segura
		poly.skeleton = poly.get_path_to(_generated_skeleton)
		_generated_polygons.append(poly)

	print("✅ Previsualización del Rig generada.")
	_debug_rig_info(_generated_rig_root, _generated_skeleton, _generated_polygons)

func on_finalize_weights_pressed():
	if not is_instance_valid(_generated_rig_root) or not is_instance_valid(_generated_skeleton) or _generated_polygons.is_empty():
		push_error("Primero genera una previsualización del rig.")
		return

	# Actualizar la pose de descanso de los huesos con sus transformaciones actuales
	_update_bone_rests(_generated_skeleton)

	WeightingEngine.new().assign_weights_to_polygons(_generated_polygons, _generated_skeleton)
	print("✅ Pesos aplicados al rig.")

func _update_bone_rests(node: Node):
	if node is Bone2D:
		node.rest = node.transform
	for child in node.get_children():
		_update_bone_rests(child)

func _assign_bone_ownership(node: Node, owner: Node):
	for child in node.get_children():
		child.owner = owner
		_assign_bone_ownership(child, owner)

func _debug_rig_info(rig_root: Node2D, skeleton: Skeleton2D, polygons:Array):
	print("\n🔍 Información del Rig Generado:")
	print("  Nodo raíz:", rig_root.name)
	print("  Esqueleto:", skeleton.name)
	print("  Total de huesos:", skeleton.get_bone_count())
	print("  Jerarquía de huesos:")
	_print_bone_hierarchy(skeleton, 0)
	print("  Polígonos:", polygons.size())
	for poly in polygons:
		print("  📐 %s | Vértices: %d" % [poly.name, poly.polygon.size()])

func _print_bone_hierarchy(node: Node, indent: int):
	var indent_str = "  ".repeat(indent)
	if node is Bone2D or node is Skeleton2D: # Also print Skeleton2D as a root for bones
		print("%s- %s" % [indent_str, node.name])
	for child in node.get_children():
		_print_bone_hierarchy(child, indent + 1)
