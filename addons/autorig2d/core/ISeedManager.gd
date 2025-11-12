# ISeedManager.gd - Interface for Seed Managers
extends RefCounted
class_name ISeedManager

# Abstract methods for seed management
func add_seed() -> void:
	push_error("add_seed() must be implemented in subclass")

func handle_texture_input(event) -> void:
	push_error("handle_texture_input() must be implemented in subclass")

func draw_seeds(rect: Control) -> void:
	push_error("draw_seeds() must be implemented in subclass")