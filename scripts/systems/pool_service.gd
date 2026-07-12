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

func prewarm(
	pool_key: String,
	scene: PackedScene,
	parent: Node,
	count: int
) -> int:
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
		if (
			is_instance_valid(node)
			and String(node.get_meta(POOL_KEY_META, "")) == pool_key
		):
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
