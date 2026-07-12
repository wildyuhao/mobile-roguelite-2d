extends Area2D
class_name EnemyProjectile

signal release_requested(node: Node)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var direction := Vector2.RIGHT
var speed: float = 0.0
var damage: int = 0
var remaining_lifetime: float = 0.0
var pool_active: bool = true

func _ready() -> void:
	var callback := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(callback):
		body_entered.connect(callback)

func configure(
	origin: Vector2,
	new_direction: Vector2,
	new_speed: float,
	new_damage: int,
	lifetime: float
) -> void:
	_resolve_nodes()
	global_position = origin
	direction = new_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = maxf(1.0, new_speed)
	damage = maxi(1, new_damage)
	remaining_lifetime = maxf(0.01, lifetime)
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	advance_projectile(delta)

func advance_projectile(delta: float) -> void:
	if not pool_active:
		return
	var safe_delta := maxf(0.0, delta)
	global_position += direction * speed * safe_delta
	remaining_lifetime -= safe_delta
	if remaining_lifetime <= 0.0:
		_release_or_free()

func try_hit(body: Node) -> bool:
	if not pool_active or body == null or not body.has_method("take_contact_damage"):
		return false
	body.call("take_contact_damage", damage)
	_release_or_free()
	return true

func activate_from_pool() -> void:
	_resolve_nodes()
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	monitoring = true
	direction = Vector2.RIGHT
	speed = 0.0
	damage = 0
	remaining_lifetime = 0.0
	rotation = 0.0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)

func deactivate_for_pool() -> void:
	begin_pool_release()
	process_mode = Node.PROCESS_MODE_DISABLED

func begin_pool_release() -> void:
	pool_active = false
	visible = false
	monitoring = false
	speed = 0.0
	damage = 0
	remaining_lifetime = 0.0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

func is_pool_active() -> bool:
	return pool_active

func _on_body_entered(body: Node) -> void:
	try_hit(body)

func _release_or_free() -> void:
	if not pool_active:
		return
	begin_pool_release()
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)

func _resolve_nodes() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
