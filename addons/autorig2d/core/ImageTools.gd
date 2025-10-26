@tool
class_name ImageTools
extends Node

var seed_points: Dictionary = {}
var atlas_image: Image
var atlas_texture: ImageTexture

func initialize(atlas: Image, texture: ImageTexture, seeds: Dictionary) -> void:
	atlas_image = atlas.duplicate()
	atlas_texture = texture
	seed_points = seeds

func generate_body_part_polygons() -> Array[Polygon2D]:
	var generated_polygons: Array[Polygon2D] = []
	if not atlas_image:
		push_error("Atlas image is not set.")
		return []

	for seed in seed_points.keys():
		var part_name: String = seed_points[seed]
		
		var filled_area: Dictionary = _flood_fill(seed)
		if filled_area.is_empty():
			print("Parte '%s' falló: No se encontraron píxeles en el flood fill (posiblemente el punto semilla está en un área transparente)." % part_name)
			continue

		var bitmap := BitMap.new()
		bitmap.create(atlas_image.get_size())
		for pixel_pos in filled_area.keys():
			bitmap.set_bitv(pixel_pos, true)

		var polygons_from_bitmap: Array = bitmap.opaque_to_polygons(Rect2i(Vector2i(0,0), atlas_image.get_size()))

		if polygons_from_bitmap.is_empty():
			print("Parte '%s' falló: opaque_to_polygons no pudo generar un contorno." % part_name)
			continue

		var main_contour: PackedVector2Array = polygons_from_bitmap[0]
		for p in polygons_from_bitmap:
			if p.size() > main_contour.size():
				main_contour = p

		var simplified_contour: PackedVector2Array = _simplify_rdp(main_contour, 2.0)
		if simplified_contour.size() < 3:
			simplified_contour = main_contour

		var poly_node: Polygon2D = _create_polygon2d(simplified_contour, part_name)
		if is_instance_valid(poly_node):
			generated_polygons.append(poly_node)
		else:
			print("Parte '%s' falló: No se pudo crear el nodo Polygon2D final." % part_name)
	
	return generated_polygons

func _flood_fill(start_pos: Vector2i) -> Dictionary:
	if start_pos.x < 0 or start_pos.x >= atlas_image.get_width() or start_pos.y < 0 or start_pos.y >= atlas_image.get_height():
		return {}

	var start_color: Color = atlas_image.get_pixelv(start_pos)
	if start_color.a <= 0.05:
		return {}

	var tolerance: float = 0.4 # Tolerancia máxima para asegurar la generación
	var filled_pixels: Dictionary = {}
	var queue: Array[Vector2i] = [start_pos]
	
	var img_width: int = atlas_image.get_width()
	var img_height: int = atlas_image.get_height()

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()

		if pos.x < 0 or pos.x >= img_width or pos.y < 0 or pos.y >= img_height:
			continue
		if filled_pixels.has(pos):
			continue

		var current_color: Color = atlas_image.get_pixelv(pos)
		if current_color.a > 0.05:
			filled_pixels[pos] = true
			queue.append(pos + Vector2i.RIGHT)
			queue.append(pos + Vector2i.LEFT)
			queue.append(pos + Vector2i.UP)
			queue.append(pos + Vector2i.DOWN)
			
	return filled_pixels

func _simplify_rdp(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var first_point = points[0]
	var last_point = points[points.size() - 1]
	var max_dist_sq = 0.0
	var index = 0
	for i in range(1, points.size() - 1):
		var dist_sq = _get_sq_segment_dist(points[i], first_point, last_point)
		if dist_sq > max_dist_sq:
			max_dist_sq = dist_sq
			index = i

	if max_dist_sq > epsilon * epsilon:
		var rec_results1 = _simplify_rdp(points.slice(0, index + 1), epsilon)
		var rec_results2 = _simplify_rdp(points.slice(index, points.size()), epsilon)
		
		var simplified = PackedVector2Array()
		for p in rec_results1.slice(0, rec_results1.size() - 1):
			simplified.append(p)
		for p in rec_results2:
			simplified.append(p)
		return simplified
	else:
		return PackedVector2Array([first_point, last_point])

func _get_sq_segment_dist(p: Vector2, p1: Vector2, p2: Vector2) -> float:
	var x = p1.x
	var y = p1.y
	var dx = p2.x - x
	var dy = p2.y - y
	if dx != 0 or dy != 0:
		var t = ((p.x - x) * dx + (p.y - y) * dy) / (dx * dx + dy * dy)
		if t > 1:
			x = p2.x
			y = p2.y
		elif t > 0:
			x += dx * t
			y += dy * t
	dx = p.x - x
	dy = p.y - y
	return dx * dx + dy * dy

func _create_polygon2d(contour: PackedVector2Array, part_name: String) -> Polygon2D:
	if contour.size() < 3:
		return null
	
	var poly = Polygon2D.new()
	poly.name = part_name
	poly.texture = atlas_texture

	var bounds := Rect2(contour[0], Vector2())
	for p in contour:
		bounds = bounds.expand(p)
	
	var local_contour: PackedVector2Array
	for p in contour:
		local_contour.append(p - bounds.position)
	
	poly.position = bounds.position
	poly.polygon = local_contour
	poly.uv = contour

	# Usar triangulate_polygon que devuelve los índices correctos para la propiedad 'polygons'
	var point_indices = Geometry2D.triangulate_polygon(local_contour)
	if point_indices.is_empty():
		print("Parte '%s' falló: triangulate_polygon no generó índices." % part_name)
		return null

	poly.polygons = [point_indices]
	return poly

func _color_distance(c1: Color, c2: Color) -> float:
	var dr = c1.r - c2.r
	var dg = c1.g - c2.g
	var db = c1.b - c2.b
	return sqrt(dr*dr + dg*dg + db*db)
