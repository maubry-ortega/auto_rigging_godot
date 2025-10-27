extends Node

# El corazón de la comunicación: la señal
signal part_name_added(new_name: String, all_parts: Array)

# Variable de datos central
const DEFAULT_PART_NAMES = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"]
var _part_names: Array = DEFAULT_PART_NAMES.duplicate()

# Constantes globales del plugin
const ATLAS_PIXEL_TO_UNIT_SCALE = 2.0
const MAX_REGION_PIXELS = 400000

# GETTER
func get_part_names() -> Array:
	return _part_names.duplicate()  # Devolver copia para evitar modificaciones externas

# SETTER (con emisión de señal)
func add_part_name(name: String):
	var clean_name = name.strip_edges().to_lower().replace(" ", "_")
	
	# Validar nombre
	if clean_name.is_empty():
		push_warning("El nombre de la parte no puede estar vacío.")
		return false
		
	if clean_name in _part_names:
		push_warning("La parte '%s' ya existe." % clean_name)
		return false
	
	# Añadir y emitir señal
	_part_names.append(clean_name)
	part_name_added.emit(clean_name, _part_names.duplicate())
	print("[PartListManager] Nueva parte añadida: ", clean_name)
	return true

# Función para resetear a valores por defecto
func reset_to_default():
	_part_names = DEFAULT_PART_NAMES.duplicate()
	part_name_added.emit("", _part_names.duplicate())
