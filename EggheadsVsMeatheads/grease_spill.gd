extends Area3D

@export var duration: float = 10.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create a timer to self-destroy
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)

func _on_body_entered(body: Node) -> void:
	if body.has_method("is_egghead") and body.is_egghead():
		if body.has_method("set_greased"):
			body.set_greased(true)

func _on_body_exited(body: Node) -> void:
	if body.has_method("is_egghead") and body.is_egghead():
		if body.has_method("set_greased"):
			body.set_greased(false)

func _on_timeout() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("is_egghead") and body.is_egghead():
			if body.has_method("set_greased"):
				body.set_greased(false)
	queue_free()
