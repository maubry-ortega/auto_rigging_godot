extends Node

var ui

func initialize(ui_node):
	ui = ui_node

func on_add_seed_pressed():
	var opt = ui.get_node("PartNameHBox/PartNameOptionButton")
	if opt.get_selected_id() == -1:
		push_error("Selecciona una parte primero.")
		return
	ui.current_part_name = opt.get_item_text(opt.get_selected_id())
	ui.adding_seeds = true
	print("\n📍 Agregar semilla para:", ui.current_part_name)

func on_texture_gui_input(event):
	if ui.adding_seeds and event is InputEventMouseButton and event.pressed:
		if not ui.atlas_image:
			push_error("No hay atlas cargado.")
			ui.adding_seeds = false
			return
		var data = _get_texture_mapping_data()
		if not data: return
		var tex_size = data.tex_size
		var draw_size = data.draw_size
		var offset = data.offset
		var pos = event.position - offset
		var img_pos = pos / draw_size * Vector2(tex_size)
		ui.seeds[ui.current_part_name] = img_pos
		ui.adding_seeds = false
		ui.get_node("TextureRect").queue_redraw()
		print("  ✅ %s → %s" % [ui.current_part_name, img_pos])

func on_texture_rect_draw():
	if not ui.atlas_image: return
	var rect = ui.get_node("TextureRect")
	var data = _get_texture_mapping_data()
	if not data: return
	for part in ui.seeds.keys():
		var pos = ui.seeds[part] / Vector2(data.tex_size) * data.draw_size + data.offset
		rect.draw_circle(pos, 4, Color.RED)
		rect.draw_string(ui.get_theme_font("font","Label"), pos + Vector2(8,5), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _get_texture_mapping_data():
	var rect = ui.get_node("TextureRect")
	var tex_size = ui.atlas_image.get_size()
	var rect_size = rect.get_size()

	if rect_size.x <= 0 or rect_size.y <= 0 or tex_size.x <= 0 or tex_size.y <= 0:
		return null

	var tex_aspect = float(tex_size.x) / tex_size.y
	var rect_aspect = rect_size.x / rect_size.y
	var draw_size = Vector2()
	var offset = Vector2()

	if tex_aspect > rect_aspect:
		draw_size.x = rect_size.x
		draw_size.y = rect_size.x / tex_aspect
		offset.y = (rect_size.y - draw_size.y) / 2.0
	else:
		draw_size.y = rect_size.y
		draw_size.x = rect_size.y * tex_aspect
		offset.x = (rect_size.x - draw_size.x) / 2.0

	if draw_size.x <= 0 or draw_size.y <= 0:
		return null

	return {"tex_size": tex_size, "draw_size": draw_size, "offset": offset}
