extends Node
signal seeds_updated

const CoordinateManager = preload("res://addons/autorig2d/core/CoordinateManager.gd")
const RiggingState = preload("res://addons/autorig2d/core/RiggingState.gd")

var _rigging_state: RiggingState
var _coordinate_manager: CoordinateManager

func initialize(rigging_state: RiggingState, coord_manager: CoordinateManager):
	_rigging_state = rigging_state
	_coordinate_manager = coord_manager
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

		var canvas_pos = _coordinate_manager.ui_to_canvas(event.position)

		if not _rigging_state.seed_data.has(_rigging_state.current_part_name):
			_rigging_state.seed_data[_rigging_state.current_part_name] = []
		
		_rigging_state.seed_data[_rigging_state.current_part_name].append(canvas_pos)
		
		# Detener después de 2 puntos
		if _rigging_state.seed_data[_rigging_state.current_part_name].size() >= 2:
			_rigging_state.adding_seeds = false

		# The UI will observe changes in _rigging_state.seed_data and redraw
		print("  ✅ %s → %s" % [_rigging_state.current_part_name, canvas_pos])
		seeds_updated.emit()

func on_texture_rect_draw(rect: Control):
	# TODO: This drawing logic should ideally be moved to the UI (e.g., RiggingDock.gd)
	#       which observes changes in RiggingState.seed_data.
	print("SeedManager: on_texture_rect_draw called.")
	if _rigging_state.loaded_image_path.is_empty(): return
	
	for part in _rigging_state.seed_data.keys():
		var points = _rigging_state.seed_data[part]
		if points.is_empty():
			continue

		# Dibujar puntos
		for canvas_point in points:
			var ui_pos = _coordinate_manager.canvas_to_ui(canvas_point)
			rect.draw_circle(ui_pos, 4, Color.RED)
		
		# Dibujar línea y etiqueta
		var first_pos_ui = _coordinate_manager.canvas_to_ui(points[0])
		rect.draw_string(rect.get_theme_font("font","Label"), first_pos_ui + Vector2(8,5), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		
		if points.size() >= 2:
			var second_pos_ui = _coordinate_manager.canvas_to_ui(points[1])
			rect.draw_line(first_pos_ui, second_pos_ui, Color.YELLOW, 2.0)
