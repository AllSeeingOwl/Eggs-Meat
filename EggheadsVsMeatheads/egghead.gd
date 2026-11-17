extends RigidBody3D
## The fragile scholar. One Egghead is the keyboard player; the rest are simple
## bots that push foundry blocks toward the forge and scatter when the Meathead
## gets close. Eggheads CRACK when hit by a charge (respawn after a delay) and are
## STUNNED when yeeted into a wall or belly-flopped.

signal cracked(egghead)

@export var is_player: bool = false
@export var move_force: float = 30.0
@export var max_speed: float = 7.0
@export var respawn_time: float = 4.0
@export var struggle_presses_needed: int = 10
@export var bot_auto_escape_time: float = 4.0

const BASE_DAMP := 5.0
const PLAYER_COLOR := Color(1.0, 0.8, 0.2)
const BOT_COLOR := Color(0.95, 0.92, 0.82)
const STUN_COLOR := Color(1.0, 0.25, 0.25)

var stun_timer: float = 0.0
var is_typing: bool = false
var is_greased: bool = false
var is_thrown: bool = false
var is_held: bool = false
var is_cracked: bool = false
var speed_multiplier: float = 1.0 ## Set by Allegro tiles.
var slam_immune: bool = false ## Set by Obsidian tiles.
var anchored: bool = false ## Set by Adagio tiles: can't be grabbed or charged down.
var spawn_point: Vector3

var _body_material: StandardMaterial3D
var _respawn_timer: float = 0.0
var _held_timer: float = 0.0
var _struggle_presses: int = 0
var _bot_wander := Vector3.ZERO
var _bot_retarget: float = 0.0
var _bot_target_block: Node3D = null
var _bot_courage: float = 1.0

func is_egghead() -> bool:
	return true

func _ready() -> void:
	add_to_group("egghead")
	contact_monitor = true
	max_contacts_reported = 5
	linear_damp = BASE_DAMP
	body_entered.connect(_on_body_entered)
	spawn_point = global_position
	_bot_courage = randf_range(0.5, 1.5)

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = PLAYER_COLOR if is_player else BOT_COLOR
	$MeshInstance3D.material_override = _body_material
	if has_node("Marker"):
		$Marker.visible = is_player

func set_greased(val: bool) -> void:
	is_greased = val
	linear_damp = 0.0 if is_greased else BASE_DAMP

func set_thrown(val: bool) -> void:
	is_thrown = val

func set_held(val: bool) -> void:
	is_held = val
	_held_timer = 0.0
	_struggle_presses = 0
	if val:
		is_typing = false

func can_be_targeted() -> bool:
	return not is_cracked and not is_held

func can_be_grabbed() -> bool:
	return can_be_targeted() and not anchored

func _physics_process(delta: float) -> void:
	if is_cracked:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if is_held:
		_held_timer += delta
		return

	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer <= 0.0:
			_body_material.albedo_color = PLAYER_COLOR if is_player else BOT_COLOR
		return

	if is_typing:
		return

	var direction := Vector3.ZERO
	if is_player:
		var input_dir := Input.get_vector("egghead_move_left", "egghead_move_right", "egghead_move_up", "egghead_move_down")
		direction = Vector3(input_dir.x, 0, input_dir.y)
	else:
		direction = _bot_direction(delta)

	if is_greased:
		direction = Vector3.ZERO # No traction: just slide.
	if direction.length() > 0.01:
		apply_central_force(direction.normalized() * move_force * speed_multiplier)

	var flat := Vector3(linear_velocity.x, 0, linear_velocity.z)
	var limit := max_speed * speed_multiplier
	if flat.length() > limit and not is_thrown:
		flat = flat.normalized() * limit
		linear_velocity = Vector3(flat.x, linear_velocity.y, flat.z)

	# Fell out of the arena somehow: put it back.
	if global_position.y < -10.0:
		_respawn()

## Called by the Meathead each frame it holds us; returns true when we break free.
func wants_to_escape() -> bool:
	if is_player:
		return _struggle_presses >= struggle_presses_needed
	return _held_timer >= bot_auto_escape_time

func _unhandled_input(event: InputEvent) -> void:
	if not is_player or not is_held:
		return
	for a in ["egghead_move_up", "egghead_move_down", "egghead_move_left", "egghead_move_right"]:
		if event.is_action_pressed(a, false):
			_struggle_presses += 1

func struggle_progress() -> float:
	return clampf(float(_struggle_presses) / struggle_presses_needed, 0.0, 1.0)

func apply_stun(duration: float, knockback: Vector3) -> void:
	if is_cracked:
		return
	is_typing = false
	_body_material.albedo_color = STUN_COLOR
	stun_timer = max(stun_timer, duration)
	apply_impulse(knockback)

func crack() -> void:
	if is_cracked:
		return
	is_cracked = true
	is_typing = false
	is_thrown = false
	stun_timer = 0.0
	_respawn_timer = respawn_time
	visible = false
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0
	cracked.emit(self)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.on_egghead_cracked(self)

func _respawn() -> void:
	is_cracked = false
	is_thrown = false
	is_held = false
	stun_timer = 0.0
	speed_multiplier = 1.0
	slam_immune = false
	anchored = false
	set_greased(false)
	_body_material.albedo_color = PLAYER_COLOR if is_player else BOT_COLOR
	global_position = spawn_point + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	collision_layer = 1
	collision_mask = 1
	visible = true
	if is_player:
		SoundFX.play_sfx("respawn", -4.0, 0.0)

func _on_body_entered(body: Node) -> void:
	if is_thrown and body is StaticBody3D:
		is_thrown = false
		apply_stun(2.0, Vector3.ZERO)
		var game = get_tree().get_first_node_in_group("game")
		if game:
			game.on_egghead_wall_splat(self)
	elif is_thrown and body.has_method("is_block"):
		is_thrown = false

# --- Bot brain -------------------------------------------------------------

func _bot_direction(delta: float) -> Vector3:
	var meathead := get_tree().get_first_node_in_group("meathead") as Node3D
	if meathead:
		var away := global_position - meathead.global_position
		away.y = 0
		if away.length() < 6.0 * _bot_courage:
			return away.normalized()

	_bot_retarget -= delta
	if _bot_retarget <= 0.0 or not _block_needs_pushing(_bot_target_block):
		_bot_retarget = randf_range(2.0, 4.0)
		_bot_target_block = _pick_block()
		_bot_wander = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))

	var forge := get_tree().get_first_node_in_group("forge") as Node3D
	if _bot_target_block == null or forge == null:
		return _bot_wander

	var block_pos := _bot_target_block.global_position
	var to_forge := forge.global_position - block_pos
	to_forge.y = 0
	to_forge = to_forge.normalized()
	# Get behind the block (opposite side from the forge), then shove it forward.
	var push_spot := block_pos - to_forge * 1.3
	var to_spot := push_spot - global_position
	to_spot.y = 0
	if to_spot.length() > 0.6:
		# Path around the block instead of through it.
		var to_block := block_pos - global_position
		to_block.y = 0
		if to_block.length() < 1.6 and to_block.normalized().dot(to_forge) < 0.3:
			to_spot += to_forge.cross(Vector3.UP) * 1.5
		return to_spot.normalized()
	return to_forge

func _block_needs_pushing(block: Node3D) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	if block.get("is_locked"):
		return false
	var forge = get_tree().get_first_node_in_group("forge")
	return forge == null or not forge.contains_block(block)

func _pick_block() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for b in get_tree().get_nodes_in_group("block"):
		if not _block_needs_pushing(b):
			continue
		var d := global_position.distance_to(b.global_position) + randf_range(0, 6)
		if d < best_d:
			best_d = d
			best = b
	return best
