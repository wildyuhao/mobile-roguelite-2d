extends RefCounted

const WEAPON_IDS: Array[String] = [
	"demon_sealing_bell",
	"flying_sword",
	"frost_talisman",
	"mechanism_crossbow",
	"soul_lantern",
	"spirit_needle_array",
	"sword_gourd_blades",
	"talisman_fire",
]
const SIGNATURE_KEYS: Array[String] = [
	"cadence",
	"target_mode",
	"carrier",
	"count",
	"area",
	"status",
	"persistence",
]
const POOL_LIMITS := {
	"projectile": 250,
	"area": 24,
	"orbit": 32,
	"summon": 12,
}

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/weapon_simulator.gd"):
		runner.assert_true(false, "weapon simulator script should exist")
		return
	var simulator_script = load("res://scripts/systems/weapon_simulator.gd")
	var simulator = simulator_script.new()

	var first_loadout: Array[String] = [
		"talisman_fire",
		"frost_talisman",
		"demon_sealing_bell",
		"sword_gourd_blades",
	]
	var first: Dictionary = simulator.run(20260713, 30.0, first_loadout)
	var repeated: Dictionary = simulator.run(20260713, 30.0, first_loadout)
	runner.assert_eq(first, repeated, "identical seeds should produce identical reports")

	var signatures: Dictionary = {}
	for weapon_id in WEAPON_IDS:
		var loadout: Array[String] = [weapon_id]
		var report: Dictionary = simulator.run(1000 + WEAPON_IDS.find(weapon_id), 30.0, loadout)
		runner.assert_true(int(report.get("requests", 0)) > 0, "%s should request effects" % weapon_id)
		runner.assert_true(int(report.get("executed", 0)) > 0, "%s should execute effects" % weapon_id)
		runner.assert_eq(int(report.get("invalid_request", -1)), 0, "%s should emit no invalid requests" % weapon_id)
		runner.assert_eq(int(report.get("pending_requests", -1)), 0, "%s should acknowledge every request" % weapon_id)
		runner.assert_true(
			int(Dictionary(report.get("hits_by_weapon", {})).get(weapon_id, 0)) > 0,
			"%s should produce at least one hit" % weapon_id
		)
		signatures[weapon_id] = Dictionary(report.get("signature", {})).get(weapon_id, {})

	for left_index in range(WEAPON_IDS.size()):
		for right_index in range(left_index + 1, WEAPON_IDS.size()):
			var left_id := WEAPON_IDS[left_index]
			var right_id := WEAPON_IDS[right_index]
			runner.assert_true(
				_signature_difference(signatures[left_id], signatures[right_id]) >= 2,
				"%s and %s should differ in at least two behavior dimensions" % [left_id, right_id]
			)

	var second_loadout: Array[String] = [
		"mechanism_crossbow",
		"soul_lantern",
		"spirit_needle_array",
		"flying_sword",
	]
	var long_first: Dictionary = simulator.run(20260713, 180.0, first_loadout)
	var long_second: Dictionary = simulator.run(20260714, 180.0, second_loadout)
	_assert_real_pool_drained(runner, long_first, "first loadout")
	_assert_real_pool_drained(runner, long_second, "second loadout")
	runner.assert_eq(int(long_first.get("no_target", -1)), 0, "dense first loadout should keep valid targets")
	runner.assert_eq(int(long_second.get("no_target", -1)), 0, "dense second loadout should keep valid targets")
	runner.assert_eq(int(long_first.get("pending_requests", -1)), 0, "first loadout should acknowledge every request")
	runner.assert_eq(int(long_second.get("pending_requests", -1)), 0, "second loadout should acknowledge every request")
	var first_signature: Dictionary = Dictionary(long_first.get("signature", {})).get("demon_sealing_bell", {})
	runner.assert_true(
		int(Dictionary(long_first.get("carrier_counts", {})).get("area", 0)) > int(first_signature.get("cadence", 0)),
		"projectile splash areas should contribute beyond bell areas"
	)
	var combined_carriers := _merge_counts(long_first.get("carrier_counts", {}), long_second.get("carrier_counts", {}))
	var combined_statuses := _merge_counts(long_first.get("statuses", {}), long_second.get("statuses", {}))
	for carrier_id in POOL_LIMITS.keys():
		runner.assert_true(int(combined_carriers.get(carrier_id, 0)) > 0, "%s carrier should execute" % carrier_id)
		runner.assert_true(
			int(Dictionary(long_first.get("pool_peaks", {})).get(carrier_id, 0)) <= int(POOL_LIMITS[carrier_id]),
			"first loadout %s peak should stay inside its limit" % carrier_id
		)
		runner.assert_true(
			int(Dictionary(long_second.get("pool_peaks", {})).get(carrier_id, 0)) <= int(POOL_LIMITS[carrier_id]),
			"second loadout %s peak should stay inside its limit" % carrier_id
		)
	for status_id in ["burn", "freeze", "armor_break", "seal"]:
		runner.assert_true(int(combined_statuses.get(status_id, 0)) > 0, "%s should be applied" % status_id)
	runner.assert_true(int(long_first.get("reactions", 0)) > 0, "burn and freeze should trigger thermal shatter")
	runner.assert_eq(int(long_first.get("pool_queued", -1)), 0, "first loadout should not queue pool work")
	runner.assert_eq(int(long_second.get("pool_queued", -1)), 0, "second loadout should not queue pool work")

func _signature_difference(left: Dictionary, right: Dictionary) -> int:
	var difference := 0
	for key in SIGNATURE_KEYS:
		if left.get(key) != right.get(key):
			difference += 1
	return difference

func _merge_counts(left_value: Variant, right_value: Variant) -> Dictionary:
	var result: Dictionary = Dictionary(left_value).duplicate(true)
	for key in Dictionary(right_value).keys():
		result[key] = int(result.get(key, 0)) + int(Dictionary(right_value)[key])
	return result

func _assert_real_pool_drained(runner, report: Dictionary, label: String) -> void:
	runner.assert_eq(report.get("pool_backend", ""), "PoolService", "%s should use the real pool service" % label)
	var final_stats: Dictionary = report.get("pool_final", {})
	for carrier_id in POOL_LIMITS.keys():
		var stats: Dictionary = final_stats.get(carrier_id, {})
		runner.assert_eq(int(stats.get("active", -1)), 0, "%s %s pool should drain" % [label, carrier_id])
		runner.assert_eq(
			int(stats.get("available", -1)),
			int(stats.get("created", -2)),
			"%s %s pool should retain every created node" % [label, carrier_id]
		)
