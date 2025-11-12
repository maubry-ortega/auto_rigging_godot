# AddSeedCommand.gd - Command for Adding Seeds
extends "res://addons/autorig2d/patterns/ICommand.gd"

class_name AddSeedCommand

var _rigging_state
var _part_name: String
var _position: Vector2
var _was_added: bool = false

func _init(rigging_state, part_name: String, position: Vector2):
	_rigging_state = rigging_state
	_part_name = part_name
	_position = position

func execute() -> void:
	if not _rigging_state.seed_data.has(_part_name):
		_rigging_state.seed_data[_part_name] = []
	if _rigging_state.seed_data[_part_name].size() < 2:
		_rigging_state.add_seed(_part_name, _position)
		_was_added = true
	else:
		push_warning("Cannot add more than 2 seeds per part")

func undo() -> void:
	if _was_added and _rigging_state.seed_data.has(_part_name):
		var seeds = _rigging_state.seed_data[_part_name]
		if _position in seeds:
			seeds.erase(_position)
			_rigging_state.notify({"type": "seed_removed", "part_name": _part_name, "position": _position})