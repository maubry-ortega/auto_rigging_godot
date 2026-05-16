@tool
extends Node2D
class_name SimpleTwoBoneIK

@export var target_node: Node2D
@export var bone1_path: NodePath
@export var bone2_path: NodePath
@export var flip_bend: bool = false

var bone1: Bone2D
var bone2: Bone2D

func _ready():
	if has_node(bone1_path):
		bone1 = get_node(bone1_path)
	if has_node(bone2_path):
		bone2 = get_node(bone2_path)

func _process(delta):
	if not bone1 or not bone2 or not target_node:
		return
		
	solve()

func solve():
	var target_pos = target_node.global_position
	var bone1_pos = bone1.global_position
	
	var len1 = bone1.get_length()
	var len2 = bone2.get_length()
	
	# If lengths are too small, default to something reasonable or skip
	if len1 < 1.0: len1 = 50.0
	if len2 < 1.0: len2 = 50.0
	
	var dist = bone1_pos.distance_to(target_pos)
	var angle_to_target = (target_pos - bone1_pos).angle()
	
	# Law of Cosines
	# c^2 = a^2 + b^2 - 2ab cos(C)
	# cos(C) = (a^2 + b^2 - c^2) / 2ab
	
	# Angle 1 (at bone1)
	var cos_angle1 = (dist * dist + len1 * len1 - len2 * len2) / (2 * dist * len1)
	
	# Angle 2 (at bone2)
	var cos_angle2 = (len1 * len1 + len2 * len2 - dist * dist) / (2 * len1 * len2)
	
	# Clamp to avoid NaN
	cos_angle1 = clamp(cos_angle1, -1.0, 1.0)
	cos_angle2 = clamp(cos_angle2, -1.0, 1.0)
	
	var angle1 = acos(cos_angle1)
	var angle2 = acos(cos_angle2)
	
	if flip_bend:
		angle1 = - angle1
		angle2 = - angle2
		
	# Apply rotations
	# Bone1 global rotation = angle to target +/- angle1
	bone1.global_rotation = angle_to_target - angle1
	
	# Bone2 local rotation = PI - angle2 (standard knee bend)
	# Adjust based on parent's rotation
	bone2.global_rotation = bone1.global_rotation + PI - angle2
