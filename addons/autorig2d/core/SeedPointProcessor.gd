@tool
class_name SeedPointProcessor
extends Node

var image_tools = ImageTools.new()

# Procesa el atlas y los puntos semilla
func process_seeds(atlas_path: String, seeds: Dictionary) -> Array[Polygon2D]:
	var data = PartLoader.new().load_atlas_and_config(atlas_path)
	if not data.atlas:
		push_error("No se cargó el atlas")
		return []
	
	# Valida partes mínimas (según el documento)
	var required_parts = ["torso"]
	for part in required_parts:
		if not seeds.values().has(part):
			push_warning("Falta la parte principal requerida: ", part)
	
	image_tools.initialize(data.atlas, data.texture, seeds)
	var polygons = image_tools.generate_body_part_polygons()
	return polygons
