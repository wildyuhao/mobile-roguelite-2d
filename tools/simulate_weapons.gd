extends SceneTree

const WeaponSimulatorScript = preload("res://scripts/systems/weapon_simulator.gd")
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
const LOADOUTS: Array[Array] = [
	["talisman_fire", "frost_talisman", "demon_sealing_bell", "sword_gourd_blades"],
	["mechanism_crossbow", "soul_lantern", "spirit_needle_array", "flying_sword"],
]
const REQUIRED_CARRIERS: Array[String] = ["projectile", "area", "orbit", "summon"]
const REQUIRED_STATUSES: Array[String] = ["burn", "freeze", "armor_break", "seal"]

func _initialize() -> void:
	var simulator = WeaponSimulatorScript.new()
	var summary := {
		"weapons": {},
		"loadouts": [],
		"carrier_counts": {},
		"statuses": {},
		"reactions": 0,
	}
	var valid := true
	for index in range(WEAPON_IDS.size()):
		var weapon_id := WEAPON_IDS[index]
		var loadout: Array[String] = [weapon_id]
		var report: Dictionary = simulator.run(7000 + index, 30.0, loadout)
		var hits := int(Dictionary(report.get("hits_by_weapon", {})).get(weapon_id, 0))
		summary["weapons"][weapon_id] = {
			"requests": int(report.get("requests", 0)),
			"executed": int(report.get("executed", 0)),
			"hits": hits,
			"invalid_request": int(report.get("invalid_request", 0)),
			"signature": Dictionary(report.get("signature", {})).get(weapon_id, {}),
		}
		valid = (
			valid
			and int(report.get("requests", 0)) > 0
			and int(report.get("executed", 0)) > 0
			and hits > 0
			and int(report.get("invalid_request", 0)) == 0
			and int(report.get("pending_requests", -1)) == 0
		)

	for index in range(LOADOUTS.size()):
		var loadout: Array[String] = []
		for weapon_id_value in LOADOUTS[index]:
			loadout.append(String(weapon_id_value))
		var report: Dictionary = simulator.run(8000 + index, 180.0, loadout)
		summary["loadouts"].append(report)
		_merge_counts(summary["carrier_counts"], report.get("carrier_counts", {}))
		_merge_counts(summary["statuses"], report.get("statuses", {}))
		summary["reactions"] = int(summary["reactions"]) + int(report.get("reactions", 0))
		valid = (
			valid
			and int(report.get("invalid_request", 0)) == 0
			and int(report.get("pool_queued", 0)) == 0
			and int(report.get("pending_requests", -1)) == 0
		)

	for carrier_id in REQUIRED_CARRIERS:
		valid = valid and int(summary["carrier_counts"].get(carrier_id, 0)) > 0
	for status_id in REQUIRED_STATUSES:
		valid = valid and int(summary["statuses"].get(status_id, 0)) > 0
	valid = valid and int(summary["reactions"]) > 0
	print(JSON.stringify(summary))
	quit(0 if valid else 1)

func _merge_counts(target: Dictionary, source_value: Variant) -> void:
	var source: Dictionary = source_value
	for key in source.keys():
		target[key] = int(target.get(key, 0)) + int(source[key])
