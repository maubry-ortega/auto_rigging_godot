extends Node

var ui
var part_manager

func initialize_dialog(ui_node, manager):
	ui = ui_node
	part_manager = manager
	_create_new_part_dialog()

func on_add_new_part_pressed():
	var edit = ui.find_child("NewPartNameEdit", true, false)
	if edit:
		edit.text = ""
		edit.grab_focus()
	ui._new_part_dialog.popup_centered()

func _create_new_part_dialog():
	ui._new_part_dialog = AcceptDialog.new()
	ui._new_part_dialog.title = "Añadir Nueva Parte"
	var container = VBoxContainer.new()
	var label = Label.new()
	label.text = "Introduce el nombre (snake_case recomendado):"
	container.add_child(label)
	var line_edit = LineEdit.new()
	line_edit.name = "NewPartNameEdit"
	line_edit.placeholder_text = "ej: left_arm, tail_tip"
	line_edit.text_submitted.connect(_on_new_part_text_submitted)
	container.add_child(line_edit)
	ui._new_part_dialog.add_child(container)
	ui._new_part_dialog.min_size = Vector2(350,120)
	ui._new_part_dialog.confirmed.connect(_on_new_part_confirmed)
	ui.add_child(ui._new_part_dialog)

func _on_new_part_text_submitted(_text: String):
	_on_new_part_confirmed()

func _on_new_part_confirmed():
	var edit = ui.find_child("NewPartNameEdit", true, false)
	if not edit: return
	var name = edit.text.strip_edges().to_lower().replace(" ","_")
	if name.is_empty():
		push_warning("⚠️ Nombre de parte vacío.")
		return
	part_manager.add_part_name(name)
	edit.text = ""

func on_part_name_added(new_name:String,_all_parts:Array):
	var opt = ui.get_node("PartNameHBox/PartNameOptionButton")
	opt.clear()
	for part_name in part_manager.get_part_names():
		opt.add_item(part_name)
	for i in range(opt.get_item_count()):
		if opt.get_item_text(i)==new_name:
			opt.select(i)
			break

func on_epsilon_slider_changed(value:float):
	ui.polygon_epsilon = value

func on_epsilon_slider_visual_update(value:float):
	if ui.has_node("EpsilonHBox/EpsilonLabel"):
		ui.get_node("EpsilonHBox/EpsilonLabel").text = "Epsilon: %.2f" % value
