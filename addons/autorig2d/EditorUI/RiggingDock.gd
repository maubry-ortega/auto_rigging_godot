@tool
extends VBoxContainer

# Constantes
const PART_NAMES = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg", "left_hand", "right_hand", "left_foot", "right_foot"]
const ATLAS_PIXEL_TO_UNIT_SCALE = 1.0 

# Variables de estado
var atlas_path: String = ""
var atlas_image: Image
var atlas_texture: ImageTexture
var seeds: Dictionary = {}

var adding_seeds: bool = false
var current_part_name: String = ""

# ==============================================================================
## Funciones Principales
# ==============================================================================

func generate_body_part_polygons(atlas_image: Image, atlas_texture: ImageTexture, seeds: Dictionary) -> Array[Polygon2D]:
	var generated_polygons: Array[Polygon2D] = []
	if not atlas_image:
		push_error("Atlas image is not set.")
		return []

	print("\n=== Iniciando generación de polígonos ===")
	print("Atlas size: ", atlas_image.get_size())
	print("Puntos semilla a procesar: ", seeds.size())

	for seed in seeds.keys():
		var part_name: String = seeds[seed]
		print("\n--- Procesando parte: '", part_name, "' ---")
		print("  Punto semilla original: ", seed)

		# 1. Flood fill - Ahora SÓLO usa la opacidad (alpha)
		var filled_area: Dictionary = _flood_fill(atlas_image, seed, 0.0)
		if filled_area.is_empty():
			print("  ❌ Parte '", part_name, "' falló: No se encontraron píxeles en el flood fill")
			continue

		# 2. Crear bitmap
		var bitmap := BitMap.new()
		bitmap.create(atlas_image.get_size())
		for pixel_pos in filled_area.keys():
			bitmap.set_bitv(pixel_pos, true)

		# 3. Generar contornos
		var polygons_from_bitmap: Array = bitmap.opaque_to_polygons(Rect2i(Vector2i(0,0), atlas_image.get_size()), ATLAS_PIXEL_TO_UNIT_SCALE)

		if polygons_from_bitmap.is_empty():
			print("  ❌ Parte '", part_name, "' falló: opaque_to_polygons no pudo generar un contorno")
			continue

		print("  Contornos generados: ", polygons_from_bitmap.size())

		# 4. Seleccionar el contorno más grande (principal)
		var main_contour: PackedVector2Array = polygons_from_bitmap[0]
		for p in polygons_from_bitmap:
			if p.size() > main_contour.size():
				main_contour = p

		print("  Puntos en contorno principal: ", main_contour.size())

		# 5. Simplificar contorno
		var simplified_contour: PackedVector2Array = _simplify_rdp(main_contour, 0.05) 
		if simplified_contour.size() < 3:
			print("  Simplificación falló, usando contorno original")
			simplified_contour = main_contour
		else:
			print("  Puntos después de simplificación: ", simplified_contour.size())

		# 6. Crear Polygon2D
		var poly_node: Polygon2D = _create_polygon2d(atlas_image, atlas_texture, simplified_contour, part_name)
		if is_instance_valid(poly_node):
			print("  ✅ Parte '", part_name, "' generada exitosamente")
			generated_polygons.append(poly_node)
		else:
			print("  ❌ Parte '", part_name, "' falló: No se pudo crear el nodo Polygon2D final")

	print("\n=== Generación completada: ", generated_polygons.size(), "/", seeds.size(), " partes exitosas ===")
	return generated_polygons


# ------------------------------------------------------------------------------
## Funciones Auxiliares
# ------------------------------------------------------------------------------

func _flood_fill(atlas_image: Image, start_pos: Vector2i, color_similarity_threshold: float) -> Dictionary:
	# ⚠️ MODIFICADO: Ignora la similitud de color y solo comprueba la opacidad.
	var img_width: int = atlas_image.get_width()
	var img_height: int = atlas_image.get_height()
	var alpha_threshold: float = 0.1 # Umbral de opacidad mínima

	if start_pos.x < 0 or start_pos.x >= img_width or start_pos.y < 0 or start_pos.y >= img_height:
		print("  Punto semilla fuera de límites: ", start_pos)
		return {}

	var effective_start_pos = start_pos
	var search_radius = 50 
	
	# Búsqueda de píxel opaco si el punto inicial es transparente
	if atlas_image.get_pixelv(effective_start_pos).a < alpha_threshold:
		print("  Punto semilla en área transparente. Buscando píxel opaco cercano (Radio %d)..." % search_radius)
		var found_opaque = false
		for y_offset in range(-search_radius, search_radius + 1):
			for x_offset in range(-search_radius, search_radius + 1):
				var check_pos = start_pos + Vector2i(x_offset, y_offset)
				if check_pos.x >= 0 and check_pos.x < img_width and check_pos.y >= 0 and check_pos.y < img_height:
					if atlas_image.get_pixelv(check_pos).a >= alpha_threshold:
						effective_start_pos = check_pos
						print("    Píxel opaco encontrado en: ", effective_start_pos)
						found_opaque = true
						break
			if found_opaque:
				break
		
		if not found_opaque:
			print("  ❌ No se encontró ningún píxel opaco cercano al punto semilla: ", start_pos)
			return {}

	var filled_pixels: Dictionary = {}
	var queue: Array[Vector2i] = [effective_start_pos]
	var visited: Dictionary = {}

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()

		if pos.x < 0 or pos.x >= img_width or pos.y < 0 or pos.y >= img_height:
			continue
		
		if visited.has(pos):
			continue
			
		visited[pos] = true

		var current_color: Color = atlas_image.get_pixelv(pos)
		
		# ⚠️ CAMBIO CRUCIAL: Solo verificamos opacidad.
		if current_color.a >= alpha_threshold: 
			filled_pixels[pos] = true
			
			queue.append(pos + Vector2i.RIGHT)
			queue.append(pos + Vector2i.LEFT)
			queue.append(pos + Vector2i.UP)
			queue.append(pos + Vector2i.DOWN)
			
	print("  Flood fill completado: ", filled_pixels.size(), " píxeles encontrados")
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

func _create_polygon2d(atlas_image: Image, atlas_texture: ImageTexture, contour: PackedVector2Array, part_name: String) -> Polygon2D:
	if contour.size() < 3:
		return null
	
	var cleaned_contour = _clean_polygon(contour)
	if cleaned_contour.size() < 3:
		return null
	
	var poly = Polygon2D.new()
	poly.name = part_name
	poly.texture = atlas_texture 

	# Calcular bounds
	var bounds := Rect2(cleaned_contour[0], Vector2(0,0))
	for p in cleaned_contour:
		bounds = bounds.expand(p)
	
	# Crear contorno local (relativo a la posición del Polygon2D)
	var local_contour: PackedVector2Array = PackedVector2Array()
	for p in cleaned_contour:
		local_contour.append(p - bounds.position)
	
	# Crear UVs normalizados (coordenadas de textura)
	var atlas_size = atlas_image.get_size()
	var uv_coords: PackedVector2Array = PackedVector2Array()
	for p in cleaned_contour:
		var uv = Vector2(
			clamp(p.x / atlas_size.x, 0.0, 1.0),
			clamp(p.y / atlas_size.y, 0.0, 1.0)
		)
		uv_coords.append(uv)
	
	# Asignar propiedades iniciales
	poly.position = bounds.position
	poly.polygon = local_contour
	poly.uv = uv_coords 

	# Triangulación de validación
	var final_polygon_points: PackedVector2Array = local_contour
	var point_indices = Geometry2D.triangulate_polygon(final_polygon_points)
	
	if point_indices.is_empty():
		print("  Triangulación falló. Intentando simplificar con RDP 0.01 como último recurso...")
		var simplified_contour: PackedVector2Array = _simplify_rdp(local_contour, 0.01)
		
		if simplified_contour.size() > 2:
			point_indices = Geometry2D.triangulate_polygon(simplified_contour)
			
			if not point_indices.is_empty():
				final_polygon_points = simplified_contour
				uv_coords.clear()
				for p in final_polygon_points:
					var uv = Vector2(
						clamp((p.x + bounds.position.x) / atlas_size.x, 0.0, 1.0),
						clamp((p.y + bounds.position.y) / atlas_size.y, 0.0, 1.0)
					)
					uv_coords.append(uv)
				poly.uv = uv_coords
				poly.polygon = final_polygon_points 
			else:
				print("  Fallo crítico de triangulación.")
				return null
		else:
			return null
	
	print("  Polygon2D creado exitosamente para '%s' con %d vértices" % [part_name, final_polygon_points.size()])
	return poly


func _clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	"""Limpia el polígono eliminando puntos duplicados y colineales"""
	if points.size() < 3:
		return points
	
	var cleaned: PackedVector2Array = PackedVector2Array()
	var epsilon: float = 0.5
	
	# Eliminar puntos duplicados y muy cercanos
	for i in range(points.size()):
		var current = points[i]
		var is_duplicate = false
		
		if cleaned.size() > 0:
			var last = cleaned[cleaned.size() - 1]
			if current.distance_to(last) < epsilon:
				is_duplicate = true
		
		if not is_duplicate:
			cleaned.append(current)
	
	if cleaned.size() > 0:
		var first = cleaned[0]
		var last = cleaned[cleaned.size() - 1]
		if first.distance_to(last) < epsilon:
			cleaned.remove_at(cleaned.size() - 1)
	
	if cleaned.size() < 3:
		return points

	# Eliminar puntos colineales
	var final: PackedVector2Array = PackedVector2Array()
	final.append(cleaned[0])

	for i in range(1, cleaned.size() - 1):
		var prev = cleaned[i - 1]
		var current = cleaned[i]
		var next = cleaned[i + 1]
		
		var v1 = current - prev
		var v2 = next - current
		var cross = abs(v1.x * v2.y - v1.y * v2.x)
		
		if cross > epsilon:
			final.append(current)
	
	final.append(cleaned[cleaned.size() - 1])
	
	if final.size() >= 3:
		var prev = final[final.size() - 1]
		var current = final[0]
		var next = final[1]
		var v1 = current - prev
		var v2 = next - current
		var cross = abs(v1.x * v2.y - v1.y * v2.x)
		if cross <= epsilon:
			final.remove_at(0)
	
	return final if final.size() >= 3 else cleaned

func _color_distance(c1: Color, c2: Color) -> float:
	var dr = c1.r - c2.r
	var dg = c1.g - c2.g
	var db = c1.b - c2.b
	return sqrt(dr*dr + dg*dg + db*db)


# ------------------------------------------------------------------------------
## Funciones de Interfaz (UI)
# ------------------------------------------------------------------------------

func _ready():
	# Connections
	$FileDialog.file_selected.connect(_on_file_selected)
	$HBoxContainer/SelectAtlasButton.pressed.connect(_on_select_atlas_pressed)
	$HBoxContainer/AddSeedButton.pressed.connect(_on_add_seed_pressed)
	$HBoxContainer/GenerateButton.pressed.connect(_on_generate_pressed)
	$TextureRect.gui_input.connect(_on_texture_gui_input)
	$TextureRect.draw.connect(_on_texture_rect_draw)
	
	# Populate OptionButton
	var option_button = $PartNameHBox/PartNameOptionButton
	option_button.clear()
	for part_name in PART_NAMES:
		option_button.add_item(part_name)

func _on_select_atlas_pressed():
	$FileDialog.popup()

func _on_file_selected(path: String):
	atlas_path = path
	atlas_image = Image.load_from_file(path)
	if atlas_image:
		atlas_texture = ImageTexture.create_from_image(atlas_image)
		$TextureRect.texture = atlas_texture
		print("Atlas cargado: ", atlas_path)
		seeds.clear()
		$TextureRect.queue_redraw()
	else:
		push_error("No se pudo cargar la imagen del atlas: " + path)


func _on_add_seed_pressed():
	var option_button = $PartNameHBox/PartNameOptionButton
	if option_button.get_selected_id() == -1:
		push_error("Por favor, selecciona una parte del cuerpo del menú desplegable.")
		return
		
	current_part_name = option_button.get_item_text(option_button.get_selected_id())
	adding_seeds = true
	print("Modo agregar puntos activado. Click para agregar seed point como: ", current_part_name)

func _on_texture_gui_input(event):
	if adding_seeds and event is InputEventMouseButton and event.pressed:
		if not atlas_image:
			push_error("No hay atlas cargado.")
			adding_seeds = false
			return
			
		var local_pos = $TextureRect.get_local_mouse_position()
		var img_size = atlas_image.get_size()
		var seed_key: Vector2i = Vector2i(int(local_pos.x), int(local_pos.y))
		
		# 🚀 MEJORA: Ajuste automático si el clic está fuera de los límites.
		if seed_key.x < 0 or seed_key.x >= img_size.x or seed_key.y < 0 or seed_key.y >= img_size.y:
			# Si el clic está fuera, forzamos el punto semilla al centro de la imagen.
			seed_key = Vector2i(img_size.x / 2, img_size.y / 2)
			push_warning("Punto de clic fuera de límites. Usando el centro de la imagen como punto semilla: " + str(seed_key))

		# Lógica para reemplazar el punto si la parte ya existe
		for existing_seed_name in seeds.values():
			if existing_seed_name == current_part_name:
				push_warning("Ya existe un punto para la parte '%s'. Reemplazando." % current_part_name)
				for key in seeds.keys():
					if seeds[key] == current_part_name:
						seeds.erase(key)
						break
				break
		
		seeds[seed_key] = current_part_name
		print("Punto agregado en:", seed_key, " como:", current_part_name)
		adding_seeds = false
		$TextureRect.queue_redraw()

func _on_texture_rect_draw():
	var texture_rect = $TextureRect
	for seed_pos in seeds.keys():
		var part_name = seeds[seed_pos]
		
		# Draw a circle for the seed point
		texture_rect.draw_circle(seed_pos, 5.0, Color.RED)
		
		# Draw the part name next to the point
		var font = get_theme_font("font", "Label")
		var font_size = get_theme_font_size("font_size", "Label")
		var text_pos = Vector2(seed_pos) + Vector2(10, 5)
		texture_rect.draw_string(font, text_pos, part_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _on_generate_pressed():
	if not atlas_image or atlas_path == "":
		push_error("Selecciona un atlas primero")
		return
	
	print("Iniciando proceso de generación de rig...")

	if seeds.is_empty():
		push_error("No se han añadido puntos semilla. Por favor, añada puntos antes de generar.")
		return

	var polygons = generate_body_part_polygons(atlas_image, atlas_texture, seeds)

	var generated_count = polygons.size()
	var seed_count = seeds.size()

	if generated_count == 0:
		push_error("No se generaron polígonos. Revisa los puntos semilla o la forma de las partes.")
		return

	# 2. Añadir los polígonos generados directamente a la escena
	print("Añadiendo polígonos a la escena...")
	
	var scene_root = get_tree().edited_scene_root
	
	var rig_root = Node2D.new()
	rig_root.name = "GeneratedRigRoot"
	
	# CORRECCIÓN DE OWNER 1: Añadir el nodo raíz ANTES de asignar el owner a sus hijos
	scene_root.add_child(rig_root)
	rig_root.owner = scene_root 
	
	var current_offset = 0.0
	
	for poly in polygons:
		if is_instance_valid(poly):
			
			# Calculamos los límites del polígono en su espacio local
			var poly_points = poly.polygon
			if poly_points.is_empty():
				continue

			var max_x = poly_points[0].x
			var min_x = poly_points[0].x
			
			for point in poly_points:
				max_x = max(max_x, point.x)
				min_x = min(min_x, point.x)
			
			var bounds_width = max_x - min_x
			
			# Ajustamos la posición x del polígono relativo al offset total
			poly.position.x += current_offset
			
			# Añadimos el Polygon2D a nuestro Node2D agrupador
			rig_root.add_child(poly)
			# CORRECCIÓN DE OWNER 2: Asignar owner después de que el poly es descendiente de scene_root
			poly.owner = scene_root 

			# Incrementamos el offset para la siguiente pieza
			current_offset += bounds_width + 10.0
			
			print("  Polígono '", poly.name, "' añadido en posición: ", poly.position)
			
	# 3. Reporte final
	print("Proceso de generación completado.")
	print(" - Puntos semilla procesados: %d" % seed_count)
	print(" - Polígonos generados con éxito: %d" % generated_count)
	if generated_count < seed_count:
		print(" - Polígonos fallidos: %d." % (seed_count - generated_count))
