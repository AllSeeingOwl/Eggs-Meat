extends TypingStation
## SUBPOENA station (Law module). Type the writ and the Meathead is hauled across
## the arena to the Witness Stand, dropping anything it holds, then made to stand
## there (stunned) for a few seconds. Long cooldown: it's a big play.

@export var phrase: String = "SUBPOENA"
@export var cooldown: float = 25.0
@export var witness_stand_path: NodePath

var cooldown_timer: float = 0.0

func _ready() -> void:
	super._ready()
	target_phrase = phrase

func can_activate() -> bool:
	var game = get_tree().get_first_node_in_group("game")
	if game and not game.round_active:
		return false
	return cooldown_timer <= 0.0

func choose_phrase() -> String:
	return phrase

func idle_text() -> String:
	if cooldown_timer > 0.0:
		return "SUBPOENA\nrecharging %ds" % ceili(cooldown_timer)
	return "SUBPOENA\n(summon the Meathead)"

func _physics_process(delta: float) -> void:
	cooldown_timer = max(0.0, cooldown_timer - delta)
	super._physics_process(delta)

func witness_stand_position() -> Vector3:
	var stand := get_node_or_null(witness_stand_path) as Node3D
	return stand.global_position if stand else Vector3(-16, 0, -16)

func on_success() -> void:
	cooldown_timer = cooldown
	for m in get_tree().get_nodes_in_group("meathead"):
		m.subpoena(witness_stand_position())
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.juice("habeas", 0.3)
		game.flash("SUBPOENA! The Meathead is summoned to the Witness Stand.")
