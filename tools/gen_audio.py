import wave, math, random, struct, os

SR = 22050
OUT = "assets/audio"
os.makedirs(OUT, exist_ok=True)
random.seed(1999)

def clamp(x, a=-1.0, b=1.0):
    return a if x < a else b if x > b else x

def save(name, samples, stereo=False):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        data = bytearray()
        for s in samples:
            if stereo:
                l = clamp(s[0]); r = clamp(s[1])
                data += struct.pack("<hh", int(l*32767), int(r*32767))
            else:
                data += struct.pack("<h", int(clamp(s)*32767))
        w.writeframes(bytes(data))
    print(name, round(len(samples)/SR, 2), "s")

def note(n):
    # midi -> hz
    return 440.0 * (2.0 ** ((n - 69) / 12.0))

def env(t, dur, a=0.01, d=0.2, s=0.6, r=0.1):
    if t < a: return t/a
    if t < a+d: return 1.0 - (1.0-s)*((t-a)/d)
    if t < dur-r: return s
    if t < dur: return s*(1.0-(t-(dur-r))/r)
    return 0.0

def saw(f, t, detune=0.0):
    ph = (f+detune)*t
    return 2.0*(ph - math.floor(ph+0.5))

def sine(f, t, ph=0.0):
    return math.sin(math.tau*f*t + ph)

# ---------------- synthwave loop ----------------
BPM = 88.0
beat = 60.0/BPM
bar = beat*4
bars = 12
total = bar*bars
n = int(total*SR)
# chord voicings (midi) Dm - Bb - F - C, lush
chords = [
    [50, 53, 57, 62],  # Dm
    [46, 50, 53, 58],  # Bb
    [41, 45, 48, 53],  # F
    [48, 52, 55, 60],  # C
]
bass_roots = [38, 34, 29, 36]
lead_scale = [62, 65, 69, 72, 74, 77, 81, 84]
music = [0.0]*n
for i in range(n):
    t = i/SR
    b = int(t/bar) % 4
    tb = t % bar
    beat_i = int(tb/beat)
    # pad
    pad = 0.0
    for k, m in enumerate(chords[b]):
        f = note(m)
        pad += 0.055*sine(f, t, ph=k*0.7) + 0.018*saw(f, t, 0.7) + 0.018*saw(f, t, -0.7)
    pad_env = min(1.0, tb/0.4) * min(1.0, max(0.0, (bar-tb)/0.4))
    # bass pulse on 8ths
    bt = (tb % (beat*0.5))
    bf = note(bass_roots[b])
    bass = (0.16*sine(bf, t) + 0.06*saw(bf, t)) * math.exp(-bt*4.0)
    # arpeggio 16ths
    at = (tb % (beat*0.25))
    step = int(tb/(beat*0.25))
    am = lead_scale[(step*3 + b*2) % len(lead_scale)]
    arp = 0.05*sine(note(am), t) * math.exp(-at*9.0)
    # kick
    kt = (tb % beat)
    kick = 0.0
    if beat_i % 4 in (0, 2) or (b == 3 and beat_i == 3):
        kick = 0.34*math.sin(math.tau*(55 + 70*math.exp(-kt*18))*kt) * math.exp(-kt*9.0)
    # snare on 2 and 4
    st = (tb % (beat*2))
    snare = 0.0
    if beat_i % 4 == 1:
        snare = 0.10*(random.random()*2-1) * math.exp(-st*18.0)
    # hat 8ths
    ht = (tb % (beat*0.5))
    hat = 0.035*(random.random()*2-1) * math.exp(-ht*55.0)
    music[i] = pad*pad_env + bass + arp + kick + snare + hat

# simple stereo widening delay
left = [0.0]*n; right = [0.0]*n
for i in range(n):
    d = int(0.011*SR)  # 11ms
    left[i] = music[i] * 0.92 + (music[i-d] * 0.16 if i >= d else 0.0)
    right[i] = music[i] * 0.86 + (music[i-int(d*1.7)] * 0.22 if i >= int(d*1.7) else 0.0)
# fade edges for clean loop
for i in range(int(0.4*SR)):
    f = i/(0.4*SR)
    left[i] *= f; right[i] *= f
    left[n-1-i] *= f; right[n-1-i] *= f
save("music_sunset.wav", list(zip(left, right)), stereo=True)

# ---------------- engine loop ----------------
n = int(2.0*SR)
eng = []
for i in range(n):
    t = i/SR
    f = 48.0 + 2.0*math.sin(math.tau*2.0*t)
    v = 0.20*saw(f, t) + 0.10*saw(f*2, t) + 0.06*sine(f*0.5, t)
    v *= 0.75 + 0.25*math.sin(math.tau*6.0*t)
    # notch noise
    v += 0.02*(random.random()*2-1)
    eng.append(v*0.8)
save("engine.wav", eng)

# ---------------- gunshot ----------------
n = int(0.4*SR)
g = []
for i in range(n):
    t = i/SR
    noise = (random.random()*2-1)
    v = noise*0.55*math.exp(-t*30.0) + 0.45*math.sin(math.tau*90*t)*math.exp(-t*18.0)
    g.append(v)
save("gunshot.wav", g)

# ---------------- explosion ----------------
n = int(1.6*SR)
e = []
for i in range(n):
    t = i/SR
    noise = (random.random()*2-1)
    v = noise*0.45*math.exp(-t*4.5) + 0.35*math.sin(math.tau*(38+26*math.exp(-t*5))*t)*math.exp(-t*2.5)
    e.append(v)
save("explosion.wav", e)

# ---------------- siren loop ----------------
n = int(3.0*SR)
s = []
for i in range(n):
    t = i/SR
    f = 760 + 180*math.sin(math.tau*0.55*t)
    v = 0.13*sine(f, t) + 0.04*sine(f*2, t)
    s.append(v)
save("siren.wav", s)

# ---------------- click ----------------
n = int(0.12*SR)
c = [0.25*math.sin(math.tau*1400*(i/SR))*math.exp(-(i/SR)*40.0) for i in range(n)]
save("click.wav", c)

# ---------------- hit / thud ----------------
n = int(0.22*SR)
h = [0.35*(random.random()*2-1)*math.exp(-(i/SR)*24.0) + 0.3*math.sin(math.tau*70*(i/SR))*math.exp(-(i/SR)*14.0) for i in range(n)]
save("hit.wav", h)

# ---------------- mission complete ----------------
n = int(2.4*SR)
m = []
for i in range(n):
    t = i/SR
    v = 0.0
    for k, nn in enumerate([62, 65, 69, 74]):
        st = k*0.12
        if t > st:
            tt = t-st
            v += 0.10*sine(note(nn), tt)*math.exp(-tt*1.8)
    m.append(v)
save("mission.wav", m)

# ---------------- pickup ----------------
n = int(0.6*SR)
p = []
for i in range(n):
    t = i/SR
    v = 0.15*sine(note(74), t)*math.exp(-t*6) + 0.12*sine(note(81), t)*math.exp(-t*4)
    p.append(v)
save("pickup.wav", p)
