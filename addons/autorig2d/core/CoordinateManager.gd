# CoordinateManager.gd
extends RefCounted

# --- Propiedades ---

# Referencia al nodo TextureRect que muestra el atlas
var texture_rect: TextureRect

# Referencia a la imagen del atlas
var atlas_image: Image

# --- Inicialización ---

# Inicializa el gestor con las referencias necesarias
func initialize(rect: TextureRect, image: Image):
	self.texture_rect = rect
	self.atlas_image = image

# --- Transformaciones de Coordenadas ---

# Convierte una posición desde el espacio del control UI (TextureRect)
# al espacio de píxeles de la imagen del atlas (lienzo).
func ui_to_canvas(ui_pos: Vector2) -> Vector2:
	var data = _get_texture_mapping_data()
	if not data:
		return Vector2.ZERO

	var pos = ui_pos - data.offset
	var canvas_pos = pos / data.draw_size * Vector2(data.tex_size)
	
	return canvas_pos

# Convierte una posición desde el espacio del lienzo (atlas)
# al espacio del control UI (TextureRect) para dibujar.
func canvas_to_ui(canvas_pos: Vector2) -> Vector2:
	var data = _get_texture_mapping_data()
	if not data:
		return Vector2.ZERO

	var ui_pos = canvas_pos / Vector2(data.tex_size) * data.draw_size + data.offset
	return ui_pos

# Convierte una posición desde el espacio del lienzo (atlas)
# al espacio de mundo de la escena final.
# Por ahora, asumimos que el origen del rig coincide con el origen del lienzo.
func canvas_to_world(canvas_pos: Vector2) -> Vector2:
	# En el futuro, aquí se podría añadir un offset global del rig.
	return canvas_pos

# --- Lógica Interna ---

# Calcula el tamaño y offset del atlas tal como se dibuja en el TextureRect.
# Esta es la lógica clave para mapear coordenadas.
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
