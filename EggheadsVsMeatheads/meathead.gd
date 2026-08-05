extends RigidBody3D

@export var move_force: float = 4000.0 # High force to move high mass
@export var max_speed: float = 5.0 # Slower than egghead
@export var charge_force: float = 20000.0
@export var charge_max_speed: float = 15.0
@export var charge_duration: float = 1.0
@export var charge_cooldown: float = 3.0
@export var grab_range: float = 3.0
@export var yeet_force: float = 40.0
@export var grease_cooldown: float = 5.0

var is_charging: bool = false
var charge_timer: float = 0.0
var cooldown_timer: float = 0.0
var charge_direction: Vector3 = Vector3.ZERO
var grease_cooldown_timer: float = 0.0

var held_object: Node3D = null
var grease_scene: PackedScene

func _ready() -> void:
	collision_mask = 3 # Collide with default (1) and barrier (2) layers
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)

	# Load grease scene
	if ResourceLoader.exists("res://grease_spill.tscn"):
		grease_scene = load("res://grease_spill.tscn")

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	if grease_cooldown_timer > 0.0:
		grease_cooldown_timer -= delta

	var input_dir = Input.get_vector("meathead_move_left", "meathead_move_right", "meathead_move_up", "meathead_move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if Input.is_action_just_pressed("meathead_charge") and cooldown_timer <= 0.0 and not is_charging and held_object == null:
		is_charging = true
		charge_timer = charge_duration
		cooldown_timer = charge_cooldown

		if direction.length() > 0.1:
			charge_direction = direction
		else:
			var vel_dir = linear_velocity
			vel_dir.y = 0
			if vel_dir.length() > 0.1:
				charge_direction = vel_dir.normalized()
			else:
				charge_direction = Vector3.FORWARD

	if Input.is_action_just_pressed("meathead_grab"):
		if held_object == null:
			# Try to grab
			for body in get_tree().get_nodes_in_group("egghead"):
				if body.global_position.distance_to(global_position) <= grab_range:
					_grab_object(body)
					break
			# If no group, fallback to iterating all nodes
			if held_object == null:
				for node in get_tree().get_root().get_children():
					_find_and_grab_egghead(node)
		else:
			# Yeet!
			_yeet_object()

	if Input.is_action_just_pressed("meathead_grease") and grease_cooldown_timer <= 0.0:
		_spill_grease()

	if is_charging:
		charge_timer -= delta
		if charge_timer <= 0.0:
			is_charging = false

	var current_max_speed = max_speed

	if is_charging:
		# Limit turning by slowly lerping the charge direction towards input
		if direction.length() > 0.1:
			charge_direction = charge_direction.lerp(direction, delta * 1.5).normalized()
		apply_central_force(charge_direction * charge_force)
		current_max_speed = charge_max_speed
	else:
		if direction:
			apply_central_force(direction * move_force)

	# Limit speed
	var current_velocity = linear_velocity
	current_velocity.y = 0 # Ignore falling speed for max speed calculation
	if current_velocity.length() > current_max_speed:
		var limited_velocity = current_velocity.normalized() * current_max_speed
		linear_velocity = Vector3(limited_velocity.x, linear_velocity.y, limited_velocity.z)

	# Update held object position
	if held_object != null:
		if is_instance_valid(held_object):
			held_object.global_position = global_position + Vector3(0, 2.5, 0)
			# also set zero velocity if rigid body to prevent physics buildup
			if held_object is RigidBody3D:
				held_object.linear_velocity = Vector3.ZERO
				held_object.angular_velocity = Vector3.ZERO
		else:
			held_object = null

func _find_and_grab_egghead(node: Node) -> void:
	if held_object != null: return
	if node.has_method("is_egghead") and node.is_egghead():
		if node.global_position.distance_to(global_position) <= grab_range:
			_grab_object(node)
			return
	for child in node.get_children():
		_find_and_grab_egghead(child)

func _grab_object(body: Node3D) -> void:
	held_object = body
	if held_object is RigidBody3D:
		# Disable collision so it doesn't push the meathead
		held_object.collision_layer = 0
		held_object.collision_mask = 0
		held_object.freeze = true

func _yeet_object() -> void:
	if held_object == null: return
	if held_object is RigidBody3D:
		var yeet_dir = linear_velocity.normalized()
		if yeet_dir.length() < 0.1:
			yeet_dir = Vector3.FORWARD
		yeet_dir.y = 0.5 # angle it up a bit
		yeet_dir = yeet_dir.normalized()

		# Move it out of meathead so it doesn't instantly collide if we re-enable masks
		held_object.global_position = global_position + yeet_dir * 2.0

		held_object.freeze = false
		held_object.collision_layer = 1
		held_object.collision_mask = 3

		# For stun when thrown into a wall, we should apply an impulse, not just velocity
		held_object.apply_impulse(yeet_dir * yeet_force * held_object.mass)

		# Set a flag or script on egghead to detect wall impact
		if held_object.has_method("set_thrown"):
			held_object.set_thrown(true)

	held_object = null

func _spill_grease() -> void:
	if grease_scene != null:
		var grease = grease_scene.instantiate()
		get_parent().add_child(grease)
		var drop_pos = global_position
		drop_pos.y = -0.4 # Slightly above floor (floor is at -0.5)
		grease.global_position = drop_pos
		grease_cooldown_timer = grease_cooldown

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_stun") and is_charging:
		var current_velocity = linear_velocity
		current_velocity.y = 0
		# If charging at high speed
		if current_velocity.length() > max_speed * 1.2:
			var knockback_dir = (body.global_position - global_position).normalized()
			knockback_dir.y = 0.5 # Add upward knockback
			var knockback_force = current_velocity.length() * 2.0
			body.apply_stun(3.0, knockback_dir * knockback_force)
