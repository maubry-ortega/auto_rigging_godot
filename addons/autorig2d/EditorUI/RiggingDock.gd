@tool
extends VBoxContainer

const PART_NAMES = ["torso"]

var atlas_path: String = ""
var atlas_image: Image
var atlas_texture: ImageTexture
var seeds: Dictionary = {}

var adding_seeds: bool = false
var current_part_name: String = ""

func _ready():
	# Connections
	$FileDialog.file_selected.connect(_on_file_selected)
	$HBoxContainer/SelectAtlasButton.pressed.connect(_on_select_atlas_pressed)
	$HBoxContainer/AddSeedButton.pressed.connect(_on_add_seed_pressed)
	$HBoxContainer/GenerateButton.pressed.connect(_on_generate_pressed)
	$TextureRect.connect("gui_input", Callable(self, "_on_texture_gui_input"))
	
	# Populate OptionButton
	var option_button = $PartNameHBox/PartNameOptionButton
	for part_name in PART_NAMES:
		option_button.add_item(part_name)

func _on_select_atlas_pressed():
	$FileDialog.popup()

func _on_file_selected(path: String):
	atlas_path = path
	atlas_image = Image.load_from_file(path)
	if atlas_image:
		atlas_texture = ImageTexture.create_from_image(atlas_image)
		$TextureRect.texture = atlas_texture
		print("Atlas cargado:", atlas_path)
	else:
		push_error("No se pudo cargar la imagen del atlas: " + path)


func _on_add_seed_pressed():
	var option_button = $PartNameHBox/PartNameOptionButton
	if option_button.get_selected_id() == -1:
		push_error("Por favor, selecciona una parte del cuerpo del menú desplegable.")
		return
		
	current_part_name = option_button.get_item_text(option_button.get_selected_id())
	adding_seeds = true
	print("Modo agregar puntos activado. Click para agregar seed point como: ", current_part_name)

func _on_texture_gui_input(event):
	if adding_seeds and event is InputEventMouseButton and event.pressed:
		var local_pos = $TextureRect.get_local_mouse_position()
		var seed_key = Vector2i(int(local_pos.x), int(local_pos.y))
		
		# Check if part already has a seed
		for existing_seed_name in seeds.values():
			if existing_seed_name == current_part_name:
				push_warning("Ya existe un punto para la parte '%s'. Reemplazando." % current_part_name)
				# Find and remove old key
				for key in seeds.keys():
					if seeds[key] == current_part_name:
						seeds.erase(key)
						break
		
		seeds[seed_key] = current_part_name
		print("Punto agregado en:", seed_key, " como:", current_part_name)
		adding_seeds = false # Deactivate after adding one point

func _on_generate_pressed():
	if not atlas_image or atlas_path == "":
		push_error("Selecciona un atlas primero")
		return
	
	print("Iniciando proceso de generación de rig...")
	
	# 1. Procesar los puntos semilla para generar polígonos
	var seed_processor = SeedPointProcessor.new()
	var polygons = seed_processor.process_seeds(atlas_path, seeds)
	
	var generated_count = polygons.size()
	var seed_count = seeds.size()

	if generated_count == 0:
		push_error("No se generaron polígonos. Revisa los puntos semilla o la forma de las partes.")
		return

	# 2. Añadir los polígonos generados directamente a la escena
	print("Añadiendo polígonos a la escena...")
	for poly in polygons:
		if is_instance_valid(poly):
			get_tree().edited_scene_root.add_child(poly)
			poly.owner = get_tree().edited_scene_root
	
	# 3. Reporte final
	print("Proceso de generación completado.")
	print(" - Puntos semilla procesados: %d" % seed_count)
	print(" - Polígonos generados con éxito: %d" % generated_count)
	if generated_count < seed_count:
		print(" - Polígonos fallidos: %d." % (seed_count - generated_count))
