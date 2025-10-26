@tool
class_name PartLoader
extends Node

# Carga el atlas y el JSON (si existe)
func load_atlas_and_config(atlas_path: String, config_path: String = "") -> Dictionary:
	var result = {"atlas": null, "texture": null, "seeds": {}}
	
	# Carga la imagen del atlas
	if FileAccess.file_exists(atlas_path):
		var atlas = Image.load_from_file(atlas_path)
		if atlas:
			result.atlas = atlas
			result.texture = ImageTexture.create_from_image(atlas)
		else:
			push_error("No se pudo cargar el atlas: ", atlas_path)
	
	# Carga el config.json (si se proporciona)
	if config_path != "" and FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if data is Dictionary and data.has("seeds"):
				result.seeds = data.seeds
		else:
			push_error("Error al parsear JSON: ", config_path)
		file.close()
	
	return result
