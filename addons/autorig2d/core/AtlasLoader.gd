extends Node

var ui
var atlas_path: String
var atlas_image: Image
var atlas_texture: ImageTexture

func initialize(ui_node):
	ui = ui_node

func on_select_atlas_pressed():
	ui.get_node("FileDialog").popup()

func on_file_selected(path: String):
	atlas_path = path
	ui.atlas_path = path
	atlas_image = Image.load_from_file(path)
	ui.atlas_image = atlas_image
	if atlas_image:
		atlas_texture = ImageTexture.create_from_image(atlas_image)
		ui.atlas_texture = atlas_texture
		ui.get_node("TextureRect").texture = atlas_texture
		ui.get_node("TextureRect").custom_minimum_size = atlas_image.get_size()
		ui.seeds.clear()
		ui.get_node("TextureRect").queue_redraw()
		print("✅ Atlas:", path)
	else:
		push_error("❌ Error cargando atlas: " + path)
