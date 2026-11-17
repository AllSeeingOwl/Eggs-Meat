extends Node3D
## Round controller for the PoC match: "The Foundry of Force".
##   Eggheads win by tempering BLOCKS_TO_WIN iron blocks in the Forge.
##   The Meathead wins by running out the clock; it earns Heat for chaos.
## Spawns 1 player Egghead + bots (the 10:1 ratio, scaled down) and builds the HUD.
## The first round opens on the title / how-to-play screen (game paused behind it),
## where the Meathead side picks a pre-match Firewall. R rematches straight away
## with the same Firewall; T goes back to the title screen.

@export var round_time: float = 180.0
@export var blocks_to_win: int = 5
@export var bot_count: int = 9
@export var block_count: int = 8
@export var egghead_scene: PackedScene = preload("res://egghead.tscn")
@export var block_scene: PackedScene = preload("res://foundry_block.tscn")
@export var show_title: bool = true ## Tests turn this off to start immediately.
@export var rng_seed: int = 0 ## Non-zero = reproducible match (tests); 0 = random.

const LIBRARY_SPAWN := Vector3(-15, 0.7, 12) # Where Eggheads (re)spawn.

var time_left: float
var blocks_locked: int = 0
var heat: int = 0
var round_active: bool = false
var round_clock: float = 0.0 ## Seconds since the round started.
var firewall: String = "NONE" ## Meathead's pre-match sabotage: "NONE" or "NO_VOWELS".
var title_screen: CanvasLayer

# Rematch state must survive a scene reload. It lives in Engine metadata rather
# than static vars: a static var keeps this script (and its preloaded scenes)
# alive past engine shutdown, which shows up as false "leaked" warnings.
const META_SKIP_TITLE := &"evm_skip_title_once"
const META_FIREWALL := &"evm_last_firewall"
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
	if rng_seed != 0:
		seed(rng_seed)
	else:
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

	if show_title and not Engine.get_meta(META_SKIP_TITLE, false):
		title_screen = preload("res://title_screen.gd").new()
		title_screen.start_requested.connect(start_round)
		add_child(title_screen)
		_hud_help.visible = false # The title screen explains the controls.
		get_tree().paused = true
	else:
		start_round(Engine.get_meta(META_FIREWALL, "NONE"))
	Engine.set_meta(META_SKIP_TITLE, false)

func start_round(chosen_firewall: String = "NONE") -> void:
	firewall = chosen_firewall
	Engine.set_meta(META_FIREWALL, chosen_firewall)
	time_left = round_time
	round_clock = 0.0
	round_active = true
	if title_screen:
		title_screen.queue_free()
		title_screen = null
	get_tree().paused = false
	_hud_help.visible = true
	if firewall == "NO_VOWELS":
		flash("FIREWALL: NO VOWELS!  The words are missing their vowels...", 5.0)
	else:
		flash("Push iron blocks into the FORGE, then type to temper them!", 5.0)
	SoundFX.play_sfx("respawn", 0.0, 0.0)

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
	if Input.is_action_just_pressed("toggle_shake"):
		camera.shake_enabled = not camera.shake_enabled
		camera.trauma = 0.0
		flash("Screen shake " + ("ON" if camera.shake_enabled else "OFF"))
	if Input.is_action_just_pressed("toggle_mute"):
		flash("Sound " + ("OFF" if SoundFX.toggle_mute_sfx() else "ON"))
	if not round_active and winner != "":
		if Input.is_action_just_pressed("restart"):
			Engine.set_meta(META_SKIP_TITLE, true)
			get_tree().reload_current_scene()
			return
		if Input.is_action_just_pressed("to_title"):
			get_tree().reload_current_scene()
			return

	if round_active:
		round_clock += delta
		var before := ceili(time_left)
		time_left -= delta
		if ceili(time_left) < before and before <= 10 and time_left > 0.0:
			SoundFX.play_sfx("tick", -4.0, 0.0) # Final countdown.
		if time_left <= 0.0:
			time_left = 0.0
			end_round("MEATHEADS")

	_flash_timer -= delta
	_hud_flash.visible = _flash_timer > 0.0
	_update_hud()

# --- Events reported by gameplay objects -----------------------------------

func on_block_locked(_block: Node3D, word: String) -> void:
	blocks_locked += 1
	juice("lock", 0.2)
	flash("%s! Block tempered (%d/%d)" % [word, blocks_locked, blocks_to_win])
	if blocks_locked >= blocks_to_win:
		end_round("EGGHEADS")

func on_egghead_cracked(e: Node3D) -> void:
	juice("crack", 0.55 if e == player else 0.35)
	add_heat(2, "CRACK! You were cracked - respawning in the Library..." if e == player else "CRACK!")

func on_egghead_wall_splat(e: Node3D) -> void:
	juice("splat", 0.4 if e == player else 0.25)
	add_heat(1, "SPLAT!")

func on_belly_flop(_m: Node3D, hits: int) -> void:
	juice("flop", 0.5 + 0.1 * hits)
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
	juice("win" if who == "EGGHEADS" else "lose", 0.3)
	for s in get_tree().get_nodes_in_group("station"):
		s.stop_typing()
	_hud_end.text = "%s WIN!\n\nBlocks tempered: %d/%d    Heat: %d\n\nR  rematch        T  title screen" % [who, blocks_locked, blocks_to_win, heat]
	_hud_end.visible = true

## Play a sound and kick the camera. Central so every impact feels consistent.
func juice(sound: String, shake: float = 0.0, volume_db: float = 0.0) -> void:
	SoundFX.play_sfx(sound, volume_db)
	if shake > 0.0 and camera:
		camera.add_trauma(shake)

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
		+ "MEATHEAD: Arrows move | Enter charge | R-Shift grab/yeet | R-Ctrl grease | / belly-flop (or gamepad) | F2 toggle AI | F3 shake | F4 mute"
	root.add_child(_hud_help)
	_hud_end = _label(44, Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_end.visible = false
	root.add_child(_hud_end)

func _update_hud() -> void:
	var mins := int(time_left) / 60
	var secs := int(time_left) % 60
	_hud_top.text = "THE FOUNDRY OF FORCE    %d:%02d    IQ (blocks): %d/%d    HEAT: %d    Meathead: %s" % [
		mins, secs, blocks_locked, blocks_to_win, heat, "AI" if meathead.ai_enabled else "HUMAN"]
	if firewall == "NO_VOWELS":
		_hud_top.text += "\nFIREWALL: NO VOWELS"

	var prompt := ""
	for s in get_tree().get_nodes_in_group("station"):
		if s.is_typing():
			prompt = "TYPE:  %s\n%s_" % [s.display_phrase(), s.current_input]
	if player and player.is_held:
		prompt = "GRABBED! Mash WASD to wriggle free  [%s]" % ("#".repeat(int(player.struggle_progress() * 10)) + "-".repeat(10 - int(player.struggle_progress() * 10)))
	elif player and player.is_cracked:
		prompt = "Cracked! Respawning..."
	_hud_prompt.text = prompt
