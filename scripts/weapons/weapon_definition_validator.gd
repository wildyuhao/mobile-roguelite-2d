extends RefCounted
class_name WeaponDefinitionValidator

const WeaponRequestBuilderScript = preload("res://scripts/weapons/weapon_request_builder.gd")
const TRIGGERS := {
	"periodic": true,
	"persistent": true,
	"on_player_hit": true,
	"on_kill": true,
}
const TARGETS := {
	"nearest": true,
	"lowest_health": true,
	"sector": true,
	"radial": true,
	"self": true,
}
const CARRIERS := {
	"projectile": true,
	"area": true,
	"orbit": true,
	"summon": true,
}
const STATUSES := {
	"burn": true,
	"freeze": true,
	"armor_break": true,
	"seal": true,
}
const SCHOOLS := {
	"sword": true,
	"talisman": true,
	"mechanism": true,
	"soul": true,
}
const OVERRIDE_FIELDS := {
	"trigger": {
		"cooldown": true,
		"event_cooldown": true,
	},
	"target": {
		"range": true,
		"angle_degrees": true,
	},
	"carrier": {
		"speed": true,
		"count": true,
		"pierce": true,
		"duration": true,
		"hit_interval": true,
		"radius": true,
		"angular_speed": true,
		"lifetime": true,
		"move_speed": true,
		"attack_interval": true,
		"attack_range": true,
	},
	"hit": {
		"damage": true,
		"splash_radius": true,
		"knockback": true,
		"statuses": true,
		"hit_effect_id": true,
	},
}

func validate(definition: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var weapon_id := String(definition.get("id", ""))
	if weapon_id == "":
		errors.append("weapon has empty id")
	if int(definition.get("version", 0)) != 1:
		errors.append("%s has unsupported version" % weapon_id)
	if String(definition.get("display_name", "")) == "":
		errors.append("%s has empty display_name" % weapon_id)
	if String(definition.get("description", "")) == "":
		errors.append("%s has empty description" % weapon_id)
	if not SCHOOLS.has(String(definition.get("school", ""))):
		errors.append("%s has unknown school" % weapon_id)
	if int(definition.get("max_level", 0)) != 5:
		errors.append("%s max_level must be 5" % weapon_id)

	var effect_ids := _validate_effects(errors, weapon_id, definition.get("effects", []))
	_validate_levels(errors, weapon_id, definition.get("levels", []), effect_ids)
	_validate_resolved_levels(errors, weapon_id, definition)
	_validate_visuals(errors, weapon_id, definition.get("visual", {}))
	return errors

func validate_catalog(definitions: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for catalog_id in definitions.keys():
		var definition_value: Variant = definitions[catalog_id]
		if typeof(definition_value) != TYPE_DICTIONARY:
			errors.append("weapon catalog item %s is not a dictionary" % catalog_id)
			continue
		var definition: Dictionary = definition_value
		if String(definition.get("id", "")) != String(catalog_id):
			errors.append("weapon catalog key %s does not match definition id" % catalog_id)
		errors.append_array(validate(definition))
	return errors

func _validate_effects(
	errors: Array[String],
	weapon_id: String,
	effects_value: Variant
) -> Dictionary:
	var effect_ids := {}
	if typeof(effects_value) != TYPE_ARRAY:
		errors.append("%s effects must be an array" % weapon_id)
		return effect_ids
	var effects: Array = effects_value
	if effects.is_empty() or effects.size() > 3:
		errors.append("%s must define one to three effects" % weapon_id)
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			errors.append("%s contains a non-dictionary effect" % weapon_id)
			continue
		var effect: Dictionary = effect_value
		var effect_id := String(effect.get("effect_id", ""))
		if effect_id == "" or effect_ids.has(effect_id):
			errors.append("%s has duplicate effect_id %s" % [weapon_id, effect_id])
		effect_ids[effect_id] = true
		var unlock_level := int(effect.get("unlock_level", 1))
		if unlock_level < 1 or unlock_level > 5:
			errors.append("%s/%s unlock level is outside 1..5" % [weapon_id, effect_id])
		_validate_module(errors, weapon_id, effect_id, "trigger", effect.get("trigger", {}), TRIGGERS)
		_validate_module(errors, weapon_id, effect_id, "target", effect.get("target", {}), TARGETS)
		_validate_module(errors, weapon_id, effect_id, "carrier", effect.get("carrier", {}), CARRIERS)
		_validate_effect_bounds(errors, weapon_id, effect_id, effect)
		_validate_hit(errors, weapon_id, effect_id, effect.get("hit", {}))
		if effect.has("visual"):
			_validate_visuals(errors, "%s/%s" % [weapon_id, effect_id], effect.get("visual", {}))
	return effect_ids

func _validate_levels(
	errors: Array[String],
	weapon_id: String,
	levels_value: Variant,
	effect_ids: Dictionary
) -> void:
	if typeof(levels_value) != TYPE_ARRAY:
		errors.append("%s levels must be an array" % weapon_id)
		return
	var seen_overrides := {}
	for level_value in Array(levels_value):
		if typeof(level_value) != TYPE_DICTIONARY:
			errors.append("%s contains a non-dictionary level" % weapon_id)
			continue
		var level: Dictionary = level_value
		var level_number := int(level.get("level", 0))
		var effect_id := String(level.get("effect_id", ""))
		var section := String(level.get("section", ""))
		if not effect_ids.has(effect_id):
			errors.append("%s level references missing effect_id %s" % [weapon_id, effect_id])
		if not OVERRIDE_FIELDS.has(section):
			errors.append("%s level has invalid section" % weapon_id)
		else:
			var values_value: Variant = level.get("values", {})
			if typeof(values_value) != TYPE_DICTIONARY:
				errors.append("%s level values must be a dictionary" % weapon_id)
			else:
				for key in Dictionary(values_value).keys():
					if not OVERRIDE_FIELDS[section].has(String(key)):
						errors.append("%s level has unsupported override %s" % [weapon_id, key])
		if level_number < 2 or level_number > 5:
			errors.append("%s level is outside 2..5" % weapon_id)
		var override_key := "%d/%s/%s" % [level_number, effect_id, section]
		if seen_overrides.has(override_key):
			errors.append("%s has duplicate level override %s" % [weapon_id, override_key])
		seen_overrides[override_key] = true

func _validate_visuals(
	errors: Array[String],
	weapon_id: String,
	visuals_value: Variant
) -> void:
	if typeof(visuals_value) != TYPE_DICTIONARY:
		errors.append("%s visual must be a dictionary" % weapon_id)
		return
	var visuals: Dictionary = visuals_value
	if visuals.is_empty():
		errors.append("%s has no visual references" % weapon_id)
	for path_value in visuals.values():
		var resource_path := String(path_value)
		if (
			resource_path == ""
			or not resource_path.begins_with("res://")
			or not ResourceLoader.exists(resource_path)
		):
			errors.append("%s references missing visual %s" % [weapon_id, resource_path])

func _validate_resolved_levels(
	errors: Array[String],
	weapon_id: String,
	definition: Dictionary
) -> void:
	var builder = WeaponRequestBuilderScript.new()
	for level in range(2, int(definition.get("max_level", 1)) + 1):
		for effect in builder.resolve_effects(definition, level):
			var level_errors: Array[String] = []
			var effect_id := String(effect.get("effect_id", ""))
			_validate_module(level_errors, weapon_id, effect_id, "trigger", effect.get("trigger", {}), TRIGGERS)
			_validate_module(level_errors, weapon_id, effect_id, "target", effect.get("target", {}), TARGETS)
			_validate_module(level_errors, weapon_id, effect_id, "carrier", effect.get("carrier", {}), CARRIERS)
			_validate_effect_bounds(level_errors, weapon_id, effect_id, effect)
			_validate_hit(level_errors, weapon_id, effect_id, effect.get("hit", {}))
			for error in level_errors:
				if not errors.has(error):
					errors.append(error)

func _validate_module(
	errors: Array[String],
	weapon_id: String,
	effect_id: String,
	label: String,
	module_value: Variant,
	registry: Dictionary
) -> void:
	if typeof(module_value) != TYPE_DICTIONARY:
		errors.append("%s/%s %s must be a dictionary" % [weapon_id, effect_id, label])
		return
	var module: Dictionary = module_value
	var module_id := String(module.get("id", ""))
	if not registry.has(module_id):
		errors.append("%s/%s has unknown %s %s" % [weapon_id, effect_id, label, module_id])
	if label == "trigger":
		if module_id == "periodic" and float(module.get("cooldown", 0.0)) <= 0.0:
			errors.append("%s/%s periodic cooldown must be positive" % [weapon_id, effect_id])
		if module_id.begins_with("on_") and float(module.get("event_cooldown", 0.0)) <= 0.0:
			errors.append("%s/%s event cooldown must be positive" % [weapon_id, effect_id])

func _validate_effect_bounds(
	errors: Array[String],
	weapon_id: String,
	effect_id: String,
	effect: Dictionary
) -> void:
	var target_value: Variant = effect.get("target", {})
	var carrier_value: Variant = effect.get("carrier", {})
	if typeof(target_value) != TYPE_DICTIONARY or typeof(carrier_value) != TYPE_DICTIONARY:
		return
	var target: Dictionary = target_value
	var carrier: Dictionary = carrier_value
	if String(target.get("id", "")) != "self" and float(target.get("range", 0.0)) <= 0.0:
		errors.append("%s/%s target range must be positive" % [weapon_id, effect_id])
	if target.has("angle_degrees"):
		var angle := float(target.get("angle_degrees", 0.0))
		if angle <= 0.0 or angle > 180.0:
			errors.append("%s/%s target angle is outside 0..180" % [weapon_id, effect_id])
	var count := int(carrier.get("count", 1))
	if count <= 0 or count > 12:
		errors.append("%s/%s carrier count is outside 1..12" % [weapon_id, effect_id])
	if float(carrier.get("duration", 0.0)) < 0.0:
		errors.append("%s/%s has negative duration" % [weapon_id, effect_id])
	if float(carrier.get("hit_interval", 0.1)) < 0.1:
		errors.append("%s/%s hit_interval must be at least 0.1" % [weapon_id, effect_id])
	var carrier_id := String(carrier.get("id", ""))
	if carrier_id == "projectile" and float(carrier.get("speed", 0.0)) <= 0.0:
		errors.append("%s/%s projectile speed must be positive" % [weapon_id, effect_id])
	if carrier_id == "orbit" and count > 8:
		errors.append("%s/%s orbit count exceeds 8" % [weapon_id, effect_id])
	if carrier_id == "summon" and count > 6:
		errors.append("%s/%s summon count exceeds 6" % [weapon_id, effect_id])

func _validate_hit(
	errors: Array[String],
	weapon_id: String,
	effect_id: String,
	hit_value: Variant
) -> void:
	if typeof(hit_value) != TYPE_DICTIONARY:
		errors.append("%s/%s hit must be a dictionary" % [weapon_id, effect_id])
		return
	var hit: Dictionary = hit_value
	if int(hit.get("damage", 0)) < 0:
		errors.append("%s/%s has negative damage" % [weapon_id, effect_id])
	var statuses_value: Variant = hit.get("statuses", [])
	if typeof(statuses_value) != TYPE_ARRAY:
		errors.append("%s/%s statuses must be an array" % [weapon_id, effect_id])
		return
	for status_value in Array(statuses_value):
		if typeof(status_value) != TYPE_DICTIONARY:
			errors.append("%s/%s contains a non-dictionary status" % [weapon_id, effect_id])
			continue
		var status: Dictionary = status_value
		if not STATUSES.has(String(status.get("id", ""))):
			errors.append("%s/%s has unknown status" % [weapon_id, effect_id])
		if int(status.get("stacks", 0)) <= 0 or float(status.get("duration", 0.0)) <= 0.0:
			errors.append("%s/%s has invalid status stacks or duration" % [weapon_id, effect_id])
