extends Node3D
class_name TypingStation
## Base for anything the player Egghead activates by typing a phrase while
## standing in its TriggerArea (the Habeas Corpus terminal, the Forge).
## Movement is frozen while typing; Esc steps away so you are never trapped.

signal phrase_completed(station)

@export var trigger_area_path: NodePath = ^"TriggerArea"
@export var label_path: NodePath = ^"Label3D"

var target_phrase: String = ""
var current_input: String = ""
var active_egghead: Node3D = null ## The player Egghead currently typing here.
var _cancelled_by: Node3D = null ## Player pressed Esc; ignore them until they leave.

@onready var trigger_area: Area3D = get_node(trigger_area_path)
@onready var ui_label: Label3D = get_node(label_path)

func _ready() -> void:
	add_to_group("station")
	trigger_area.body_exited.connect(_on_body_exited)

## Override: is the station currently usable?
func can_activate() -> bool:
	return true

## Override: pick the phrase when typing starts.
func choose_phrase() -> String:
	return target_phrase

## Override: what happens on success.
func on_success() -> void:
	pass

## Override: idle text shown when nobody is typing.
func idle_text() -> String:
	return ""

func is_typing() -> bool:
	return active_egghead != null

func _physics_process(_delta: float) -> void:
	var player := _player_in_area()
	if active_egghead:
		if player != active_egghead or not can_activate() or not active_egghead.can_be_targeted() or active_egghead.stun_timer > 0.0:
			stop_typing()
	elif player and player != _cancelled_by and can_activate() and player.stun_timer <= 0.0:
		start_typing(player)
	if not active_egghead:
		ui_label.text = idle_text()

func _player_in_area() -> Node3D:
	for b in trigger_area.get_overlapping_bodies():
		if b.has_method("is_egghead") and b.is_player and b.can_be_targeted():
			return b
	return null

func start_typing(egghead: Node3D) -> void:
	active_egghead = egghead
	target_phrase = choose_phrase()
	current_input = ""
	egghead.is_typing = true
	egghead.linear_velocity = Vector3.ZERO
	_update_ui()

func stop_typing() -> void:
	if active_egghead and is_instance_valid(active_egghead):
		active_egghead.is_typing = false
	active_egghead = null
	current_input = ""
	ui_label.text = idle_text()

## Feed one character (or "\b" for backspace). Public so tests can drive it.
func type_char(c: String) -> void:
	if not active_egghead:
		return
	if c == "\b":
		current_input = current_input.substr(0, max(0, current_input.length() - 1))
	else:
		current_input += c
		# Wrong letter: wipe the line (keeps it a skill check, not a mash).
		if not target_phrase.begins_with(current_input):
			current_input = ""
			SoundFX.play_sfx("wrong", -6.0, 0.0)
		elif current_input != target_phrase:
			SoundFX.play_sfx("key", -8.0, 0.15)
	_update_ui()
	if current_input == target_phrase:
		var egghead := active_egghead
		stop_typing()
		_cancelled_by = null
		on_success()
		phrase_completed.emit(self)
		# Let the same player go again straight away if the station allows it.
		if egghead and can_activate() and _player_in_area() == egghead:
			start_typing(egghead)

func _unhandled_key_input(event: InputEvent) -> void:
	if not active_egghead or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.physical_keycode == KEY_ESCAPE:
		_cancelled_by = active_egghead
		stop_typing()
	elif key.physical_keycode == KEY_BACKSPACE:
		type_char("\b")
	elif key.physical_keycode == KEY_SPACE:
		type_char(" ")
	elif key.unicode > 0:
		var c := char(key.unicode).to_upper()
		if c >= "A" and c <= "Z":
			type_char(c)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func _update_ui() -> void:
	ui_label.text = "TYPE: %s\n%s_" % [target_phrase, current_input]

func _on_body_exited(body: Node3D) -> void:
	if body == _cancelled_by:
		_cancelled_by = null
