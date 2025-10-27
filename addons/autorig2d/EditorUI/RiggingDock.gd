@tool
extends VBoxContainer

# Instancia del módulo de lógica (Ruta ajustada según tu carpeta 'core')
const PolygonGenerator = preload("uid://dcc5an3ptehth")
var generator = PolygonGenerator.new()

# Constantes y variables de estado (se mantienen en la UI, excepto las constantes del core)
@export var PART_NAMES = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg", "left_hand", "right_hand", "left_foot", "right_foot"]

var atlas_path: String = ""
var atlas_image: Image
var atlas_texture: ImageTexture
var seeds: Dictionary = {}

var adding_seeds: bool = false
var current_part_name: String = ""

# VARIABLE DE CONTROL DE DETALLE DEL POLÍGONO (Epsilon RDP)
var polygon_epsilon: float = 0.1

# ==============================================================================
## Funciones de UI y Conexión
# ==============================================================================

func _ready():
	# Conexiones de UI
	$FileDialog.file_selected.connect(_on_file_selected)
	$HBoxContainer/SelectAtlasButton.pressed.connect(_on_select_atlas_pressed)
	$HBoxContainer/AddSeedButton.pressed.connect(_on_add_seed_pressed)
	$HBoxContainer/GenerateButton.pressed.connect(_on_generate_pressed)
	$TextureRect.gui_input.connect(_on_texture_gui_input)
	$TextureRect.draw.connect(_on_texture_rect_draw)
	
	# Configuración del Slider
	if $EpsilonHBox/EpsilonSlider:
		$EpsilonHBox/EpsilonSlider.value = polygon_epsilon
		$EpsilonHBox/EpsilonSlider.value_changed.connect(_on_epsilon_slider_visual_update)
		# Usamos value_changed en Godot 4 para actualizar mientras se arrastra
		$EpsilonHBox/EpsilonSlider.value_changed.connect(_on_epsilon_slider_changed)
		_on_epsilon_slider_visual_update(polygon_epsilon)
	
	# Llenar OptionButton
	var option_button = $PartNameHBox/PartNameOptionButton
	option_button.clear()
	for part_name in PART_NAMES:
		option_button.add_item(part_name)

func _on_epsilon_slider_changed(value: float):
	polygon_epsilon = value

func _on_epsilon_slider_visual_update(value: float):
	if $EpsilonHBox/EpsilonLabel:
		$EpsilonHBox/EpsilonLabel.text = "Epsilon: %.2f" % value

func _on_select_atlas_pressed():
	$FileDialog.popup()

func _on_file_selected(path: String):
	atlas_path = path
	atlas_image = Image.load_from_file(path)
	if atlas_image:
		atlas_texture = ImageTexture.create_from_image(atlas_image)
		$TextureRect.texture = atlas_texture
		$TextureRect.custom_minimum_size = atlas_image.get_size()
		print("\n✅ Atlas: ", path)
		seeds.clear()
		$TextureRect.queue_redraw()
	else:
		push_error("Error cargando: " + path)

func _on_add_seed_pressed():
	var option_button = $PartNameHBox/PartNameOptionButton
	if option_button.get_selected_id() == -1:
		push_error("Selecciona una parte")
		return
	
	current_part_name = option_button.get_item_text(option_button.get_selected_id())
	adding_seeds = true
	print("\n📍 Agregar: ", current_part_name)

func _on_texture_gui_input(event):
	if adding_seeds and event is InputEventMouseButton and event.pressed:
		if not atlas_image:
			push_error("No hay atlas cargado.")
			adding_seeds = false
			return

		var rect = $TextureRect
		var tex_size = atlas_image.get_size()
		var rect_size = rect.get_size()
		if tex_size.x == 0 or tex_size.y == 0:
			push_error("Atlas vacío o inválido.")
			return

		# Calculamos proporciones (Mapeo de la UI al Atlas)
		var texture_aspect = float(tex_size.x) / tex_size.y
		var rect_aspect = float(rect_size.x) / rect_size.y

		var draw_size = Vector2()
		var offset = Vector2()

		# Ajuste según el modo “Keep Aspect Centered”
		if texture_aspect > rect_aspect:
			draw_size.x = rect_size.x
			draw_size.y = rect_size.x / texture_aspect
			offset.y = (rect_size.y - draw_size.y) / 2.0
		else:
			draw_size.y = rect_size.y
			draw_size.x = rect_size.y * texture_aspect
			offset.x = (rect_size.x - draw_size.x) / 2.0

		# Coordenadas del clic en el espacio del atlas (píxeles)
		var pos = event.position - offset
		
		# Verificación de límites (tolerancia de 1px)
		if pos.x < -1 or pos.y < -1 or pos.x > draw_size.x + 1 or pos.y > draw_size.y + 1:
			push_warning("Clic fuera de la imagen visible.")
			return

		var img_pos = pos / draw_size * Vector2(tex_size)
		var seed = Vector2i(int(img_pos.x), int(img_pos.y))

		# Clamp de seguridad
		seed.x = clamp(seed.x, 0, tex_size.x - 1)
		seed.y = clamp(seed.y, 0, tex_size.y - 1)

		if seeds.has(current_part_name):
			print("  Reemplazando semilla anterior.")

		seeds[current_part_name] = seed
		print("  ✅ %s → %s" % [current_part_name, seed])
		adding_seeds = false
		$TextureRect.queue_redraw()

func _on_texture_rect_draw():
	var rect = $TextureRect
	if not atlas_image:
		return

	var tex_size = atlas_image.get_size()
	var rect_size = rect.get_size()
	var texture_aspect = tex_size.x / tex_size.y
	var rect_aspect = rect_size.x / rect_size.y

	var draw_size = Vector2()
	var offset = Vector2()

	if texture_aspect > rect_aspect:
		draw_size.x = rect_size.x
		draw_size.y = rect_size.x / texture_aspect
		offset.y = (rect_size.y - draw_size.y) / 2.0
	else:
		draw_size.y = rect_size.y
		draw_size.x = rect_size.y * texture_aspect
		offset.x = (rect_size.x - draw_size.x) / 2.0

	for part_name in seeds.keys():
		var pos = Vector2(seeds[part_name]) / Vector2(tex_size) * draw_size + offset
		rect.draw_circle(pos, 4.0, Color.RED)

		var font = get_theme_font("font", "Label")
		var size = get_theme_font_size("font_size", "Label")
		var text_pos = pos + Vector2(8, 5)
		rect.draw_string(font, text_pos, part_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)

func _on_generate_pressed():
	if not atlas_image:
		push_error("Carga un atlas primero")
		return
	
	if seeds.is_empty():
		push_error("Agrega puntos semilla")
		return
	
	# ======================================================================
	# LLAMADA AL MÓDULO MODULARIZADO
	# ======================================================================
	var polygons = generator.generate_body_part_polygons(atlas_image, atlas_texture, seeds, polygon_epsilon)
	
	if polygons.is_empty():
		push_error("No se generaron polígonos")
		return
	
	print("\n📦 Añadiendo a escena...")
	
	var root = get_tree().edited_scene_root
	if not is_instance_valid(root):
		push_error("No hay una escena abierta para editar.")
		return
		
	var existing = root.find_child("GeneratedRigRoot")
	
	if existing:
		existing.queue_free()
		# Usamos yield en Godot 4.x para esperar la liberación
		await get_tree().process_frame
	
	var rig_root = Node2D.new()
	rig_root.name = "GeneratedRigRoot"
	root.add_child(rig_root)
	rig_root.owner = root # Importante para guardar en la escena
	
	for poly in polygons:
		rig_root.add_child(poly)
		poly.owner = root # Importante para guardar en la escena
	
	print("✅ Generación completa: %d partes" % polygons.size())
