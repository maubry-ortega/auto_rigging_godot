extends Node

var _rigging_state: RiggingState

# El corazón de la comunicación: la señal
signal part_name_added(new_name: String, all_parts: Array)

# Constantes globales del plugin
const ATLAS_PIXEL_TO_UNIT_SCALE = 2.0
const MAX_REGION_PIXELS = 400000

func initialize(rigging_state: RiggingState):
	_rigging_state = rigging_state

# GETTER
func get_part_names() -> Array:
	return _rigging_state.part_names.duplicate()  # Devolver copia para evitar modificaciones externas

# SETTER (con emisión de señal)
func add_part_name(name: String):
	print("[PartListManager] 🔄 Iniciando add_part_name con: '", name, "'")
	
	var clean_name = name.strip_edges().to_lower().replace(" ", "_")
	print("[PartListManager] 🔄 Nombre limpio: '", clean_name, "'")
	
	# Validar nombre
	if clean_name.is_empty():
		push_warning("El nombre de la parte no puede estar vacío.")
		print("[PartListManager] ❌ Nombre vacío rechazado")
		return false
		
	if clean_name in _rigging_state.part_names:
		push_warning("La parte '%s' ya existe." % clean_name)
		print("[PartListManager] ❌ Nombre duplicado rechazado: '", clean_name, "'")
		print("[PartListManager] 📋 Partes actuales: ", _rigging_state.part_names)
		return false
	
	# Añadir y emitir señal
	_rigging_state.part_names.append(clean_name)
	print("[PartListManager] ✅ Nueva parte añadida: ", clean_name)
	print("[PartListManager] 📋 Lista actualizada: ", _rigging_state.part_names)

	# EMITIR SEÑAL - ¡Esto es crucial!
	part_name_added.emit(clean_name, _rigging_state.part_names.duplicate())
	print("[PartListManager] 📢 Señal part_name_added emitida")
	
	return true

# Función para resetear a valores por defecto
func reset_to_default():
	_rigging_state.part_names = ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"]
	part_name_added.emit("", _rigging_state.part_names.duplicate())
