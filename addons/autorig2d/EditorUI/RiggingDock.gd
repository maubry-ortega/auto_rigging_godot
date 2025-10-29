@tool
extends VBoxContainer

# Instancia del módulo de lógica
const PolygonGenerator = preload("uid://dcc5an3ptehth")
var generator = PolygonGenerator.new()

# Instancia del manager de partes
const PartListManager = preload("res://addons/autorig2d/core/PartListManager.gd")
var part_manager = PartListManager.new()

# NUEVOS MÓDULOS
const HumanoidBuilder = preload("res://addons/autorig2d/core/HumanoidBuilder.gd")
const WeightingEngine = preload("res://addons/autorig2d/core/WeightingEngine.gd")

# Variables de estado
var atlas_path: String = ""
var atlas_image: Image
var atlas_texture: ImageTexture
var seeds: Dictionary = {}

var adding_seeds: bool = false
var current_part_name: String = ""

# VARIABLE DE CONTROL DE DETALLE DEL POLÍGONO (Epsilon RDP)
var polygon_epsilon: float = 0.1

# Diálogo para añadir nuevas partes
var _new_part_dialog: AcceptDialog = null

# ==============================================================================
## Funciones de UI y Conexión
# ==============================================================================

func _ready():
	# CONEXIONES
	$FileDialog.file_selected.connect(_on_file_selected)
	
	# Botones en $HBoxContainer
	$HBoxContainer/SelectAtlasButton.pressed.connect(_on_select_atlas_pressed)
	$HBoxContainer/GenerateButton.pressed.connect(_on_generate_pressed)
	$HBoxContainer/AddSeedButton.pressed.connect(_on_add_seed_pressed)
	
	# Botón en $PartNameHBox
	$PartNameHBox/AddNewPartButton.pressed.connect(_on_add_new_part_pressed)
	
	# Área de dibujo
	$TextureRect.gui_input.connect(_on_texture_gui_input)
	$TextureRect.draw.connect(_on_texture_rect_draw)
	
	# Configuración del Slider
	var epsilon_slider = $EpsilonHBox/EpsilonSlider
	if epsilon_slider:
		epsilon_slider.value = polygon_epsilon
		epsilon_slider.value_changed.connect(_on_epsilon_slider_visual_update)
		epsilon_slider.value_changed.connect(_on_epsilon_slider_changed)
		_on_epsilon_slider_visual_update(polygon_epsilon)
	
	# Conectar señal del part_manager
	part_manager.part_name_added.connect(_on_part_name_added)
	
	# Llenar OptionButton con las partes actuales
	_update_part_option_button()
	
	# Crear el diálogo de nueva parte
	_create_new_part_dialog()

func _update_part_option_button():
	var option_button = $PartNameHBox/PartNameOptionButton
	option_button.clear()
	for part_name in part_manager.get_part_names():
		option_button.add_item(part_name)

func _on_part_name_added(new_name: String, all_parts: Array):
	_update_part_option_button()
	
	# Seleccionar automáticamente la nueva parte
	var option_button = $PartNameHBox/PartNameOptionButton
	for i in range(option_button.get_item_count()):
		if option_button.get_item_text(i) == new_name:
			option_button.select(i)
			break

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
	print("\n📍 Agregar semilla para: ", current_part_name)

# ------------------------------------------------------------------------------
## Lógica Dinámica de Partes
# ------------------------------------------------------------------------------

func _create_new_part_dialog():
	_new_part_dialog = AcceptDialog.new()
	_new_part_dialog.title = "Añadir Nueva Parte"
	
	# Contenedor para el LineEdit y el texto
	var container = VBoxContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = "Introduce el nombre (snake_case recomendado):"
	container.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.name = "NewPartNameEdit"
	line_edit.placeholder_text = "ej: ala_izquierda, tercer_ojo"
	line_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Conectar el evento de tecla Enter
	line_edit.text_submitted.connect(_on_new_part_text_submitted)
	
	container.add_child(line_edit)
	
	_new_part_dialog.add_child(container)
	_new_part_dialog.min_size = Vector2(350, 120)
	
	_new_part_dialog.confirmed.connect(_on_new_part_confirmed)
	
	# Añade el diálogo al nodo base del plugin
	add_child(_new_part_dialog)

func _on_add_new_part_pressed():
	var line_edit = find_child("NewPartNameEdit", true, false)
	if line_edit:
		line_edit.text = ""
		line_edit.grab_focus()
	
	_new_part_dialog.popup_centered()

func _on_new_part_text_submitted(new_text: String):
	_on_new_part_confirmed()

func _on_new_part_confirmed():
	var line_edit = find_child("NewPartNameEdit", true, false)
	if not line_edit: 
		return
	
	var new_name = line_edit.text.strip_edges().to_lower().replace(" ", "_")
	line_edit.text = ""
	
	if new_name.is_empty():
		push_warning("El nombre de la parte no puede estar vacío.")
		return
	
	# Usar el manager para añadir la nueva parte
	part_manager.add_part_name(new_name)

# ------------------------------------------------------------------------------
## Lógica de Interacción con TextureRect (Mapeo)
# ------------------------------------------------------------------------------

func _get_texture_mapping_data():
	var rect = $TextureRect
	if not atlas_image:
		return null
		
	var tex_size = atlas_image.get_size()
	var rect_size = rect.get_size()
	var texture_aspect = float(tex_size.x) / tex_size.y
	var rect_aspect = float(rect_size.x) / rect_size.y

	var draw_size = Vector2()
	var offset = Vector2()

	# Ajuste según el modo "Keep Aspect Centered"
	if texture_aspect > rect_aspect:
		draw_size.x = rect_size.x
		draw_size.y = rect_size.x / texture_aspect
		offset.y = (rect_size.y - draw_size.y) / 2.0
	else:
		draw_size.y = rect_size.y
		draw_size.x = rect_size.y * texture_aspect
		offset.x = (rect_size.x - draw_size.x) / 2.0
		
	return {
		"tex_size": tex_size,
		"draw_size": draw_size,
		"offset": offset
	}

func _on_texture_gui_input(event):
	if adding_seeds and event is InputEventMouseButton and event.pressed:
		if not atlas_image:
			push_error("No hay atlas cargado.")
			adding_seeds = false
			return

		var data = _get_texture_mapping_data()
		if not data:
			return
			
		var tex_size = data.tex_size
		var draw_size = data.draw_size
		var offset = data.offset
		
		if tex_size.x == 0 or tex_size.y == 0:
			push_error("Atlas vacío o inválido.")
			return

		var pos = event.position - offset
		
		if pos.x < -1 or pos.y < -1 or pos.x > draw_size.x + 1 or pos.y > draw_size.y + 1:
			push_warning("Clic fuera de la imagen visible.")
			return

		var img_pos = pos / draw_size * Vector2(tex_size)
		var seed = Vector2i(int(img_pos.x), int(img_pos.y))

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

	var data = _get_texture_mapping_data()
	if not data:
		return
		
	var tex_size = data.tex_size
	var draw_size = data.draw_size
	var offset = data.offset

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
	
	# LLAMADA AL MÓDULO MODULARIZADO
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
		await get_tree().process_frame
	
	var rig_root = Node2D.new()
	rig_root.name = "GeneratedRigRoot"
	root.add_child(rig_root)
	rig_root.owner = root
	
	# CORREGIDO: Crear esqueleto con jerarquía correcta
	print("\n🦴 Construyendo esqueleto...")
	var humanoid_builder = HumanoidBuilder.new()
	var skeleton = humanoid_builder.build_complete_rig(seeds, atlas_image.get_size())
	
	# Añadir esqueleto como nodo INDEPENDIENTE
	rig_root.add_child(skeleton)
	skeleton.owner = root
	
	# CORREGIDO: Asignar ownership a TODOS los huesos después de añadir al árbol
	_assign_bone_ownership(skeleton, root)
	
	# CORREGIDO: Configurar rutas de skeleton en los polígonos ANTES de añadirlos
	for poly in polygons:
		# Configurar la ruta del skeleton antes de añadir al árbol
		poly.skeleton = NodePath("../" + skeleton.name)
		rig_root.add_child(poly)
		poly.owner = root
	
	# Asignar pesos básicos a los polígonos
	print("\n⚖️ Asignando pesos...")
	var weighting_engine = WeightingEngine.new()
	weighting_engine.assign_weights_to_polygons(polygons, skeleton)
	
	print("✅ Generación completa: %d partes con esqueleto básico" % polygons.size())
	
	# Crear AnimationPlayer básico para pruebas
	_create_test_animation_player(rig_root, skeleton)
	
	# Mostrar información de debug
	_debug_rig_info(rig_root, skeleton, polygons)

# NUEVA FUNCIÓN PARA ASIGNAR OWNERSHIP
func _assign_bone_ownership(node: Node, owner_node: Node):
	for child in node.get_children():
		child.owner = owner_node
		_assign_bone_ownership(child, owner_node)
func _create_test_animation_player(rig_root: Node2D, skeleton: Skeleton2D):
	# Crear un AnimationPlayer básico para probar la deformación
	var anim_player = AnimationPlayer.new()
	anim_player.name = "TestAnimations"
	rig_root.add_child(anim_player)
	anim_player.owner = rig_root.owner
	
	# Crear animación simple de prueba
	var animation = Animation.new()
	animation.length = 2.0
	animation.loop_mode = Animation.LOOP_LINEAR
	
	# Añadir tracks para rotar brazos
	var bones = _collect_all_bones(skeleton)
	for bone in bones:
		if "arm" in bone.name and not "end" in bone.name and not "tip" in bone.name:
			var track_idx = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track_idx, str(skeleton.get_path_to(bone)) + ":rotation")
			
			# Keyframes para rotación
			animation.track_insert_key(track_idx, 0.0, 0.0)
			animation.track_insert_key(track_idx, 1.0, deg_to_rad(45))  # 45 grados
			animation.track_insert_key(track_idx, 2.0, 0.0)
	
	# CORRECCIÓN: En Godot 4.x se usa add_animation_library en lugar de add_animation
	var anim_library = AnimationLibrary.new()
	anim_library.add_animation("test_rotation", animation)
	anim_player.add_animation_library("", anim_library)
	anim_player.current_animation = "test_rotation"
	
	print("🎬 AnimationPlayer creado con animación de prueba 'test_rotation'")

func _debug_rig_info(rig_root: Node2D, skeleton: Skeleton2D, polygons: Array):
	print("\n🔍 Información del Rig Generado:")
	print("  Nodo raíz: ", rig_root.name)
	print("  Esqueleto: ", skeleton.name)
	print("  Polígonos: ", polygons.size())
	
	print("\n📋 Estructura del Esqueleto:")
	var bones = _collect_all_bones(skeleton)
	for bone in bones:
		var parent_name = bone.get_parent().name if bone.get_parent() else "ROOT"
		print("  🦴 %s → Padre: %s | Pos: %s" % [bone.name, parent_name, bone.position])
	
	print("\n📋 Polígonos generados:")
	for poly in polygons:
		var has_skeleton = poly.skeleton != NodePath()
		var skeleton_path = poly.skeleton if has_skeleton else "NONE"
		print("  📐 %s | Skeleton: %s | Ruta: %s | Vértices: %d" % [poly.name, has_skeleton, skeleton_path, poly.polygon.size()])

func _collect_all_bones(node: Node) -> Array:
	var bones = []
	if node is Bone2D:
		bones.append(node)
	
	for child in node.get_children():
		bones.append_array(_collect_all_bones(child))
	
	return bones
