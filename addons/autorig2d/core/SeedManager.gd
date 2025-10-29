extends Node

var ui
var coordinate_manager

func initialize(ui_node, coord_manager):
	ui = ui_node
	coordinate_manager = coord_manager

func on_add_seed_pressed():
	var opt = ui.get_node("PartNameHBox/PartNameOptionButton")
	if opt.get_selected_id() == -1:
		push_error("Selecciona una parte primero.")
		return
	ui.current_part_name = opt.get_item_text(opt.get_selected_id())
	ui.adding_seeds = true
	# Reiniciar las semillas para esta parte
	ui.seeds[ui.current_part_name] = []
	ui.get_node("TextureRect").queue_redraw()
	print("\n📍 Agregar semilla para:", ui.current_part_name)

func on_texture_gui_input(event):
	if ui.adding_seeds and event is InputEventMouseButton and event.pressed:
		if not ui.atlas_image:
			push_error("No hay atlas cargado.")
			ui.adding_seeds = false
			return

		var canvas_pos = coordinate_manager.ui_to_canvas(event.position)

		if not ui.seeds.has(ui.current_part_name):
			ui.seeds[ui.current_part_name] = []
		
		ui.seeds[ui.current_part_name].append(canvas_pos)
		
		# Detener después de 2 puntos
		if ui.seeds[ui.current_part_name].size() >= 2:
			ui.adding_seeds = false

		ui.get_node("TextureRect").queue_redraw()
		print("  ✅ %s → %s" % [ui.current_part_name, canvas_pos])

func on_texture_rect_draw():
	if not ui.atlas_image: return
	
	var rect = ui.get_node("TextureRect")
	
	for part in ui.seeds.keys():
		var points = ui.seeds[part]
		if points.is_empty():
			continue

		# Dibujar puntos
		for canvas_point in points:
			var ui_pos = coordinate_manager.canvas_to_ui(canvas_point)
			rect.draw_circle(ui_pos, 4, Color.RED)
		
		# Dibujar línea y etiqueta
		var first_pos_ui = coordinate_manager.canvas_to_ui(points[0])
		rect.draw_string(ui.get_theme_font("font","Label"), first_pos_ui + Vector2(8,5), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		
		if points.size() >= 2:
			var second_pos_ui = coordinate_manager.canvas_to_ui(points[1])
			rect.draw_line(first_pos_ui, second_pos_ui, Color.YELLOW, 2.0)
