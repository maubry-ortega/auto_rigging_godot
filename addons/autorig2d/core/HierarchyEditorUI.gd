@tool
extends AcceptDialog
class_name HierarchyEditorUI

signal hierarchy_changed(hierarchy_name: String)

# Referencias a nodos de la UI
@onready var hierarchy_tree: Tree = $VBoxContainer/HierarchyContainer/HierarchyTree
@onready var hierarchy_name_edit: LineEdit = $VBoxContainer/ControlsContainer/HierarchyNameEdit
@onready var create_button: Button = $VBoxContainer/ControlsContainer/CreateButton
@onready var save_button: Button = $VBoxContainer/ControlsContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/ControlsContainer/LoadButton
@onready var add_bone_button: Button = $VBoxContainer/BoneControlsContainer/AddBoneButton
@onready var remove_bone_button: Button = $VBoxContainer/BoneControlsContainer/RemoveBoneButton
@onready var bone_name_edit: LineEdit = $VBoxContainer/BoneControlsContainer/BoneNameEdit
@onready var parent_combo: OptionButton = $VBoxContainer/BoneControlsContainer/ParentCombo
@onready var file_dialog: FileDialog = $FileDialog

# Referencia al constructor de jerarquías
var hierarchy_builder: SkeletonHierarchyBuilder

# Estado actual
var current_hierarchy_name: String = ""
var selected_bone_name: String = ""

func _ready():
	# Conectar señales
	create_button.pressed.connect(_on_create_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	add_bone_button.pressed.connect(_on_add_bone_button_pressed)
	remove_bone_button.pressed.connect(_on_remove_bone_button_pressed)
	hierarchy_tree.item_selected.connect(_on_tree_item_selected)
	hierarchy_tree.button_clicked.connect(_on_tree_button_clicked)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)

func set_hierarchy_builder(builder: SkeletonHierarchyBuilder):
	hierarchy_builder = builder
	print("HierarchyEditorUI: hierarchy_builder is ", hierarchy_builder)
	_update_hierarchy_list()
	_update_hierarchy_tree()

# Actualizar la lista de jerarquías disponibles
func _update_hierarchy_list():
	var hierarchies = hierarchy_builder.get_available_hierarchies()
	
	# Actualizar el combo de padres
	parent_combo.clear()
	parent_combo.add_item("(Raíz)")
	
	# Si hay una jerarquía actual, añadir sus huesos al combo de padres
	if not current_hierarchy_name.is_empty():
		var hierarchy = hierarchy_builder.get_hierarchy(current_hierarchy_name)
		for bone_name in hierarchy.keys():
			parent_combo.add_item(bone_name)

# Actualizar el árbol de jerarquías
func _update_hierarchy_tree():
	hierarchy_tree.clear()
	hierarchy_tree.set_column_titles_visible(true)
	hierarchy_tree.set_column_title(0, "Jerarquía de Huesos")
	
	if current_hierarchy_name.is_empty():
		return
	
	var hierarchy = hierarchy_builder.get_hierarchy(current_hierarchy_name)
	if hierarchy.is_empty():
		return
	
	# Crear el árbol de jerarquías
	var root_items = {}
	
	# Primero, encontrar todos los huesos raíz (sin padre)
	for bone_name in hierarchy.keys():
		var bone = hierarchy[bone_name]
		if bone.parent.is_empty():
			var item = hierarchy_tree.create_item()
			item.set_text(0, bone_name)
			item.set_metadata(0, bone_name)
			root_items[bone_name] = item
	
	# Luego, añadir el resto de los huesos recursivamente
	for bone_name in hierarchy.keys():
		if not root_items.has(bone_name):
			_add_bone_to_tree(hierarchy, bone_name, root_items)
	
	# Expandir todos los nodos
	_expand_all_items(hierarchy_tree.get_root())

# Añadir un hueso al árbol de forma recursiva
func _add_bone_to_tree(hierarchy: Dictionary, bone_name: String, items: Dictionary):
	var bone = hierarchy[bone_name]
	var parent_item = null
	
	# Buscar el padre en los items existentes
	if not bone.parent.is_empty() and items.has(bone.parent):
		parent_item = items[bone.parent]
	
	# Crear el item para este hueso
	var item = hierarchy_tree.create_item(parent_item)
	item.set_text(0, bone_name)
	item.set_metadata(0, bone_name)
	
	# Guardar el item para que los hijos puedan encontrarlo
	items[bone_name] = item
	
	# Añadir botones para eliminar y cambiar padre
	item.add_button(0, get_theme_icon("Remove", "EditorIcons"))
	item.add_button(0, get_theme_icon("ArrowRight", "EditorIcons"))
	
	# Añadir recursivamente los hijos
	for child_name in bone.children:
		_add_bone_to_tree(hierarchy, child_name, items)

# Expandir todos los items del árbol
func _expand_all_items(item: TreeItem):
	if not item:
		return
	
	item.set_collapsed(false)
	
	var child = item.get_first_child()
	while child:
		_expand_all_items(child)
		child = child.get_next_in_tree()

# Manejar la selección de un item en el árbol
func _on_tree_item_selected():
	var item = hierarchy_tree.get_selected()
	if not item:
		selected_bone_name = ""
		return
	
	selected_bone_name = item.get_metadata(0)
	bone_name_edit.text = selected_bone_name
	
	# Seleccionar el padre en el combo
	var hierarchy = hierarchy_builder.get_hierarchy(current_hierarchy_name)
	if hierarchy.has(selected_bone_name):
		var parent_name = hierarchy[selected_bone_name].parent
		for i in range(parent_combo.get_item_count()):
			if parent_combo.get_item_text(i) == parent_name:
				parent_combo.selected = i
				break

# Manejar clics en botones del árbol
func _on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int):
	var bone_name = item.get_metadata(0)
	
	if id == 0:  # Botón de eliminar
		_remove_bone(bone_name)
	elif id == 1:  # Botón de cambiar padre
		# Mostrar diálogo para seleccionar nuevo padre
		_show_parent_selector(bone_name)

# Eliminar un hueso
func _remove_bone(bone_name: String):
	if bone_name.is_empty():
		return
	
	if hierarchy_builder.remove_bone_from_current_hierarchy(bone_name):
		_update_hierarchy_tree()
		_update_hierarchy_list()
		hierarchy_changed.emit(current_hierarchy_name)

# Mostrar selector de padre
func _show_parent_selector(bone_name: String):
	# Aquí podrías mostrar un diálogo personalizado para seleccionar el nuevo padre
	# Por simplicidad, usaremos el combo existente
	parent_combo.grab_focus()

# Manejar el botón de crear jerarquía
func _on_create_button_pressed():
	var name = hierarchy_name_edit.text.strip_edges()
	if name.is_empty():
		push_error("El nombre de la jerarquía no puede estar vacío")
		return
	
	if hierarchy_builder.create_custom_hierarchy(name):
		current_hierarchy_name = name
		_update_hierarchy_tree()
		_update_hierarchy_list()
		hierarchy_changed.emit(current_hierarchy_name)
	else:
		# If creation failed, ensure current_hierarchy_name is not set to a non-existent hierarchy
		# or handle the error appropriately, e.g., by showing a message.
		push_error("Failed to create hierarchy: " + name + ". It might already exist.")

# Manejar el botón de guardar jerarquía
func _on_save_button_pressed():
	if current_hierarchy_name.is_empty():
		push_error("No hay una jerarquía seleccionada")
		return
	
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered()

# Manejar el botón de cargar jerarquía
func _on_load_button_pressed():
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered()

# Manejar la selección de archivo
func _on_file_dialog_file_selected(path: String):
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		if hierarchy_builder.save_current_hierarchy_to_file(path):
			print("Jerarquía guardada correctamente")
	else:
		if hierarchy_builder.load_hierarchy_from_file(path):
			# Obtener el nombre de la jerarquía cargada
			var file = FileAccess.open(path, FileAccess.READ)
			if file == null:
				push_error("Could not open file to read hierarchy name.")
				return
			var json_string = file.get_as_text()
			file.close()
			
			var data = JSON.parse_string(json_string)
			if data == null:
				push_error("Could not parse JSON to get hierarchy name.")
				return
			
			current_hierarchy_name = data.name
			hierarchy_name_edit.text = current_hierarchy_name
			
			_update_hierarchy_tree()
			_update_hierarchy_list()
			hierarchy_changed.emit(current_hierarchy_name)

# Manejar el botón de añadir hueso
func _on_add_bone_button_pressed():
	var bone_name = bone_name_edit.text.strip_edges()
	if bone_name.is_empty():
		push_error("El nombre del hueso no puede estar vacío")
		return
	
	var parent_name = ""
	if parent_combo.selected > 0:
		parent_name = parent_combo.get_item_text(parent_combo.selected)
	
	if hierarchy_builder.add_bone_to_current_hierarchy(bone_name, parent_name):
		_update_hierarchy_tree()
		_update_hierarchy_list()
		hierarchy_changed.emit(current_hierarchy_name)

# Manejar el botón de eliminar hueso
func _on_remove_bone_button_pressed():
	_remove_bone(selected_bone_name)

# Establecer la jerarquía actual
func set_current_hierarchy(name: String):
	if not hierarchy_builder.get_available_hierarchies().has(name):
		push_error("No existe la jerarquía especificada")
		return
	
	current_hierarchy_name = name
	hierarchy_name_edit.text = current_hierarchy_name
	
	_update_hierarchy_tree()
	_update_hierarchy_list()
