# ISubject.gd - Subject Interface for Observer Pattern
extends RefCounted

# Abstract methods for managing observers
func attach(observer) -> void:
	push_error("attach() must be implemented in subclass")

func detach(observer) -> void:
	push_error("detach() must be implemented in subclass")

func notify(data = null) -> void:
	push_error("notify() must be implemented in subclass")