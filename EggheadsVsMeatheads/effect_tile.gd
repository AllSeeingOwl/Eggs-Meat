extends Area3D
## A stealth-learning floor tile.
##   ALLEGRO  (music):   Eggheads standing here move faster.
##   OBSIDIAN (geology): Eggheads standing here ignore the Meathead's belly-flop slam.

enum Kind { ALLEGRO, OBSIDIAN }

@export var kind: Kind = Kind.ALLEGRO
@export var speed_bonus: float = 1.8

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	var mat := StandardMaterial3D.new()
	var label := $Label3D as Label3D
	match kind:
		Kind.ALLEGRO:
			mat.albedo_color = Color(0.2, 0.8, 0.35)
			label.text = "ALLEGRO >>\n(fast)"
		Kind.OBSIDIAN:
			mat.albedo_color = Color(0.08, 0.05, 0.12)
			mat.metallic = 0.8
			mat.roughness = 0.1
			label.text = "OBSIDIAN\n(slam-proof)"
	$MeshInstance3D.material_override = mat

func _on_enter(body: Node) -> void:
	if not body.has_method("is_egghead"):
		return
	match kind:
		Kind.ALLEGRO: body.speed_multiplier = speed_bonus
		Kind.OBSIDIAN: body.slam_immune = true

func _on_exit(body: Node) -> void:
	if not body.has_method("is_egghead"):
		return
	match kind:
		Kind.ALLEGRO: body.speed_multiplier = 1.0
		Kind.OBSIDIAN: body.slam_immune = false
