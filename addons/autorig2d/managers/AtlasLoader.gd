extends Node

const CoordinateManager = preload("res://addons/autorig2d/utils/CoordinateManager.gd")
const RiggingStateManager = preload("res://addons/autorig2d/managers/RiggingStateManager.gd")

var _rigging_state: RiggingStateManager
var _coordinate_manager: CoordinateManager

func initialize(rigging_state: RiggingStateManager, coord_manager: CoordinateManager):
	_rigging_state = rigging_state
	_coordinate_manager = coord_manager

func on_select_atlas_pressed():
	# This function should ideally emit a signal for the UI to handle file dialogs.
	# For now, RiggingDock will directly call the FileDialog.
	pass

func on_file_selected(path: String, texture_rect: TextureRect) -> Dictionary:
	print("AtlasLoader: on_file_selected called with path: ", path)
	_rigging_state.loaded_image_path = path
	var atlas_image = Image.load_from_file(path)
	if atlas_image:
		print("AtlasLoader: Image loaded successfully.")
		var atlas_texture = ImageTexture.create_from_image(atlas_image)
		
		# Inicializar el gestor de coordenadas
		_coordinate_manager.initialize(texture_rect, atlas_image)

		_rigging_state.seed_data.clear()
		# The UI will observe changes in _rigging_state.loaded_image_path and redraw
		print("✅ Atlas:", path)
		return {"texture": atlas_texture, "image": atlas_image}
	else:
		push_error("❌ Error cargando atlas: " + path)
		print("AtlasLoader: Failed to load image from path: ", path)
		return {"texture": null, "image": null}
