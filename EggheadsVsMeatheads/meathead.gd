extends RigidBody3D

@export var move_force: float = 4000.0 # High force to move high mass
@export var max_speed: float = 5.0 # Slower than egghead
@export var charge_force: float = 20000.0
@export var charge_max_speed: float = 15.0
@export var charge_duration: float = 1.0
@export var charge_cooldown: float = 3.0

var is_charging: bool = false
var charge_timer: float = 0.0
var cooldown_timer: float = 0.0
var charge_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	var input_dir = Input.get_vector("meathead_move_left", "meathead_move_right", "meathead_move_up", "meathead_move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if Input.is_action_just_pressed("meathead_charge") and cooldown_timer <= 0.0 and not is_charging:
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
