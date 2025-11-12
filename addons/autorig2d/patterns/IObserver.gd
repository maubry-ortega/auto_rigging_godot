# IObserver.gd - Observer Pattern Interface
extends RefCounted

# Abstract method for receiving notifications
func update(subject, data = null) -> void:
	push_error("update() must be implemented in subclass")