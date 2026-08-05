extends Camera3D

@export var target1: Node3D
@export var target2: Node3D
@export var min_zoom: float = 10.0
@export var zoom_factor: float = 0.5
@export var fixed_y_angle: float = -60.0 # Degrees
@export var camera_distance_multiplier: float = 1.0

func _process(delta: float) -> void:
	if not target1 or not target2:
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
