/**
 * Procedural SFX via Web Audio API — no external files.
 * Unlock on first user gesture (browser autoplay policy).
 */

let ctx: AudioContext | null = null;
let master: GainNode | null = null;
let muted = false;
let unlocked = false;

function ensure(): AudioContext | null {
  if (typeof window === "undefined") return null;
  if (!ctx) {
    const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = muted ? 0 : 0.55;
    master.connect(ctx.destination);
  }
  return ctx;
}

export async function unlockAudio(): Promise<void> {
  const c = ensure();
  if (!c) return;
  if (c.state === "suspended") {
    try {
      await c.resume();
    } catch {
      /* ignore */
    }
  }
  unlocked = c.state === "running";
}

export function isAudioUnlocked() {
  return unlocked;
}

export function setMuted(next: boolean) {
  muted = next;
  if (master) master.gain.value = muted ? 0 : 0.55;
}

export function toggleMute(): boolean {
  setMuted(!muted);
  return muted;
}

export function isMuted() {
  return muted;
}

function out(): GainNode | null {
  ensure();
  return master;
}

function noiseBuffer(duration: number, color: "white" | "pink" = "white"): AudioBuffer | null {
  const c = ensure();
  if (!c) return null;
  const len = Math.max(1, Math.floor(c.sampleRate * duration));
  const buf = c.createBuffer(1, len, c.sampleRate);
  const data = buf.getChannelData(0);
  let last = 0;
  for (let i = 0; i < len; i++) {
    const w = Math.random() * 2 - 1;
    if (color === "pink") {
      last = (last + 0.02 * w) / 1.02;
      data[i] = last * 3.5;
    } else {
      data[i] = w;
    }
  }
  return buf;
}

function safeAudio(fn: () => void) {
  try {
    fn();
  } catch {
    /* ignore WebAudio edge cases */
  }
}

function playNoise(
  duration: number,
  {
    gain = 0.3,
    filterFreq = 1200,
    filterType = "bandpass" as BiquadFilterType,
    color = "white" as "white" | "pink",
    attack = 0.001,
    decay = duration,
  } = {},
) {
  try {
    const c = ensure();
    const m = out();
    if (!c || !m || muted) return;
    const buf = noiseBuffer(duration, color);
    if (!buf) return;
    const src = c.createBufferSource();
    src.buffer = buf;
    const filter = c.createBiquadFilter();
    filter.type = filterType;
    filter.frequency.value = Math.max(20, filterFreq);
    filter.Q.value = 0.7;
    const g = c.createGain();
    const t = c.currentTime;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0001, gain), t + Math.max(0.001, attack));
    g.gain.exponentialRampToValueAtTime(0.0001, t + Math.max(attack + 0.01, decay));
    src.connect(filter);
    filter.connect(g);
    g.connect(m);
    src.start(t);
    src.stop(t + Math.max(0.02, duration) + 0.05);
  } catch {
    /* ignore */
  }
}

function playTone(
  freq: number,
  duration: number,
  {
    type = "square" as OscillatorType,
    gain = 0.2,
    attack = 0.005,
    decay,
    slideTo,
  }: {
    type?: OscillatorType;
    gain?: number;
    attack?: number;
    decay?: number;
    slideTo?: number;
  } = {},
) {
  try {
    const c = ensure();
    const m = out();
    if (!c || !m || muted) return;
    const osc = c.createOscillator();
    const g = c.createGain();
    osc.type = type;
    const t = c.currentTime;
    const f0 = Math.max(20, freq);
    osc.frequency.setValueAtTime(f0, t);
    if (slideTo != null) {
      osc.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t + Math.max(0.01, duration));
    }
    const d = decay ?? duration;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0001, gain), t + Math.max(0.001, attack));
    g.gain.exponentialRampToValueAtTime(0.0001, t + Math.max(attack + 0.01, d));
    osc.connect(g);
    g.connect(m);
    osc.start(t);
    osc.stop(t + Math.max(0.02, duration) + 0.05);
  } catch {
    /* ignore */
  }
}

function playChord(freqs: number[], duration: number, gain = 0.12) {
  for (const f of freqs) {
    playTone(f, duration, { type: "triangle", gain: gain / freqs.length, decay: duration });
  }
}

function whoosh(kind: "punch" | "kick" | "special", player = true) {
  const vol = player ? 1 : 0.55;
  if (kind === "punch") {
    playNoise(0.08, {
      gain: 0.22 * vol,
      filterFreq: 1800,
      filterType: "highpass",
      color: "white",
      attack: 0.002,
      decay: 0.07,
    });
    playTone(220, 0.07, { type: "sawtooth", gain: 0.06 * vol, slideTo: 90 });
  } else if (kind === "kick") {
    playNoise(0.12, {
      gain: 0.28 * vol,
      filterFreq: 900,
      filterType: "bandpass",
      color: "pink",
      attack: 0.004,
      decay: 0.11,
    });
    playTone(140, 0.1, { type: "sawtooth", gain: 0.08 * vol, slideTo: 55 });
  } else {
    playNoise(0.18, {
      gain: 0.32 * vol,
      filterFreq: 1400,
      filterType: "highpass",
      color: "white",
      attack: 0.003,
      decay: 0.16,
    });
    playTone(320, 0.2, { type: "square", gain: 0.1 * vol, slideTo: 80 });
    playTone(480, 0.18, { type: "triangle", gain: 0.08 * vol, slideTo: 160 });
  }
}

function impact(heavy = false, combo = 1) {
  const boost = Math.min(1.35, 1 + (combo - 1) * 0.06);
  playNoise(heavy ? 0.16 : 0.09, {
    gain: (heavy ? 0.42 : 0.3) * boost,
    filterFreq: heavy ? 280 : 450,
    filterType: "lowpass",
    color: "pink",
    attack: 0.001,
    decay: heavy ? 0.14 : 0.08,
  });
  playTone(heavy ? 90 : 130, heavy ? 0.14 : 0.08, {
    type: "square",
    gain: (heavy ? 0.18 : 0.12) * boost,
    slideTo: 40,
  });
  if (heavy) {
    playTone(55, 0.2, { type: "sine", gain: 0.2 * boost, slideTo: 30 });
  }
}

export const sfx = {
  unlock: unlockAudio,

  punch(player = true) {
    whoosh("punch", player);
  },
  kick(player = true) {
    whoosh("kick", player);
  },
  special(player = true) {
    // short wind-up whoosh then full riff
    whoosh("special", player);
    sfx.guitarRiff();
  },

  /** Power-chord guitar riff for the AOE special */
  guitarRiff() {
    // Leaner riff — fewer simultaneous nodes (was crashing some browsers)
    const power = (root: number, atMs: number, hold = 0.16) => {
      setTimeout(() => {
        try {
          playTone(root, hold, { type: "sawtooth", gain: 0.12, attack: 0.01, decay: hold });
          playTone(root * 1.5, hold * 0.9, { type: "square", gain: 0.06, attack: 0.01, decay: hold });
          playNoise(hold * 0.55, {
            gain: 0.07,
            filterFreq: 900,
            filterType: "bandpass",
            color: "pink",
            attack: 0.005,
            decay: hold * 0.5,
          });
        } catch {
          /* ignore */
        }
      }, atMs);
    };
    power(82, 0, 0.14);
    power(98, 120, 0.12);
    power(110, 230, 0.14);
    power(82, 360, 0.2);
    power(147, 520, 0.26);
    setTimeout(() => {
      try {
        playTone(880, 0.28, { type: "sawtooth", gain: 0.06, slideTo: 1200, attack: 0.02, decay: 0.26 });
      } catch {
        /* ignore */
      }
    }, 680);
  },

  jump() {
    playTone(240, 0.1, { type: "square", gain: 0.08, slideTo: 420 });
    playNoise(0.08, {
      gain: 0.12,
      filterFreq: 2000,
      filterType: "highpass",
      color: "white",
      decay: 0.07,
    });
  },

  land() {
    playNoise(0.06, {
      gain: 0.14,
      filterFreq: 350,
      filterType: "lowpass",
      color: "pink",
      decay: 0.05,
    });
    playTone(90, 0.05, { type: "sine", gain: 0.08, slideTo: 50 });
  },

  gunshot() {
    try {
      playNoise(0.09, {
        gain: 0.4,
        filterFreq: 900,
        filterType: "lowpass",
        color: "white",
        attack: 0.001,
        decay: 0.07,
      });
      playTone(180, 0.08, { type: "square", gain: 0.16, slideTo: 40 });
      playTone(90, 0.12, { type: "sine", gain: 0.14, slideTo: 30 });
      playNoise(0.05, {
        gain: 0.2,
        filterFreq: 2800,
        filterType: "highpass",
        color: "white",
        decay: 0.04,
      });
    } catch {
      /* ignore */
    }
  },

  hit(kind: "punch" | "kick" | "special" | null, combo = 1) {
    try {
      impact(kind === "kick" || kind === "special", combo);
      if (kind === "special") {
        // single ping — full chord per foe was overload
        playTone(520 + Math.min(4, combo) * 40, 0.09, { type: "triangle", gain: 0.07, slideTo: 200 });
      }
    } catch {
      /* ignore */
    }
  },

  hurt() {
    playTone(180, 0.12, { type: "sawtooth", gain: 0.12, slideTo: 70 });
    playNoise(0.1, {
      gain: 0.18,
      filterFreq: 700,
      filterType: "bandpass",
      color: "pink",
      decay: 0.09,
    });
  },

  ko() {
    playNoise(0.22, {
      gain: 0.35,
      filterFreq: 200,
      filterType: "lowpass",
      color: "pink",
      decay: 0.2,
    });
    playTone(160, 0.25, { type: "square", gain: 0.14, slideTo: 40 });
    playTone(90, 0.3, { type: "sine", gain: 0.16, slideTo: 35 });
  },

  playerDown() {
    playTone(220, 0.35, { type: "sawtooth", gain: 0.12, slideTo: 50 });
    playTone(165, 0.4, { type: "triangle", gain: 0.1, slideTo: 40 });
    playNoise(0.35, {
      gain: 0.2,
      filterFreq: 400,
      filterType: "lowpass",
      color: "pink",
      decay: 0.32,
    });
  },

  waveStart(wave: number) {
    const base = 330 + wave * 20;
    playTone(base, 0.12, { type: "square", gain: 0.1 });
    setTimeout(() => playTone(base * 1.25, 0.14, { type: "square", gain: 0.1 }), 90);
    setTimeout(() => playTone(base * 1.5, 0.18, { type: "triangle", gain: 0.12 }), 180);
  },

  waveClear() {
    playChord([392, 494, 587], 0.22, 0.14);
    setTimeout(() => playChord([494, 587, 740], 0.28, 0.14), 120);
  },

  smokeBreak() {
    // soft lighter click + drag inhale
    playNoise(0.05, {
      gain: 0.08,
      filterFreq: 3200,
      filterType: "highpass",
      color: "white",
      attack: 0.001,
      decay: 0.04,
    });
    playTone(180, 0.08, { type: "triangle", gain: 0.04, slideTo: 90 });
    setTimeout(() => {
      playNoise(0.22, {
        gain: 0.06,
        filterFreq: 700,
        filterType: "lowpass",
        color: "pink",
        attack: 0.04,
        decay: 0.2,
      });
    }, 80);
  },

  exhale() {
    playNoise(0.28, {
      gain: 0.07,
      filterFreq: 500,
      filterType: "lowpass",
      color: "pink",
      attack: 0.05,
      decay: 0.25,
    });
  },

  victory() {
    const notes = [392, 494, 587, 784, 988];
    notes.forEach((f, i) => {
      setTimeout(() => playTone(f, 0.22, { type: "triangle", gain: 0.12 }), i * 90);
    });
    setTimeout(() => playChord([523, 659, 784, 1046], 0.5, 0.16), 480);
  },

  gameOver() {
    playTone(280, 0.3, { type: "sawtooth", gain: 0.1, slideTo: 90 });
    setTimeout(() => playTone(180, 0.4, { type: "triangle", gain: 0.1, slideTo: 60 }), 140);
    setTimeout(() => playTone(90, 0.55, { type: "sine", gain: 0.14, slideTo: 40 }), 300);
  },

  uiConfirm() {
    playTone(520, 0.08, { type: "square", gain: 0.08 });
    setTimeout(() => playTone(780, 0.12, { type: "square", gain: 0.09 }), 60);
  },

  uiClick() {
    playTone(640, 0.04, { type: "square", gain: 0.06 });
  },

  pause() {
    playTone(400, 0.06, { type: "triangle", gain: 0.07 });
    setTimeout(() => playTone(280, 0.08, { type: "triangle", gain: 0.06 }), 50);
  },

  resume() {
    playTone(280, 0.06, { type: "triangle", gain: 0.07 });
    setTimeout(() => playTone(400, 0.08, { type: "triangle", gain: 0.06 }), 50);
  },
};

export const TRACKS = [
  { id: "night", name: "Night Shift", notes: [110, 146, 164, 196] },
  { id: "brand", name: "Brand Ambush", notes: [98, 123, 147, 185] },
  { id: "riff", name: "Riff or Die", notes: [82, 110, 123, 164] },
  { id: "smoke", name: "Smoke Break", notes: [130, 164, 196, 246] },
] as const;

let jukeHandle: number | null = null;
let jukeId: string | null = null;

export function currentTrack() {
  return jukeId;
}

export function stopTrack() {
  if (jukeHandle != null) {
    window.clearInterval(jukeHandle);
    jukeHandle = null;
  }
  jukeId = null;
}

export function playTrack(id: string) {
  const track = TRACKS.find((t) => t.id === id);
  if (!track) return;
  stopTrack();
  jukeId = id;
  let i = 0;
  const tick = () => {
    const n = track.notes[i % track.notes.length]!;
    playTone(n, 0.22, { type: "square", gain: 0.07 });
    playTone(n * 2, 0.16, { type: "triangle", gain: 0.04 });
    i += 1;
  };
  tick();
  jukeHandle = window.setInterval(tick, 280);
}
