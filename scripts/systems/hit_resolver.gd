extends RefCounted
class_name HitResolver

func resolve(target: Node, packet: Dictionary) -> Dictionary:
	return _resolve(target, packet, true, true)

func resolve_status_damage(target: Node, packet: Dictionary) -> Dictionary:
	var status_packet := packet.duplicate(true)
	var tags: Array = status_packet.get("damage_tags", []).duplicate()
	if not tags.has("status_damage"):
		tags.append("status_damage")
	status_packet["damage_tags"] = tags
	status_packet["status_payloads"] = []
	status_packet["knockback"] = 0.0
	return _resolve(target, status_packet, false, false)

func _resolve(
	target: Node,
	packet: Dictionary,
	apply_statuses: bool,
	apply_damage_modifier: bool
) -> Dictionary:
	var result := {
		"applied": false,
		"actual_damage": 0,
		"applied_statuses": [],
		"reaction_damage": 0,
		"target_dead": false,
	}
	if target == null or not is_instance_valid(target):
		return result
	var health := target.get_node_or_null("HealthComponent")
	if health == null or not health.has_method("take_damage"):
		return result
	var status := target.get_node_or_null("StatusController")
	var tags: Array = packet.get("damage_tags", []).duplicate()
	var multiplier := 1.0
	if apply_damage_modifier and status != null and status.has_method("get_damage_multiplier"):
		multiplier = float(status.get_damage_multiplier(tags))
	var damage: int = maxi(
		0,
		int(round(int(packet.get("base_damage", 0)) * multiplier))
	)
	var health_before := int(health.get("current_health"))
	if damage > 0:
		var weapon_id := String(packet.get("source_weapon_id", ""))
		if weapon_id != "":
			target.set_meta("last_weapon_id", weapon_id)
		health.take_damage(damage)
	result["actual_damage"] = maxi(0, health_before - int(health.get("current_health")))
	result["applied"] = damage > 0

	_apply_knockback(target, packet)
	if apply_statuses and status != null and status.has_method("apply_status"):
		var source := {
			"weapon_id": String(packet.get("source_weapon_id", "")),
			"source_instance_id": int(packet.get("source_instance_id", 0)),
		}
		for payload_value in packet.get("status_payloads", []):
			if typeof(payload_value) != TYPE_DICTIONARY:
				continue
			var payload: Dictionary = payload_value
			var status_result: Dictionary = status.apply_status(payload, source)
			if bool(status_result.get("applied", false)):
				result["applied_statuses"].append(String(payload.get("id", "")))
				result["applied"] = true
			var reaction_damage := int(status_result.get("thermal_shatter_damage", 0))
			if reaction_damage > 0:
				var reaction_packet := {
					"source_weapon_id": source["weapon_id"],
					"source_instance_id": source["source_instance_id"],
					"base_damage": reaction_damage,
					"damage_tags": ["reaction", "status_damage"],
					"knockback": 0.0,
					"hit_position": packet.get("hit_position", Vector2.ZERO),
					"status_payloads": [],
					"hit_effect_id": "thermal_shatter",
				}
				var reaction_result := resolve_status_damage(target, reaction_packet)
				result["reaction_damage"] = int(reaction_result.get("actual_damage", 0))
	result["target_dead"] = bool(health.call("is_dead")) if health.has_method("is_dead") else false
	return result

func _apply_knockback(target: Node, packet: Dictionary) -> void:
	if not target is Node2D:
		return
	var amount := float(packet.get("knockback", 0.0))
	if amount <= 0.0:
		return
	var target_node := target as Node2D
	var hit_position: Vector2 = packet.get("hit_position", target_node.global_position)
	var direction := hit_position.direction_to(target_node.global_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	target_node.global_position += direction * amount
