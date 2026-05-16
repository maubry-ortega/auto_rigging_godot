extends Node
class_name SeedManager
signal seeds_updated

const CoordinateManager = preload("res://addons/autorig2d/utils/CoordinateManager.gd")
const RiggingStateManager = preload("res://addons/autorig2d/managers/RiggingStateManager.gd")

var _rigging_state
var _coordinate_manager

var _hierarchy_builder

func initialize(rigging_state, coord_manager, hierarchy_builder = null):
	_rigging_state = rigging_state
	_coordinate_manager = coord_manager
	_hierarchy_builder = hierarchy_builder
	print("SeedManager initialized. _rigging_state is: ", _rigging_state)

func on_add_seed_pressed():
	print("SeedManager: on_add_seed_pressed called.")
	print("SeedManager: current_part_name before check: ", _rigging_state.current_part_name)
	# The UI should set _rigging_state.current_part_name before calling this.
	if _rigging_state.current_part_name.is_empty():
		push_error("Selecciona una parte primero.")
		return
	_rigging_state.adding_seeds = true # Assuming RiggingState will have this property
	print("SeedManager: adding_seeds set to: ", _rigging_state.adding_seeds)
	# Reiniciar las semillas para esta parte
	_rigging_state.seed_data[_rigging_state.current_part_name] = []
	# The TextureRect redraw will be handled by the UI observing RiggingState changes
	print("📍 Agregar semilla para:", _rigging_state.current_part_name)

func on_texture_gui_input(event):
	# Only process input if we are in "adding seeds" mode
	if not _rigging_state.adding_seeds:
		return

	if event is InputEventMouseButton and event.pressed:
		print("SeedManager: on_texture_gui_input called.")
		print("SeedManager: current_part_name in gui_input: ", _rigging_state.current_part_name)
		print("SeedManager: adding_seeds in gui_input: ", _rigging_state.adding_seeds)
		if _rigging_state.loaded_image_path.is_empty(): # Check if an image is loaded
			push_error("No hay atlas cargado.")
			_rigging_state.adding_seeds = false
			return

		if not _rigging_state.seed_data.has(_rigging_state.current_part_name):
			_rigging_state.seed_data[_rigging_state.current_part_name] = []

		if _rigging_state.seed_data[_rigging_state.current_part_name].size() >= 2:
			print("SeedManager: No se pueden agregar más de 2 semillas por parte.")
			_rigging_state.adding_seeds = false
			return

		var canvas_pos = _coordinate_manager.ui_to_canvas(event.position)
		_rigging_state.seed_data[_rigging_state.current_part_name].append(canvas_pos)
		

		# The UI will observe changes in _rigging_state.seed_data and redraw
		print("  ✅ %s → %s (Canvas: %s)" % [_rigging_state.current_part_name, event.position, canvas_pos])
		seeds_updated.emit()

func on_texture_rect_draw(rect: Control):
	# TODO: This drawing logic should ideally be moved to the UI (e.g., RiggingDock.gd)
	#       which observes changes in RiggingState.seed_data.
	# print("SeedManager: on_texture_rect_draw called.") # Spam reduction
	if _rigging_state.loaded_image_path.is_empty(): return
	
	# 1. Dibujar conexiones de jerarquía (huesos fantasma)
	if _hierarchy_builder:
		var hierarchy_name = _rigging_state.get_current_hierarchy()
		var hierarchy = _hierarchy_builder.get_hierarchy(hierarchy_name)
		
		for part_name in hierarchy.keys():
			var data = hierarchy[part_name]
			var parent_name = data.parent
			
			# Si tenemos semillas para esta parte y su padre, dibujar conexión
			if parent_name and not parent_name.is_empty():
				if _rigging_state.seed_data.has(part_name) and _rigging_state.seed_data.has(parent_name):
					var my_seeds = _rigging_state.seed_data[part_name]
					var parent_seeds = _rigging_state.seed_data[parent_name]
					
					if not my_seeds.is_empty() and not parent_seeds.is_empty():
						# Conectar el final del padre con el inicio del hijo
						# Si el padre tiene 2 semillas, el final es la segunda. Si tiene 1, es la primera.
						var parent_end_canvas = parent_seeds[-1]
						var my_start_canvas = my_seeds[0]
						
						var parent_end_ui = _coordinate_manager.canvas_to_ui(parent_end_canvas)
						var my_start_ui = _coordinate_manager.canvas_to_ui(my_start_canvas)
						
						rect.draw_line(parent_end_ui, my_start_ui, Color(0.0, 1.0, 1.0, 0.5), 2.0)
						rect.draw_circle(parent_end_ui, 3, Color(0.0, 1.0, 1.0, 0.5))

	# 2. Dibujar semillas y huesos internos
	for part in _rigging_state.seed_data.keys():
		var points_canvas = _rigging_state.seed_data[part]
		if points_canvas.is_empty():
			continue

		# Convertir a UI para dibujar
		var points_ui = []
		for p in points_canvas:
			points_ui.append(_coordinate_manager.canvas_to_ui(p))

		# Dibujar puntos
		for point in points_ui:
			rect.draw_circle(point, 4, Color.RED)

		# Dibujar línea y etiqueta
		if not points_ui.is_empty():
			rect.draw_string(rect.get_theme_font("font", "Label"), points_ui[0] + Vector2(8, 5), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

		if points_ui.size() >= 2:
			rect.draw_line(points_ui[0], points_ui[1], Color.YELLOW, 2.0)
