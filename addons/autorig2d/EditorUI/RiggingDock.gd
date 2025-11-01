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
var _rigging_state = RiggingState.new() 

# Estado
var _new_part_dialog
var _part_option_button: OptionButton 

func _ready():
	await get_tree().process_frame

	# CORREGIDO: Inicializar _rigging_state primero y verificar que no sea null
	if _rigging_state == null:
		_rigging_state = RiggingState.new()
	
	# CORREGIDO: Inicializar arrays si no existen
	if _rigging_state.part_names == null:
		_rigging_state.part_names = ["head", "left_arm", "right_arm", "left_leg", "right_leg"]  # Valores por defecto
	if _rigging_state.part_data == null:
		_rigging_state.part_data = {}

	# CORREGIDO: Usar solo ParentOptionButton para todo
	_part_option_button = $PartNameHBox/ParentOptionButton

	# Limpiar y poblar con las partes actuales
	_part_option_button.clear()
	for part_name in _rigging_state.part_names:
		_part_option_button.add_item(part_name)

	if _part_option_button.item_count > 0:
		_part_option_button.select(0)
		_rigging_state.current_part_name = _part_option_button.get_item_text(0)
		print("Default selected part: ", _rigging_state.current_part_name)
	
	# Inicializar módulos
	part_manager.initialize(_rigging_state)
	part_dialog.initialize_dialog(self, _rigging_state, part_manager)
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
		var new_index = _get_option_button_item_index_by_text(_part_option_button, new_name)
		if new_index != -1:
			_part_option_button.select(new_index)
			_rigging_state.current_part_name = new_name
			print("RiggingDock: New part '" + new_name + "' selected and current_part_name updated.")
		_update_parent_option_button()
	)

	_part_option_button.item_selected.connect(self._on_part_selected)

	# Actualizar el estado inicial
	_update_parent_option_button()

func _on_part_selected(index: int):
	_rigging_state.current_part_name = _part_option_button.get_item_text(index)
	print("RiggingDock: _rigging_state.current_part_name updated to: ", _rigging_state.current_part_name)
	print("Selected part: ", _rigging_state.current_part_name)
	_update_parent_option_button()
	
func _update_parent_option_button():
	# Esta función ahora actualiza la lógica de parentesco internamente
	# pero seguimos usando el mismo OptionButton para seleccionar partes
	
	var current_part_name = _rigging_state.current_part_name
	print("Current part updated: ", current_part_name)
	
func _on_seeds_updated():
	$TextureRect.queue_redraw()

func _on_file_selected(path: String):
	var result = atlas_loader.on_file_selected(path, $TextureRect)
	if result.texture:
		$TextureRect.texture = result.texture
		$TextureRect.queue_redraw()

func _get_option_button_item_index_by_text(option_button: OptionButton, target_text: String) -> int:
	for i in range(option_button.get_item_count()):
		if option_button.get_item_text(i) == target_text:
			return i
	return -1 # Return -1 if the item is not found
