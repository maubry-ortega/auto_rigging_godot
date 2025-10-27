# PolygonGenerator.gd
extends RefCounted

# Constantes deben ser redefinidas o referenciadas si el script no es un Singleton.
# Usamos las constantes definidas en el código original para que funcione sin un Singleton externo,
# pero si quieres usar un Singleton como en la respuesta anterior, deberías ajustar estas líneas.
const ATLAS_PIXEL_TO_UNIT_SCALE = 2.0
const MAX_REGION_PIXELS = 400000
const MIN_REGION_PIXELS = 30 # Mantenemos el 30 para ignorar ruido.

# ==============================================================================
## Funciones Principales
# ==============================================================================

func generate_body_part_polygons(atlas_image: Image, atlas_texture: ImageTexture, seeds: Dictionary, polygon_epsilon: float) -> Array[Polygon2D]:
	var generated_polygons: Array[Polygon2D] = []
	if not atlas_image:
		push_error("Atlas image is not set.")
		return []

	print("\n=== 🎨 Iniciando generación ===")
	print("Atlas: ", atlas_image.get_size())
	print("Partes: ", seeds.size())
	print("Epsilon: ", polygon_epsilon)

	# PASO 1: Extraer TODAS las regiones conectadas del atlas
	var all_regions = _extract_all_regions(atlas_image)
	print("\n🔍 Regiones detectadas: ", all_regions.size())

	# Marcar todas las regiones como no usadas
	var used_regions: Array[bool] = []
	for i in range(all_regions.size()):
		used_regions.append(false)

	# PASO 2: Crear mapeo semilla → región más cercana
	var seed_to_region = {}

	for part_name in seeds.keys():
		var seed_pos = seeds[part_name]
		var best_region: int = -1
		var best_distance = INF

		# Buscar la región más cercana y no usada
		for i in range(all_regions.size()):
			if used_regions[i]:
				continue

			var region = all_regions[i]
			var distance = _get_distance_to_region(seed_pos, region)

			if distance < best_distance:
				best_distance = distance
				best_region = i

		if best_region != -1:
			seed_to_region[part_name] = best_region
			used_regions[best_region] = true  # marcar región como usada
			print("  '%s' → región #%d (dist: %.1f px)" % [part_name, best_region, best_distance])
		else:
			print("  ❌ '%s' no encontró región cercana" % part_name)

	# PASO 3: Generar polígonos para cada parte
	for part_name in seeds.keys():
		print("\n--- Procesando: '%s' ---" % part_name)
		print("  Semilla: ", seeds[part_name])

		if not seed_to_region.has(part_name):
			print("  ❌ No se asignó región")
			continue

		var region_idx = seed_to_region[part_name]
		var region = all_regions[region_idx]

		print("  ✅ Región: %d píxeles" % region.size())

		var poly = _create_polygon_from_region(atlas_image, atlas_texture, region, part_name, polygon_epsilon)

		if is_instance_valid(poly):
			generated_polygons.append(poly)
		else:
			print("  ❌ Fallo al crear polígono")

	print("\n=== ✅ Completado: %d/%d partes ===" % [generated_polygons.size(), seeds.size()])
	return generated_polygons


# ------------------------------------------------------------------------------
## Extracción de Todas las Regiones (Flood Fill)
# ------------------------------------------------------------------------------

func _extract_all_regions(image: Image) -> Array:
	var width = image.get_width()
	var height = image.get_height()
	var alpha_threshold = 0.1
	var visited = {}
	var regions = []
	
	print("🔎 Escaneando atlas para detectar regiones...")
	
	for y in range(height):
		for x in range(width):
			var pos = Vector2i(x, y)
			var pos_key = "%d,%d" % [x, y]
			
			if visited.has(pos_key):
				continue
			
			var color = image.get_pixelv(pos)
			if color.a < alpha_threshold:
				visited[pos_key] = true
				continue
			
			# Encontramos un nuevo píxel opaco no visitado!
			var region = _flood_fill_simple(image, pos, visited, alpha_threshold)
			
			if region.size() > MIN_REGION_PIXELS: # Ignorar regiones muy pequeñas (ruido)
				regions.append(region)
				print("  → Región encontrada: %d píxeles" % region.size())
	
	return regions


func _flood_fill_simple(image: Image, start: Vector2i, visited_global: Dictionary, threshold: float) -> Dictionary:
	var width = image.get_width()
	var height = image.get_height()
	var region = {}
	var queue = [start]
	var visited_local = {}
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		
		# Bounds
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			continue
		
		var pos_key = "%d,%d" % [pos.x, pos.y]
		
		if visited_local.has(pos_key):
			continue
		
		visited_local[pos_key] = true
		visited_global[pos_key] = true
		
		# Opaco?
		var color = image.get_pixelv(pos)
		if color.a < threshold:
			continue
		
		# Añadir a región
		region[pos] = true
		
		# Expandir
		queue.append(pos + Vector2i(1, 0))
		queue.append(pos + Vector2i(-1, 0))
		queue.append(pos + Vector2i(0, 1))
		queue.append(pos + Vector2i(0, -1))
		
		# Límite de seguridad
		if region.size() > MAX_REGION_PIXELS:
			break
	
	return region


# ------------------------------------------------------------------------------
# Distancia
# ------------------------------------------------------------------------------
func _get_distance_to_region(seed: Vector2i, region: Dictionary) -> float:
	if region.has(seed):
		return 0.0
	
	var min_sq = INF
	for key in region.keys():
		var p = Vector2(key)
		var dsq = seed.distance_squared_to(p)
		if dsq < min_sq:
			min_sq = dsq
	
	if min_sq == INF:
		return INF
	return sqrt(min_sq)


# ------------------------------------------------------------------------------
## Crear Polígono desde Región
# ------------------------------------------------------------------------------

func _create_polygon_from_region(image: Image, texture: ImageTexture, pixels: Dictionary, part_name: String, polygon_epsilon: float) -> Polygon2D:
	if pixels.is_empty():
		return null
	
	# 1. Crear BitMap
	var bitmap = BitMap.new()
	bitmap.create(Vector2i(image.get_width(), image.get_height()))
	
	for pixel in pixels.keys():
		bitmap.set_bitv(pixel, true)
	
	# 2. Extraer contornos
	var polygons = bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, image.get_size()),
		ATLAS_PIXEL_TO_UNIT_SCALE
	)
	
	if polygons.is_empty():
		print("  ❌ No se pudo generar contorno")
		return null
	
	# 3. Contorno principal (más grande)
	var main_contour: PackedVector2Array = polygons[0]
	for poly in polygons:
		if poly.size() > main_contour.size():
			main_contour = poly
	
	print("  📐 Contorno: %d puntos" % main_contour.size())
	
	# 4. Simplificar
	var simplified = _simplify_rdp(main_contour, polygon_epsilon)
	
	if simplified.size() < 3:
		simplified = main_contour
	else:
		print("  ✂️ Simplificado: %d puntos" % simplified.size())
	
	# 5. Limpiar
	var cleaned = _clean_polygon(simplified)
	
	if cleaned.size() < 3:
		print("  ❌ Polígono inválido")
		return null
	
	# 6. Crear Polygon2D
	var poly = Polygon2D.new()
	poly.name = part_name
	poly.texture = texture
	
	# 7. Calcular bounds (en coordenadas del atlas)
	var bounds = Rect2(cleaned[0], Vector2.ZERO)
	for point in cleaned:
		bounds = bounds.expand(point)
	
	# La POSICIÓN del nodo es la esquina superior izquierda del bounds
	poly.position = bounds.position
	
	# 8. Contorno LOCAL (relativo a poly.position)
	var local_points = PackedVector2Array()
	for point in cleaned:
		local_points.append(point - bounds.position)
	
	# 9. UVs en coordenadas del ATLAS (globales, sin restar position)
	var uvs = PackedVector2Array()
	for point in cleaned:
		uvs.append(point)  # ← Coordenadas GLOBALES del atlas
	
	poly.polygon = local_points
	poly.uv = uvs
	
	# 10. Validar triangulación
	if not _validate_triangulation(poly, local_points, bounds.position):
		return null
	
	print("  📍 Pos: %s | Tamaño: %.0fx%.0f" % [poly.position, bounds.size.x, bounds.size.y])
	return poly


func _validate_triangulation(poly: Polygon2D, points: PackedVector2Array, offset: Vector2) -> bool:
	var indices = Geometry2D.triangulate_polygon(points)
	
	if not indices.is_empty():
		return true
	
	print("  ⚠️ Triangulación falló, simplificando...")
	
	var simplified = _simplify_rdp(points, 2.0)
	
	if simplified.size() < 3:
		return false
	
	indices = Geometry2D.triangulate_polygon(simplified)
	
	if indices.is_empty():
		return false
	
	# Actualizar con versión simplificada
	var new_uvs = PackedVector2Array()
	for p in simplified:
		new_uvs.append(p + offset)  # UVs globales
	
	poly.polygon = simplified
	poly.uv = new_uvs
	
	print("  ✅ Triangulación con simplificación agresiva")
	return true


# ------------------------------------------------------------------------------
## Simplificación RDP
# ------------------------------------------------------------------------------

func _simplify_rdp(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	
	var first = points[0]
	var last = points[points.size() - 1]
	var max_dist_sq = 0.0
	var index = 0
	
	for i in range(1, points.size() - 1):
		var dist_sq = _point_to_segment_distance_sq(points[i], first, last)
		if dist_sq > max_dist_sq:
			max_dist_sq = dist_sq
			index = i
	
	if max_dist_sq > epsilon * epsilon:
		# Nota: Godot 4.x PackedVector2Array.slice() excluye el final.
		var left = _simplify_rdp(points.slice(0, index + 1), epsilon)
		var right = _simplify_rdp(points.slice(index, points.size()), epsilon)
		
		var result = PackedVector2Array()
		# Omitir el último punto del 'left' ya que es el primero del 'right'
		for p in left.slice(0, left.size() - 1):
			result.append(p)
		for p in right:
			result.append(p)
		return result
	else:
		return PackedVector2Array([first, last])


func _point_to_segment_distance_sq(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var x = seg_a.x
	var y = seg_a.y
	var dx = seg_b.x - x
	var dy = seg_b.y - y
	
	if dx != 0 or dy != 0:
		var t = ((point.x - x) * dx + (point.y - y) * dy) / (dx * dx + dy * dy)
		t = clamp(t, 0.0, 1.0)
		x += dx * t
		y += dy * t
	
	var dist_x = point.x - x
	var dist_y = point.y - y
	return dist_x * dist_x + dist_y * dist_y


func _clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	
	var epsilon = 0.5
	var cleaned = PackedVector2Array()
	
	# Eliminar duplicados
	for i in range(points.size()):
		var current = points[i]
		var is_dup = false
		
		if cleaned.size() > 0:
			if current.distance_to(cleaned[cleaned.size() - 1]) < epsilon:
				is_dup = true
		
		if not is_dup:
			cleaned.append(current)
	
	# Cerrar polígono
	if cleaned.size() > 0:
		if cleaned[0].distance_to(cleaned[cleaned.size() - 1]) < epsilon:
			cleaned.remove_at(cleaned.size() - 1)
	
	if cleaned.size() < 3:
		return points
	
	# Eliminar colineales
	var final = PackedVector2Array()
	final.append(cleaned[0])
	
	for i in range(1, cleaned.size() - 1):
		var prev = cleaned[i - 1]
		var curr = cleaned[i]
		var next = cleaned[i + 1]
		
		var v1 = curr - prev
		var v2 = next - curr
		# Cross product para determinar colinealidad (área del paralelogramo)
		var cross = abs(v1.x * v2.y - v1.y * v2.x)
		
		if cross > epsilon:
			final.append(curr)
	
	final.append(cleaned[cleaned.size() - 1])
	
	return final if final.size() >= 3 else cleaned
