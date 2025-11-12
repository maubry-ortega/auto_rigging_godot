# ComponentFactory.gd - Factory Pattern for Creating Rigging Components
extends RefCounted

class_name ComponentFactory

# Create polygon generator based on type
static func create_polygon_generator(type: String = "optimized", hierarchy_builder = null) -> Object:
	match type:
		"optimized":
			var generator_script = load("res://addons/autorig2d/core/OptimizedPolygonGenerator.gd")
			var generator = generator_script.new(hierarchy_builder)
			return generator
		"basic":
			# Could implement a basic version later
			push_error("Basic polygon generator not implemented yet")
			return null
		_:
			push_error("Unknown polygon generator type: " + type)
			return null

# Create rig builder based on type
static func create_rig_builder(type: String = "generic", hierarchy_builder = null) -> Object:
	match type:
		"generic":
			var builder_script = load("res://addons/autorig2d/builders/GenericRigBuilder.gd")
			var builder = builder_script.new()
			if hierarchy_builder:
				builder.hierarchy_builder = hierarchy_builder
			return builder
		"basic":
			# Could implement a basic version later
			push_error("Basic rig builder not implemented yet")
			return null
		_:
			push_error("Unknown rig builder type: " + type)
			return null

# Create seed manager
static func create_seed_manager(rigging_state, coordinate_manager) -> Object:
	var manager = load("res://addons/autorig2d/managers/SeedManager.gd").new()
	manager.initialize(rigging_state, coordinate_manager)
	return manager

# Create coordinate manager
static func create_coordinate_manager(texture_rect = null, atlas_image = null) -> Object:
	var manager_script = load("res://addons/autorig2d/utils/CoordinateManager.gd")
	var manager = manager_script.new()
	if texture_rect and atlas_image:
		manager.initialize(texture_rect, atlas_image)
	return manager

# Create hierarchy builder
static func create_hierarchy_builder() -> Object:
	return load("res://addons/autorig2d/managers/SkeletonHierarchyBuilder.gd").new()

# Create weighting engine
static func create_weighting_engine(type: String = "optimized") -> Object:
	match type:
		"optimized":
			return load("res://addons/autorig2d/core/OptimizedWeightingEngine.gd").new()
		"basic":
			# Could implement a basic version later
			push_error("Basic weighting engine not implemented yet")
			return null
		_:
			push_error("Unknown weighting engine type: " + type)
			return null