# CoordinateManager.gd
extends RefCounted
class_name CoordinateManager

# --- Propiedades ---
var texture_rect: TextureRect
var atlas_image: Image
var rig_offset: Vector2 = Vector2.ZERO

func initialize(rect: TextureRect, image: Image):
	self.texture_rect = rect
	self.atlas_image = image

func set_atlas_image(image: Image):
	self.atlas_image = image

func set_texture_rect(rect: TextureRect):
	self.texture_rect = rect

func set_rig_offset(offset: Vector2):
	rig_offset = offset

# Convierte UI -> canvas (pixeles del atlas)
func ui_to_canvas(ui_pos: Vector2) -> Vector2:
	var data = _get_texture_mapping_data()
	if not data:
		return Vector2.ZERO

	var pos = ui_pos - data.offset
	var canvas_pos = Vector2(0,0)
	if data.draw_size.x > 0 and data.tex_size.x > 0:
		canvas_pos = pos / data.draw_size * Vector2(data.tex_size)
	return canvas_pos

# Convierte canvas -> UI
func canvas_to_ui(canvas_pos: Vector2) -> Vector2:
	var data = _get_texture_mapping_data()
	if not data:
		return Vector2.ZERO

	var ui_pos = canvas_pos / Vector2(data.tex_size) * data.draw_size + data.offset
	return ui_pos

# Convierte canvas -> world (aplicando rig_offset si corresponde)
func canvas_to_world(canvas_pos: Vector2) -> Vector2:
	# Asumimos coordenadas del atlas en pixels: simplemente aplicar offset del rig si se ha definido
	return canvas_pos - rig_offset

# Convierte world -> canvas
func world_to_canvas(world_pos: Vector2) -> Vector2:
	return world_pos + rig_offset

func _get_texture_mapping_data() -> Dictionary:
	if not is_instance_valid(texture_rect) or not atlas_image:
		return {}

	var tex_size = atlas_image.get_size()
	var rect_size = texture_rect.size

	if rect_size.x <= 0 or rect_size.y <= 0 or tex_size.x <= 0 or tex_size.y <= 0:
		return {}

	var tex_aspect = float(tex_size.x) / tex_size.y
	var rect_aspect = rect_size.x / rect_size.y
	
	var draw_size := Vector2.ZERO
	var offset := Vector2.ZERO

	if tex_aspect > rect_aspect:
		draw_size.x = rect_size.x
		draw_size.y = rect_size.x / tex_aspect
		offset.y = (rect_size.y - draw_size.y) / 2.0
	else:
		draw_size.y = rect_size.y
		draw_size.x = rect_size.y * tex_aspect
		offset.x = (rect_size.x - draw_size.x) / 2.0

	if draw_size.x <= 0 or draw_size.y <= 0:
		return {}

	return {"tex_size": tex_size, "draw_size": draw_size, "offset": offset}
