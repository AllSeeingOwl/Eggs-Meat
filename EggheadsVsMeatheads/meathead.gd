extends RigidBody3D
## The heavy brawler. Strong but clumsy: input is delayed, turning while charging
## is sluggish, and a belly-flop leaves it winded. Can be driven by a human
## (keyboard arrows or gamepad) or by a simple AI so one person can test solo.
## Any human Meathead input takes control away from the AI automatically.

@export var move_force: float = 4000.0
@export var max_speed: float = 5.0
@export var charge_force: float = 20000.0
@export var charge_max_speed: float = 15.0
@export var charge_duration: float = 1.0
@export var charge_cooldown: float = 3.0
@export var grab_range: float = 2.8
@export var yeet_force: float = 18.0
@export var grease_cooldown: float = 8.0
@export var flop_cooldown: float = 6.0
@export var flop_radius: float = 4.5
@export var flop_recovery: float = 1.2
@export var input_lag: float = 0.12 ## Seconds of deliberate input delay (clumsiness).
@export var subpoena_speed: float = 14.0
@export var witness_stand_time: float = 3.0 ## Stun once dragged onto the stand.
@export var ai_enabled: bool = true
@export var ai_aggression: float = 0.5 ## 0..1: how often the AI commits to attacks.

var is_charging: bool = false
var charge_timer: float = 0.0
var cooldown_timer: float = 0.0
var charge_direction: Vector3 = Vector3.FORWARD
var grease_cooldown_timer: float = 0.0
var flop_cooldown_timer: float = 0.0
var stun_timer: float = 0.0
var facing: Vector3 = Vector3.FORWARD
var subpoena_timer: float = 0.0 ## > 0 while being dragged to the Witness Stand.
var subpoena_target: Vector3

var held_object: Node3D = null
var grease_scene: PackedScene = preload("res://grease_spill.tscn")

var _input_buffer: Array = [] # [time, Vector3]
var _clock: float = 0.0
var _ai_hold_time: float = 0.0
var _ai_think: float = 0.0
var _ai_target: Node3D = null
var _ai_rest: float = 0.0 ## Lumbering pause after an attack so Eggheads get breathing room.

func _ready() -> void:
	add_to_group("meathead")
	collision_mask = 3 # Default world (1) + Habeas Corpus barrier (2).
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_clock += delta
	cooldown_timer = max(0.0, cooldown_timer - delta)
	grease_cooldown_timer = max(0.0, grease_cooldown_timer - delta)
	flop_cooldown_timer = max(0.0, flop_cooldown_timer - delta)

	var intent := _human_intent()
	var game = get_tree().get_first_node_in_group("game")
	# Grace period: the Enter that starts the round must not count as a takeover.
	if intent.any_input and ai_enabled and (game == null or game.round_clock > 0.5):
		ai_enabled = false
		if game:
			game.flash("A human has taken control of the Meathead!")
	if ai_enabled:
		intent = _ai_intent(delta)

	# Clumsiness: movement responds to where the stick was a moment ago.
	_input_buffer.append([_clock, intent.move])
	var direction: Vector3 = Vector3.ZERO
	while _input_buffer.size() > 1 and _clock - _input_buffer[1][0] >= input_lag:
		_input_buffer.pop_front()
	if _clock - _input_buffer[0][0] >= input_lag:
		direction = _input_buffer[0][1]

	if subpoena_timer > 0.0:
		_process_subpoena(delta)
		return

	if stun_timer > 0.0:
		stun_timer -= delta
		_update_held()
		return

	if direction.length() > 0.1:
		facing = direction.normalized()

	if intent.charge:
		start_charge(direction)
	if intent.grab:
		if held_object == null:
			try_grab()
		else:
			yeet(facing)
	if intent.grease:
		spill_grease()
	if intent.flop:
		belly_flop()

	if is_charging:
		charge_timer -= delta
		if charge_timer <= 0.0:
			is_charging = false

	var current_max_speed := max_speed
	if is_charging:
		if direction.length() > 0.1:
			charge_direction = charge_direction.lerp(direction, delta * 1.5).normalized()
		apply_central_force(charge_direction * charge_force)
		current_max_speed = charge_max_speed
		facing = charge_direction
	elif direction.length() > 0.1:
		apply_central_force(direction * move_force)

	var flat := Vector3(linear_velocity.x, 0, linear_velocity.z)
	if flat.length() > current_max_speed:
		flat = flat.normalized() * current_max_speed
		linear_velocity = Vector3(flat.x, linear_velocity.y, flat.z)

	_update_held()

func _human_intent() -> Dictionary:
	var v := Input.get_vector("meathead_move_left", "meathead_move_right", "meathead_move_up", "meathead_move_down")
	var i := {
		"move": Vector3(v.x, 0, v.y),
		"charge": Input.is_action_just_pressed("meathead_charge"),
		"grab": Input.is_action_just_pressed("meathead_grab"),
		"grease": Input.is_action_just_pressed("meathead_grease"),
		"flop": Input.is_action_just_pressed("meathead_flop"),
	}
	i.any_input = v.length() > 0.3 or i.charge or i.grab or i.grease or i.flop
	return i

# --- Abilities (public so tests and the AI can call them) ------------------

func start_charge(direction: Vector3 = Vector3.ZERO) -> bool:
	if cooldown_timer > 0.0 or is_charging or held_object != null or stun_timer > 0.0:
		return false
	is_charging = true
	charge_timer = charge_duration
	cooldown_timer = charge_cooldown
	charge_direction = direction.normalized() if direction.length() > 0.1 else facing
	_juice("charge", 0.12)
	return true

func try_grab() -> bool:
	if held_object != null:
		return false
	var best: Node3D = null
	var best_d := grab_range
	for e in get_tree().get_nodes_in_group("egghead"):
		if not e.can_be_grabbed():
			continue
		var d := global_position.distance_to(e.global_position)
		if d <= best_d:
			best = e
			best_d = d
	if best == null:
		return false
	grab(best)
	return true

func grab(body: Node3D) -> void:
	held_object = body
	_ai_hold_time = 0.0
	_juice("grab", 0.05)
	if body is RigidBody3D:
		body.collision_layer = 0
		body.collision_mask = 0
		body.freeze = true
	if body.has_method("set_held"):
		body.set_held(true)

## Drop whatever we hold without throwing it (used by Habeas Corpus and escapes).
func release(pop: Vector3 = Vector3.ZERO) -> Node3D:
	var body := held_object
	if body == null:
		return null
	held_object = null
	if is_instance_valid(body):
		body.global_position = global_position + Vector3(facing.x * 1.8, 0.5, facing.z * 1.8)
		if body is RigidBody3D:
			body.freeze = false
			body.collision_layer = 1
			body.collision_mask = 1
			body.linear_velocity = Vector3.ZERO
			body.apply_impulse(pop)
		if body.has_method("set_held"):
			body.set_held(false)
	return body

func yeet(direction: Vector3) -> void:
	var dir := Vector3(direction.x, 0, direction.z)
	if dir.length() < 0.1:
		dir = facing
	dir = (dir.normalized() + Vector3(0, 0.35, 0)).normalized()
	var body := release()
	if body is RigidBody3D:
		body.global_position = global_position + Vector3(dir.x, 0, dir.z) * 2.0 + Vector3(0, 0.5, 0)
		body.apply_impulse(dir * yeet_force * body.mass)
		if body.has_method("set_thrown"):
			body.set_thrown(true)
		_juice("yeet", 0.15)
		var game = get_tree().get_first_node_in_group("game")
		if game:
			game.add_heat(1, "YEET!")

func spill_grease() -> bool:
	if grease_cooldown_timer > 0.0 or stun_timer > 0.0:
		return false
	var grease := grease_scene.instantiate()
	get_parent().add_child(grease)
	grease.global_position = Vector3(global_position.x, 0.05, global_position.z)
	grease_cooldown_timer = grease_cooldown
	_juice("grease")
	return true

func belly_flop() -> int:
	if flop_cooldown_timer > 0.0 or stun_timer > 0.0 or held_object != null:
		return 0
	flop_cooldown_timer = flop_cooldown
	stun_timer = flop_recovery # Winded after the slam.
	is_charging = false
	var hits := 0
	for e in get_tree().get_nodes_in_group("egghead"):
		if not e.can_be_targeted() or e.slam_immune:
			continue
		var away: Vector3 = e.global_position - global_position
		away.y = 0
		if away.length() <= flop_radius:
			e.apply_stun(2.5, away.normalized() * 6.0 + Vector3(0, 4, 0))
			hits += 1
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.on_belly_flop(self, hits)
	return hits

## SUBPOENA: drop whatever we hold and get hauled to the Witness Stand, then
## stand there (stunned) for witness_stand_time. Input is ignored throughout.
func subpoena(target: Vector3, max_time: float = 4.0) -> void:
	if held_object != null:
		release(Vector3(0, 4, 0))
	is_charging = false
	subpoena_target = Vector3(target.x, global_position.y, target.z)
	subpoena_timer = max_time

func _process_subpoena(delta: float) -> void:
	subpoena_timer -= delta
	var to := subpoena_target - global_position
	to.y = 0
	if to.length() < 0.8 or subpoena_timer <= 0.0:
		subpoena_timer = 0.0
		linear_velocity = Vector3.ZERO
		apply_stun(witness_stand_time)
		return
	var v := to.normalized() * subpoena_speed
	linear_velocity = Vector3(v.x, linear_velocity.y, v.z)
	facing = to.normalized()

func apply_stun(duration: float, knockback: Vector3 = Vector3.ZERO) -> void:
	stun_timer = max(stun_timer, duration)
	is_charging = false
	apply_central_impulse(knockback * mass)

func _update_held() -> void:
	if held_object == null:
		return
	if not is_instance_valid(held_object):
		held_object = null
		return
	held_object.global_position = global_position + Vector3(0, 2.0, 0)
	if held_object.has_method("wants_to_escape") and held_object.wants_to_escape():
		release(Vector3(randf_range(-2, 2), 3, randf_range(-2, 2)))
		_juice("free")
		var game = get_tree().get_first_node_in_group("game")
		if game:
			game.flash("An Egghead wriggled free!")

func _juice(sound: String, shake: float = 0.0) -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.juice(sound, shake)
	else:
		SoundFX.play_sfx(sound)

func _on_body_entered(body: Node) -> void:
	if not is_charging or not body.has_method("is_egghead"):
		return
	var flat := Vector3(linear_velocity.x, 0, linear_velocity.z)
	if flat.length() > max_speed * 1.2 and body.can_be_targeted():
		if body.anchored:
			# Adagio: the heavy Egghead doesn't budge; the Meathead bounces off.
			body.linear_velocity = Vector3.ZERO
			apply_stun(1.0, -flat.normalized() * 4.0)
			_juice("splat", 0.3)
		else:
			body.crack()

# --- AI --------------------------------------------------------------------

func _ai_intent(delta: float) -> Dictionary:
	var i := {"move": Vector3.ZERO, "charge": false, "grab": false, "grease": false, "flop": false, "any_input": false}
	var game = get_tree().get_first_node_in_group("game")
	if game and not game.round_active:
		return i

	var forge := get_tree().get_first_node_in_group("forge") as Node3D

	if held_object != null:
		# Carry the Egghead a little, then hurl it at the nearest wall.
		_ai_hold_time += delta
		var to_wall := _nearest_wall_direction()
		i.move = to_wall
		if _ai_hold_time > 1.5:
			facing = to_wall
			i.grab = true
			_ai_rest = randf_range(2.0, 4.0) / ai_aggression
		return i

	_ai_think -= delta
	if _ai_think <= 0.0 or _ai_target == null or not _ai_target.can_be_targeted():
		_ai_think = 2.5
		_ai_target = _ai_pick_target(forge)
	if _ai_target == null:
		return i

	if _ai_rest > 0.0:
		_ai_rest -= delta
		return i # Stand there catching its breath.

	var to_t := _ai_target.global_position - global_position
	to_t.y = 0
	var dist := to_t.length()
	i.move = to_t.normalized()

	var nearby := 0
	for e in get_tree().get_nodes_in_group("egghead"):
		if e.can_be_targeted() and not e.slam_immune and global_position.distance_to(e.global_position) < flop_radius - 0.5:
			nearby += 1
	if nearby >= 3 and flop_cooldown_timer <= 0.0 and randf() < delta * 2.0 * ai_aggression:
		i.flop = true
		_ai_rest = randf_range(1.5, 3.0) / ai_aggression
	elif dist < grab_range and randf() < delta * 4.0 * ai_aggression:
		i.grab = true
	elif dist > 3.0 and dist < 9.0 and cooldown_timer <= 0.0 and randf() < delta * ai_aggression:
		i.charge = true
		_ai_rest = randf_range(1.0, 2.5) / ai_aggression
	if forge and grease_cooldown_timer <= 0.0 and global_position.distance_to(forge.global_position) < 6.0:
		i.grease = true
	return i

func _ai_pick_target(forge: Node3D) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("egghead"):
		if not e.can_be_targeted():
			continue
		var score := global_position.distance_to(e.global_position)
		if forge:
			score += 0.5 * e.global_position.distance_to(forge.global_position) # Harass the workers near the forge.
		if e.is_player:
			score -= 4.0
		if e.anchored:
			score += 10.0 # Not worth it: can't be grabbed or charged down.
		score += randf_range(0, 4)
		if score < best_score:
			best_score = score
			best = e
	return best

func _nearest_wall_direction() -> Vector3:
	var p := global_position
	var options := [
		[20.0 - p.x, Vector3.RIGHT], [p.x + 20.0, Vector3.LEFT],
		[20.0 - p.z, Vector3.BACK], [p.z + 20.0, Vector3.FORWARD],
	]
	options.sort_custom(func(a, b): return a[0] < b[0])
	return options[0][1]
