@tool
extends Node2D

@export var color: Color = Color.hex(0xFFCC00FF)
@export var radius: float = 6.0

func _draw():
	draw_circle(Vector2.ZERO, radius, color)
	draw_line(Vector2(-radius*1.5,0), Vector2(radius*1.5,0), color, 2)
	draw_line(Vector2(0,-radius*1.5), Vector2(0,radius*1.5), color, 2)

func _process(_d):
	queue_redraw()


