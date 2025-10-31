@tool
extends VBoxContainer

# Módulos principales
const PolygonGenerator = preload("uid://dcc5an3ptehth")
const PartListManager  = preload("res://addons/autorig2d/core/PartListManager.gd")
const HumanoidBuilder  = preload("res://addons/autorig2d/core/HumanoidBuilder.gd")
const WeightingEngine  = preload("res://addons/autorig2d/core/WeightingEngine.gd")

# Nueva lógica separada
const AtlasLoader = preload("uid://cosxar5jkhmk7")
const SeedManager = preload("uid://cq7neflhr0lsd")
const RigGenerator = preload("uid://k7dfof5c0asq")
const PartDialogManager = preload("uid://c0rs41p7wmh1u")
const CoordinateManager = preload("res://addons/autorig2d/core/CoordinateManager.gd")
const RiggingState = preload("res://addons/autorig2d/core/RiggingState.gd")

# Instancias
var generator = PolygonGenerator.new()
var part_manager = PartListManager.new()
var atlas_loader = AtlasLoader.new()
var seed_manager = SeedManager.new()
var rig_generator = RigGenerator.new()
var part_dialog = PartDialogManager.new()
var coordinate_manager = CoordinateManager.new()
var _rigging_state = preload("res://addons/autorig2d/core/RiggingState.gd").new()

# Estado
var _new_part_dialog
var _parent_option_button: OptionButton
var _part_option_button: OptionButton

func _ready():
	await get_tree().process_frame

	# Inicializar todos los módulos con las dependencias necesarias
	part_manager.initialize(_rigging_state)

	_part_option_button = $PartNameHBox/ParentOptionButton
	for part_name in _rigging_state.part_names:
		_part_option_button.add_item(part_name)

		_part_option_button.select(0)
		_rigging_state.current_part_name = _part_option_button.get_item_text(0)
		print("Default selected part: ", _rigging_state.current_part_name)

	part_dialog.initialize_dialog(self, _rigging_state)
	atlas_loader.initialize(_rigging_state, coordinate_manager)
	seed_manager.initialize(_rigging_state, coordinate_manager)
	rig_generator.initialize(_rigging_state, generator, HumanoidBuilder, WeightingEngine, coordinate_manager)
	add_child(rig_generator)

	# Conexiones UI
	$FileDialog.file_selected.connect(self._on_file_selected)
	$HBoxContainer/SelectAtlasButton.pressed.connect($FileDialog.popup)
	$HBoxContainer/AddSeedButton.pressed.connect(seed_manager.on_add_seed_pressed)
	$HBoxContainer/GeneratePreviewButton.pressed.connect(rig_generator.on_generate_preview_pressed)
	$HBoxContainer/FinalizeWeightsButton.pressed.connect(rig_generator.on_finalize_weights_pressed)
	$PartNameHBox/AddNewPartButton.pressed.connect(part_dialog.on_add_new_part_pressed)

	if $TextureRect:
		$TextureRect.gui_input.connect(seed_manager.on_texture_gui_input)
		$TextureRect.draw.connect(seed_manager.on_texture_rect_draw.bind($TextureRect))
		seed_manager.seeds_updated.connect(self._on_seeds_updated)

	if $EpsilonHBox/EpsilonSlider:
		var slider = $EpsilonHBox/EpsilonSlider
		slider.value = _rigging_state.polygon_epsilon
		slider.value_changed.connect(func(value): _rigging_state.polygon_epsilon = value)
		slider.value_changed.connect(part_dialog.on_epsilon_slider_visual_update.bind($EpsilonHBox/EpsilonLabel))
		part_dialog.on_epsilon_slider_visual_update(_rigging_state.polygon_epsilon, $EpsilonHBox/EpsilonLabel)
		
	part_manager.part_name_added.connect(func(new_name, _all_parts):
		part_dialog.on_part_name_added(new_name, _part_option_button)
		_update_parent_option_button()
	)

	_parent_option_button = $PartNameHBox/ParentOptionButton

	_part_option_button.item_selected.connect(func(index):
		_rigging_state.current_part_name = _part_option_button.get_item_text(index)
		print("Selected part: ", _rigging_state.current_part_name)
		_update_parent_option_button()
	)
	_parent_option_button.item_selected.connect(self._on_parent_selected)

	_update_parent_option_button() # Initial population

func _update_parent_option_button():
	var part_option_button = _part_option_button

	_parent_option_button.clear()
	_parent_option_button.add_item("None", 0) # Option for no parent

	var current_part_name = _rigging_state.current_part_name
	var current_parent_index = 0

	for i in range(_rigging_state.part_names.size()):
		var part_name = _rigging_state.part_names[i]
		if part_name != current_part_name: # A part cannot be its own parent
			_parent_option_button.add_item(part_name, i + 1) # +1 because of 'None' at index 0
			if _rigging_state.part_data.has(current_part_name) and _rigging_state.part_data[current_part_name].has("parent") and _rigging_state.part_data[current_part_name]["parent"] == part_name:
				current_parent_index = i + 1

	_parent_option_button.select(current_parent_index)

func _on_parent_selected(index: int):
	var selected_parent_name = _parent_option_button.get_item_text(index)

	if not _rigging_state.part_data.has(_rigging_state.current_part_name):
		_rigging_state.part_data[_rigging_state.current_part_name] = {}

	if selected_parent_name == "None":
		_rigging_state.part_data[_rigging_state.current_part_name]["parent"] = ""
	else:
		_rigging_state.part_data[_rigging_state.current_part_name]["parent"] = selected_parent_name
	print("Parent for ", _rigging_state.current_part_name, ": ", _rigging_state.part_data[_rigging_state.current_part_name]["parent"])


func _on_seeds_updated():
	$TextureRect.queue_redraw()

func _on_file_selected(path: String):
	var result = atlas_loader.on_file_selected(path, $TextureRect)
	if result.texture:
		$TextureRect.texture = result.texture
		$TextureRect.queue_redraw()
