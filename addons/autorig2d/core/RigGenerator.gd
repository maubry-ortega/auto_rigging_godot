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

func on_generate_pressed():
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

	var rig_root = Node2D.new()
	rig_root.name = "GeneratedRigRoot"
	root.add_child(rig_root)
	rig_root.owner = root

	var skeleton = HumanoidBuilder.new().build_complete_rig(origins, _rigging_state.seed_data, atlas_image.get_size())
	rig_root.add_child(skeleton)
	skeleton.owner = root

	_assign_bone_ownership(skeleton, root)

	# Primero añadir los polígonos a la escena
	for poly in polygons:
		rig_root.add_child(poly)
		poly.owner = root
		# Ahora que ambos nodos están en el árbol, podemos obtener la ruta de forma segura
		poly.skeleton = poly.get_path_to(skeleton)

	# Ahora, con todo en su sitio, asignar los pesos
	WeightingEngine.new().assign_weights_to_polygons(polygons, skeleton)

	print("✅ Rig generado completamente.")
	_debug_rig_info(rig_root, skeleton, polygons)

func _assign_bone_ownership(node: Node, owner: Node):
	for child in node.get_children():
		child.owner = owner
		_assign_bone_ownership(child, owner)

func _debug_rig_info(rig_root: Node2D, skeleton, polygons:Array):
	print("\n🔍 Información del Rig Generado:")
	print("  Nodo raíz:", rig_root.name)
	print("  Esqueleto:", skeleton.name)
	print("  Polígonos:", polygons.size())
	for poly in polygons:
		print("  📐 %s | Vértices: %d" % [poly.name, poly.polygon.size()])