extends Node

## Music, engine, siren and one-shot SFX. All audio is original and generated.

var music: AudioStreamPlayer
var engine: AudioStreamPlayer
var siren: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _engine_target := -55.0
var _siren_target := -55.0
var _engine_pitch := 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = _make_player(_loop("res://assets/audio/music_sunset.wav"), -13.0, true)
	engine = _make_player(_loop("res://assets/audio/engine.wav"), -60.0, true)
	siren = _make_player(_loop("res://assets/audio/siren.wav"), -60.0, true)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx.append(p)
	transition_music("WAVE 99.1 — SUNSET FM")

func _make_player(stream: AudioStream, db: float, looped: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = "Master"
	add_child(p)
	if looped:
		p.play()
	return p

func _loop(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream

func _process(delta: float) -> void:
	if engine:
		engine.volume_db = lerpf(engine.volume_db, _engine_target, delta * 6.0)
		engine.pitch_scale = lerpf(engine.pitch_scale, _engine_pitch, delta * 4.0)
	if siren:
		siren.volume_db = lerpf(siren.volume_db, _siren_target, delta * 3.0)

func transition_music(station: String) -> void:
	Game.radio_station = station
	Game.radio_changed.emit(station)
	if music and music.stream:
		music.play()

func set_engine(active: bool, speed_ratio := 0.0) -> void:
	_engine_target = -18.0 if active else -55.0
	_engine_pitch = clampf(0.72 + speed_ratio * 1.35, 0.6, 2.4)

func set_siren(active: bool) -> void:
	_siren_target = -22.0 if active else -55.0

func play_sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStream = load("res://assets/audio/%s.wav" % name)
	if stream == null:
		return
	var p := _sfx[_sfx_index % _sfx.size()]
	_sfx_index += 1
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

func gunshot() -> void:
	play_sfx("gunshot", -4.0, randf_range(0.92, 1.08))

func explosion() -> void:
	play_sfx("explosion", -2.0, randf_range(0.9, 1.0))

func click() -> void:
	play_sfx("click", -8.0)

func pickup() -> void:
	play_sfx("pickup", -6.0)

func hit() -> void:
	play_sfx("hit", -5.0, randf_range(0.9, 1.1))

func mission_done() -> void:
	play_sfx("mission", -5.0)
