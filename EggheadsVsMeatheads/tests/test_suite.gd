extends SceneTree
## Headless gameplay tests. Run from the project folder:
##   godot --headless --fixed-fps 60 -s res://tests/test_suite.gd
## Each test loads a fresh copy of main.tscn and steps real physics.

var failures: Array[String] = []
var main: Node

func _initialize() -> void:
	# `-s` runs don't instantiate project autoloads, so install them like the game would.
	for a in [["Controls", "res://controls.gd"], ["Sfx", "res://sfx.gd"]]:
		var n: Node = load(a[1]).new()
		n.name = a[0]
		root.add_child(n)
		if a[0] == "Sfx":
			n.silent = true # Gameplay tests don't need audio; test_sounds_synthesized checks it.
	_run.call_deferred()

func _run() -> void:
	var tests := [
		"test_scene_setup", "test_grab_and_yeet_into_wall", "test_charge_cracks_and_respawns",
		"test_belly_flop_respects_obsidian", "test_allegro_speeds_up", "test_grease",
		"test_habeas_corpus_frees_captive", "test_escape_cancels_typing",
		"test_forge_locks_block_and_wins", "test_wrong_letter_resets", "test_timer_expiry",
		"test_struggle_free", "test_subpoena_hauls_meathead", "test_adagio_is_grab_and_charge_proof",
		"test_no_vowels_firewall", "test_title_screen_flow", "test_sounds_synthesized", "test_screen_shake", "test_ai_soak",
	]
	var only := OS.get_environment("TESTS") # e.g. TESTS=test_grease,test_timer_expiry
	if only != "":
		tests = tests.filter(func(t): return only.split(",").has(t))
	for t in tests:
		await _fresh()
		var before := failures.size()
		await call(t)
		print(("PASS  " if failures.size() == before else "FAIL  ") + t)
	_teardown()
	var sfx := root.get_node_or_null("Sfx")
	if sfx:
		sfx.stop_all()
	# The audio server frees stopped playbacks on its own real-time mix thread;
	# --fixed-fps runs far faster than real time, so wait in wall-clock time.
	OS.delay_msec(250)
	await frames(2)
	if failures.is_empty():
		print("\nAll %d tests passed." % tests.size())
		quit(0)
	else:
		print("\n%d failure(s):\n  %s" % [failures.size(), "\n  ".join(failures)])
		quit(1)

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error("CHECK FAILED: " + msg)

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _teardown() -> void:
	if main and is_instance_valid(main):
		root.remove_child(main)
		main.free()
	main = null

func _fresh() -> void:
	_teardown()
	main = load("res://main.tscn").instantiate()
	main.show_title = false
	root.add_child(main)
	await frames(2)

func meat() -> Node: return main.get_node("Meathead")
func bots() -> Array: return get_nodes_in_group("egghead").filter(func(e): return not e.is_player)

func place(body: Node3D, pos: Vector3) -> void:
	body.global_position = pos
	body.linear_velocity = Vector3.ZERO

func park_everyone_else(keep: Array) -> void:
	var i := 0
	for e in get_nodes_in_group("egghead"):
		if not keep.has(e):
			place(e, Vector3(-17 + (i % 4) * 1.2, 0.7, -17 + (i / 4) * 1.2))
			e.process_mode = Node.PROCESS_MODE_DISABLED
			i += 1

# --- Tests -----------------------------------------------------------------

func test_scene_setup() -> void:
	check(main.player != null and main.player.is_player, "player egghead spawned")
	check(bots().size() == 9, "9 bot eggheads (10:1 ratio scaled down), got %d" % bots().size())
	check(get_nodes_in_group("block").size() == 8, "8 foundry blocks")
	check(get_nodes_in_group("meathead").size() == 1, "one meathead")
	check(get_nodes_in_group("station").size() == 3, "terminal + subpoena + forge stations")
	check(main.round_active, "round starts active")

func test_grab_and_yeet_into_wall() -> void:
	var m := meat(); m.ai_enabled = false
	var e: Node3D = bots()[0]
	park_everyone_else([e])
	place(m, Vector3(14, 1, -14)); place(e, Vector3(12.5, 0.7, -14))
	await frames(3)
	check(m.try_grab(), "grab succeeds in range")
	check(m.held_object == e and e.is_held and e.freeze, "egghead is held & frozen")
	await frames(5)
	check(e.global_position.y > 2.0, "held egghead is carried above the meathead")
	var heat0: int = main.heat
	m.yeet(Vector3.RIGHT)
	check(m.held_object == null and not e.is_held and e.is_thrown, "yeet releases and flags thrown")
	check(main.heat == heat0 + 1, "yeet earns heat")
	for i in 120:
		await physics_frame
		if e.stun_timer > 0.0: break
	check(e.stun_timer > 0.0 and not e.is_thrown, "egghead stunned on hitting the wall")

func test_charge_cracks_and_respawns() -> void:
	var m := meat(); m.ai_enabled = false
	var e: Node3D = bots()[0]
	park_everyone_else([e])
	place(m, Vector3(0, 1, 0)); place(e, Vector3(0, 0.7, -5))
	await frames(3)
	check(m.start_charge(Vector3.FORWARD), "charge starts")
	for i in 90:
		await physics_frame
		if e.is_cracked: break
	check(e.is_cracked and not e.visible, "charged egghead cracks")
	check(main.heat >= 2, "crack earns heat")
	check(not m.start_charge(Vector3.FORWARD), "charge has a cooldown")
	await frames(int(e.respawn_time * 60) + 5)
	check(not e.is_cracked and e.visible and e.global_position.distance_to(main.LIBRARY_SPAWN) < 5.0, "egghead respawns in the Library")

func test_belly_flop_respects_obsidian() -> void:
	var m := meat(); m.ai_enabled = false
	var tile: Node3D = main.get_node("ObsidianTile")
	var safe: Node3D = bots()[0]
	var exposed: Node3D = bots()[1]
	park_everyone_else([safe, exposed])
	var c := tile.global_position
	place(m, c + Vector3(-3.2, 1, 0)); place(safe, c + Vector3(-1.2, 0.7, 0)); place(exposed, c + Vector3(-3.2, 0.7, 2.5))
	await frames(4)
	check(safe.slam_immune, "egghead on obsidian is slam-immune")
	var hits: int = m.belly_flop()
	check(hits == 1, "belly-flop hit exactly the exposed egghead (got %d)" % hits)
	check(exposed.stun_timer > 0.0 and safe.stun_timer <= 0.0, "obsidian egghead unaffected")
	check(m.stun_timer > 0.0, "meathead is winded after flopping")
	check(m.belly_flop() == 0, "belly-flop has a cooldown")

func test_allegro_speeds_up() -> void:
	var e: Node3D = bots()[0]
	park_everyone_else([e])
	place(e, main.get_node("AllegroTile").global_position + Vector3(0, 0.7, 0))
	await frames(3)
	check(e.speed_multiplier > 1.0, "allegro boosts speed")
	place(e, Vector3(0, 0.7, 0))
	await frames(3)
	check(e.speed_multiplier == 1.0, "boost ends when leaving the tile")

func test_grease() -> void:
	var m := meat(); m.ai_enabled = false
	var e: Node3D = bots()[0]
	park_everyone_else([e])
	place(m, Vector3(0, 1, 0)); place(e, Vector3(2, 0.7, 0))
	await frames(2)
	check(m.spill_grease(), "grease spills")
	await frames(3)
	check(e.is_greased and e.linear_damp == 0.0, "egghead in grease loses traction")
	place(e, Vector3(10, 0.7, 0))
	await frames(3)
	check(not e.is_greased and e.linear_damp == 5.0, "traction returns after leaving grease")

func _walk_player_onto(station: Node3D, offset := Vector3(1.5, 0.7, 0)) -> void:
	place(main.player, station.global_position + offset)
	for i in 30:
		await physics_frame
		if station.is_typing(): return

func _type(station: Node3D, text: String) -> void:
	for c in text:
		station.type_char(c)

func test_habeas_corpus_frees_captive() -> void:
	var m := meat(); m.ai_enabled = false
	var term: Node3D = main.get_node("Terminal")
	var captive: Node3D = bots()[0]
	park_everyone_else([captive, main.player])
	place(m, Vector3(5, 1, 0)); place(captive, Vector3(6.5, 0.7, 0))
	await frames(3)
	m.grab(captive)
	await _walk_player_onto(term)
	check(term.is_typing() and main.player.is_typing, "player starts typing at the terminal and is rooted")
	_type(term, "HABEAS CORPUS")
	check(m.held_object == null and not captive.is_held, "captive egghead freed")
	check(m.stun_timer > 0.0, "meathead stunned by the writ")
	check(term.barrier.visible, "barrier raised")
	check(not term.can_activate(), "terminal goes on cooldown")
	check(not main.player.is_typing, "player can move again")

func test_escape_cancels_typing() -> void:
	var term: Node3D = main.get_node("Terminal")
	park_everyone_else([main.player])
	await _walk_player_onto(term)
	check(term.is_typing(), "typing started")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	term._unhandled_key_input(ev)
	check(not term.is_typing() and not main.player.is_typing, "Esc releases the player")
	await frames(5)
	check(not term.is_typing(), "station doesn't re-trap the player while still standing on it")

func test_forge_locks_block_and_wins() -> void:
	var forge: Node3D = main.get_node("Forge")
	park_everyone_else([main.player])
	await _walk_player_onto(forge, Vector3(2, 0.7, 2))
	check(not forge.is_typing(), "forge stays idle with no block in it")
	var blocks := get_nodes_in_group("block")
	place(blocks[0], forge.global_position + Vector3(-1, 0.6, -1))
	for i in 30:
		await physics_frame
		if forge.is_typing(): break
	check(forge.is_typing(), "forge activates once a block is inside")
	main.blocks_locked = main.blocks_to_win - 1
	_type(forge, forge.target_phrase)
	check(blocks[0].is_locked and blocks[0].freeze, "block is tempered & fixed")
	check(main.blocks_locked == main.blocks_to_win, "score incremented")
	check(not main.round_active and main.winner == "EGGHEADS", "eggheads win at the target")

func test_wrong_letter_resets() -> void:
	var term: Node3D = main.get_node("Terminal")
	park_everyone_else([main.player])
	await _walk_player_onto(term)
	_type(term, "HAB")
	check(term.current_input == "HAB", "correct prefix accumulates")
	term.type_char("X")
	check(term.current_input == "", "wrong letter wipes the line")

func test_timer_expiry() -> void:
	main.time_left = 0.05
	await frames(10)
	check(not main.round_active and main.winner == "MEATHEADS", "meatheads win when time runs out")

func test_struggle_free() -> void:
	var m := meat(); m.ai_enabled = false
	park_everyone_else([main.player])
	place(m, Vector3(0, 1, 0)); place(main.player, Vector3(1.5, 0.7, 0))
	await frames(2)
	m.grab(main.player)
	for i in main.player.struggle_presses_needed:
		var ev := InputEventAction.new()
		ev.action = "egghead_move_left"
		ev.pressed = true
		main.player._unhandled_input(ev)
	await frames(2)
	check(not main.player.is_held and m.held_object == null, "mashing frees the player")

func test_subpoena_hauls_meathead() -> void:
	var m := meat(); m.ai_enabled = false
	var sub: Node3D = main.get_node("Subpoena")
	var stand: Vector3 = main.get_node("WitnessStand").global_position
	var captive: Node3D = bots()[0]
	park_everyone_else([captive, main.player])
	place(m, Vector3(12, 1, -8)); place(captive, Vector3(13.5, 0.7, -8))
	await frames(3)
	m.grab(captive)
	await _walk_player_onto(sub)
	check(sub.is_typing(), "player starts typing at the subpoena station")
	check(sub.display_phrase() == "SUBPOENA", "full phrase shown without a firewall")
	_type(sub, "SUBPOENA")
	check(m.held_object == null and not captive.is_held, "subpoena makes the meathead drop its captive")
	check(m.subpoena_timer > 0.0, "meathead is being hauled")
	check(not sub.can_activate(), "subpoena goes on cooldown")
	# Human input must not break the haul.
	for i in 300:
		await physics_frame
		if m.subpoena_timer <= 0.0: break
	var flat := Vector3(m.global_position.x - stand.x, 0, m.global_position.z - stand.z)
	check(flat.length() < 2.0, "meathead ends up on the witness stand (%.1fm away)" % flat.length())
	check(m.stun_timer > 0.0, "meathead is stuck on the stand for a while")
	check(not m.start_charge(Vector3.FORWARD), "meathead can't act while on the stand")

func test_adagio_is_grab_and_charge_proof() -> void:
	var m := meat(); m.ai_enabled = false
	var tile: Vector3 = main.get_node("AdagioTile").global_position
	var e: Node3D = bots()[0]
	park_everyone_else([e])
	place(e, tile + Vector3(0, 0.7, 0)); place(m, tile + Vector3(0, 1, 2.5))
	await frames(3)
	check(e.anchored and e.speed_multiplier < 1.0, "adagio makes the egghead heavy and slow")
	check(not m.try_grab(), "anchored egghead can't be grabbed")
	place(m, tile + Vector3(0, 1, 6))
	await frames(2)
	m.start_charge(Vector3.FORWARD)
	for i in 90:
		await physics_frame
		if m.stun_timer > 0.0: break
	check(not e.is_cracked, "charge doesn't crack an anchored egghead")
	check(m.stun_timer > 0.0, "meathead bounces off and is dazed")
	place(e, Vector3(0, 0.7, 0))
	await frames(3)
	check(not e.anchored and e.speed_multiplier == 1.0, "leaving adagio restores the egghead")

func test_no_vowels_firewall() -> void:
	main.firewall = "NO_VOWELS"
	var forge: Node3D = main.get_node("Forge")
	park_everyone_else([main.player])
	place(get_nodes_in_group("block")[0], forge.global_position + Vector3(-1, 0.6, -1))
	await _walk_player_onto(forge, Vector3(2, 0.7, 2))
	check(forge.is_typing(), "forge typing starts")
	var shown: String = forge.display_phrase()
	check(not shown.contains("A") and not shown.contains("E") and not shown.contains("I") \
		and not shown.contains("O") and not shown.contains("U"), "vowels hidden: %s" % shown)
	check(shown.length() == forge.target_phrase.length(), "blanks keep the word's length")
	main._update_hud()
	check(main._hud_prompt.text.contains(shown), "HUD prompt shows the masked word")
	_type(forge, forge.target_phrase)
	check(main.blocks_locked == 1, "typing the real word still works")
	check(TypingStation.hide_vowels("HABEAS CORPUS") == "H_B__S C_RP_S", "hide_vowels keeps consonants and spaces")

func test_title_screen_flow() -> void:
	# Rebuild the scene the way the real game starts: title first, paused.
	_teardown()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(2)
	check(main.title_screen != null and paused, "game opens paused on the title screen")
	check(not main.round_active, "round hasn't started yet")
	var t0: float = main.time_left
	await frames(10)
	check(main.time_left == t0, "clock doesn't run behind the title screen")
	var left := InputEventAction.new(); left.action = "meathead_move_right"; left.pressed = true
	main.title_screen._unhandled_input(left)
	check(main.title_screen.selected_firewall() == "NO_VOWELS", "meathead side can pick a firewall")
	var go := InputEventAction.new(); go.action = "ui_accept"; go.pressed = true
	main.title_screen._unhandled_input(go)
	await frames(3)
	check(main.round_active and not paused and main.firewall == "NO_VOWELS", "start begins the round with the firewall")
	check(main.title_screen == null, "title screen dismissed")
	check(main.meathead.ai_enabled, "pressing start doesn't steal the Meathead from the AI")
	main.end_round("MEATHEADS")
	check(main._hud_end.text.contains("rematch") and main._hud_end.text.contains("title"), "end screen offers rematch and title")

func test_sounds_synthesized() -> void:
	var sfx := root.get_node("Sfx")
	for name in ["crack", "splat", "flop", "charge", "grab", "yeet", "grease", "key", "wrong",
			"lock", "habeas", "respawn", "free", "tick", "win", "lose"]:
		var s: AudioStreamWAV = sfx.sounds.get(name)
		check(s != null and s.data.size() > 200, "sound '%s' synthesized" % name)
		if s:
			var peak := 0
			for i in range(0, s.data.size(), 2):
				peak = max(peak, absi(s.data.decode_s16(i)))
			check(peak > 3000 and peak <= 32767, "sound '%s' is audible and not clipped (peak %d)" % [name, peak])
		sfx.play(name) # Silent mode still validates the name (warns if unknown).

func test_screen_shake() -> void:
	var cam: Camera3D = main.get_node("Camera3D")
	var m := meat(); m.ai_enabled = false
	var e: Node3D = bots()[0]
	park_everyone_else([e])
	check(cam.trauma == 0.0, "no shake at rest")
	e.crack()
	check(cam.trauma > 0.3, "crack shakes the camera (trauma %.2f)" % cam.trauma)
	await frames(3)
	check(absf(cam.h_offset) + absf(cam.v_offset) > 0.0, "shake moves the view")
	await frames(90)
	check(cam.trauma == 0.0 and absf(cam.h_offset) < 0.001, "shake settles back to rest")
	place(m, Vector3(0, 1, 0))
	m.belly_flop()
	var flop_trauma: float = cam.trauma
	check(flop_trauma >= 0.5, "belly-flop shakes harder than a grab")
	cam.trauma = 0.0
	cam.shake_enabled = false
	e._respawn()
	e.crack()
	check(cam.trauma == 0.0, "shake can be turned off")

func test_ai_soak() -> void:
	# 40 simulated seconds of AI Meathead vs bot Eggheads: must not error, and stuff must happen.
	# Seeded so the outcome is reproducible: the AI is random enough that an unseeded
	# run occasionally sees no delivery in 40s, which would make CI flaky.
	_teardown()
	main = load("res://main.tscn").instantiate()
	main.show_title = false
	main.rng_seed = int(OS.get_environment("SOAK_SEED")) if OS.get_environment("SOAK_SEED") != "" else 1
	root.add_child(main)
	await frames(2)
	var start := {}
	for b in get_nodes_in_group("block"):
		start[b] = b.global_position
	var forge: Node3D = main.get_node("Forge")
	var max_in_forge := 0
	for i in 2400:
		await physics_frame
		if i % 30 == 0:
			max_in_forge = max(max_in_forge, forge.blocks_inside().size())
	var moved := 0
	for b in start:
		if b.global_position.distance_to(start[b]) > 3.0:
			moved += 1
	print("    soak: heat=%d, blocks moved=%d, max blocks in forge=%d" % [main.heat, moved, max_in_forge])
	check(main.heat > 0, "AI meathead causes chaos")
	check(moved >= 2, "bots push blocks around")
	check(max_in_forge >= 1, "bots deliver at least one block to the forge")
