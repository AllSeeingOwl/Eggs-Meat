extends CanvasLayer
## Title / how-to-play screen shown before the first round. The game is paused
## behind it. The Meathead side picks its pre-match "Firewall" here (Left/Right),
## then anyone starts the round with Enter, Space or gamepad A.

signal start_requested(firewall: String)

const FIREWALLS := [
	{"id": "NONE", "name": "OPEN BOOK", "desc": "No sabotage: Eggheads see every word in full."},
	{"id": "NO_VOWELS", "name": "NO VOWELS", "desc": "Eggheads see words with the vowels blanked out:  C_NT_L_V_R"},
]

const EGG_COLOR := Color(1.0, 0.82, 0.3)
const MEAT_COLOR := Color(1.0, 0.5, 0.5)
const DIM := Color(0.8, 0.82, 0.88)

var firewall_index: int = 0
var _firewall_label: Label
var _firewall_desc: Label
var _start_label: Label
var _blink: float = 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()

func selected_firewall() -> String:
	return FIREWALLS[firewall_index].id

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("meathead_move_left") or event.is_action_pressed("ui_left"):
		cycle(-1)
	elif event.is_action_pressed("meathead_move_right") or event.is_action_pressed("ui_right"):
		cycle(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("meathead_charge"):
		start_requested.emit(selected_firewall())
	else:
		return
	get_viewport().set_input_as_handled()

func cycle(step: int) -> void:
	firewall_index = posmod(firewall_index + step, FIREWALLS.size())
	SoundFX.play_sfx("key", -4.0, 0.0)
	_refresh()

func _process(delta: float) -> void:
	_blink += delta
	_start_label.modulate.a = 0.55 + 0.45 * absf(sin(_blink * 2.5))

func _refresh() -> void:
	var f: Dictionary = FIREWALLS[firewall_index]
	_firewall_label.text = "<   %s   >" % f.name
	_firewall_desc.text = f.desc

# --- Layout ------------------------------------------------------------------

func _label(text: String, size: int, color: Color = Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

func _column(title: String, color: Color, lines: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(540, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.add_child(_label(title, 24, color))
	for line in lines:
		col.add_child(_label(line, 16, DIM))
	return col

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.border_color = Color(0.35, 0.35, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := _label("EGGHEADS  vs  MEATHEADS", 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	v.add_child(title)
	v.add_child(_label("Round 1:  The Foundry of Force", 22, Color(1, 0.6, 0.25), HORIZONTAL_ALIGNMENT_CENTER))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 36)
	cols.add_child(_column("EGGHEADS  (you: the gold egg)", EGG_COLOR, [
		"Temper 5 iron blocks before the 3:00 clock runs out.",
		"Shove grey blocks onto the orange FORGE (bots help).",
		"Stand on the Forge and type the word to temper one.",
		"WASD move  ·  type at stations  ·  Esc step away",
		"Charges CRACK you. Grabbed? Mash WASD to wriggle free.",
	]))
	cols.add_child(_column("MEATHEAD  (2nd player, or the AI)", MEAT_COLOR, [
		"Stop them until time runs out. Chaos earns HEAT.",
		"Arrows move  ·  Enter charge  ·  R-Shift grab / yeet",
		"R-Ctrl grease  ·  /  belly-flop  ·  or use a gamepad",
		"Clumsy on purpose: laggy controls, winded after flops.",
		"The AI plays until you touch the controls (F2: AI).",
	]))
	v.add_child(cols)

	v.add_child(_label("KNOWLEDGE IS POWER", 22, Color(0.6, 0.85, 1.0)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 2)
	for t in [
		"HABEAS CORPUS (blue, type it): free a grabbed Egghead",
		"SUBPOENA (purple, type it): haul Meathead to the stand",
		"ALLEGRO (green tile): run faster",
		"ADAGIO (brown tile): slow, but grab- and charge-proof",
		"OBSIDIAN (black tile): immune to belly-flops",
		"F3 screen shake  ·  F4 mute",
	]:
		var l := _label(t, 16, DIM)
		l.custom_minimum_size = Vector2(540, 0)
		grid.add_child(l)
	v.add_child(grid)

	var sep := HSeparator.new()
	v.add_child(sep)
	var fw_row := HBoxContainer.new()
	fw_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fw_row.add_theme_constant_override("separation", 18)
	fw_row.add_child(_label("MEATHEAD'S FIREWALL (Left / Right):", 22, MEAT_COLOR))
	_firewall_label = _label("", 26, Color.WHITE)
	fw_row.add_child(_firewall_label)
	v.add_child(fw_row)
	_firewall_desc = _label("", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_firewall_desc)

	_start_label = _label("Press ENTER or SPACE to start", 28, Color(0.6, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_start_label)
