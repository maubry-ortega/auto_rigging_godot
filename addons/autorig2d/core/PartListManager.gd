extends Node

# El corazón de la comunicación: la señal
signal part_name_added(new_name: String, all_parts: Array)

# Variable de datos central. Antes era una @export en el VBoxContainer.
# Usamos una función para acceder a ella para mayor control.
const DEFAULT_PART_NAMES = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg", "left_hand", "right_hand", "left_foot", "right_foot"]
var _part_names: Array = DEFAULT_PART_NAMES.duplicate()

# Constantes globales del plugin, movidas para centralizar
const ATLAS_PIXEL_TO_UNIT_SCALE = 2.0
const MAX_REGION_PIXELS = 400000

# GETTER
func get_part_names() -> Array:
	return _part_names

# SETTER (con emisión de señal)
func add_part_name(name: String):
	var clean_name = name.strip_edges().to_lower()
	if not _part_names.has(clean_name):
		_part_names.append(clean_name)
		# 1. Emite la señal con el nuevo nombre y la lista completa
		part_name_added.emit(clean_name, _part_names)
		print("[PartListManager] Nueva parte añadida: ", clean_name)
	else:
		print("[PartListManager] La parte ", clean_name, " ya existe.")
