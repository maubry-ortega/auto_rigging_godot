extends Node

var ui
var generator
var atlas_loader
var seed_manager
var HumanoidBuilder
var WeightingEngine
var coordinate_manager

func initialize(ui_node, gen, atlas, seeds, hb, we, coord_manager):
	ui = ui_node
	generator = gen
	atlas_loader = atlas
	seed_manager = seeds
	HumanoidBuilder = hb
	WeightingEngine = we
	coordinate_manager = coord_manager

func on_generate_pressed():
	if not atlas_loader.atlas_image:
		push_error("Carga un atlas primero.")
		return
	if ui.seeds.is_empty():
		push_error("Agrega al menos una semilla.")
		return

	var generation_result = generator.generate_body_part_polygons(atlas_loader.atlas_image, atlas_loader.atlas_texture, ui.seeds, ui.polygon_epsilon)
	if generation_result.is_empty() or not generation_result.has("polygons") or generation_result.polygons.is_empty():
		push_error("No se generaron polígonos.")
		return

	var polygons = generation_result.polygons
	var origins = generation_result.origins

	var root = ui.get_tree().edited_scene_root
	if not is_instance_valid(root):
		push_error("No hay escena abierta.")
		return

	var rig_root = Node2D.new()
	rig_root.name = "GeneratedRigRoot"
	root.add_child(rig_root)
	rig_root.owner = root

	var skeleton = HumanoidBuilder.new().build_complete_rig(origins, ui.seeds, atlas_loader.atlas_image.get_size())
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