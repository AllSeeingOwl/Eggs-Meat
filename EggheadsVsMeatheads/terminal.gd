extends Node3D

@export var target_phrase: String = "HABEAS CORPUS"
var current_input: String = ""
var active_egghead = null
var is_active: bool = false
var barrier_timer: float = 0.0

@onready var ui_label: Label3D = $Label3D
@onready var barrier: StaticBody3D = $Barrier
@onready var trigger_area: Area3D = $TriggerArea

func _ready() -> void:
    ui_label.text = ""
    barrier.collision_layer = 2
    barrier.collision_mask = 0
    barrier.hide()
    barrier.process_mode = Node.PROCESS_MODE_DISABLED

    trigger_area.body_entered.connect(_on_body_entered)
    trigger_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
    if barrier_timer > 0.0:
        barrier_timer -= delta
        if barrier_timer <= 0.0:
            barrier.hide()
            barrier.process_mode = Node.PROCESS_MODE_DISABLED
            # Optional: reset state so they can do it again, or disable the terminal entirely
            # Here we'll just let them type again if they are still there
            current_input = ""
            ui_label.text = "HABEAS CORPUS"
            is_active = false
            if active_egghead:
                _start_typing()

func _unhandled_key_input(event: InputEvent) -> void:
    if not is_active or barrier_timer > 0.0:
        return

    if event is InputEventKey and event.pressed and not event.echo:
        var keycode = event.keycode
        var key_string = ""

        # Simple backspace
        if keycode == KEY_BACKSPACE:
            if current_input.length() > 0:
                current_input = current_input.substr(0, current_input.length() - 1)
        elif keycode == KEY_SPACE:
            key_string = " "
        else:
            # Godot 4 keycode to string
            var c = OS.get_keycode_string(keycode)
            if c.length() == 1:
                key_string = c.to_upper()

        if key_string != "":
            current_input += key_string

        _update_ui()
        _check_phrase()

        # Stop the input event from propagating further if we handled a character
        get_viewport().set_input_as_handled()

func _update_ui() -> void:
    var combined = "TARGET: " + target_phrase + "\nTYPED: " + current_input
    ui_label.text = combined

func _check_phrase() -> void:
    if current_input == target_phrase:
        _trigger_success()

func _trigger_success() -> void:
    is_active = false
    if active_egghead and active_egghead.has_method("is_egghead"):
        active_egghead.is_typing = false

    ui_label.text = "[SUCCESS]"
    barrier.show()
    barrier.process_mode = Node.PROCESS_MODE_INHERIT
    barrier_timer = 5.0
    current_input = ""

func _on_body_entered(body: Node3D) -> void:
    if barrier_timer > 0.0:
        return # Don't start if barrier is already up

    if body.has_method("is_egghead") and body.is_egghead():
        if active_egghead == null:
            active_egghead = body
            _start_typing()

func _on_body_exited(body: Node3D) -> void:
    if body == active_egghead:
        _stop_typing()
        active_egghead = null

func _start_typing() -> void:
    is_active = true
    current_input = ""
    _update_ui()
    if active_egghead:
        active_egghead.is_typing = true
        # Also kill any velocity
        active_egghead.linear_velocity = Vector3.ZERO
        active_egghead.angular_velocity = Vector3.ZERO

func _stop_typing() -> void:
    is_active = false
    ui_label.text = ""
    if active_egghead:
        active_egghead.is_typing = false
