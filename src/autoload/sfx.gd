extends Node
## Tiny procedural sound-effect synth (no audio files needed) + a soft generated ambient loop.

const RATE := 22050
var sounds: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var _next := 0
var music: AudioStreamPlayer
var _cooldowns: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	add_child(music)
	_build()


func _process(delta: float) -> void:
	for k in _cooldowns.keys():
		_cooldowns[k] -= delta
		if _cooldowns[k] <= 0:
			_cooldowns.erase(k)
	if music.playing:
		music.volume_db = linear_to_db(max(Settings.music_volume * 0.35, 0.0001))


func play(name: String, pitch_var: float = 0.08, vol: float = 1.0) -> void:
	if not sounds.has(name) or _cooldowns.has(name):
		return
	_cooldowns[name] = 0.035
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = linear_to_db(max(Settings.sfx_volume * vol, 0.0001))
	p.play()


func play_music(on: bool) -> void:
	if on and not music.playing:
		music.play()
	elif not on:
		music.stop()


# ---------------------------------------------------------------- synthesis
func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _tone(dur: float, f0: float, f1: float, wave: String = "sine", noise: float = 0.0, attack: float = 0.005, vol: float = 0.6, decay_pow: float = 1.5) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 13 + dur * 1000)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var s := 0.0
		match wave:
			"sine":
				s = sin(phase * TAU)
			"square":
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				s *= 0.5
			"saw":
				s = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.6
			"tri":
				s = (abs(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0)
		if noise > 0.0:
			var nz := rng.randf_range(-1.0, 1.0)
			lp = lerpf(lp, nz, 0.35)
			s = lerpf(s, lp * 1.6, noise)
		var env := minf(1.0, float(i) / max(1.0, attack * RATE)) * pow(1.0 - t, decay_pow)
		out[i] = s * env * vol
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: float = 0.0) -> PackedFloat32Array:
	var off := int(offset * RATE)
	var n := maxi(a.size(), b.size() + off)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size():
			v += a[i]
		if i - off >= 0 and i - off < b.size():
			v += b[i - off]
		out[i] = v
	return out


func _build() -> void:
	sounds["swing"] = _wav(_tone(0.12, 900, 300, "sine", 0.85, 0.02, 0.35, 2.0))
	sounds["hit"] = _wav(_tone(0.11, 220, 90, "square", 0.55, 0.002, 0.55, 2.0))
	sounds["crit"] = _wav(_mix(_tone(0.16, 320, 110, "square", 0.5, 0.002, 0.55), _tone(0.12, 1400, 900, "sine", 0.0, 0.002, 0.25)))
	sounds["shoot"] = _wav(_tone(0.10, 1200, 500, "tri", 0.3, 0.002, 0.35, 2.5))
	sounds["gun"] = _wav(_tone(0.14, 400, 80, "square", 0.8, 0.001, 0.55, 3.0))
	sounds["magic"] = _wav(_mix(_tone(0.25, 500, 1100, "sine", 0.0, 0.01, 0.3), _tone(0.25, 750, 1650, "tri", 0.0, 0.01, 0.15)))
	sounds["explode"] = _wav(_tone(0.45, 120, 30, "square", 0.9, 0.002, 0.7, 1.6))
	sounds["hurt"] = _wav(_tone(0.18, 300, 140, "saw", 0.3, 0.003, 0.5))
	sounds["dash"] = _wav(_tone(0.16, 300, 1200, "sine", 0.85, 0.01, 0.3, 1.2))
	sounds["pickup"] = _wav(_mix(_tone(0.07, 880, 880, "square", 0.0, 0.002, 0.25), _tone(0.09, 1320, 1320, "square", 0.0, 0.002, 0.25), 0.06))
	sounds["coin"] = _wav(_mix(_tone(0.06, 1500, 1500, "square", 0.0, 0.001, 0.2), _tone(0.2, 2000, 2000, "square", 0.0, 0.001, 0.2), 0.05))
	var lv := _tone(0.12, 523, 523, "square", 0.0, 0.002, 0.22)
	lv = _mix(lv, _tone(0.12, 659, 659, "square", 0.0, 0.002, 0.22), 0.1)
	lv = _mix(lv, _tone(0.12, 784, 784, "square", 0.0, 0.002, 0.22), 0.2)
	lv = _mix(lv, _tone(0.4, 1046, 1046, "square", 0.0, 0.002, 0.22, 1.0), 0.3)
	sounds["levelup"] = _wav(lv)
	sounds["click"] = _wav(_tone(0.04, 1000, 800, "square", 0.0, 0.001, 0.15))
	sounds["equip"] = _wav(_tone(0.12, 600, 300, "square", 0.6, 0.001, 0.3))
	sounds["death"] = _wav(_tone(0.35, 400, 60, "saw", 0.4, 0.005, 0.45))
	sounds["heal"] = _wav(_mix(_tone(0.35, 600, 900, "sine", 0.0, 0.03, 0.25), _tone(0.35, 900, 1350, "sine", 0.0, 0.03, 0.18), 0.05))
	sounds["buff"] = _wav(_tone(0.4, 300, 900, "tri", 0.1, 0.05, 0.3, 1.0))
	sounds["error"] = _wav(_tone(0.18, 160, 140, "square", 0.0, 0.002, 0.25))
	sounds["portal"] = _wav(_mix(_tone(0.6, 200, 800, "sine", 0.3, 0.1, 0.3, 1.0), _tone(0.6, 300, 1200, "tri", 0.0, 0.1, 0.15, 1.0)))
	sounds["chest"] = _wav(_mix(_tone(0.15, 200, 120, "square", 0.5, 0.002, 0.35), _tone(0.3, 1200, 1800, "sine", 0.0, 0.01, 0.2), 0.12))
	sounds["trap"] = _wav(_tone(0.12, 1800, 600, "square", 0.3, 0.001, 0.25))
	sounds["chop"] = _wav(_tone(0.09, 300, 200, "square", 0.75, 0.001, 0.4, 2.5))
	sounds["mine"] = _wav(_tone(0.08, 1600, 1200, "tri", 0.4, 0.001, 0.35, 3.0))
	sounds["block"] = _wav(_tone(0.1, 1400, 1100, "tri", 0.2, 0.001, 0.35, 2.5))
	sounds["fire"] = _wav(_tone(0.35, 200, 90, "saw", 0.9, 0.02, 0.4, 1.2))
	sounds["ice"] = _wav(_mix(_tone(0.25, 2200, 1800, "sine", 0.3, 0.002, 0.2), _tone(0.2, 3100, 2600, "sine", 0.0, 0.002, 0.12)))
	sounds["wind"] = _wav(_tone(0.4, 400, 600, "sine", 0.95, 0.08, 0.35, 1.0))
	sounds["earth"] = _wav(_tone(0.35, 90, 40, "square", 0.85, 0.005, 0.6, 1.4))
	sounds["light"] = _wav(_mix(_tone(0.4, 1000, 1500, "sine", 0.0, 0.01, 0.25), _tone(0.4, 1500, 2250, "sine", 0.0, 0.02, 0.15)))
	sounds["dark"] = _wav(_tone(0.4, 220, 110, "saw", 0.4, 0.03, 0.35, 1.0))
	sounds["eat"] = _wav(_tone(0.12, 300, 250, "square", 0.8, 0.002, 0.25, 2.0))
	sounds["roar"] = _wav(_tone(0.7, 160, 70, "saw", 0.6, 0.05, 0.55, 1.0))
	_build_music()


func _build_music() -> void:
	# 16-second ambient pad: slow arpeggio over soft chords
	var dur := 16.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66], [164.81, 207.65, 246.94]]
	for ci in 4:
		var c: Array = chords[ci]
		var start := int(ci * 4.0 * RATE)
		for i in int(4.0 * RATE):
			var t := float(i) / RATE
			var env := minf(1.0, t / 1.2) * minf(1.0, (4.0 - t) / 1.2)
			var v := 0.0
			for f in c:
				v += sin(TAU * f * 0.5 * t) * 0.10 + sin(TAU * f * t * 1.002) * 0.04
			# arpeggio
			var step := int(t * 4.0) % 3
			var at := fmod(t * 4.0, 1.0)
			v += sin(TAU * float(c[step]) * 2.0 * t) * 0.05 * pow(1.0 - at, 3.0)
			out[start + i] = v * env
	music.stream = _wav(out, true)
