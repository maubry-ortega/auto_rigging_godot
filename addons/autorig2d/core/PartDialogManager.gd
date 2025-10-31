extends Node

var _rigging_state: RiggingState
var _new_part_dialog: AcceptDialog
var _ui_node: Control # Keep a reference to the UI node to add the dialog

func initialize_dialog(ui_node: Control, rigging_state: RiggingState):
	_ui_node = ui_node
	_rigging_state = rigging_state
	_create_new_part_dialog()

func on_add_new_part_pressed():
	var edit = _new_part_dialog.find_child("NewPartNameEdit", true, false)
	if edit:
		edit.text = ""
		edit.grab_focus()
	_new_part_dialog.popup_centered()

func _create_new_part_dialog():
	_new_part_dialog = AcceptDialog.new()
	_new_part_dialog.title = "Añadir Nueva Parte"
	var container = VBoxContainer.new()
	var label = Label.new()
	label.text = "Introduce el nombre (snake_case recomendado):"
	container.add_child(label)
	var line_edit = LineEdit.new()
	line_edit.name = "NewPartNameEdit"
	line_edit.placeholder_text = "ej: left_arm, tail_tip"
	line_edit.text_submitted.connect(_on_new_part_text_submitted)
	container.add_child(line_edit)
	_new_part_dialog.add_child(container)
	_new_part_dialog.min_size = Vector2(350,120)
	_new_part_dialog.confirmed.connect(_on_new_part_confirmed)
	_ui_node.add_child(_new_part_dialog)

func _on_new_part_text_submitted(_text: String):
	_on_new_part_confirmed()

func _on_new_part_confirmed():
	var edit = _new_part_dialog.find_child("NewPartNameEdit", true, false)
	if not edit: return
	var name = edit.text.strip_edges().to_lower().replace(" ","_")
	if name.is_empty():
		push_warning("⚠️ Nombre de parte vacío.")
		return
	# Call the RiggingState to add the part
	_rigging_state.add_part_name(name)
	edit.text = ""

func on_part_name_added(new_name:String, opt: OptionButton):
	opt.clear()
	for part_name in _rigging_state.part_names:
		opt.add_item(part_name)
	for i in range(opt.get_item_count()):
		if opt.get_item_text(i)==new_name:
			opt.select(i)
			break

func on_epsilon_slider_visual_update(value:float, label_node: Label):
	label_node.text = "Epsilon: %.2f" % value
