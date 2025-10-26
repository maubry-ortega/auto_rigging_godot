@tool
extends EditorPlugin

var dock: Control

func _enter_tree():
	print("AutoRig2D activado!")
	dock = preload("res://addons/autorig2d/EditorUI/RiggingDock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	print("AutoRig2D desactivado!")
	remove_control_from_docks(dock)
	dock.free()
