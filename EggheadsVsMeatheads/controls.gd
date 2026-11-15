extends Node
## Autoload: registers every input action at startup so the bindings live in
## one readable place instead of the serialized blob in project.godot.
##
## Egghead (keyboard + typing):  WASD to move, letters/space to type at stations,
##                               Esc to step away from a station.
## Meathead (keyboard):          Arrows to move, Enter = charge, Right Shift = grab/yeet,
##                               Right Ctrl = grease, / = belly-flop.
## Meathead (gamepad):           Left stick, A = charge, X = grab/yeet, B = grease, Y = belly-flop.
## Global:                       F2 = toggle Meathead AI, F3 = toggle screen shake,
##                               F4 = mute, R = restart (after a round ends).

func _ready() -> void:
	_key_action("egghead_move_up", [KEY_W])
	_key_action("egghead_move_down", [KEY_S])
	_key_action("egghead_move_left", [KEY_A])
	_key_action("egghead_move_right", [KEY_D])
	_key_action("egghead_cancel", [KEY_ESCAPE])

	_key_action("meathead_move_up", [KEY_UP])
	_key_action("meathead_move_down", [KEY_DOWN])
	_key_action("meathead_move_left", [KEY_LEFT])
	_key_action("meathead_move_right", [KEY_RIGHT])
	_axis("meathead_move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("meathead_move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("meathead_move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("meathead_move_right", JOY_AXIS_LEFT_X, 1.0)

	_key_action("meathead_charge", [KEY_ENTER, KEY_KP_ENTER])
	_button("meathead_charge", JOY_BUTTON_A)
	_key_action("meathead_grab", [KEY_SHIFT])
	_button("meathead_grab", JOY_BUTTON_X)
	_key_action("meathead_grease", [KEY_CTRL])
	_button("meathead_grease", JOY_BUTTON_B)
	_key_action("meathead_flop", [KEY_SLASH])
	_button("meathead_flop", JOY_BUTTON_Y)

	_key_action("toggle_meathead_ai", [KEY_F2])
	_key_action("toggle_shake", [KEY_F3])
	_key_action("toggle_mute", [KEY_F4])
	_key_action("restart", [KEY_R])

func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)

func _key_action(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
