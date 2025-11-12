# ICommand.gd - Command Pattern Interface
extends RefCounted

# Abstract methods for command execution
func execute() -> void:
	push_error("execute() must be implemented in subclass")

func undo() -> void:
	push_error("undo() must be implemented in subclass")