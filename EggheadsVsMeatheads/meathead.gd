extends RigidBody3D

@export var move_force: float = 1000.0 # High force to move high mass
@export var max_speed: float = 5.0 # Slower than egghead

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("meathead_move_left", "meathead_move_right", "meathead_move_up", "meathead_move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction:
		apply_central_force(direction * move_force)

	# Limit speed
	var current_velocity = linear_velocity
	current_velocity.y = 0 # Ignore falling speed for max speed calculation
	if current_velocity.length() > max_speed:
		var limited_velocity = current_velocity.normalized() * max_speed
		linear_velocity = Vector3(limited_velocity.x, linear_velocity.y, limited_velocity.z)
