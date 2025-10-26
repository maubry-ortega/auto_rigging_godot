@tool
class_name HumanoidBuilder
extends Node

func build_rig(polygons: Array[Polygon2D]) -> Node2D:
	var root = Node2D.new()
	root.name = "Character2D"

	var skeleton = Skeleton2D.new()
	root.add_child(skeleton)
	skeleton.owner = root

	# Añade cada Polygon2D como hijo directo del Character2D
	for poly in polygons:
		if is_instance_valid(poly):
			root.add_child(poly)
			poly.owner = root

	return root
