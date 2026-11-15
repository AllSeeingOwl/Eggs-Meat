extends Node3D
## Round controller for the PoC match: "The Foundry of Force".
##   Eggheads win by tempering BLOCKS_TO_WIN iron blocks in the Forge.
##   The Meathead wins by running out the clock; it earns Heat for chaos.
## Spawns 1 player Egghead + bots (the 10:1 ratio, scaled down) and builds the HUD.

@export var round_time: float = 180.0
@export var blocks_to_win: int = 5
@export var bot_count: int = 9
@export var block_count: int = 8
@export var egghead_scene: PackedScene = preload("res://egghead.tscn")
@export var block_scene: PackedScene = preload("res://foundry_block.tscn")

const LIBRARY_SPAWN := Vector3(-15, 0.7, 12) # Where Eggheads (re)spawn.

var time_left: float
var blocks_locked: int = 0
var heat: int = 0
var round_active: bool = true
var winner: String = ""
var player: Node3D

@onready var meathead: Node3D = $Meathead
@onready var camera: Camera3D = $Camera3D

var _hud_top: Label
var _hud_prompt: Label
var _hud_flash: Label
var _hud_help: Label
var _hud_end: Label
var _flash_timer: float = 0.0

func _ready() -> void:
	add_to_group("game")
	randomize()
	time_left = round_time
	_build_hud()

	player = _spawn_egghead(true, LIBRARY_SPAWN)
	for i in bot_count:
		var p := LIBRARY_SPAWN + Vector3((i % 3) * 1.6 + 1.5, 0, -(i / 3) * 1.6 - 1.5)
		_spawn_egghead(false, p)
	for i in block_count:
		var b := block_scene.instantiate()
		add_child(b)
		b.global_position = Vector3(-10 + i * 3.0 + randf_range(-0.8, 0.8), 0.6, randf_range(-12, -4))

	if camera.follow_targets:
		camera.target1 = player
		camera.target2 = meathead
	flash("Push iron blocks into the FORGE, then type to temper them!", 5.0)

func _spawn_egghead(is_player: bool, pos: Vector3) -> Node3D:
	var e := egghead_scene.instantiate()
	e.is_player = is_player
	e.name = "PlayerEgghead" if is_player else "EggBot"
	e.position = pos
	add_child(e)
	e.spawn_point = LIBRARY_SPAWN + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	return e

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_meathead_ai"):
		meathead.ai_enabled = not meathead.ai_enabled
		flash("Meathead: " + ("AI" if meathead.ai_enabled else "HUMAN (arrows / gamepad)"))
	if not round_active and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if round_active:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			end_round("MEATHEADS")

	_flash_timer -= delta
	_hud_flash.visible = _flash_timer > 0.0
	_update_hud()

# --- Events reported by gameplay objects -----------------------------------

func on_block_locked(_block: Node3D, word: String) -> void:
	blocks_locked += 1
	flash("%s! Block tempered (%d/%d)" % [word, blocks_locked, blocks_to_win])
	if blocks_locked >= blocks_to_win:
		end_round("EGGHEADS")

func on_egghead_cracked(e: Node3D) -> void:
	add_heat(2, "CRACK! You were cracked - respawning in the Library..." if e == player else "CRACK!")

func on_egghead_wall_splat(_e: Node3D) -> void:
	add_heat(1, "SPLAT!")

func on_belly_flop(_m: Node3D, hits: int) -> void:
	if hits > 0:
		add_heat(hits, "BELLY-FLOP! x%d" % hits)

func add_heat(amount: int, message: String = "") -> void:
	if not round_active:
		return
	heat += amount
	if message != "":
		flash(message, 1.5)

func end_round(who: String) -> void:
	if not round_active:
		return
	round_active = false
	winner = who
	for s in get_tree().get_nodes_in_group("station"):
		s.stop_typing()
	_hud_end.text = "%s WIN!\n\nBlocks tempered: %d/%d    Heat: %d\n\nPress R to play again" % [who, blocks_locked, blocks_to_win, heat]
	_hud_end.visible = true

func flash(text: String, seconds: float = 2.5) -> void:
	if _hud_flash == null:
		return
	_hud_flash.text = text
	_flash_timer = seconds

# --- HUD -------------------------------------------------------------------

func _label(size: int, preset: Control.LayoutPreset, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE, 12)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	return l

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_hud_top = _label(26, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_hud_top)
	_hud_flash = _label(30, Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_flash.offset_top = -140
	_hud_flash.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	root.add_child(_hud_flash)
	_hud_prompt = _label(36, Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_prompt.offset_top = -170
	_hud_prompt.offset_bottom = -90
	root.add_child(_hud_prompt)
	_hud_help = _label(15, Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_help.grow_horizontal = Control.GROW_DIRECTION_END
	_hud_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_help.text = "EGGHEAD (you, gold): WASD move | stand on a station & type | Esc step away | mash WASD to escape a grab\n" \
		+ "MEATHEAD: Arrows move | Enter charge | R-Shift grab/yeet | R-Ctrl grease | / belly-flop (or gamepad) | F2 toggle AI"
	root.add_child(_hud_help)
	_hud_end = _label(44, Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_end.visible = false
	root.add_child(_hud_end)

func _update_hud() -> void:
	var mins := int(time_left) / 60
	var secs := int(time_left) % 60
	_hud_top.text = "THE FOUNDRY OF FORCE    %d:%02d    IQ (blocks): %d/%d    HEAT: %d    Meathead: %s" % [
		mins, secs, blocks_locked, blocks_to_win, heat, "AI" if meathead.ai_enabled else "HUMAN"]

	var prompt := ""
	for s in get_tree().get_nodes_in_group("station"):
		if s.is_typing():
			prompt = "TYPE:  %s\n%s_" % [s.target_phrase, s.current_input]
	if player and player.is_held:
		prompt = "GRABBED! Mash WASD to wriggle free  [%s]" % ("#".repeat(int(player.struggle_progress() * 10)) + "-".repeat(10 - int(player.struggle_progress() * 10)))
	elif player and player.is_cracked:
		prompt = "Cracked! Respawning..."
	_hud_prompt.text = prompt
