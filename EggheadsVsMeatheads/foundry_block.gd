extends RigidBody3D
## An iron block. Eggheads shove it into the Forge; once tempered it turns gold
## and is fixed in place (it can no longer be knocked out by the Meathead).

var is_locked: bool = false
var _mat: StandardMaterial3D

func is_block() -> bool:
	return true

func _ready() -> void:
	add_to_group("block")
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.45, 0.45, 0.5)
	_mat.metallic = 0.6
	$MeshInstance3D.material_override = _mat

func lock_in() -> void:
	is_locked = true
	freeze = true
	_mat.albedo_color = Color(1.0, 0.75, 0.1)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.5, 0.0)
	_mat.emission_energy_multiplier = 0.6
	remove_from_group("block")

func _physics_process(_delta: float) -> void:
	if global_position.y < -10.0:
		global_position = Vector3(randf_range(-8, 8), 1, randf_range(-12, -6))
		linear_velocity = Vector3.ZERO
