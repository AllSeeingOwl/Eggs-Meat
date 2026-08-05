extends RigidBody3D

@export var move_force: float = 30.0
@export var max_speed: float = 15.0

var stun_timer: float = 0.0
var original_material: Material
var is_typing: bool = false

func is_egghead() -> bool:
	return true

func _ready() -> void:
	# Get the mesh material to change its color later
	var mesh_instance = $MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		var mat = mesh_instance.mesh.surface_get_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
		original_material = mat.duplicate()
		mesh_instance.set_surface_override_material(0, original_material)

func _physics_process(delta: float) -> void:
	if is_typing:
		return # Disable movement while typing

	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer <= 0.0:
			# End stun
			if $MeshInstance3D:
				$MeshInstance3D.set_surface_override_material(0, original_material)
		return # Disable input while stunned

	var input_dir = Input.get_vector("egghead_move_left", "egghead_move_right", "egghead_move_up", "egghead_move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction:
		apply_central_force(direction * move_force)

	# Limit speed
	var current_velocity = linear_velocity
	current_velocity.y = 0 # Ignore falling speed for max speed calculation
	if current_velocity.length() > max_speed:
		var limited_velocity = current_velocity.normalized() * max_speed
		linear_velocity = Vector3(limited_velocity.x, linear_velocity.y, limited_velocity.z)

func apply_stun(duration: float, knockback: Vector3) -> void:
	if stun_timer <= 0.0: # Don't re-stun if already stunned, or maybe refresh it? Let's just reset timer for now
		if $MeshInstance3D:
			var stun_material = original_material.duplicate()
			stun_material.albedo_color = Color.RED
			$MeshInstance3D.set_surface_override_material(0, stun_material)
	stun_timer = duration
	apply_impulse(knockback)
