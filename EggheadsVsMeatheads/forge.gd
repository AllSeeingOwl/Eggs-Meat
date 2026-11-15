extends TypingStation
## The Foundry Forge: the Egghead objective. Push iron blocks into the forge
## pad, then stand on it and type the engineering term shown to temper (lock)
## one block. Lock enough blocks before time runs out to win.

@export var words: PackedStringArray = [
	"TENSILE", "TRUSS", "CANTILEVER", "KEYSTONE", "GIRDER",
	"RIVET", "ALLOY", "ARCH", "FULCRUM", "TORQUE",
]

func _ready() -> void:
	super._ready()
	add_to_group("forge")

func contains_block(block: Node3D) -> bool:
	return trigger_area.overlaps_body(block)

func blocks_inside() -> Array:
	var out := []
	for b in trigger_area.get_overlapping_bodies():
		if b.has_method("is_block") and not b.is_locked:
			out.append(b)
	return out

func can_activate() -> bool:
	var game = get_tree().get_first_node_in_group("game")
	if game and not game.round_active:
		return false
	return blocks_inside().size() > 0

func choose_phrase() -> String:
	return words[randi() % words.size()]

func idle_text() -> String:
	var n := blocks_inside().size()
	if n == 0:
		return "THE FORGE\npush iron blocks here"
	return "THE FORGE\n%d block(s) ready - step on to temper" % n

func on_success() -> void:
	var blocks := blocks_inside()
	if blocks.is_empty():
		return
	blocks.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	blocks[0].lock_in()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.on_block_locked(blocks[0], target_phrase)
