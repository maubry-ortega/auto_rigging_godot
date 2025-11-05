# PolygonGenerator.gd
extends RefCounted

# Constantes
const ATLAS_PIXEL_TO_UNIT_SCALE = 1.0
const MAX_REGION_PIXELS = 400000
const MIN_REGION_PIXELS = 30

# ==============================================================================
## Funciones Principales
# ==============================================================================

func generate_body_part_polygons(atlas_image: Image, atlas_texture: ImageTexture, seeds: Dictionary, polygon_epsilon: float) -> Dictionary:
	var generated_polygons: Array = []
	var part_origins: Dictionary = {} # Diccionario para almacenar los orígenes de las partes
	if not atlas_image: # Verificar si la imagen del atlas está configurada
		push_error("Atlas image is not set.") # Mostrar error si no hay imagen
		return {} # Retornar diccionario vacío

	print("\n=== 🎨 Iniciando generación ===") # Mensaje de inicio
	print("Atlas: ", atlas_image.get_size()) # Imprimir tamaño del atlas
	print("Partes: ", seeds.size()) # Imprimir número de partes
	print("Epsilon: ", polygon_epsilon) # Imprimir valor de epsilon

	# PASO 1: Extraer TODAS las regiones conectadas del atlas (basado en píxeles opacos)
	var all_regions = _extract_all_regions(atlas_image) # Llamar a la función para extraer regiones
	print("\n🔍 Regiones detectadas: ", all_regions.size()) # Imprimir número de regiones detectadas

	# Marcar todas las regiones como no usadas
	var used_regions: Array[bool] = []
	for i in range(all_regions.size()):
		used_regions.append(false)

	# PASO 2: Crear mapeo semilla → región que la contiene
	var seed_to_region = {} # Diccionario para mapear nombres de partes a índices de región

	for part_name in seeds.keys(): # Iterar sobre cada nombre de parte en las semillas
		var seed_points = seeds[part_name] # Obtener los puntos de semilla para la parte actual
		if seed_points.is_empty(): # Si no hay puntos de semilla, saltar
			continue
		
		var seed_pos = seed_points[0] # Tomar el primer punto de semilla
		var seed_pos_int = Vector2i(seed_pos) # Convertir a Vector2i
		var best_region: int = -1 # Inicializar el índice de la mejor región

		# Buscar la región que CONTIENE la semilla
		for i in range(all_regions.size()): # Iterar sobre todas las regiones
			if used_regions[i]: # Si la región ya ha sido usada, saltar
				continue

			var region = all_regions[i] # Obtener la región actual
			if region.has(seed_pos_int): # Si la región contiene el punto de semilla
				best_region = i # Asignar el índice de la región
				break # Salir del bucle, ya se encontró la región

		if best_region != -1: # Si se encontró una región
			seed_to_region[part_name] = best_region # Mapear la parte a la región
			used_regions[best_region] = true  # Marcar la región como usada
			print("  '%s' → región #%d (contenida)" % [part_name, best_region]) # Imprimir mensaje
		else: # Si no se encontró una región
			print("  ❌ '%s' no encontró región. La semilla debe estar dentro de la pieza." % part_name) # Imprimir error

	# PASO 3: Generar polígonos para cada parte
	for part_name in seeds.keys(): # Iterar sobre cada nombre de parte en las semillas
		print("\n--- Procesando: '%s' ---" % part_name) # Mensaje de procesamiento
		print("  Semilla: ", seeds[part_name]) # Imprimir puntos de semilla

		if not seed_to_region.has(part_name):
			print("  ❌ No se asignó región")
			continue

		var region_idx = seed_to_region[part_name]
		var region = all_regions[region_idx]

		print("  ✅ Región: %d píxeles" % region.size())
		# Crear el polígono a partir de la región
		var poly = _create_polygon_from_region(atlas_image, atlas_texture, region, part_name, polygon_epsilon, seeds) 

		if is_instance_valid(poly):
			generated_polygons.append(poly)
			part_origins[part_name] = poly.position
		else:
			print("  ❌ Fallo al crear polígono")

	# PASO 4: Generar polígonos para las INTERSECCIONES
	print("\n--- 🔗 Buscando intersecciones ---")
	var part_names = seed_to_region.keys() # Obtener los nombres de las partes
	var image_size = atlas_image.get_size() # Obtener el tamaño de la imagen del atlas
	var dilation_amount = 10 # Cantidad de píxeles para dilatar las regiones

	for i in range(part_names.size()): # Iterar sobre los nombres de las partes
		for j in range(i + 1, part_names.size()): # Iterar sobre las partes restantes para formar pares
			var name_a = part_names[i] # Primer nombre de parte
			var name_b = part_names[j] # Segundo nombre de parte
			
			var region_a = all_regions[seed_to_region[name_a]] # Región de la parte A
			var region_b = all_regions[seed_to_region[name_b]] # Región de la parte B

			# --- Nuevo método optimizado con BitMap ---
			# 1. Crear Bitmaps para cada región
			var bmp_a = BitMap.new() # Crear un nuevo BitMap para la región A
			bmp_a.create(image_size) # Inicializar el BitMap con el tamaño de la imagen
			for pixel in region_a.keys(): # Iterar sobre los píxeles de la región A
				bmp_a.set_bitv(pixel, true) # Establecer el bit correspondiente a true

			var bmp_b = BitMap.new() # Crear un nuevo BitMap para la región B
			bmp_b.create(image_size) # Inicializar el BitMap con el tamaño de la imagen
			for pixel in region_b.keys(): # Iterar sobre los píxeles de la región B
				bmp_b.set_bitv(pixel, true) # Establecer el bit correspondiente a true
			
			# 2. Dilatar ambos bitmaps (operación nativa y rápida)
			var image_rect = Rect2i(Vector2i.ZERO, image_size) # Crear un Rect2i que abarque toda la imagen
			bmp_a.grow_mask(dilation_amount, image_rect) # Dilatar el BitMap A
			bmp_b.grow_mask(dilation_amount, image_rect) # Dilatar el BitMap B
			
			# 3. Encontrar la intersección con una operación bitwise AND
			bmp_a = _bitmap_bitwise_and(bmp_a, bmp_b) # Realizar la operación AND bit a bit
			
			# 4. Convertir el bitmap de intersección de nuevo a un diccionario de píxeles
			var intersection_pixels = {} # Diccionario para almacenar los píxeles de la intersección
			var bmp_size = bmp_a.get_size()
			for y in range(bmp_size.y):
				for x in range(bmp_size.x):
					var pos = Vector2i(x, y)
					if bmp_a.get_bitv(pos):
						intersection_pixels[pos] = true
			# --- Fin del nuevo método ---

			print("  - '%s' y '%s'" % [name_a, name_b])
			
			if not intersection_pixels.is_empty(): # Si hay píxeles en la intersección
				var intersection_poly = _create_intersection_polygon(intersection_pixels, atlas_image, atlas_texture, name_a, name_b, polygon_epsilon) # Crear polígono de intersección
				if is_instance_valid(intersection_poly):
					generated_polygons.append(intersection_poly)
					part_origins[intersection_poly.name] = intersection_poly.position
			else:
				print("  - No se encontró intersección.")

	print("\n=== ✅ Completado: %d/%d partes ===" % [generated_polygons.size(), seeds.size()]) # Mensaje de finalización
	return {"polygons": generated_polygons, "origins": part_origins}


# ------------------------------------------------------------------------------
## Extracción de Todas las Regiones (Flood Fill)
# ------------------------------------------------------------------------------

func _extract_all_regions(image: Image) -> Array:
	var width = image.get_width()
	var height = image.get_height() # Altura de la imagen
	var alpha_threshold = 0.1 # Umbral de transparencia para considerar un píxel opaco
	var visited = {} # Diccionario para almacenar los píxeles ya visitados (globalmente)
	var regions = [] # Array para almacenar las regiones detectadas
	
	print("🔎 Escaneando atlas para detectar regiones...") # Mensaje de escaneo
	
	for y in range(height): # Iterar sobre cada fila de píxeles
		for x in range(width): # Iterar sobre cada columna de píxeles
			var pos = Vector2i(x, y) # Posición actual del píxel
			var pos_key = "%d,%d" % [x, y] # Clave para el diccionario visited
			
			if visited.has(pos_key): # Si el píxel ya fue visitado, saltar
				continue
			
			var color = image.get_pixelv(pos) # Obtener el color del píxel
			if color.a < alpha_threshold: # Si el píxel es transparente
				visited[pos_key] = true # Marcarlo como visitado
				continue # Saltar al siguiente píxel
			
			# Encontramos un nuevo píxel opaco no visitado, iniciar un flood fill
			var region = _flood_fill_simple(image, pos, visited, alpha_threshold) # Realizar flood fill
			
			if region.size() > MIN_REGION_PIXELS: # Si la región es lo suficientemente grande (no ruido)
				regions.append(region) # Añadir la región al array de regiones
				print("  → Región encontrada: %d píxeles" % region.size()) # Imprimir tamaño de la región
	
	return regions # Retornar todas las regiones encontradas


func _flood_fill_simple(image: Image, start: Vector2i, visited_global: Dictionary, threshold: float) -> Dictionary:
	var width = image.get_width() # Ancho de la imagen
	var height = image.get_height()
	var region = {}
	var queue = [start]
	var visited_local = {}
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		# Verificar límites de la imagen
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height: 
			continue # Si está fuera de límites, saltar
		
		var pos_key = "%d,%d" % [pos.x, pos.y] # Clave para el diccionario de visitados
		
		if visited_local.has(pos_key): # Si ya fue visitado localmente, saltar
			continue
		
		visited_local[pos_key] = true # Marcar como visitado localmente
		visited_global[pos_key] = true # Marcar como visitado globalmente
		
		# Verificar si el píxel es opaco
		var color = image.get_pixelv(pos) # Obtener el color del píxel
		if color.a < threshold: # Si es transparente, saltar
			continue
		
		# Añadir el píxel a la región
		region[pos] = true # Añadir el píxel al diccionario de la región
		
		# Expandir a los vecinos (4 direcciones)
		queue.append(pos + Vector2i(1, 0)) # Derecha
		queue.append(pos + Vector2i(-1, 0))
		queue.append(pos + Vector2i(0, 1))
		queue.append(pos + Vector2i(0, -1))
		
		# Límite de seguridad
		if region.size() > MAX_REGION_PIXELS:
			break

	return region

# ------------------------------------------------------------------------------
## Dilatación (Método manual - LENTO)
# ------------------------------------------------------------------------------
func _dilate_region(region: Dictionary, amount: int, image_size: Vector2i) -> Dictionary:
	var dilated = region.duplicate(true)
	var width = image_size.x
	var height = image_size.y # Altura de la imagen

	for p in region.keys(): # Iterar sobre cada píxel en la región original
		for y in range(p.y - amount, p.y + amount + 1): # Iterar en el rango de dilatación en Y
			for x in range(p.x - amount, p.x + amount + 1): # Iterar en el rango de dilatación en X
				if x < 0 or x >= width or y < 0 or y >= height: # Verificar límites de la imagen
					continue # Si está fuera de límites, saltar
				var new_pos = Vector2i(x, y) # Nueva posición del píxel
				if not dilated.has(new_pos): # Si el píxel no está ya en la región dilatada
					dilated[new_pos] = true # Añadirlo
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

	# Recorrer todos los píxeles del bitmap y aplicar AND manual
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
		return 0.0 # Si la semilla está en la región, la distancia es 0
	
	var min_sq = INF # Inicializar la distancia cuadrada mínima a infinito
	for key in region.keys(): # Iterar sobre cada píxel en la región
		var p = Vector2(key) # Convertir la clave a Vector2
		var dsq = seed.distance_squared_to(p) # Calcular la distancia cuadrada entre la semilla y el píxel
		if dsq < min_sq: # Si la distancia cuadrada actual es menor que la mínima
			min_sq = dsq # Actualizar la distancia cuadrada mínima
	
	if min_sq == INF: # Si no se encontró ningún píxel (región vacía o error)
		return INF # Retornar infinito
	return sqrt(min_sq)


# ------------------------------------------------------------------------------
## Crear Polígono desde Región
# ------------------------------------------------------------------------------

func _create_polygon_from_region(image: Image, texture: ImageTexture, pixels: Dictionary, part_name: String, polygon_epsilon: float, seeds: Dictionary) -> Polygon2D:
	if pixels.is_empty():
		return null # Si no hay píxeles, no se puede crear un polígono
	
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

	if polygons.is_empty(): # Si no se generaron contornos
		print("  ❌ No se pudo generar contorno") # Imprimir error
		return null # Retornar null
	
	# 3. Contorno principal (más grande)
	var main_contour: PackedVector2Array = polygons[0] # Asumir el primer polígono como el principal
	for poly in polygons:
		if poly.size() > main_contour.size():
			main_contour = poly
	
	print("  📐 Contorno: %d puntos" % main_contour.size())
	
	# 4. Simplificar
	var simplified = _simplify_rdp(main_contour, polygon_epsilon) # Simplificar el contorno usando RDP
	
	if simplified.size() < 3: # Si el polígono simplificado tiene menos de 3 puntos (inválido)
		simplified = main_contour # Usar el contorno original
	else: # Si la simplificación fue exitosa
		print("  ✂️ Simplificado: %d puntos" % simplified.size()) # Imprimir el número de puntos simplificados
	
	# 5. Limpiar
	var cleaned = _clean_polygon(simplified) # Limpiar el polígono (eliminar duplicados y colineales)
	
	if cleaned.size() < 3: # Si el polígono limpiado tiene menos de 3 puntos (inválido)
		print("  ❌ Polígono inválido") # Imprimir error
		return null # Retornar null
	
	# 6. Crear Polygon2D
	var poly = Polygon2D.new()
	poly.name = part_name
	poly.texture = texture
	
	# 7. Determinar el pivote
	var pivot_point: Vector2
	var bounds = Rect2(cleaned[0], Vector2.ZERO) # Inicializar bounds con el primer punto
	# El pivote es el primer punto de la semilla para un control preciso
	if seeds.has(part_name) and not seeds[part_name].is_empty():
		pivot_point = seeds[part_name][0] # Usar el primer punto de semilla como pivote
	else: # Si no hay semillas o están vacías
		# Fallback al centro geométrico si no hay semillas
		for point in cleaned: # Expandir los bounds para incluir todos los puntos
			bounds = bounds.expand(point) 
		pivot_point = bounds.position + bounds.size / 2.0

	# La POSICIÓN del nodo es el punto de pivote
	poly.position = pivot_point
	
	# 8. Contorno LOCAL (relativo al pivote)
	var local_points = PackedVector2Array()
	for point in cleaned: # Iterar sobre los puntos limpiados
		local_points.append(point - pivot_point) # Calcular la posición relativa al pivote
	
	# 9. UVs en coordenadas del ATLAS (globales, sin restar position)
	var uvs = PackedVector2Array()
	for point in cleaned: # Iterar sobre los puntos limpiados
		uvs.append(point)  # Añadir las coordenadas GLOBALES del atlas como UVs
	
	poly.polygon = local_points # Asignar los puntos locales al polígono
	poly.uv = uvs # Asignar las UVs al polígono
	
	# 10. Validar triangulación
	# Para validar, necesitamos los bounds, asegurémonos de que se calculen si no lo fueron antes
	if bounds.size == Vector2.ZERO:
		for point in cleaned:
			bounds = bounds.expand(point)
	
	if not _validate_triangulation(poly, local_points, bounds.position):
		return null
	
	print("  📍 Pos: %s | Tamaño: %.0fx%.0f" % [poly.position, bounds.size.x, bounds.size.y])
	return poly # Retornar el Polygon2D creado


# ------------------------------------------------------------------------------
## Creación de Polígono de Intersección
# ------------------------------------------------------------------------------
func _create_intersection_polygon(intersection_pixels: Dictionary, image: Image, texture: ImageTexture, name_a: String, name_b: String, polygon_epsilon: float) -> Polygon2D:

	if intersection_pixels.size() < MIN_REGION_PIXELS:
		return null # Si la intersección es muy pequeña, no crear polígono

	print("  - Intersección encontrada: %d píxeles" % intersection_pixels.size()) # Imprimir tamaño de la intersección

	# 2. Crear un polígono a partir de los píxeles de la intersección
	# Usamos un nombre combinado para la nueva parte
	var intersection_name = "%s_%s_overlap" % [name_a, name_b] # Crear un nombre para el polígono de intersección
	
	# Para la intersección, no tenemos una semilla predefinida. 
	# El pivote se calculará como el centroide del polígono resultante.
	var fake_seeds = {} # Diccionario vacío para las semillas (no se usan para intersecciones)

	var poly = _create_polygon_from_region(image, texture, intersection_pixels, intersection_name, polygon_epsilon, fake_seeds) # Crear el polígono
	
	return poly # Retornar el polígono de intersección


func _validate_triangulation(poly: Polygon2D, points: PackedVector2Array, offset: Vector2) -> bool:
	var indices = Geometry2D.triangulate_polygon(points)
	
	if not indices.is_empty():
		return true

	print("  ⚠️ Triangulación falló, simplificando...") # Mensaje de advertencia
	
	var simplified = _simplify_rdp(points, 2.0) # Intentar simplificar el polígono con un epsilon más agresivo
	
	if simplified.size() < 3: # Si el polígono simplificado es inválido
		return false # Fallar la validación
	
	indices = Geometry2D.triangulate_polygon(simplified) # Intentar triangulación de nuevo
	
	if indices.is_empty(): # Si la triangulación sigue fallando
		return false # Fallar la validación
	
	# Si la triangulación fue exitosa con la versión simplificada
	
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
