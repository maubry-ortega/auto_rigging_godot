extends Node

var _rigging_state: RiggingStateManager
var _part_manager: PartListManager
var _new_part_dialog: AcceptDialog
var _ui_node: Control # Keep a reference to the UI node to add the dialog

func initialize_dialog(ui_node: Control, rigging_state: RiggingStateManager, part_manager: PartListManager):
	_ui_node = ui_node
	_rigging_state = rigging_state
	_part_manager = part_manager
	_create_new_part_dialog()

func on_add_new_part_pressed():
	# Verificar que las dependencias estén inicializadas
	if _new_part_dialog == null:
		push_error("PartDialogManager: _new_part_dialog no está inicializado")
		return
		
	var edit = _new_part_dialog.find_child("NewPartNameEdit", true, false)
	if edit:
		edit.text = ""
		edit.grab_focus()
	_new_part_dialog.popup_centered()
	print("PartDialogManager: New part dialog popped up.")

func _create_new_part_dialog():
	_new_part_dialog = AcceptDialog.new()
	_new_part_dialog.title = "Añadir Nueva Parte"
	
	var container = VBoxContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = "Introduce el nombre (snake_case recomendado):"
	container.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.name = "NewPartNameEdit"
	line_edit.placeholder_text = "ej: left_arm, tail_tip"
	line_edit.text_submitted.connect(_on_new_part_text_submitted)
	container.add_child(line_edit)
	
	_new_part_dialog.add_child(container)
	_new_part_dialog.min_size = Vector2(350, 120)
	_new_part_dialog.confirmed.connect(_on_new_part_confirmed)
	
	# Verificar que _ui_node existe antes de agregar el diálogo
	if _ui_node and _ui_node.is_inside_tree():
		_ui_node.add_child(_new_part_dialog)
	else:
		push_error("PartDialogManager: _ui_node no está inicializado o no está en el árbol de escena")

func _on_new_part_text_submitted(_text: String):
	_on_new_part_confirmed()

func _on_new_part_confirmed():
	# Verificar que las dependencias estén inicializadas
	if _new_part_dialog == null or _part_manager == null:
		push_error("PartDialogManager: Dependencias no inicializadas")
		return
		
	var edit = _new_part_dialog.find_child("NewPartNameEdit", true, false)
	if not edit: 
		return
		
	var name = edit.text.strip_edges().to_lower().replace(" ", "_")
	print("PartDialogManager: Attempting to add part with name: ", name)
	
	if name.is_empty():
		push_warning("⚠️ Nombre de parte vacío.")
		print("PartDialogManager: Part name is empty.")
		return
		
	# Call the RiggingState to add the part
	var add_success = _part_manager.add_part_name(name)
	print("PartDialogManager: Result of _part_manager.add_part_name: ", add_success)
	edit.text = ""

func on_part_name_added(new_name: String, opt: OptionButton):
	# Verificar que _rigging_state esté inicializado
	if _rigging_state == null:
		push_error("PartDialogManager: _rigging_state no está inicializado en on_part_name_added")
		return
		
	if opt == null:
		push_error("PartDialogManager: OptionButton es null en on_part_name_added")
		return
		
	opt.clear()
	for part_name in _rigging_state.part_names:
		opt.add_item(part_name)
		
	for i in range(opt.get_item_count()):
		if opt.get_item_text(i) == new_name:
			opt.select(i)
			break

func on_epsilon_slider_visual_update(value: float, label_node: Label):
	if label_node == null:
		return
	label_node.text = "Epsilon: %.2f" % value
