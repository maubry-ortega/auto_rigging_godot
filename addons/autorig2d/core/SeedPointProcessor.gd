@tool
class_name SeedPointProcessor
extends Node

# Procesa el atlas y los puntos semilla
func process_seeds(atlas_path: String) -> Dictionary:
	var data = PartLoader.new().load_atlas_and_config(atlas_path)
	if not data.atlas:
		push_error("No se cargó el atlas")
		return {}
	return data.seeds
