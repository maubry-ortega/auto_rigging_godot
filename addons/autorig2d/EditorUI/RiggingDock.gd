@tool
extends PanelContainer

# Módulos principales
const PolygonGenerator = preload("uid://dcc5an3ptehth")
const PartListManager  = preload("res://addons/autorig2d/core/PartListManager.gd")
const HumanoidBuilder = preload("uid://h5xmctj7pxg6")


# Nueva lógica separada
const AtlasLoader = preload("uid://cosxar5jkhmk7")
const SeedManager = preload("uid://cq7neflhr0lsd")
const RigGenerator = preload("uid://k7dfof5c0asq")
const PartDialogManager = preload("uid://c0rs41p7wmh1u")
const CoordinateManager = preload("res://addons/autorig2d/core/CoordinateManager.gd")
const RiggingState = preload("res://addons/autorig2d/core/RiggingState.gd")

# Nuevas clases optimizadas y de jerarquía
const SkeletonHierarchyBuilder = preload("res://addons/autorig2d/core/SkeletonHierarchyBuilder.gd")
const OptimizedWeightingEngine = preload("res://addons/autorig2d/core/OptimizedWeightingEngine.gd")
const OptimizedPolygonGenerator = preload("res://addons/autorig2d/core/OptimizedPolygonGenerator.gd")
const GenericRigBuilder = preload("res://addons/autorig2d/core/GenericRigBuilder.gd")
const HierarchyEditorUI_Scene = preload("res://addons/autorig2d/core/HierarchyEditorUI.tscn")

# Instancias
var generator = PolygonGenerator.new()
var part_manager = PartListManager.new()
var atlas_loader = AtlasLoader.new()
var seed_manager = SeedManager.new()
var rig_generator = RigGenerator.new()
var part_dialog = PartDialogManager.new()
var coordinate_manager = CoordinateManager.new()
var _rigging_state = RiggingState.new() 

# Nuevas instancias optimizadas
var hierarchy_builder = SkeletonHierarchyBuilder.new()
var optimized_weighting_engine = OptimizedWeightingEngine.new()
var optimized_polygon_generator = OptimizedPolygonGenerator.new(hierarchy_builder)
var generic_rig_builder = GenericRigBuilder.new(hierarchy_builder)
var hierarchy_editor_ui = null

# Estado
var _new_part_dialog
var _part_option_button: OptionButton 
var _hierarchy_option_button: OptionButton
var _use_optimized_engines: bool = true

func _ready():
    await get_tree().process_frame

    # CORREGIDO: Inicializar _rigging_state primero y verificar que no sea null
    if _rigging_state == null:
        _rigging_state = RiggingState.new()
    
    # CORREGIDO: Inicializar arrays si no existen
    if _rigging_state.part_names == null:
        _rigging_state.part_names = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"]  # Valores por defecto
    if _rigging_state.part_data == null:
        _rigging_state.part_data = {}

    # CORREGIDO: Usar solo ParentOptionButton para todo
    _part_option_button = $VBoxContainer/PartNameHBox/ParentOptionButton

    # Limpiar y poblar con las partes actuales
    _part_option_button.clear()
    for part_name in _rigging_state.part_names:
        _part_option_button.add_item(part_name)

    if _part_option_button.item_count > 0:
        _part_option_button.select(0)
        _rigging_state.current_part_name = _part_option_button.get_item_text(0)
        print("Default selected part: ", _rigging_state.current_part_name)
    
    # Añadir UI para selección de jerarquía
    _setup_hierarchy_ui()
    
    # Inicializar módulos
    part_manager.initialize(_rigging_state)
    part_dialog.initialize_dialog(self, _rigging_state, part_manager)
    atlas_loader.initialize(_rigging_state, coordinate_manager)
    seed_manager.initialize(_rigging_state, coordinate_manager)
    
    # Inicializar rig_generator con el constructor apropiado según la configuración
    var builder_to_use = generic_rig_builder
    var weighting_engine_to_use = optimized_weighting_engine
    var generator_to_use = optimized_polygon_generator
    
    rig_generator.initialize(_rigging_state, generator_to_use, builder_to_use, weighting_engine_to_use, coordinate_manager, hierarchy_builder)
    add_child(rig_generator)

    # Conexiones UI
    var file_dialog = $VBoxContainer/FileDialog
    if file_dialog:
        file_dialog.file_selected.connect(self._on_file_selected)

    var select_atlas_button = $VBoxContainer/HBoxContainer/SelectAtlasButton
    if select_atlas_button and file_dialog:
        select_atlas_button.pressed.connect(file_dialog.popup)
    
    var add_seed_button = $VBoxContainer/HBoxContainer/AddSeedButton
    if add_seed_button:
        add_seed_button.pressed.connect(seed_manager.on_add_seed_pressed)

    var generate_preview_button = $VBoxContainer/GenerationHBox/GeneratePreviewButton
    if generate_preview_button:
        generate_preview_button.pressed.connect(rig_generator.on_generate_preview_pressed)
    else:
        printerr("GeneratePreviewButton not found in RiggingDock scene.")

    var generate_weights_button = $VBoxContainer/GenerationHBox/GenerateWeightsButton
    if generate_weights_button:
        generate_weights_button.pressed.connect(rig_generator.on_generate_weights_pressed)
    else:
        printerr("GenerateWeightsButton not found in RiggingDock scene.")

    var add_new_part_button = $VBoxContainer/PartNameHBox/AddNewPartButton
    if add_new_part_button:
        add_new_part_button.pressed.connect(part_dialog.on_add_new_part_pressed)

    if $VBoxContainer/TextureRect:
        $VBoxContainer/TextureRect.gui_input.connect(seed_manager.on_texture_gui_input)
        $VBoxContainer/TextureRect.draw.connect(seed_manager.on_texture_rect_draw.bind($VBoxContainer/TextureRect))
        seed_manager.seeds_updated.connect(self._on_seeds_updated)

    if $VBoxContainer/EpsilonHBox/EpsilonSlider:
        var slider = $VBoxContainer/EpsilonHBox/EpsilonSlider
        slider.value = _rigging_state.polygon_epsilon
        slider.value_changed.connect(func(value): _rigging_state.polygon_epsilon = value)
        slider.value_changed.connect(part_dialog.on_epsilon_slider_visual_update.bind($VBoxContainer/EpsilonHBox/EpsilonLabel))
        part_dialog.on_epsilon_slider_visual_update(_rigging_state.polygon_epsilon, $VBoxContainer/EpsilonHBox/EpsilonLabel)
        
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

# Configurar la UI para la selección y edición de jerarquías
func _setup_hierarchy_ui():
    # Crear contenedor para la UI de jerarquía
    var hierarchy_container = HBoxContainer.new()
    hierarchy_container.name = "HierarchyHBox"
    
    # Etiqueta para la selección de jerarquía
    var hierarchy_label = Label.new()
    hierarchy_label.text = "Jerarquía:"
    hierarchy_container.add_child(hierarchy_label)
    
    # OptionButton para seleccionar jerarquía
    _hierarchy_option_button = OptionButton.new()
    _hierarchy_option_button.name = "HierarchyOptionButton"
    # CORREGIDO: Cambiar __hierarchy_option_button por _hierarchy_option_button
    hierarchy_container.add_child(_hierarchy_option_button)
    
    # Botón para editar jerarquía
    var edit_hierarchy_button = Button.new()
    edit_hierarchy_button.text = "Editar"
    edit_hierarchy_button.name = "EditHierarchyButton"
    edit_hierarchy_button.pressed.connect(_on_edit_hierarchy_pressed)
    hierarchy_container.add_child(edit_hierarchy_button)
    
    # Checkbox para usar motores optimizados
    var optimized_checkbox = CheckBox.new()
    optimized_checkbox.text = "Usar motores optimizados"
    optimized_checkbox.name = "OptimizedCheckbox"
    optimized_checkbox.button_pressed = _use_optimized_engines
    optimized_checkbox.toggled.connect(_on_optimized_toggled)
    hierarchy_container.add_child(optimized_checkbox)
    
    # Añadir el contenedor al VBox principal (después del contenedor de partes)
    var part_container = $VBoxContainer/PartNameHBox
    $VBoxContainer.add_child(hierarchy_container)
    $VBoxContainer.move_child(hierarchy_container, part_container.get_index() + 1)
    
    # Poblar el OptionButton con jerarquías disponibles
    _update_hierarchy_list()
    
    # Conectar la señal de selección
    _hierarchy_option_button.item_selected.connect(_on_hierarchy_selected)
    
    # Seleccionar la jerarquía actual
    var current_hierarchy = _rigging_state.get_current_hierarchy()
    var index = _get_option_button_item_index_by_text(_hierarchy_option_button, current_hierarchy)
    if index != -1:
        _hierarchy_option_button.select(index)

# Actualizar la lista de jerarquías disponibles
func _update_hierarchy_list():
    if not _hierarchy_option_button:
        return
        
    _hierarchy_option_button.clear()
    var hierarchies = hierarchy_builder.get_available_hierarchies()
    
    for hierarchy_name in hierarchies:
        _hierarchy_option_button.add_item(hierarchy_name)

# Manejar la selección de una jerarquía
func _on_hierarchy_selected(index: int):
    var hierarchy_name = _hierarchy_option_button.get_item_text(index)
    
    # Actualizar el builder con la jerarquía seleccionada
    hierarchy_builder.current_hierarchy_name = hierarchy_name
    
    # Actualizar el estado global con la jerarquía del builder
    _rigging_state.current_hierarchy_name = hierarchy_builder.current_hierarchy_name
    
    # Actualizar el rig_generator para usar la nueva jerarquía
    if rig_generator:
        rig_generator.set_current_hierarchy(hierarchy_name)
    
    # Si el editor de jerarquías está abierto, actualizarlo también
    if is_instance_valid(hierarchy_editor_ui) and hierarchy_editor_ui.visible:
        hierarchy_editor_ui.set_current_hierarchy(hierarchy_name)
    
    print("Jerarquía seleccionada: ", hierarchy_name)

# Manejar el botón de editar jerarquía
func _on_edit_hierarchy_pressed():
    # Crear y mostrar el diálogo de edición de jerarquía
    if not is_instance_valid(hierarchy_editor_ui):
        hierarchy_editor_ui = HierarchyEditorUI_Scene.instantiate()
        add_child(hierarchy_editor_ui)
        
        # Pasar la instancia de hierarchy_builder
        hierarchy_editor_ui.set_hierarchy_builder(hierarchy_builder)
        
        # Conectar señales
        hierarchy_editor_ui.connect("hierarchy_changed", Callable(self, "_on_hierarchy_changed"))
        # Esperar a que el nodo esté listo en el árbol de escenas del editor
        await get_tree().process_frame
        await get_tree().process_frame
    
    # Establecer la jerarquía actual
    var current_hierarchy = _rigging_state.get_current_hierarchy()
    hierarchy_editor_ui.set_current_hierarchy(current_hierarchy)
    
    # Mostrar el diálogo como ventana emergente
    hierarchy_editor_ui.popup_centered(Vector2i(600, 400))

# Manejar cambios en la jerarquía
func _on_hierarchy_changed(hierarchy_name: String):
    # Actualizar la lista de jerarquías
    _update_hierarchy_list()
    
    # Seleccionar la jerarquía modificada
    # Desconectar temporalmente para evitar la llamada recursiva a _on_hierarchy_selected
    _hierarchy_option_button.item_selected.disconnect(_on_hierarchy_selected)
    var index = _get_option_button_item_index_by_text(_hierarchy_option_button, hierarchy_name)
    if index != -1:
        _hierarchy_option_button.select(index)
    _hierarchy_option_button.item_selected.connect(_on_hierarchy_selected)

# Manejar el checkbox de motores optimizados
func _on_optimized_toggled(pressed: bool):
    _use_optimized_engines = pressed
    
    # Reinicializar rig_generator con las nuevas configuraciones
    if rig_generator:
        var builder_to_use = generic_rig_builder
        var weighting_engine_to_use = optimized_weighting_engine
        var generator_to_use = optimized_polygon_generator
        
        rig_generator.initialize(_rigging_state, generator_to_use, builder_to_use, weighting_engine_to_use, coordinate_manager, hierarchy_builder)
    
    print("Motores optimizados: ", "Activados" if _use_optimized_engines else "Desactivados")

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
    $VBoxContainer/TextureRect.queue_redraw()

func _on_file_selected(path: String):
    var result = atlas_loader.on_file_selected(path, $VBoxContainer/TextureRect)
    if result.texture:
        $VBoxContainer/TextureRect.texture = result.texture
        $VBoxContainer/TextureRect.queue_redraw()

func _get_option_button_item_index_by_text(option_button: OptionButton, target_text: String) -> int:
    for i in range(option_button.get_item_count()):
        if option_button.get_item_text(i) == target_text:
            return i
    return -1 # Return -1 if item is not found