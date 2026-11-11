extends RefCounted
## Sons gerados em código (16 bits, mono). Assim o apartamento tem chuva,
## ruído de cidade, tensão, passos, celular e helicóptero sem arquivos de áudio
## novos — e cada som pode ser ajustado aqui mesmo.

const RATE: int = 22050

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

## Os últimos 0,3 s se misturam ao começo: o laço não estala.
static func _seamless(s: PackedFloat32Array) -> PackedFloat32Array:
	var fade: int = int(RATE * 0.3)
	var n: int = s.size() - fade
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		out[i] = s[i]
	for i: int in range(fade):
		var t: float = float(i) / float(fade)
		out[i] = s[n + i] * (1.0 - t) + s[i] * t
	return out

## Chuva no vidro: chiado filtrado com gotas mais grossas de vez em quando.
static func rain(seconds: float = 4.0) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var n: int = int(RATE * seconds)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp: float = 0.0
	var lp2: float = 0.0
	var drop: float = 0.0
	for i: int in range(n):
		var w: float = rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.35
		lp2 += (lp - lp2) * 0.5
		if rng.randf() < 0.0016:
			drop = rng.randf_range(0.3, 0.8)
		drop *= 0.992
		s[i] = lp2 * 0.55 + w * drop * 0.25
	return _wav(_seamless(s), true)

## Cidade lá embaixo: ronco grave de trânsito e um zumbido elétrico.
static func city(seconds: float = 6.0) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23
	var n: int = int(RATE * seconds)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		var swell: float = 0.6 + 0.4 * sin(t * TAU / seconds * 2.0)
		s[i] = lp * 2.2 * swell + sin(t * TAU * 60.0) * 0.015
	return _wav(_seamless(s), true)

## Tensão: dois graves quase iguais batendo devagar (o "pulso" do medo).
static func drone(seconds: float = 8.0) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i: int in range(n):
		var t: float = float(i) / RATE
		var a: float = sin(t * TAU * 55.0) + sin(t * TAU * 55.5) * 0.9 + sin(t * TAU * 110.25) * 0.25
		s[i] = a * 0.22 * (0.7 + 0.3 * sin(t * TAU * 0.25))
	return _wav(s, true)

## Batida de coração (suspeita crítica): tum-tum, pausa.
static func heartbeat() -> AudioStreamWAV:
	var n: int = int(RATE * 1.0)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i: int in range(n):
		var t: float = float(i) / RATE
		var beat: float = exp(-t * 28.0) + 0.7 * exp(-maxf(0.0, t - 0.22) * 30.0) * (1.0 if t > 0.22 else 0.0)
		s[i] = sin(t * TAU * 48.0) * beat * 0.9
	return _wav(s, true)

## Um passo no taco de madeira (tocado com pitch aleatório).
static func step() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var n: int = int(RATE * 0.14)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		s[i] = (lp * 1.6 + sin(t * TAU * 90.0) * 0.5) * exp(-t * 38.0)
	return _wav(s, false)

## Celular vibrando sobre a mesa (vibra 0,8 s, pausa 0,6 s).
static func phone_buzz() -> AudioStreamWAV:
	var n: int = int(RATE * 1.4)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i: int in range(n):
		var t: float = float(i) / RATE
		if t > 0.8:
			s[i] = 0.0
			continue
		var env: float = minf(1.0, t * 40.0) * minf(1.0, (0.8 - t) * 40.0)
		var motor: float = signf(sin(t * TAU * 170.0)) * 0.5 + sin(t * TAU * 340.0) * 0.3
		var rattle: float = sin(t * TAU * 1200.0) * 0.12 * (0.5 + 0.5 * sin(t * TAU * 23.0))
		s[i] = (motor + rattle) * env * 0.45
	return _wav(s, true)

## Helicóptero distante: pás cortando o ar.
static func helicopter(seconds: float = 2.0) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	var n: int = int(RATE * seconds)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		var chop: float = pow(0.5 + 0.5 * sin(t * TAU * 11.0), 6.0)
		s[i] = lp * 3.0 * (0.25 + chop) + sin(t * TAU * 44.0) * 0.1 * chop
	return _wav(s, true)
