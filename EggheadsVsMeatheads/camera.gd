extends Camera3D
## Fixed overview of the arena by default (best for one shared screen).
## Enable follow_targets to track the midpoint of two players instead.

@export var follow_targets: bool = false

@export var target1: Node3D
@export var target2: Node3D
@export var min_zoom: float = 10.0
@export var zoom_factor: float = 0.5
@export var fixed_y_angle: float = -60.0 # Degrees
@export var camera_distance_multiplier: float = 1.0

@export_group("Screen shake")
@export var shake_enabled: bool = true
@export var max_shake_offset: float = 0.9 ## Metres of h/v offset at full trauma.
@export var max_shake_roll: float = 2.5 ## Degrees of roll at full trauma.
@export var trauma_decay: float = 1.6 ## Trauma lost per second.

## 0..1. Shake strength is trauma squared, so small hits are subtle and big ones punch.
var trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _noise_t: float = 0.0
var _base_roll: float

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 2.0
	_base_roll = rotation.z

func add_trauma(amount: float) -> void:
	if shake_enabled:
		trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_apply_shake(delta)
	if not follow_targets or not target1 or not target2:
		return

	# Calculate midpoint
	var pos1 = target1.global_position
	var pos2 = target2.global_position
	var midpoint = (pos1 + pos2) / 2.0

	# Calculate distance between players
	var distance = pos1.distance_to(pos2)

	# Determine desired camera height based on distance
	var desired_height = max(min_zoom, distance * zoom_factor)

	# Set position: centered on midpoint, pulled back on Z and up on Y based on angle
	# A simple approach for an isometric-ish dynamic camera
	var rad_angle = deg_to_rad(fixed_y_angle)
	var z_offset = desired_height * cos(rad_angle) * camera_distance_multiplier
	var y_offset = desired_height * -sin(rad_angle) * camera_distance_multiplier

	global_position = midpoint + Vector3(0, y_offset, z_offset)

	# Always look at the midpoint
	look_at(midpoint, Vector3.UP)

func _apply_shake(delta: float) -> void:
	trauma = max(0.0, trauma - trauma_decay * delta)
	var power := trauma * trauma
	_noise_t += delta * 30.0
	# Offsets don't touch the transform, so they never fight the follow logic.
	h_offset = max_shake_offset * power * _noise.get_noise_2d(_noise_t, 0.0)
	v_offset = max_shake_offset * power * _noise.get_noise_2d(0.0, _noise_t)
	rotation.z = _base_roll + deg_to_rad(max_shake_roll) * power * _noise.get_noise_2d(_noise_t, 100.0)
