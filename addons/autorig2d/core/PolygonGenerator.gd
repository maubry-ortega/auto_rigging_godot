# PolygonGenerator.gd
extends RefCounted

# Constantes
const ATLAS_PIXEL_TO_UNIT_SCALE = 1.0
const MAX_REGION_PIXELS = 400000
const MIN_REGION_PIXELS = 30

# Parámetros ajustables
const REGION_FALLBACK_DISTANCE := 80.0         # px: cuánto permitimos que una seed esté fuera de la región y aun así la asignamos por proximidad
const INTERSECTION_DILATION := 20              # dilatación inicial para buscar intersecciones
const INTERSECTION_DILATION_FALLBACK := 40     # dilatación más agresiva si no hay intersección pero las regiones están cercanas
const FORCE_ASSIGN_MISSING_SEEDS := false       # si true, asigna seeds siempre a la región más cercana (aunque quede lejos)

const HIERARCHY_MAP := {
	"torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"],
	"head": [], "left_arm": ["left_hand"], "right_arm": ["right_hand"], "left_leg": ["left_foot"], "right_leg": ["right_foot"]
}

func _are_parts_related(part_a: String, part_b: String) -> bool:
	if HIERARCHY_MAP.has(part_a) and part_b in HIERARCHY_MAP[part_a]:
		return true
	if HIERARCHY_MAP.has(part_b) and part_a in HIERARCHY_MAP[part_b]:
		return true
	
	# Check for secondary relationships (e.g., hand to arm)
	for key in HIERARCHY_MAP.keys():
		if (part_a == key and part_b in HIERARCHY_MAP[key]) or (part_b == key and part_a in HIERARCHY_MAP[key]):
			return true
	
	return false

# ==============================================================================
## Funciones Principales
# ==============================================================================

func generate_body_part_polygons(atlas_image: Image, atlas_texture: ImageTexture, seeds: Dictionary, polygon_epsilon: float) -> Dictionary:
	var generated_polygons: Array = []
	var part_origins: Dictionary = {}
	if not atlas_image:
		push_error("Atlas image is not set.")
		return {}

	print("\n=== 🎨 Iniciando generación ===")
	print("Atlas: ", atlas_image.get_size())
	print("Partes: ", seeds.size())
	print("Epsilon: ", polygon_epsilon)

	# PASO 1: Extraer regiones conectadas
	var all_regions = _extract_all_regions(atlas_image)
	print("\n🔍 Regiones detectadas: ", all_regions.size())

	# marcar no usadas
	var used_regions: Array[bool] = []
	for i in range(all_regions.size()):
		used_regions.append(false)

	# Precompute centroids para fallback por distancia
	var region_centroids = []
	for region in all_regions:
		var current_sum = Vector2.ZERO
		var current_count = 0
		for p in region.keys():
			current_sum += Vector2(p)
			current_count += 1
		var centroid = Vector2.ZERO
		if current_count > 0:
			centroid = current_sum / float(current_count)
		region_centroids.append(centroid)

	# PASO 2: seed -> región con fallback por cercanía (y opción de forzar)
	var seed_to_region = {}
	for part_name in seeds.keys():
		var seed_points = seeds[part_name]
		if seed_points == null or seed_points.is_empty():
			continue
		var seed_pos = _normalize_seed_pos(seed_points[0])
		var seed_pos_int = Vector2i(seed_pos)
		var best_region := -1
		# buscar contención
		for k in range(all_regions.size()):
			if used_regions[k]:
				continue
			var region_k = all_regions[k]
			if region_k.has(seed_pos_int):
				best_region = k
				break

		# fallback por distancia al centroid
		if best_region == -1:
			var best_dist = INF
			var nearest_idx = -1
			for k in range(all_regions.size()):
				if used_regions[k]:
					continue
				var c = region_centroids[k]
				var d = _get_distance_to_region(seed_pos_int, all_regions[k])
				if d < best_dist:
					best_dist = d
					nearest_idx = k

			if nearest_idx != -1:
				# Si FORCE_ASSIGN_MISSING_SEEDS está activado, forzamos la asignación aunque la distancia sea mayor
				if best_dist <= REGION_FALLBACK_DISTANCE:
					best_region = nearest_idx
					print("  ℹ️ Fallback: seed '%s' asignada por proximidad a región #%d (dist %.1f px)." % [part_name, best_region, best_dist])
				else:
					if FORCE_ASSIGN_MISSING_SEEDS:
						best_region = nearest_idx
						print("  ⚠️ FORZANDO: seed '%s' asignada a región #%d (dist %.1f px) — revisa posición de seed." % [part_name, best_region, best_dist])
					else:
						print("  ❌ Seed '%s' está demasiado lejos (%.1f px) de cualquier región. Por favor, reposiciona la semilla más cerca de la parte deseada." % [part_name, best_dist])
						best_region = -1

		if best_region != -1:
			seed_to_region[part_name] = best_region
			used_regions[best_region] = true
			print("  '%s' → región #%d (asignada)" % [part_name, best_region])
		else:
			print("  ❌ '%s' no encontró región. La semilla debe estar dentro o cerca de la pieza." % part_name)

	# PASO 3: Generar polígonos desde regiones asignadas
	for part_name in seeds.keys():
		print("\n--- Procesando: '%s' ---" % part_name)
		print("  Semilla: ", seeds[part_name])

		if not seed_to_region.has(part_name):
			print("  ❌ No se asignó región")
			continue

		var region_idx = seed_to_region[part_name]
		var region = all_regions[region_idx]

		print("  ✅ Región: %d píxeles" % region.size())
		var poly = _create_polygon_from_region(atlas_image, atlas_texture, region, part_name, polygon_epsilon, seeds)
		if is_instance_valid(poly):
			generated_polygons.append(poly)
			part_origins[part_name] = poly.position
		else:
			print("  ❌ Fallo al crear polígono")

	# PASO 4: Generar polígonos para las INTERSECCIONES (incluye intento con dilatación más agresiva)
	print("\n--- 🔗 Buscando intersecciones ---")
	var part_names = seed_to_region.keys()
	var image_size = atlas_image.get_size()

	for i in range(part_names.size()):
		for j in range(i + 1, part_names.size()):
			var name_a = part_names[i]
			var name_b = part_names[j]

			# Solo buscar intersecciones entre partes relacionadas
			if not _are_parts_related(name_a, name_b):
				continue

			var region_a = all_regions[seed_to_region[name_a]]
			var region_b = all_regions[seed_to_region[name_b]]

			# primer intento con dilatación normal
			var intersection_pixels = _compute_intersection_pixels(region_a, region_b, image_size, INTERSECTION_DILATION)
			print("  - '%s' y '%s'" % [name_a, name_b])
			if intersection_pixels == null or (typeof(intersection_pixels) == TYPE_DICTIONARY and intersection_pixels.is_empty()):
				# si no hay intersección, reintentar con dilatación más agresiva si los centroides están cerca
				var ca = region_centroids[seed_to_region[name_a]]
				var cb = region_centroids[seed_to_region[name_b]]
				var cent_dist = ca.distance_to(cb)
				if cent_dist <= max(INTERSECTION_DILATION_FALLBACK, REGION_FALLBACK_DISTANCE * 1.5):
					intersection_pixels = _compute_intersection_pixels(region_a, region_b, image_size, INTERSECTION_DILATION_FALLBACK)
					if intersection_pixels != null and not intersection_pixels.is_empty():
						print("    ℹ️ Intersección encontrada tras dilatación agresiva (centroid dist: %.1f px)" % cent_dist)
			if intersection_pixels != null and not intersection_pixels.is_empty():
				var intersection_poly = _create_intersection_polygon(intersection_pixels, atlas_image, atlas_texture, name_a, name_b, polygon_epsilon)
				if is_instance_valid(intersection_poly):
					generated_polygons.append(intersection_poly)
					part_origins[intersection_poly.name] = intersection_poly.position
			else:
				print("  - No se encontró intersección.")

	print("\n=== ✅ Completado: %d/%d partes ===" % [generated_polygons.size(), seeds.size()])
	return {"polygons": generated_polygons, "origins": part_origins}


# ------------------------------------------------------------------------------
## Helpers: Intersection / Bitmap generation
# ------------------------------------------------------------------------------
func _compute_intersection_pixels(region_a: Dictionary, region_b: Dictionary, image_size: Vector2i, dilation_amount: int) -> Dictionary:
	var bmp_a = BitMap.new()
	bmp_a.create(image_size)
	for pixel in region_a.keys():
		bmp_a.set_bitv(pixel, true)
	var bmp_b = BitMap.new()
	bmp_b.create(image_size)
	for pixel in region_b.keys():
		bmp_b.set_bitv(pixel, true)

	var image_rect = Rect2i(Vector2i.ZERO, image_size)
	bmp_a.grow_mask(dilation_amount, image_rect)
	bmp_b.grow_mask(dilation_amount, image_rect)

	var and_bmp = _bitmap_bitwise_and(bmp_a, bmp_b)
	if and_bmp == null:
		return {}
	var intersection_pixels = {}
	var bmp_size = and_bmp.get_size()
	for y in range(bmp_size.y):
		for x in range(bmp_size.x):
			var pos = Vector2i(x, y)
			if and_bmp.get_bitv(pos):
				intersection_pixels[pos] = true
	return intersection_pixels


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
			var region = _flood_fill_simple(image, pos, visited, alpha_threshold)
			if region.size() > MIN_REGION_PIXELS:
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
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			continue
		var pos_key = "%d,%d" % [pos.x, pos.y]
		if visited_local.has(pos_key):
			continue
		visited_local[pos_key] = true
		visited_global[pos_key] = true
		var color = image.get_pixelv(pos)
		if color.a < threshold:
			continue
		region[pos] = true
		queue.append(pos + Vector2i(1, 0))
		queue.append(pos + Vector2i(-1, 0))
		queue.append(pos + Vector2i(0, 1))
		queue.append(pos + Vector2i(0, -1))
		if region.size() > MAX_REGION_PIXELS:
			break
	return region


# ------------------------------------------------------------------------------
## Dilatación (Mantengo el método lento como fallback)
# ------------------------------------------------------------------------------
func _dilate_region(region: Dictionary, amount: int, image_size: Vector2i) -> Dictionary:
	var dilated = region.duplicate(true)
	var width = image_size.x
	var height = image_size.y
	for p in region.keys():
		for y in range(p.y - amount, p.y + amount + 1):
			for x in range(p.x - amount, p.x + amount + 1):
				if x < 0 or x >= width or y < 0 or y >= height:
					continue
				var new_pos = Vector2i(x, y)
				if not dilated.has(new_pos):
					dilated[new_pos] = true
	return dilated


# ------------------------------------------------------------------------------
## Operaciones de BitMap (Helpers)
# ------------------------------------------------------------------------------
func _bitmap_bitwise_and(bitmap1: BitMap, bitmap2: BitMap) -> BitMap:
	if bitmap1.get_size() != bitmap2.get_size():
		push_error("Bitmaps must have the same size for bitwise AND operation.")
		return null
	var size = bitmap1.get_size()
	var result_bitmap = BitMap.new()
	result_bitmap.create(size)
	for y in range(size.y):
		for x in range(size.x):
			var pos = Vector2i(x, y)
			if bitmap1.get_bitv(pos) and bitmap2.get_bitv(pos):
				result_bitmap.set_bitv(pos, true)
	return result_bitmap


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
func _create_polygon_from_region(image: Image, texture: ImageTexture, pixels: Dictionary, part_name: String, polygon_epsilon: float, seeds: Dictionary) -> Polygon2D:
	if pixels.is_empty():
		return null
	var bitmap = BitMap.new()
	bitmap.create(Vector2i(image.get_width(), image.get_height()))
	for pixel in pixels.keys():
		bitmap.set_bitv(pixel, true)

	var polygons = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), ATLAS_PIXEL_TO_UNIT_SCALE)
	if polygons.is_empty():
		print("  ❌ No se pudo generar contorno")
		return null

	var main_contour: PackedVector2Array = polygons[0]
	for poly in polygons:
		if poly.size() > main_contour.size():
			main_contour = poly

	print("  📐 Contorno: %d puntos" % main_contour.size())

	var simplified = _simplify_rdp(main_contour, polygon_epsilon)
	if simplified.size() < 3:
		simplified = main_contour
	else:
		print("  ✂️ Simplificado: %d puntos" % simplified.size())

	var cleaned = _clean_polygon(simplified)
	if cleaned.size() < 3:
		print("  ❌ Polígono inválido")
		return null

	var poly = Polygon2D.new()
	poly.name = part_name
	poly.texture = texture

	# pivote
	var pivot_point: Vector2
	var bounds = Rect2(cleaned[0], Vector2.ZERO)
	if seeds.has(part_name) and not seeds[part_name].is_empty():
		pivot_point = _normalize_seed_pos(seeds[part_name][0])
	else:
		for point in cleaned:
			bounds = bounds.expand(point)
		pivot_point = bounds.position + bounds.size / 2.0

	poly.position = pivot_point

	var local_points = PackedVector2Array()
	for point in cleaned:
		local_points.append(point - pivot_point)

	var uvs = PackedVector2Array()
	for point in cleaned:
		uvs.append(point)

	poly.polygon = local_points
	poly.uv = uvs

	if bounds.size == Vector2.ZERO:
		for point in cleaned:
			bounds = bounds.expand(point)

	if not _validate_triangulation(poly, local_points, bounds.position):
		return null

	print("  📍 Pos: %s | Tamaño: %.0fx%.0f" % [poly.position, bounds.size.x, bounds.size.y])
	return poly


# ------------------------------------------------------------------------------
## Creación de Polígono de Intersección
# ------------------------------------------------------------------------------
func _create_intersection_polygon(intersection_pixels: Dictionary, image: Image, texture: ImageTexture, name_a: String, name_b: String, polygon_epsilon: float) -> Polygon2D:
	if intersection_pixels == null or intersection_pixels.is_empty():
		return null
	print("  - Intersección encontrada: %d píxeles" % intersection_pixels.size())
	var intersection_name = "%s_%s_overlap" % [name_a, name_b]
	var fake_seeds = {}
	var poly = _create_polygon_from_region(image, texture, intersection_pixels, intersection_name, polygon_epsilon, fake_seeds)
	return poly


# ------------------------------------------------------------------------------
## Triangulación / Simplificación / Limpieza (sin cambios significativos)
# ------------------------------------------------------------------------------
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
	print("  ✅ Triangulación con simplificación agresiva")
	return true


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
		var left = _simplify_rdp(points.slice(0, index + 1), epsilon)
		var right = _simplify_rdp(points.slice(index, points.size()), epsilon)
		var result = PackedVector2Array()
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
	for i in range(points.size()):
		var current = points[i]
		var is_dup = false
		if cleaned.size() > 0:
			if current.distance_to(cleaned[cleaned.size() - 1]) < epsilon:
				is_dup = true
		if not is_dup:
			cleaned.append(current)
	if cleaned.size() > 0:
		if cleaned[0].distance_to(cleaned[cleaned.size() - 1]) < epsilon:
			cleaned.remove_at(cleaned.size() - 1)
	if cleaned.size() < 3:
		return points
	var final = PackedVector2Array()
	final.append(cleaned[0])
	for i in range(1, cleaned.size() - 1):
		var prev = cleaned[i - 1]
		var curr = cleaned[i]
		var next = cleaned[i + 1]
		var v1 = curr - prev
		var v2 = next - curr
		var cross = abs(v1.x * v2.y - v1.y * v2.x)
		if cross > epsilon:
			final.append(curr)
	final.append(cleaned[cleaned.size() - 1])
	return final if final.size() >= 3 else cleaned


# ------------------------------------------------------------------------------
## Util / normalización de seed (acepta Vector2 o Dict {pos:Vector2})
# ------------------------------------------------------------------------------
func _normalize_seed_pos(item) -> Vector2:
	if typeof(item) == TYPE_DICTIONARY and item.has("pos"):
		return item.pos
	return item
