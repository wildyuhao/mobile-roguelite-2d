extends RefCounted
class_name WeaponRequestBuilder

func resolve_effects(definition: Dictionary, level: int) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for raw_effect in definition.get("effects", []):
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = raw_effect
		if int(effect.get("unlock_level", 1)) <= level:
			effects.append(effect.duplicate(true))

	for raw_override in definition.get("levels", []):
		if typeof(raw_override) != TYPE_DICTIONARY:
			continue
		var override: Dictionary = raw_override
		if int(override.get("level", 0)) > level:
			continue
		var effect := _find_effect(effects, String(override.get("effect_id", "")))
		var section := String(override.get("section", ""))
		if effect.is_empty() or not effect.has(section):
			continue
		var values_value: Variant = override.get("values", {})
		if typeof(values_value) != TYPE_DICTIONARY:
			continue
		var section_values: Dictionary = effect[section]
		for key in Dictionary(values_value).keys():
			section_values[key] = values_value[key]
	return effects

func _find_effect(effects: Array[Dictionary], effect_id: String) -> Dictionary:
	for effect in effects:
		if String(effect.get("effect_id", "")) == effect_id:
			return effect
	return {}
