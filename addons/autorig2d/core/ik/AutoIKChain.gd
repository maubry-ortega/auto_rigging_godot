@tool
extends Node2D

var _bone_chain: Array = [] # Array[Bone2D]
var _target: Node2D
@export var iterations: int = 12
@export var tolerance: float = 0.5
@export var bone_limits: Array # Array of Dictionaries {min_angle: float, max_angle: float}

func set_bone_chain(chain: Array) -> void:
	_bone_chain = chain

func set_target(target: Node2D) -> void:
	_target = target

func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		return
	if _bone_chain.size() < 2:
		return
	_solve_ccd(_target.global_position)

func _solve_ccd(goal: Vector2) -> void:
	# CCD simple en espacio global
	for _i in range(iterations):
		var end_effector: Bone2D = _bone_chain[_bone_chain.size() - 1]
		var dist = end_effector.get_global_position().distance_to(goal)
		if dist <= tolerance:
			break
		for j in range(_bone_chain.size() - 1, -1, -1):
			var bone: Bone2D = _bone_chain[j]
			var bone_pos = bone.get_global_position()
			var to_end = (end_effector.get_global_position() - bone_pos)
			var to_goal = (goal - bone_pos)
			if to_end.length() == 0 or to_goal.length() == 0:
				continue
			var angle_diff = to_end.angle_to(to_goal)
			bone.global_rotation += angle_diff

			# Apply joint limits if available
			if j < bone_limits.size():
				var limits = bone_limits[j]
				if limits.has("min_angle") and limits.has("max_angle"):
					var current_rotation = bone.global_rotation
					var min_limit = limits.min_angle
					var max_limit = limits.max_angle

					# Normalize current rotation to be within -PI to PI for consistent clamping
					current_rotation = wrapf(current_rotation, -PI, PI)

					# Clamp the rotation
					bone.global_rotation = clampf(current_rotation, min_limit, max_limit)


