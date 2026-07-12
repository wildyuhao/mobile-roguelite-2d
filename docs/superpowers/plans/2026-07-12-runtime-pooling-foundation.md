# Runtime Pooling Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse enemies, projectiles, and experience pickups without leaking health, action, collision, hit, signal, metadata, or collection state between activations.

**Architecture:** A scene-local `PoolService` owns available/active instances by stable string key and connects once to a shared `release_requested(node)` signal. Poolable scene scripts own their type-specific `activate_from_pool` and `deactivate_for_pool` reset contracts. Existing systems acquire from the service with an instantiate fallback, preserving isolated unit tests and non-pooled scenes.

**Tech Stack:** Godot 4.7, GDScript, existing packed scenes, headless tests and churn simulator, Git.

## Global Constraints

- Pooling never changes combat timing, damage, rewards, or encounter selection.
- Inactive pooled nodes are invisible, processing-disabled, collision-disabled, and absent from gameplay groups.
- Enemy reuse resets health, action state, velocity, target, telegraph tint, damage latch, collision, role metadata, and encounter metadata.
- Projectile reuse resets velocity, damage, 1.5-second lifetime, pierce, area radius, range, start position, rotation, hit target IDs, visual tint, and collision.
- Pickup reuse resets collection lock, value configuration, collection radius bonus, collision, and group membership.
- External gameplay signal connections are connected at most once and remain valid across reuse.
- A release request without an attached pool falls back to `queue_free()` for test and scene compatibility.
- Pool release is idempotent; duplicate release requests never place the same node in an available bucket twice.
- A release requested inside a physics callback becomes logically inactive immediately, then completes collision/process shutdown and bucket return after the physics frame. Pending nodes cannot be reacquired in the same frame.
- Game scene prewarms 32 enemies, 48 projectiles, and 32 pickups before combat.
- Stress verification reaches concurrent peaks of 140 enemies, 250 projectiles, and 100 pickups for three cycles without creating beyond the peak.
- The service remains scene-local; no Autoload or global singleton is introduced.
- Every production change follows red-green-refactor and ends with the complete Godot suite.

---

## File Map

- Create `scripts/systems/pool_service.gd`: scene-keyed acquire, release, prewarm, and statistics.
- Create `tests/test_pool_service.gd`: reuse, idempotence, lifecycle callback, and stats contract.
- Modify `scenes/game/Game.tscn`: add a local `PoolService` node.
- Modify `tests/test_game_scene_composition.gd`: require the pool node.
- Modify `scripts/enemies/enemy_agent.gd`: add resettable enemy lifecycle and release request.
- Modify `scripts/systems/enemy_director.gd`: acquire pooled enemies and prune inactive registry entries.
- Modify `tests/test_enemy_agent.gd` and `tests/test_enemy_director.gd`: verify clean enemy reuse.
- Modify `scripts/weapons/projectile.gd`: add resettable projectile lifecycle.
- Modify `scripts/core/game_loop.gd`: acquire projectiles and pickups from the shared pool.
- Modify `tests/test_projectile.gd` and `tests/test_game_loop_summary.gd`: verify reuse and single signal wiring.
- Modify `scripts/pickups/experience_pickup.gd`: add resettable collection lifecycle.
- Modify `tests/test_experience_pickup.gd`: verify exactly one collection per activation.
- Create `tools/simulate_pool_churn.gd`: no-render concurrent peak churn verifier.

---

### Task 1: Generic Scene-Local Pool Service

**Files:**
- Create: `scripts/systems/pool_service.gd`
- Create: `tests/test_pool_service.gd`
- Modify: `tests/run_all_tests.gd`
- Modify: `scenes/game/Game.tscn`
- Modify: `tests/test_game_scene_composition.gd`

**Interfaces:**
- Produces: `acquire(key, scene, parent) -> Node`, `release(node) -> bool`, `prewarm(key, scene, parent, count) -> int`, and `get_stats(key) -> Dictionary`.
- Consumes: optional node methods `activate_from_pool()` and `deactivate_for_pool()`, plus optional signal `release_requested(node)`.

- [ ] **Step 1: Write the failing pool service test**

Create `tests/test_pool_service.gd`:

```gdscript
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
```

Register after `test_game_database.gd` in `tests/run_all_tests.gd`.

- [ ] **Step 2: Add failing scene-composition assertion**

In `tests/test_game_scene_composition.gd`, add:

```gdscript
	runner.assert_true(game.has_node("PoolService"), "game scene should include a local pool service")
```

- [ ] **Step 3: Run the suite and verify RED**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because `pool_service.gd` and the scene node do not exist.

- [ ] **Step 4: Implement `PoolService`**

Create `scripts/systems/pool_service.gd`:

```gdscript
extends Node
class_name PoolService

signal node_created(pool_key: String, node: Node)
signal node_acquired(pool_key: String, node: Node)
signal node_released(pool_key: String, node: Node)

const POOL_KEY_META := &"_pool_key"

var available: Dictionary = {}
var active_by_id: Dictionary = {}
var created_counts: Dictionary = {}

func acquire(pool_key: String, scene: PackedScene, parent: Node) -> Node:
	if pool_key == "" or scene == null or parent == null:
		return null
	var bucket: Array = available.get(pool_key, [])
	_prune_bucket(bucket)
	var node: Node = null
	if not bucket.is_empty():
		node = bucket.pop_back()
	else:
		node = scene.instantiate()
		parent.add_child(node)
		node.set_meta(POOL_KEY_META, pool_key)
		_connect_release_signal(node)
		created_counts[pool_key] = int(created_counts.get(pool_key, 0)) + 1
		node_created.emit(pool_key, node)
	available[pool_key] = bucket
	if node.get_parent() != parent:
		var old_parent := node.get_parent()
		if old_parent != null:
			old_parent.remove_child(node)
		parent.add_child(node)
	active_by_id[node.get_instance_id()] = node
	if node.has_method("activate_from_pool"):
		node.activate_from_pool()
	node_acquired.emit(pool_key, node)
	return node

func release(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var instance_id := node.get_instance_id()
	if not active_by_id.has(instance_id):
		return false
	active_by_id.erase(instance_id)
	var pool_key := String(node.get_meta(POOL_KEY_META, ""))
	if node.has_method("deactivate_for_pool"):
		node.deactivate_for_pool()
	var bucket: Array = available.get(pool_key, [])
	if not bucket.has(node):
		bucket.append(node)
	available[pool_key] = bucket
	node_released.emit(pool_key, node)
	return true

func prewarm(pool_key: String, scene: PackedScene, parent: Node, count: int) -> int:
	var nodes: Array[Node] = []
	for index in range(maxi(0, count)):
		var node := acquire(pool_key, scene, parent)
		if node != null:
			nodes.append(node)
	for node in nodes:
		release(node)
	return nodes.size()

func get_stats(pool_key: String) -> Dictionary:
	var bucket: Array = available.get(pool_key, [])
	_prune_bucket(bucket)
	available[pool_key] = bucket
	var active_count := 0
	for node in active_by_id.values():
		if is_instance_valid(node) and String(node.get_meta(POOL_KEY_META, "")) == pool_key:
			active_count += 1
	return {
		"created": int(created_counts.get(pool_key, 0)),
		"active": active_count,
		"available": bucket.size(),
	}

func _connect_release_signal(node: Node) -> void:
	if not node.has_signal("release_requested"):
		return
	var callback := Callable(self, "_on_release_requested")
	if not node.is_connected("release_requested", callback):
		node.connect("release_requested", callback)

func _on_release_requested(node: Node) -> void:
	release(node)

func _prune_bucket(bucket: Array) -> void:
	for index in range(bucket.size() - 1, -1, -1):
		if not is_instance_valid(bucket[index]):
			bucket.remove_at(index)
```

- [ ] **Step 5: Add the scene-local service**

In `scenes/game/Game.tscn`, increase `load_steps` by one, add:

```text
[ext_resource type="Script" path="res://scripts/systems/pool_service.gd" id="14"]

[node name="PoolService" type="Node" parent="."]
script = ExtResource("14")
```

Place the node before `EnemyDirector`.

- [ ] **Step 6: Run full suite and commit**

Expected: `All tests passed.`

```powershell
git add scripts/systems/pool_service.gd tests/test_pool_service.gd tests/run_all_tests.gd scenes/game/Game.tscn tests/test_game_scene_composition.gd
git commit -m "feat: add scene local pool service"
```

---

### Task 2: Enemy Pool Lifecycle and Director Integration

**Files:**
- Modify: `scripts/enemies/enemy_agent.gd`
- Modify: `scripts/systems/enemy_director.gd`
- Modify: `scripts/core/game_loop.gd`
- Modify: `tests/test_enemy_agent.gd`
- Modify: `tests/test_enemy_director.gd`

**Interfaces:**
- Enemy produces: `release_requested(node)`, `activate_from_pool()`, `deactivate_for_pool()`, `is_pool_active() -> bool`.
- Director consumes: `PoolService.acquire("enemy", enemy_scene, parent)` with instantiate fallback.

- [ ] **Step 1: Add failing enemy reset assertions**

In `tests/test_enemy_agent.gd`, before final frees, add:

```gdscript
	var release_requests: Array[Node] = []
	enemy.release_requested.connect(func(node: Node) -> void: release_requests.append(node))
	enemy.set_meta("encounter_id", "old_encounter")
	enemy.set_meta("enemy_role", "charger")
	enemy.action_state.start_attack(0.1, 0.1, 0.1)
	enemy.deactivate_for_pool()
	runner.assert_true(not enemy.is_pool_active(), "deactivated enemy should be inactive")
	runner.assert_true(not enemy.has_meta("encounter_id"), "deactivation should clear encounter metadata")
	runner.assert_true(not enemy.has_meta("enemy_role"), "deactivation should clear role metadata")
	enemy.activate_from_pool()
	enemy.configure({"max_health": 77, "behavior": "chase"}, target)
	runner.assert_true(enemy.is_pool_active(), "reactivated enemy should be active")
	runner.assert_eq(health.current_health, 77, "reactivation should restore configured health")
	runner.assert_eq(enemy.action_state.state, "locomotion", "reactivation should reset action state")
	enemy._on_died()
	runner.assert_eq(release_requests, [enemy], "pooled enemy death should request one release")
```

- [ ] **Step 2: Add failing director reuse assertion**

In `tests/test_enemy_director.gd`, add a `FakePoolService` that records acquire calls and returns one prebuilt enemy, inject it into the budgeted encounter test, then assert at least one enemy acquisition uses key `enemy` and `enemy_scene`.

```gdscript
class FakePoolService:
	extends Node

	var calls: Array[String] = []

	func acquire(pool_key: String, scene: PackedScene, parent: Node) -> Node:
		calls.append(pool_key)
		var node = scene.instantiate()
		parent.add_child(node)
		if node.has_method("activate_from_pool"):
			node.activate_from_pool()
		return node

	func prewarm(_pool_key: String, _scene: PackedScene, _parent: Node, count: int) -> int:
		return count
```

After constructing the budgeted director:

```gdscript
	var fake_pool := FakePoolService.new()
	parent.add_child(fake_pool)
	director.pool_service = fake_pool
```

After spawning:

```gdscript
	runner.assert_true(fake_pool.calls.has("enemy"), "director should acquire enemies from the pool")
```

- [ ] **Step 3: Run and verify RED**

Expected: missing lifecycle signal/methods and director pool field.

- [ ] **Step 4: Implement enemy lifecycle**

In `enemy_agent.gd`, add:

```gdscript
signal release_requested(node: Node)

var pool_active: bool = true

func activate_from_pool() -> void:
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	velocity = Vector2.ZERO
	action_state.reset()
	locked_action_direction = Vector2.RIGHT
	damage_applied_this_action = false
	if not is_in_group(GameConstantsScript.ENEMY_GROUP):
		add_to_group(GameConstantsScript.ENEMY_GROUP)
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if sprite != null:
		sprite.modulate = Color.WHITE

func deactivate_for_pool() -> void:
	pool_active = false
	target = null
	velocity = Vector2.ZERO
	action_state.mark_dead()
	damage_applied_this_action = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group(GameConstantsScript.ENEMY_GROUP)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if has_meta("encounter_id"):
		remove_meta("encounter_id")
	if has_meta("enemy_role"):
		remove_meta("enemy_role")

func is_pool_active() -> bool:
	return pool_active

func _release_or_free() -> void:
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)
```

Replace the final `queue_free()` in `_on_died` with `_release_or_free()`.

- [ ] **Step 5: Integrate the director**

Add to `enemy_director.gd`:

```gdscript
var pool_service: Node
```

In `configure`:

```gdscript
	if pool_service == null:
		pool_service = get_node_or_null("../PoolService")
	if pool_service != null and pool_service.has_method("prewarm"):
		pool_service.prewarm("enemy", enemy_scene, get_parent(), 32)
```

Replace enemy creation in `_spawn_enemy` with:

```gdscript
	var enemy: Node
	if pool_service != null and pool_service.has_method("acquire"):
		enemy = pool_service.acquire("enemy", enemy_scene, get_parent())
	else:
		enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy)
	if enemy == null:
		return false
```

Do not add the acquired node to the parent a second time. Replace the unconditional `tree_exited.connect` line with this guarded connection:

```gdscript
	var tree_exit_callback := Callable(self, "_on_enemy_tree_exited").bind(enemy)
	if not enemy.tree_exited.is_connected(tree_exit_callback):
		enemy.tree_exited.connect(tree_exit_callback, CONNECT_ONE_SHOT)
```

Update `_prune_active_enemies` so entries with `is_pool_active() == false` are removed:

```gdscript
		elif enemy.has_method("is_pool_active") and not enemy.is_pool_active():
			active_enemies.remove_at(index)
```

- [ ] **Step 6: Prevent duplicate defeat connections**

Replace `_on_enemy_spawned` in `game_loop.gd` with:

```gdscript
func _on_enemy_spawned(enemy: Node) -> void:
	if not enemy.has_signal("defeated"):
		return
	var callback := Callable(self, "_on_enemy_defeated")
	if not enemy.is_connected("defeated", callback):
		enemy.connect("defeated", callback)
```

- [ ] **Step 7: Run full suite and commit**

```powershell
git add scripts/enemies/enemy_agent.gd scripts/systems/enemy_director.gd scripts/core/game_loop.gd tests/test_enemy_agent.gd tests/test_enemy_director.gd
git commit -m "feat: pool enemy lifecycle"
```

---

### Task 3: Projectile Pool Lifecycle

**Files:**
- Modify: `scripts/weapons/projectile.gd`
- Modify: `scripts/core/game_loop.gd`
- Modify: `tests/test_projectile.gd`
- Modify: `tests/test_game_loop_summary.gd`

**Interfaces:**
- Projectile produces: `release_requested(node)`, `activate_from_pool()`, `deactivate_for_pool()`.
- GameLoop consumes: `PoolService.acquire("projectile", projectile_scene, self)`.

- [ ] **Step 1: Add failing projectile reset assertions**

In `tests/test_projectile.gd`, after the current event assertions:

```gdscript
	projectile.hit_targets[42] = true
	projectile.remaining_lifetime = 0.2
	projectile.deactivate_for_pool()
	projectile.activate_from_pool()
	projectile.configure(Vector2.DOWN, 300.0, 4)
	runner.assert_eq(projectile.remaining_pierce, 0, "reused projectile should reset pierce")
	runner.assert_eq(projectile.area_damage_radius, 0.0, "reused projectile should reset area damage")
	runner.assert_eq(projectile.max_travel_distance, 0.0, "reused projectile should reset range")
	runner.assert_eq(projectile.remaining_lifetime, 1.5, "reused projectile should reset lifetime")
	runner.assert_true(projectile.hit_targets.is_empty(), "reused projectile should clear hit targets")
	var release_requests: Array[Node] = []
	projectile.release_requested.connect(func(node: Node) -> void: release_requests.append(node))
	projectile._physics_process(2.0)
	runner.assert_eq(release_requests, [projectile], "expired pooled projectile should request release once")
```

- [ ] **Step 2: Add failing GameLoop acquisition test**

Add this reusable fixture to `tests/test_game_loop_summary.gd`:

```gdscript
class FakePoolService:
	extends Node

	var acquired_keys: Array[String] = []
	var cached_nodes: Dictionary = {}

	func acquire(pool_key: String, scene: PackedScene, parent: Node) -> Node:
		acquired_keys.append(pool_key)
		var node: Node = cached_nodes.get(pool_key)
		if node == null:
			node = scene.instantiate()
			parent.add_child(node)
			cached_nodes[pool_key] = node
		if node.has_method("activate_from_pool"):
			node.activate_from_pool()
		return node
```

Append this focused test near the end of `run`:

```gdscript
	var projectile_pool_loop = game_loop_script.new()
	var projectile_pool := FakePoolService.new()
	projectile_pool_loop.set_pool_service(projectile_pool)
	var pooled_projectile = projectile_pool_loop._acquire_runtime_node(
		"projectile",
		load("res://scenes/weapons/Projectile.tscn")
	)
	runner.assert_true(pooled_projectile != null, "game loop should acquire a projectile node")
	runner.assert_eq(projectile_pool.acquired_keys, ["projectile"], "game loop should request the projectile pool")
	projectile_pool.free()
	projectile_pool_loop.free()
```

- [ ] **Step 3: Run and verify RED**

- [ ] **Step 4: Implement projectile lifecycle**

Add signal, active flag, lifecycle methods, and release helper to `projectile.gd`:

```gdscript
signal release_requested(node: Node)

var pool_active: bool = true

func activate_from_pool() -> void:
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	velocity = Vector2.ZERO
	damage = 1
	remaining_lifetime = 1.5
	remaining_pierce = 0
	area_damage_radius = 0.0
	max_travel_distance = 0.0
	start_position = global_position
	rotation = 0.0
	hit_targets.clear()
	if not is_in_group(GameConstantsScript.PROJECTILE_GROUP):
		add_to_group(GameConstantsScript.PROJECTILE_GROUP)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", false)
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.modulate = Color.WHITE

func deactivate_for_pool() -> void:
	pool_active = false
	velocity = Vector2.ZERO
	hit_targets.clear()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group(GameConstantsScript.PROJECTILE_GROUP)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)

func _release_or_free() -> void:
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)
```

Replace all three projectile `queue_free()` calls with `_release_or_free()`.

- [ ] **Step 5: Acquire projectiles through GameLoop**

Add:

```gdscript
@onready var pool_service: Node = get_node_or_null("PoolService")

func set_pool_service(service: Node) -> void:
	pool_service = service

func _acquire_runtime_node(pool_key: String, scene: PackedScene) -> Node:
	if scene == null:
		return null
	if pool_service != null and pool_service.has_method("acquire"):
		return pool_service.acquire(pool_key, scene, self)
	var node = scene.instantiate()
	add_child(node)
	return node
```

Replace projectile instantiate/add-child with:

```gdscript
		var projectile = _acquire_runtime_node("projectile", projectile_scene)
		if projectile == null:
			continue
```

- [ ] **Step 6: Run full suite and commit**

```powershell
git add scripts/weapons/projectile.gd scripts/core/game_loop.gd tests/test_projectile.gd tests/test_game_loop_summary.gd
git commit -m "feat: pool projectile lifecycle"
```

---

### Task 4: Experience Pickup Lifecycle and Runtime Prewarm

**Files:**
- Modify: `scripts/pickups/experience_pickup.gd`
- Modify: `scripts/core/game_loop.gd`
- Modify: `tests/test_experience_pickup.gd`
- Modify: `tests/test_game_loop_summary.gd`

**Interfaces:**
- Pickup produces: `release_requested(node)`, `activate_from_pool()`, `deactivate_for_pool()`.
- GameLoop prewarms and acquires projectile/pickup pools while EnemyDirector prewarms enemies.

- [ ] **Step 1: Add failing pickup reuse test**

Replace the first pickup test setup so `release_requested` is connected to an array, then run two activation cycles:

```gdscript
	var release_requests: Array[Node] = []
	pickup.release_requested.connect(func(node: Node) -> void: release_requests.append(node))
	pickup.configure(5)
	pickup.collect()
	pickup.collect()
	runner.assert_eq(collected_amounts, [5], "pickup should collect once per activation")
	runner.assert_eq(release_requests, [pickup], "first collection should request release")
	pickup.deactivate_for_pool()
	pickup.activate_from_pool()
	pickup.configure(7)
	pickup.collect()
	runner.assert_eq(collected_amounts, [5, 7], "reused pickup should collect in a new activation")
	runner.assert_eq(release_requests.size(), 2, "each activation should release once")
```

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Implement pickup lifecycle**

Add to `experience_pickup.gd`:

```gdscript
signal release_requested(node: Node)

var pool_active: bool = true

func activate_from_pool() -> void:
	pool_active = true
	_collected = false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if not is_in_group(GameConstantsScript.PICKUP_GROUP):
		add_to_group(GameConstantsScript.PICKUP_GROUP)
	_resolve_collection_shape()
	set_collection_radius_bonus(0.0)
	if collection_shape != null:
		collection_shape.set_deferred("disabled", false)

func deactivate_for_pool() -> void:
	pool_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group(GameConstantsScript.PICKUP_GROUP)
	if collection_shape != null:
		collection_shape.set_deferred("disabled", true)

func _release_or_free() -> void:
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)
```

Replace `queue_free()` in `collect()` with `_release_or_free()`.

- [ ] **Step 4: Acquire pickups and keep one signal connection**

Replace instantiate/add-child in `_spawn_experience_pickup` with:

```gdscript
	var pickup = _acquire_runtime_node("pickup", experience_pickup_scene)
	if pickup == null:
		return
```

Replace the collected connection with:

```gdscript
	if experience_system != null and pickup.has_signal("collected") and experience_system.has_method("add_experience"):
		var callback := Callable(experience_system, "add_experience")
		if not pickup.is_connected("collected", callback):
			pickup.connect("collected", callback)
```

Add a `FakeExperienceSystem` fixture to `tests/test_game_loop_summary.gd`:

```gdscript
class FakeExperienceSystem:
	extends Node

	var total: int = 0

	func add_experience(amount: int) -> void:
		total += amount
```

Add this reuse assertion after the pickup integration code is implemented:

```gdscript
	var pickup_pool_loop = game_loop_script.new()
	var pickup_pool = load("res://scripts/systems/pool_service.gd").new()
	var pickup_experience := FakeExperienceSystem.new()
	pickup_pool_loop.add_child(pickup_pool)
	pickup_pool_loop.set_pool_service(pickup_pool)
	pickup_pool_loop.experience_system = pickup_experience
	pickup_pool_loop.experience_pickup_scene = load("res://scenes/pickups/ExperiencePickup.tscn")
	pickup_pool_loop._spawn_experience_pickup(Vector2.ZERO, 3)
	var pooled_pickup = pickup_pool_loop.get_child(pickup_pool_loop.get_child_count() - 1)
	pooled_pickup.collect()
	pickup_pool_loop._spawn_experience_pickup(Vector2.ZERO, 5)
	var reused_pickup = pickup_pool_loop.get_child(pickup_pool_loop.get_child_count() - 1)
	runner.assert_true(reused_pickup == pooled_pickup, "game loop should reuse the released pickup")
	pooled_pickup.collect()
	runner.assert_eq(pickup_experience.total, 8, "reused pickup should keep exactly one collected connection")
	pickup_experience.free()
	pickup_pool_loop.free()
```

- [ ] **Step 5: Prewarm projectile and pickup pools**

In `GameLoop._ready`, after database load and before combat configuration:

```gdscript
	if pool_service != null and pool_service.has_method("prewarm"):
		pool_service.prewarm("projectile", projectile_scene, self, 48)
		pool_service.prewarm("pickup", experience_pickup_scene, self, 32)
```

- [ ] **Step 6: Run full suite and commit**

```powershell
git add scripts/pickups/experience_pickup.gd scripts/core/game_loop.gd tests/test_experience_pickup.gd tests/test_game_loop_summary.gd
git commit -m "feat: pool experience pickup lifecycle"
```

---

### Task 5: Concurrent Peak Churn Verification and Publication

**Files:**
- Create: `tools/simulate_pool_churn.gd`
- Create: `tests/test_pool_churn.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: a deterministic three-cycle report proving created counts stop at concurrent peaks.

- [ ] **Step 1: Write failing churn test**

Create `tests/test_pool_churn.gd` that loads the real pool and three scenes, runs two cycles at smaller test peaks, and asserts exact created counts:

```gdscript
extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/pool_service.gd"):
		runner.assert_true(false, "pool churn requires pool service")
		return
	var parent := Node2D.new()
	var service = load("res://scripts/systems/pool_service.gd").new()
	parent.add_child(service)
	var definitions := [
		{"key": "enemy", "scene": load("res://scenes/enemies/BasicDemon.tscn"), "peak": 12},
		{"key": "projectile", "scene": load("res://scenes/weapons/Projectile.tscn"), "peak": 24},
		{"key": "pickup", "scene": load("res://scenes/pickups/ExperiencePickup.tscn"), "peak": 16},
	]
	for cycle in range(2):
		for definition in definitions:
			var nodes: Array[Node] = []
			for index in range(int(definition["peak"])):
				nodes.append(service.acquire(definition["key"], definition["scene"], parent))
			for node in nodes:
				service.release(node)
	for definition in definitions:
		var stats: Dictionary = service.get_stats(definition["key"])
		runner.assert_eq(stats.get("created", -1), definition["peak"], "%s should stop creating at peak" % definition["key"])
		runner.assert_eq(stats.get("active", -1), 0, "%s should finish with no active nodes" % definition["key"])
	parent.free()
```

- [ ] **Step 2: Add production-scale CLI churn tool**

Create `tools/simulate_pool_churn.gd` with the same algorithm using peaks 140, 250, and 100 for three cycles. Print one JSON object containing each key's stats and exit 1 unless created equals peak, active is zero, and available equals peak for every key.

```gdscript
extends SceneTree

func _initialize() -> void:
	var service = load("res://scripts/systems/pool_service.gd").new()
	root.add_child(service)
	var definitions := [
		{"key": "enemy", "scene": load("res://scenes/enemies/BasicDemon.tscn"), "peak": 140},
		{"key": "projectile", "scene": load("res://scenes/weapons/Projectile.tscn"), "peak": 250},
		{"key": "pickup", "scene": load("res://scenes/pickups/ExperiencePickup.tscn"), "peak": 100},
	]
	for cycle in range(3):
		for definition in definitions:
			var nodes: Array[Node] = []
			for index in range(int(definition["peak"])):
				nodes.append(service.acquire(definition["key"], definition["scene"], root))
			for node in nodes:
				service.release(node)
	var report: Dictionary = {}
	var valid := true
	for definition in definitions:
		var stats: Dictionary = service.get_stats(definition["key"])
		report[definition["key"]] = stats
		valid = valid and int(stats.get("created", -1)) == int(definition["peak"])
		valid = valid and int(stats.get("active", -1)) == 0
		valid = valid and int(stats.get("available", -1)) == int(definition["peak"])
	print(JSON.stringify(report))
	quit(0 if valid else 1)
```

- [ ] **Step 3: Register test and run full verification**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --editor --path . --import
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tools/simulate_pool_churn.gd
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit-after 600
git diff --check
```

Expected: import exits 0, complete suite prints `All tests passed.`, churn report shows exact peaks `140/250/100` with zero active, and scene smoke exits 0.

- [ ] **Step 4: Commit and push**

```powershell
git add tools/simulate_pool_churn.gd tests/test_pool_churn.gd tests/run_all_tests.gd
git commit -m "test: verify pool churn peaks"
git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 -c http.version=HTTP/1.1 -c core.compression=9 push --progress origin main
```

---

## Plan Self-Review

- Scope coverage: implements the approved `PoolService` boundary for enemies, projectiles, and pickups, including prewarm, release, lifecycle reset, fallback free, statistics, and peak churn evidence.
- Scope boundary: common visual effects remain non-pooled until a reusable effect scene exists; pooling an absent effect type would create dead abstraction.
- Lifecycle consistency: each type owns its mutable state reset; the generic service only owns membership, creation, reuse, and callbacks.
- Physics consistency: poolables expose an immediate logical-release phase, while `PoolService` defers physical shutdown and bucket return when Godot is inside a physics frame.
- Signal consistency: pool release signal is connected once at creation; gameplay signals are guarded with `is_connected` before reuse.
- Director consistency: inactive enemies leave gameplay groups and are pruned from the active registry without relying on `tree_exited`.
- Mobile consistency: prewarm avoids first-combat spikes and production churn proves no allocation growth beyond 140 enemy, 250 projectile, and 100 pickup peaks.
- Compatibility consistency: every caller has an instantiate fallback and unpooled release falls back to `queue_free()`.
- Verification consistency: generic reuse, per-type state reset, real-scene churn, full tests, and scene smoke each have explicit checks.
