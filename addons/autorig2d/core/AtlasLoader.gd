extends Node

var ui
var coordinate_manager
var atlas_path: String
var atlas_image: Image
var atlas_texture: ImageTexture

func initialize(ui_node, coord_manager):
	ui = ui_node
	coordinate_manager = coord_manager

func on_select_atlas_pressed():
	ui.get_node("FileDialog").popup()

func on_file_selected(path: String):
	atlas_path = path
	ui.atlas_path = path
	atlas_image = Image.load_from_file(path)
	ui.atlas_image = atlas_image
	if atlas_image:
		atlas_texture = ImageTexture.create_from_image(atlas_image)
		var texture_rect = ui.get_node("TextureRect")
		texture_rect.texture = atlas_texture
		texture_rect.custom_minimum_size = atlas_image.get_size()
		
		# Inicializar el gestor de coordenadas
		coordinate_manager.initialize(texture_rect, atlas_image)

		ui.seeds.clear()
		texture_rect.queue_redraw()
		print("✅ Atlas:", path)
	else:
		push_error("❌ Error cargando atlas: " + path)
