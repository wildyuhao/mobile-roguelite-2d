extends RefCounted

class FakePoolable:
	extends Node2D

	signal release_requested(node: Node)

	var activation_count: int = 0
	var deactivation_count: int = 0

	func activate_from_pool() -> void:
		activation_count += 1
		visible = true

	func deactivate_for_pool() -> void:
		deactivation_count += 1
		visible = false

	func request_release() -> void:
		release_requested.emit(self)

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/pool_service.gd"):
		runner.assert_true(false, "pool service should exist")
		return
	var service = load("res://scripts/systems/pool_service.gd").new()
	var parent := Node.new()
	parent.add_child(service)
	var source := FakePoolable.new()
	var scene := PackedScene.new()
	runner.assert_eq(scene.pack(source), OK, "fake poolable should pack")
	source.free()

	var first = service.acquire("fake", scene, parent)
	runner.assert_true(first is FakePoolable, "pool should instantiate the requested scene")
	runner.assert_eq(first.activation_count, 1, "new node should activate once")
	first.request_release()
	runner.assert_eq(first.deactivation_count, 1, "release signal should deactivate the node")
	runner.assert_true(not service.release(first), "duplicate release should be ignored")

	var second = service.acquire("fake", scene, parent)
	runner.assert_true(second == first, "next acquire should reuse the released instance")
	runner.assert_eq(second.activation_count, 2, "reused node should activate again")
	var stats: Dictionary = service.get_stats("fake")
	runner.assert_eq(stats.get("created", -1), 1, "reuse should create only one instance")
	runner.assert_eq(stats.get("active", -1), 1, "acquired node should be active")
	runner.assert_eq(stats.get("available", -1), 0, "acquired node should leave the bucket")
	service.release(second)
	parent.free()
