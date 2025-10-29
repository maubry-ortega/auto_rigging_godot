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

# Instancias
var generator = PolygonGenerator.new()
var part_manager = PartListManager.new()
var atlas_loader = AtlasLoader.new()
var seed_manager = SeedManager.new()
var rig_generator = RigGenerator.new()
var part_dialog = PartDialogManager.new()

# Estado
var _new_part_dialog
var atlas_path: String = ""
var atlas_image: Image
var atlas_texture: ImageTexture
var seeds: Dictionary = {}
var adding_seeds: bool = false
var current_part_name: String = ""
var polygon_epsilon: float = 0.1

func _ready():
	await get_tree().process_frame

	part_dialog.initialize_dialog(self, part_manager)
	atlas_loader.initialize(self)
	seed_manager.initialize(self)
	rig_generator.initialize(self, generator, atlas_loader, seed_manager, HumanoidBuilder, WeightingEngine)

	# Conexiones UI
	$FileDialog.file_selected.connect(atlas_loader.on_file_selected)
	$HBoxContainer/SelectAtlasButton.pressed.connect(atlas_loader.on_select_atlas_pressed)
	$HBoxContainer/AddSeedButton.pressed.connect(seed_manager.on_add_seed_pressed)
	$HBoxContainer/GenerateButton.pressed.connect(rig_generator.on_generate_pressed)
	$PartNameHBox/AddNewPartButton.pressed.connect(part_dialog.on_add_new_part_pressed)

	if $TextureRect:
		$TextureRect.gui_input.connect(seed_manager.on_texture_gui_input)
		$TextureRect.draw.connect(seed_manager.on_texture_rect_draw)

	if $EpsilonHBox/EpsilonSlider:
		var slider = $EpsilonHBox/EpsilonSlider
		slider.value = polygon_epsilon
		slider.value_changed.connect(part_dialog.on_epsilon_slider_visual_update)
		slider.value_changed.connect(part_dialog.on_epsilon_slider_changed)
		part_dialog.on_epsilon_slider_visual_update(polygon_epsilon)

	part_manager.part_name_added.connect(part_dialog.on_part_name_added)
