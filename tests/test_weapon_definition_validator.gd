extends RefCounted

func run(runner) -> void:
	var script_path := "res://scripts/weapons/weapon_definition_validator.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "weapon definition validator should exist")
		return

	var validator = load(script_path).new()
	var valid := _valid_definition()
	runner.assert_true(
		validator.validate(valid).is_empty(),
		"valid modular weapon should pass"
	)

	var invalid := valid.duplicate(true)
	invalid["effects"][0]["carrier"]["id"] = "script_string"
	invalid["effects"].append(invalid["effects"][0].duplicate(true))
	var errors: Array[String] = validator.validate(invalid)
	runner.assert_true(_contains(errors, "unknown carrier"), "unknown carrier should fail")
	runner.assert_true(_contains(errors, "duplicate effect_id"), "duplicate effect id should fail")

	invalid = valid.duplicate(true)
	invalid["levels"] = [{
		"level": 2,
		"effect_id": "missing",
		"section": "hit",
		"values": { "damage": 20, "script_path": "res://bad.gd" },
	}]
	errors = validator.validate(invalid)
	runner.assert_true(
		_contains(errors, "missing effect_id"),
		"level override should reference an existing effect"
	)
	runner.assert_true(
		_contains(errors, "unsupported override"),
		"arbitrary override fields should fail"
	)

	invalid = valid.duplicate(true)
	invalid["effects"][0]["target"]["range"] = 0
	invalid["effects"][0]["carrier"]["count"] = 13
	invalid["effects"][0]["hit"]["statuses"] = [{
		"id": "burn",
		"stacks": 0,
		"duration": -1.0,
	}]
	errors = validator.validate(invalid)
	runner.assert_true(_contains(errors, "target range"), "non-self target range should be positive")
	runner.assert_true(_contains(errors, "carrier count"), "carrier count above twelve should fail")
	runner.assert_true(_contains(errors, "status stacks or duration"), "invalid status values should fail")

	invalid = valid.duplicate(true)
	invalid["visual"]["carrier"] = "res://art/weapons/missing.png"
	runner.assert_true(
		_contains(validator.validate(invalid), "missing visual"),
		"missing production visuals should fail"
	)

	invalid["id"] = "invalid_weapon"
	var catalog := {
		"test_weapon": valid,
		"invalid_weapon": invalid,
	}
	runner.assert_true(
		not validator.validate_catalog(catalog).is_empty(),
		"catalog validation should include invalid definitions"
	)

func _valid_definition() -> Dictionary:
	return {
		"id": "test_weapon",
		"version": 1,
		"display_name": "测试武器",
		"description": "用于验证模块化武器结构。",
		"school": "sword",
		"max_level": 5,
		"effects": [{
			"effect_id": "main",
			"trigger": { "id": "periodic", "cooldown": 1.0 },
			"target": { "id": "nearest", "range": 320.0 },
			"carrier": { "id": "projectile", "speed": 500.0, "count": 1 },
			"hit": { "damage": 10, "statuses": [] },
		}],
		"visual": {
			"carrier": "res://art/weapons/flying_sword/flying_sword_projectile.png",
		},
		"levels": [],
	}

func _contains(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false
