/**
 * Menu theme is a module singleton so React screen changes never restart it.
 * Title starts the 8-bit track; menu select calls playMenuTheme() again and
 * that is a no-op while it is already playing — same playback head, no cut.
 */

const THEME_SRC = "/audio/tdm-8bit.mp3";
const THEME_VOL = 0.58;

type ThemeHandle = {
  el: HTMLAudioElement;
  fadeRaf: number | null;
};

let theme: ThemeHandle | null = null;
let ctx: AudioContext | null = null;
let muted = false;
let sfxMaster = 0.7;
const listeners = new Set<() => void>();

function isBrowser() {
  return typeof window !== "undefined";
}

function notify() {
  for (const fn of listeners) fn();
}

export function subscribeAudio(fn: () => void) {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}

export function getAudioCtx(): AudioContext | null {
  return ctx;
}

export function isMuted() {
  return muted;
}

export function isThemePlaying() {
  return Boolean(theme && !theme.el.paused && !theme.el.ended);
}

export function getThemeTime() {
  return theme?.el.currentTime ?? 0;
}

function ensureCtx() {
  if (!isBrowser()) return null;
  if (!ctx) {
    const AC =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    ctx = new AC({ latencyHint: "interactive" });
  }
  if (ctx.state === "suspended") {
    void ctx.resume();
  }
  return ctx;
}

function ensureTheme() {
  if (!isBrowser()) return null;
  if (!theme) {
    const el = new Audio(THEME_SRC);
    el.loop = true;
    el.preload = "auto";
    el.volume = muted ? 0 : THEME_VOL;
    el.setAttribute("playsinline", "true");
    el.dataset.role = "menu-theme";
    el.className = "sr-only";
    if (document.body) document.body.appendChild(el);
    theme = { el, fadeRaf: null };
  }
  return theme;
}

/** Call synchronously inside the first click / tap / key. */
export function unlockAudio() {
  ensureCtx();
  ensureTheme();
}

export function playMenuTheme() {
  unlockAudio();
  const handle = ensureTheme();
  if (!handle) return;
  if (handle.fadeRaf != null) {
    cancelAnimationFrame(handle.fadeRaf);
    handle.fadeRaf = null;
  }
  handle.el.volume = muted ? 0 : THEME_VOL;
  // Already rolling — do not seek, do not replay. Title → menu continuity.
  if (!handle.el.paused && !handle.el.ended) return;
  const play = handle.el.play();
  if (play) void play.catch(() => {});
}

export function fadeOutMenuTheme(ms = 700) {
  const handle = theme;
  if (!handle || handle.el.paused) return;
  if (handle.fadeRaf != null) cancelAnimationFrame(handle.fadeRaf);
  const start = handle.el.volume;
  const t0 = performance.now();
  const step = (now: number) => {
    const t = Math.min(1, (now - t0) / ms);
    handle.el.volume = start * (1 - t);
    if (t < 1) {
      handle.fadeRaf = requestAnimationFrame(step);
      return;
    }
    handle.fadeRaf = null;
    handle.el.pause();
  };
  handle.fadeRaf = requestAnimationFrame(step);
}

export function fadeInMenuTheme(ms = 500) {
  unlockAudio();
  const handle = ensureTheme();
  if (!handle) return;
  if (handle.fadeRaf != null) {
    cancelAnimationFrame(handle.fadeRaf);
    handle.fadeRaf = null;
  }
  const target = muted ? 0 : THEME_VOL;
  handle.el.volume = 0;
  const play = handle.el.play();
  if (play) void play.catch(() => {});
  const t0 = performance.now();
  const step = (now: number) => {
    const t = Math.min(1, (now - t0) / ms);
    handle.el.volume = target * t;
    if (t < 1) {
      handle.fadeRaf = requestAnimationFrame(step);
      return;
    }
    handle.fadeRaf = null;
    handle.el.volume = target;
  };
  handle.fadeRaf = requestAnimationFrame(step);
}

export function setMuted(next: boolean) {
  muted = next;
  if (theme) {
    if (theme.fadeRaf != null) {
      cancelAnimationFrame(theme.fadeRaf);
      theme.fadeRaf = null;
    }
    theme.el.volume = muted || theme.el.paused ? 0 : THEME_VOL;
  }
  notify();
}

export function toggleMute() {
  setMuted(!muted);
  return muted;
}

function beep(
  freq: number,
  dur: number,
  type: OscillatorType = "square",
  gain = 0.08,
  slide?: number,
) {
  const ac = ensureCtx();
  if (!ac || muted) return;
  const osc = ac.createOscillator();
  const g = ac.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, ac.currentTime);
  if (slide != null) {
    osc.frequency.linearRampToValueAtTime(slide, ac.currentTime + dur);
  }
  g.gain.setValueAtTime(0.0001, ac.currentTime);
  g.gain.exponentialRampToValueAtTime(gain * sfxMaster, ac.currentTime + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + dur);
  osc.connect(g);
  g.connect(ac.destination);
  osc.start();
  osc.stop(ac.currentTime + dur + 0.02);
}

export const sfx = {
  uiConfirm() {
    beep(520, 0.08, "square", 0.07);
  },
  uiMove() {
    beep(280, 0.05, "square", 0.04);
  },
  punch() {
    beep(220, 0.07, "sawtooth", 0.06, 90);
  },
  kick() {
    beep(140, 0.1, "sawtooth", 0.08, 55);
  },
  special() {
    beep(320, 0.2, "square", 0.09, 80);
    beep(82, 0.18, "sawtooth", 0.08);
  },
  hit(heavy: boolean) {
    beep(heavy ? 90 : 130, heavy ? 0.14 : 0.08, "square", heavy ? 0.14 : 0.1, 40);
  },
  hurt() {
    beep(180, 0.12, "sawtooth", 0.1, 70);
  },
  jump() {
    beep(240, 0.1, "square", 0.07, 420);
  },
  land() {
    beep(90, 0.05, "sine", 0.06, 50);
  },
  ko() {
    beep(70, 0.25, "square", 0.12, 30);
  },
  gameOver() {
    beep(200, 0.4, "square", 0.08, 60);
  },
  victory() {
    beep(523, 0.15, "square", 0.08);
    window.setTimeout(() => beep(659, 0.15, "square", 0.08), 120);
    window.setTimeout(() => beep(784, 0.3, "square", 0.1), 240);
  },
  waveStart(wave: number) {
    beep(300 + wave * 40, 0.15, "square", 0.07);
  },
  waveClear() {
    beep(440, 0.12, "triangle", 0.08);
    beep(660, 0.18, "triangle", 0.08);
  },
  pause() {
    beep(200, 0.08, "sine", 0.05);
  },
  resume() {
    beep(320, 0.08, "sine", 0.05);
  },
};

if (isBrowser()) {
  const resume = () => {
    if (ctx && ctx.state === "suspended") void ctx.resume();
  };
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") resume();
  });
  window.addEventListener("focus", resume);
}
