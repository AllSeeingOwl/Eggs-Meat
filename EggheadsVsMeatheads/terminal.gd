extends TypingStation
## HABEAS CORPUS terminal (Law module). Type the writ and:
##   * any Egghead held by the Meathead is instantly released, and the Meathead
##     is stunned ("produce the body!"),
##   * a protective barrier blocks the Meathead from the terminal for a while.

@export var phrase: String = "HABEAS CORPUS"
@export var barrier_duration: float = 5.0
@export var cooldown: float = 12.0
@export var meathead_stun: float = 2.0

var barrier_timer: float = 0.0
var cooldown_timer: float = 0.0

@onready var barrier: StaticBody3D = $Barrier

func _ready() -> void:
	super._ready()
	target_phrase = phrase
	barrier.collision_layer = 2
	barrier.collision_mask = 0
	_set_barrier(false)

func can_activate() -> bool:
	return cooldown_timer <= 0.0

func choose_phrase() -> String:
	return phrase

func idle_text() -> String:
	if cooldown_timer > 0.0:
		return "HABEAS CORPUS\nrecharging %ds" % ceili(cooldown_timer)
	return "HABEAS CORPUS\n(free a captured Egghead)"

func _physics_process(delta: float) -> void:
	if barrier_timer > 0.0:
		barrier_timer -= delta
		if barrier_timer <= 0.0:
			_set_barrier(false)
	cooldown_timer = max(0.0, cooldown_timer - delta)
	super._physics_process(delta)

func on_success() -> void:
	cooldown_timer = cooldown
	barrier_timer = barrier_duration
	_set_barrier(true)
	var freed := 0
	for m in get_tree().get_nodes_in_group("meathead"):
		# Shove the Meathead out of the barrier footprint so it doesn't get stuck inside.
		var away: Vector3 = m.global_position - global_position
		away.y = 0
		if away.length() < 4.5:
			var dir := away.normalized() if away.length() > 0.1 else Vector3.BACK
			m.global_position = global_position + dir * 5.5 + Vector3(0, 1, 0)
		if m.held_object != null:
			m.release(Vector3(0, 4, 0))
			freed += 1
		if freed > 0 or away.length() < 4.5:
			m.apply_stun(meathead_stun)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.juice("habeas", 0.35)
		game.flash("HABEAS CORPUS! The body is produced." if freed > 0 else "HABEAS CORPUS! Barrier raised.")

func _set_barrier(on: bool) -> void:
	barrier.visible = on
	barrier.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
