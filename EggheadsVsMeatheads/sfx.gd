extends Node
class_name SoundFX
## Autoload ("Sfx"): procedurally synthesized sound effects (no audio assets needed).
## Every sound is generated once at startup into an AudioStreamWAV, then played
## from a small pool of players with a little random pitch so repeats don't grate.
##
##   SoundFX.play_sfx("crack")            # default volume, slight pitch variation
##   SoundFX.play_sfx("key", -12.0, 0.0)  # quieter, no pitch variation
## (The static wrappers are safe to call even when the autoload isn't loaded,
## e.g. in headless `-s` test runs.)
##
## F4 mutes/unmutes all audio.

const RATE := 22050
const POOL_SIZE := 16

var sounds: Dictionary = {} ## name -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _next := 0

static var instance: SoundFX

static func play_sfx(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if instance:
		instance.play(sound, volume_db, pitch_jitter)

static func toggle_mute_sfx() -> bool:
	return instance.toggle_mute() if instance else false

func _ready() -> void:
	instance = self
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_build_all()

func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var stream: AudioStreamWAV = sounds.get(sound)
	if stream == null:
		push_warning("Unknown sound: " + sound)
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

func toggle_mute() -> bool:
	var muted := not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, muted)
	return muted

# --- Sound design ------------------------------------------------------------

func _build_all() -> void:
	# Egghead cracks: a sharp shell snap plus a squeaky falling "eep".
	sounds.crack = _mix([
		_noise(0.06, 0.9, 0.0, 0.5),
		_tone(1400, 700, 0.05, "square", 0.25),
		_delay(_tone(900, 250, 0.18, "sine", 0.4), 0.03),
	])
	# Thrown egg hits a wall.
	sounds.splat = _mix([_noise(0.22, 0.15, 0.0, 0.6), _tone(140, 45, 0.2, "sine", 0.9)])
	# Belly-flop: big low boom with a rumble tail.
	sounds.flop = _mix([_tone(90, 28, 0.55, "sine", 1.0), _noise(0.5, 0.06, 0.0, 0.7)])
	# Charge: angry snort that rises.
	sounds.charge = _mix([_tone(70, 150, 0.35, "saw", 0.45), _noise(0.3, 0.2, 0.05, 0.35)])
	# Grab: rubbery pop.
	sounds.grab = _tone(250, 650, 0.09, "sine", 0.7)
	# Yeet: whoosh that swells then fades, with a rising whistle.
	sounds.yeet = _mix([_noise(0.4, 0.35, 0.5, 0.6), _tone(500, 1500, 0.35, "sine", 0.15)])
	# Grease: wobbly squelch.
	sounds.grease = _mix([_wobble(220, 70, 0.3, 18.0, 0.6), _noise(0.25, 0.1, 0.02, 0.3)])
	# Typing: keyboard click / wrong-key buzz.
	sounds.key = _mix([_noise(0.015, 1.0, 0.0, 0.4), _tone(2200, 2200, 0.02, "sine", 0.15)])
	sounds.wrong = _tone(130, 110, 0.18, "square", 0.35)
	# Block tempered: bright two-note chime.
	sounds.lock = _mix([_bell(880, 0.7, 0.5), _delay(_bell(1318.5, 0.8, 0.45), 0.09)])
	# HABEAS CORPUS: two gavel knocks, then a chime.
	var knock := _mix([_tone(200, 90, 0.09, "sine", 0.9), _noise(0.03, 0.5, 0.0, 0.5)])
	sounds.habeas = _mix([knock, _delay(knock, 0.16), _delay(_bell(1046.5, 0.6, 0.4), 0.34)])
	# Respawn / wriggle free / countdown tick.
	sounds.respawn = _tone(600, 1200, 0.12, "sine", 0.35)
	sounds.free = _mix([_tone(300, 900, 0.18, "square", 0.25), _tone(450, 1350, 0.18, "sine", 0.3)])
	sounds.tick = _tone(1000, 1000, 0.05, "sine", 0.35)
	# End of round.
	sounds.win = _sequence([523.3, 659.3, 784.0, 1046.5], 0.13, "square", 0.45, 0.5)
	sounds.lose = _sequence([392.0, 329.6, 261.6, 196.0], 0.2, "saw", 0.45, 0.6)

	for k in sounds:
		sounds[k] = _to_stream(sounds[k])

# --- Tiny synth --------------------------------------------------------------
# Buffers are PackedFloat32Array in -1..1 at RATE Hz.

func _osc(wave: String, phase: float) -> float:
	match wave:
		"square": return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw": return fmod(phase, 1.0) * 2.0 - 1.0
		_: return sin(phase * TAU)

## Pitch sweep from f0 to f1 (exponential) with a short attack and linear decay.
func _tone(f0: float, f1: float, dur: float, wave: String, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += f0 * pow(f1 / f0, t) / RATE
		out[i] = _osc(wave, phase) * amp * _env(t, 0.02)
	return out

## Frequency wobble (vibrato) for squelchy sounds.
func _wobble(f0: float, f1: float, dur: float, rate_hz: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t) * (1.0 + 0.35 * sin(TAU * rate_hz * i / RATE))
		phase += f / RATE
		out[i] = sin(phase * TAU) * amp * _env(t, 0.05)
	return out

## Filtered noise. `bright` 0..1 is a one-pole low-pass coefficient (1 = raw white noise).
## `swell` is the fraction of the duration spent fading in.
func _noise(dur: float, bright: float, swell: float, amp: float = 0.8) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += bright * (randf_range(-1, 1) - y)
		out[i] = y * amp * _env(t, swell) * (1.0 / sqrt(maxf(bright, 0.05)))
	return out

## Bell: sine plus a quiet inharmonic partial with exponential decay.
func _bell(f: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var s := float(i) / RATE
		var e := exp(-s * 6.0) * minf(1.0, float(i) / 40.0)
		out[i] = (sin(TAU * f * s) + 0.3 * sin(TAU * f * 2.76 * s)) * amp * e
	return out

func _sequence(freqs: Array, note: float, wave: String, amp: float, last_len: float) -> PackedFloat32Array:
	var parts := []
	for i in freqs.size():
		var d: float = last_len if i == freqs.size() - 1 else note * 1.2
		parts.append(_delay(_tone(freqs[i], freqs[i], d, wave, amp), note * i))
	return _mix(parts)

## Attack (fraction of duration) then linear decay to zero.
func _env(t: float, attack: float) -> float:
	if attack > 0.0 and t < attack:
		return t / attack
	return clampf((1.0 - t) / max(1.0 - attack, 0.001), 0.0, 1.0)

func _delay(buf: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(seconds * RATE))
	pad.append_array(buf)
	return pad

func _mix(bufs: Array) -> PackedFloat32Array:
	var n := 0
	for b in bufs:
		n = max(n, b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for b in bufs:
		for i in b.size():
			out[i] += b[i]
	return out

func _to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for v in buf:
		peak = max(peak, absf(v))
	var gain := 0.9 / peak if peak > 0.9 else 1.0 # Normalize only if it would clip.
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
