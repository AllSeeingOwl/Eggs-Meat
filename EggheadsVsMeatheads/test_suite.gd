extends SceneTree

func _init():
	print("Running test suite...")

	# We need to simulate the scene
	var root = Node3D.new()
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)

	var egghead = load("res://egghead.tscn").instantiate()
	egghead.global_position = Vector3(5, 1, 0)
	root.add_child(egghead)

	var meathead = load("res://meathead.tscn").instantiate()
	meathead.global_position = Vector3(0, 1, 0)
	root.add_child(meathead)

	root.add_to_group("test_root")

	# Add to tree properly to avoid transform errors
	# Wait, we can't easily add to a non-existent main loop without run, but we can set original_material manually for the test
	egghead.original_material = StandardMaterial3D.new()

	print("Test 1: Check Grab")
	meathead.global_position = Vector3(0, 1, 0)
	egghead.global_position = Vector3(1, 1, 0)
	meathead._grab_object(egghead)

	if meathead.held_object == egghead and egghead.freeze == true:
		print("Grab test passed")
	else:
		print("Grab test failed")
		quit(1)

	print("Test 2: Check Yeet and Wall Impact")
	# Force meathead velocity so it yeets in a specific direction
	meathead.linear_velocity = Vector3.FORWARD
	meathead._yeet_object()

	if meathead.held_object == null and egghead.freeze == false and egghead.is_thrown == true:
		print("Yeet test passed")
	else:
		print("Yeet test failed")
		quit(1)

	# Now simulate wall impact
	egghead._on_body_entered(arena.get_node("WallN"))
	if egghead.stun_timer > 0.0 and egghead.is_thrown == false:
		print("Wall impact test passed")
	else:
		print("Wall impact test failed")
		quit(1)

	print("Test 3: Check Grease")
	var grease = load("res://grease_spill.tscn").instantiate()
	root.add_child(grease)
	grease._on_body_entered(egghead)

	if egghead.is_greased == true and egghead.linear_damp == 0.0:
		print("Grease enter test passed")
	else:
		print("Grease enter test failed")
		quit(1)

	grease._on_body_exited(egghead)
	if egghead.is_greased == false and egghead.linear_damp == 5.0:
		print("Grease exit test passed")
	else:
		print("Grease exit test failed")
		quit(1)

	print("All tests passed.")

	# Cleanup
	root.queue_free()

	quit(0)
