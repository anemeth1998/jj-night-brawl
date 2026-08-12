import { r as __toESM } from "../_runtime.mjs";
import { M as require_react, h as require_jsx_runtime } from "../_libs/@tanstack/react-router+[...].mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/routes-CqLWc2Pm.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var V = "v=7";
var SHEETS = {
	jjIdle: {
		src: `/assets/sprites/jj/idle/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	jjWalk: {
		src: `/assets/sprites/jj/walk/sheet-transparent.png?${V}`,
		cols: 4,
		rows: 2
	},
	jjAttack: {
		src: `/assets/sprites/jj/attack/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	jjKick: {
		src: `/assets/sprites/jj/kick/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	jjHurt: {
		src: `/assets/sprites/jj/hurt/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	jjJump: {
		src: `/assets/sprites/jj/jump/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	jjSpecial: {
		src: `/assets/sprites/jj/special/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	jjSmoke: {
		src: `/assets/sprites/jj/smoke/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	bizIdle: {
		src: `/assets/sprites/enemies/biz/idle-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	bizWalk: {
		src: `/assets/sprites/enemies/biz/walk-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	bizAttack: {
		src: `/assets/sprites/enemies/biz/attack-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	magaIdle: {
		src: `/assets/sprites/enemies/maga/idle-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	magaWalk: {
		src: `/assets/sprites/enemies/maga/walk-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	magaAttack: {
		src: `/assets/sprites/enemies/maga/attack-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	gothmIdle: {
		src: `/assets/sprites/enemies/gothm/idle-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	gothmWalk: {
		src: `/assets/sprites/enemies/gothm/walk-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	gothmAttack: {
		src: `/assets/sprites/enemies/gothm/attack-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	gothfIdle: {
		src: `/assets/sprites/enemies/gothf/idle-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	gothfWalk: {
		src: `/assets/sprites/enemies/gothf/walk-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	gothfAttack: {
		src: `/assets/sprites/enemies/gothf/attack-sheet.png?${V}`,
		cols: 2,
		rows: 2
	},
	fxImpact: {
		src: `/assets/sprites/fx/sheet-transparent.png?${V}`,
		cols: 2,
		rows: 2
	},
	sky: {
		src: `/assets/map/sky.png?${V}`,
		cols: 1,
		rows: 1
	},
	farBg: {
		src: `/assets/map/far-bg.png?${V}`,
		cols: 1,
		rows: 1
	},
	midBg: {
		src: `/assets/map/mid-bg.png?${V}`,
		cols: 1,
		rows: 1
	}
};
function loadImage(src) {
	return new Promise((resolve, reject) => {
		const img = new Image();
		img.crossOrigin = "anonymous";
		img.onload = () => resolve(img);
		img.onerror = () => reject(/* @__PURE__ */ new Error(`Failed to load ${src}`));
		img.src = src;
	});
}
async function loadAssets() {
	const entries = await Promise.all(Object.keys(SHEETS).map(async (key) => {
		const def = SHEETS[key];
		const img = await loadImage(def.src);
		return [key, {
			img,
			cols: def.cols,
			rows: def.rows,
			frameW: Math.floor(img.naturalWidth / def.cols),
			frameH: Math.floor(img.naturalHeight / def.rows),
			frameCount: def.cols * def.rows
		}];
	}));
	return Object.fromEntries(entries);
}
/** Frame index left-to-right, top-to-bottom */
function drawFrame(ctx, sheet, frame, dx, dy, dw, dh, flipX = false) {
	const total = sheet.frameCount;
	const f = (frame % total + total) % total;
	const col = f % sheet.cols;
	const row = Math.floor(f / sheet.cols);
	const sx = col * sheet.frameW;
	const sy = row * sheet.frameH;
	ctx.save();
	if (flipX) {
		ctx.translate(dx + dw / 2, dy + dh / 2);
		ctx.scale(-1, 1);
		ctx.translate(-(dx + dw / 2), -(dy + dh / 2));
	}
	ctx.imageSmoothingEnabled = false;
	ctx.drawImage(sheet.img, sx, sy, sheet.frameW, sheet.frameH, dx, dy, dw, dh);
	ctx.restore();
}
/**
* Procedural SFX via Web Audio API — no external files.
* Unlock on first user gesture (browser autoplay policy).
*/
var ctx = null;
var master = null;
var muted = false;
function ensure() {
	if (typeof window === "undefined") return null;
	if (!ctx) {
		const AC = window.AudioContext || window.webkitAudioContext;
		if (!AC) return null;
		ctx = new AC();
		master = ctx.createGain();
		master.gain.value = muted ? 0 : .55;
		master.connect(ctx.destination);
	}
	return ctx;
}
async function unlockAudio() {
	const c = ensure();
	if (!c) return;
	if (c.state === "suspended") try {
		await c.resume();
	} catch {}
	c.state;
}
function setMuted(next) {
	muted = next;
	if (master) master.gain.value = muted ? 0 : .55;
}
function toggleMute() {
	setMuted(!muted);
	return muted;
}
function isMuted() {
	return muted;
}
function out() {
	ensure();
	return master;
}
function noiseBuffer(duration, color = "white") {
	const c = ensure();
	if (!c) return null;
	const len = Math.max(1, Math.floor(c.sampleRate * duration));
	const buf = c.createBuffer(1, len, c.sampleRate);
	const data = buf.getChannelData(0);
	let last = 0;
	for (let i = 0; i < len; i++) {
		const w = Math.random() * 2 - 1;
		if (color === "pink") {
			last = (last + .02 * w) / 1.02;
			data[i] = last * 3.5;
		} else data[i] = w;
	}
	return buf;
}
function playNoise(duration, { gain = .3, filterFreq = 1200, filterType = "bandpass", color = "white", attack = .001, decay = duration } = {}) {
	const c = ensure();
	const m = out();
	if (!c || !m || muted) return;
	const buf = noiseBuffer(duration, color);
	if (!buf) return;
	const src = c.createBufferSource();
	src.buffer = buf;
	const filter = c.createBiquadFilter();
	filter.type = filterType;
	filter.frequency.value = filterFreq;
	filter.Q.value = .7;
	const g = c.createGain();
	const t = c.currentTime;
	g.gain.setValueAtTime(1e-4, t);
	g.gain.exponentialRampToValueAtTime(Math.max(1e-4, gain), t + attack);
	g.gain.exponentialRampToValueAtTime(1e-4, t + Math.max(attack + .01, decay));
	src.connect(filter);
	filter.connect(g);
	g.connect(m);
	src.start(t);
	src.stop(t + duration + .05);
}
function playTone(freq, duration, { type = "square", gain = .2, attack = .005, decay, slideTo } = {}) {
	const c = ensure();
	const m = out();
	if (!c || !m || muted) return;
	const osc = c.createOscillator();
	const g = c.createGain();
	osc.type = type;
	const t = c.currentTime;
	osc.frequency.setValueAtTime(freq, t);
	if (slideTo != null) osc.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t + duration);
	const d = decay ?? duration;
	g.gain.setValueAtTime(1e-4, t);
	g.gain.exponentialRampToValueAtTime(Math.max(1e-4, gain), t + attack);
	g.gain.exponentialRampToValueAtTime(1e-4, t + Math.max(attack + .01, d));
	osc.connect(g);
	g.connect(m);
	osc.start(t);
	osc.stop(t + duration + .05);
}
function playChord(freqs, duration, gain = .12) {
	for (const f of freqs) playTone(f, duration, {
		type: "triangle",
		gain: gain / freqs.length,
		decay: duration
	});
}
function whoosh(kind, player = true) {
	const vol = player ? 1 : .55;
	if (kind === "punch") {
		playNoise(.08, {
			gain: .22 * vol,
			filterFreq: 1800,
			filterType: "highpass",
			color: "white",
			attack: .002,
			decay: .07
		});
		playTone(220, .07, {
			type: "sawtooth",
			gain: .06 * vol,
			slideTo: 90
		});
	} else if (kind === "kick") {
		playNoise(.12, {
			gain: .28 * vol,
			filterFreq: 900,
			filterType: "bandpass",
			color: "pink",
			attack: .004,
			decay: .11
		});
		playTone(140, .1, {
			type: "sawtooth",
			gain: .08 * vol,
			slideTo: 55
		});
	} else {
		playNoise(.18, {
			gain: .32 * vol,
			filterFreq: 1400,
			filterType: "highpass",
			color: "white",
			attack: .003,
			decay: .16
		});
		playTone(320, .2, {
			type: "square",
			gain: .1 * vol,
			slideTo: 80
		});
		playTone(480, .18, {
			type: "triangle",
			gain: .08 * vol,
			slideTo: 160
		});
	}
}
function impact(heavy = false, combo = 1) {
	const boost = Math.min(1.35, 1 + (combo - 1) * .06);
	playNoise(heavy ? .16 : .09, {
		gain: (heavy ? .42 : .3) * boost,
		filterFreq: heavy ? 280 : 450,
		filterType: "lowpass",
		color: "pink",
		attack: .001,
		decay: heavy ? .14 : .08
	});
	playTone(heavy ? 90 : 130, heavy ? .14 : .08, {
		type: "square",
		gain: (heavy ? .18 : .12) * boost,
		slideTo: 40
	});
	if (heavy) playTone(55, .2, {
		type: "sine",
		gain: .2 * boost,
		slideTo: 30
	});
}
var sfx = {
	unlock: unlockAudio,
	punch(player = true) {
		whoosh("punch", player);
	},
	kick(player = true) {
		whoosh("kick", player);
	},
	special(player = true) {
		whoosh("special", player);
		sfx.guitarRiff();
	},
	/** Power-chord guitar riff for the AOE special */
	guitarRiff() {
		const power = (root, atMs, hold = .16) => {
			setTimeout(() => {
				playTone(root, hold, {
					type: "sawtooth",
					gain: .14,
					attack: .01,
					decay: hold
				});
				playTone(root * 1.5, hold, {
					type: "sawtooth",
					gain: .09,
					attack: .01,
					decay: hold
				});
				playTone(root * 2, hold * .9, {
					type: "square",
					gain: .05,
					attack: .01,
					decay: hold
				});
				playNoise(hold * .7, {
					gain: .1,
					filterFreq: 900,
					filterType: "bandpass",
					color: "pink",
					attack: .005,
					decay: hold * .65
				});
			}, atMs);
		};
		power(82, 0, .14);
		power(98, 110, .12);
		power(110, 210, .14);
		power(82, 340, .22);
		power(123, 480, .18);
		power(147, 600, .28);
		setTimeout(() => {
			playTone(880, .35, {
				type: "sawtooth",
				gain: .07,
				slideTo: 1400,
				attack: .02,
				decay: .32
			});
			playNoise(.3, {
				gain: .08,
				filterFreq: 2400,
				filterType: "highpass",
				color: "white",
				decay: .28
			});
		}, 720);
	},
	jump() {
		playTone(240, .1, {
			type: "square",
			gain: .08,
			slideTo: 420
		});
		playNoise(.08, {
			gain: .12,
			filterFreq: 2e3,
			filterType: "highpass",
			color: "white",
			decay: .07
		});
	},
	land() {
		playNoise(.06, {
			gain: .14,
			filterFreq: 350,
			filterType: "lowpass",
			color: "pink",
			decay: .05
		});
		playTone(90, .05, {
			type: "sine",
			gain: .08,
			slideTo: 50
		});
	},
	hit(kind, combo = 1) {
		impact(kind === "kick" || kind === "special", combo);
		if (kind === "special") {
			playTone(660, .12, {
				type: "triangle",
				gain: .1,
				slideTo: 220
			});
			playChord([
				523,
				659,
				784
			], .15, .1);
		}
	},
	hurt() {
		playTone(180, .12, {
			type: "sawtooth",
			gain: .12,
			slideTo: 70
		});
		playNoise(.1, {
			gain: .18,
			filterFreq: 700,
			filterType: "bandpass",
			color: "pink",
			decay: .09
		});
	},
	ko() {
		playNoise(.22, {
			gain: .35,
			filterFreq: 200,
			filterType: "lowpass",
			color: "pink",
			decay: .2
		});
		playTone(160, .25, {
			type: "square",
			gain: .14,
			slideTo: 40
		});
		playTone(90, .3, {
			type: "sine",
			gain: .16,
			slideTo: 35
		});
	},
	playerDown() {
		playTone(220, .35, {
			type: "sawtooth",
			gain: .12,
			slideTo: 50
		});
		playTone(165, .4, {
			type: "triangle",
			gain: .1,
			slideTo: 40
		});
		playNoise(.35, {
			gain: .2,
			filterFreq: 400,
			filterType: "lowpass",
			color: "pink",
			decay: .32
		});
	},
	waveStart(wave) {
		const base = 330 + wave * 20;
		playTone(base, .12, {
			type: "square",
			gain: .1
		});
		setTimeout(() => playTone(base * 1.25, .14, {
			type: "square",
			gain: .1
		}), 90);
		setTimeout(() => playTone(base * 1.5, .18, {
			type: "triangle",
			gain: .12
		}), 180);
	},
	waveClear() {
		playChord([
			392,
			494,
			587
		], .22, .14);
		setTimeout(() => playChord([
			494,
			587,
			740
		], .28, .14), 120);
	},
	smokeBreak() {
		playNoise(.05, {
			gain: .08,
			filterFreq: 3200,
			filterType: "highpass",
			color: "white",
			attack: .001,
			decay: .04
		});
		playTone(180, .08, {
			type: "triangle",
			gain: .04,
			slideTo: 90
		});
		setTimeout(() => {
			playNoise(.22, {
				gain: .06,
				filterFreq: 700,
				filterType: "lowpass",
				color: "pink",
				attack: .04,
				decay: .2
			});
		}, 80);
	},
	exhale() {
		playNoise(.28, {
			gain: .07,
			filterFreq: 500,
			filterType: "lowpass",
			color: "pink",
			attack: .05,
			decay: .25
		});
	},
	victory() {
		[
			392,
			494,
			587,
			784,
			988
		].forEach((f, i) => {
			setTimeout(() => playTone(f, .22, {
				type: "triangle",
				gain: .12
			}), i * 90);
		});
		setTimeout(() => playChord([
			523,
			659,
			784,
			1046
		], .5, .16), 480);
	},
	gameOver() {
		playTone(280, .3, {
			type: "sawtooth",
			gain: .1,
			slideTo: 90
		});
		setTimeout(() => playTone(180, .4, {
			type: "triangle",
			gain: .1,
			slideTo: 60
		}), 140);
		setTimeout(() => playTone(90, .55, {
			type: "sine",
			gain: .14,
			slideTo: 40
		}), 300);
	},
	uiConfirm() {
		playTone(520, .08, {
			type: "square",
			gain: .08
		});
		setTimeout(() => playTone(780, .12, {
			type: "square",
			gain: .09
		}), 60);
	},
	uiClick() {
		playTone(640, .04, {
			type: "square",
			gain: .06
		});
	},
	pause() {
		playTone(400, .06, {
			type: "triangle",
			gain: .07
		});
		setTimeout(() => playTone(280, .08, {
			type: "triangle",
			gain: .06
		}), 50);
	},
	resume() {
		playTone(280, .06, {
			type: "triangle",
			gain: .07
		});
		setTimeout(() => playTone(400, .08, {
			type: "triangle",
			gain: .06
		}), 50);
	}
};
var LANE_TOP = 310;
var LANE_BOTTOM = 500;
var STAGE_WIDTH = 2800;
var PLAYER_SPEED = 190;
var PLAYER_DEPTH_SPEED = 120;
var ENEMY_SPEED = 95;
var ENEMY_DEPTH_SPEED = 70;
var JUMP_VEL = 520;
var GRAVITY = 1450;
var AIR_CONTROL = .72;
/** 8-frame walk cycle playback rate (frames per second) */
var PLAYER_WALK_FPS = 12;
var ENEMY_WALK_FPS = 8;
var ATTACK_DURATION = {
	punch: .36,
	kick: .48,
	special: .95
};
var ATTACK_ACTIVE = {
	punch: [.12, .28],
	kick: [.16, .38],
	special: [.18, .82]
};
/** World-space radius of the riff blast (expands during active window) */
var RIFF_RADIUS_MIN = 90;
var RIFF_DAMAGE = 22;
var RIFF_KNOCK = 340;
var HURT_DURATION = .35;
var INVULN_AFTER_HIT = .55;
var COMBO_WINDOW = 1.1;
var SPEECH_BUBBLE_LIFE = 1.15;
/** Cigarette break between waves */
var WAVE_CLEAR_DURATION = 3.2;
var SMOKE_FRAME_FPS = 2.2;
/** Pre-riff taunts — random one pops in a speech bubble above JJ */
var PUNK_SLOGANS = [
	"FUCK YEAH!",
	"EAT SHIT BOOTLICKERS!",
	"NOT MY PRESIDENT!",
	"EAT THE RICH!",
	"NO GODS NO MASTERS!",
	"SMASH THE STATE!",
	"DIE YUPPIE SCUM!",
	"THIS MACHINE KILLS FASCISTS!",
	"PUNKS NOT DEAD!",
	"BURN IT DOWN!",
	"ACAB!",
	"CLASS WAR NOW!",
	"NO FUTURE? MAKE ONE!",
	"SCREW YOUR SUIT!",
	"RIFF OR DIE!"
];
var ENEMY_TYPES = [
	"biz",
	"maga",
	"gothm",
	"gothf"
];
var nextId = 1;
function grounded(f) {
	return f.z <= .5 && f.zVel <= 0;
}
function makePlayer() {
	return {
		id: nextId++,
		kind: "player",
		x: 220,
		y: 400,
		z: 0,
		zVel: 0,
		vx: 0,
		vy: 0,
		facing: 1,
		hp: 100,
		maxHp: 100,
		anim: "idle",
		animTime: 0,
		animFrame: 0,
		attackTimer: 0,
		attackActive: false,
		attackHit: false,
		attackKind: null,
		specialHitIds: [],
		hurtTimer: 0,
		invulnTimer: 0,
		combo: 0,
		comboTimer: 0,
		dead: false,
		deathTimer: 0,
		aiCooldown: 0,
		flash: 0,
		scoreValue: 0,
		scale: 1.7,
		bodyW: 42,
		bodyH: 88
	};
}
function makeEnemy(x, y, wave, type) {
	const enemyType = type ?? ENEMY_TYPES[Math.floor(Math.random() * ENEMY_TYPES.length)];
	const hpMul = enemyType === "biz" ? 1.1 : enemyType === "maga" ? 1.05 : .95;
	const hp = Math.round((28 + wave * 8) * hpMul);
	const scale = enemyType === "gothf" ? 1.4 : enemyType === "biz" ? 1.5 : 1.48;
	return {
		id: nextId++,
		kind: "enemy",
		enemyType,
		x,
		y,
		z: 0,
		zVel: 0,
		vx: 0,
		vy: 0,
		facing: -1,
		hp,
		maxHp: hp,
		anim: "idle",
		animTime: 0,
		animFrame: 0,
		attackTimer: 0,
		attackActive: false,
		attackHit: false,
		attackKind: null,
		specialHitIds: [],
		hurtTimer: 0,
		invulnTimer: 0,
		combo: 0,
		comboTimer: 0,
		dead: false,
		deathTimer: 0,
		aiCooldown: .4 + Math.random() * .6,
		flash: 0,
		scoreValue: 100 + wave * 40 + (enemyType === "biz" ? 20 : 0),
		scale,
		bodyW: 48,
		bodyH: 90
	};
}
function createGameState() {
	return {
		phase: "title",
		player: makePlayer(),
		enemies: [],
		particles: [],
		floats: [],
		speechBubble: null,
		cameraX: 0,
		score: 0,
		wave: 0,
		maxWaves: 5,
		waveEnemiesLeft: 0,
		spawnQueue: 0,
		spawnTimer: 0,
		shake: 0,
		hitStop: 0,
		message: "",
		messageTimer: 0,
		specialMeter: 0,
		keys: /* @__PURE__ */ new Set(),
		touch: {
			left: false,
			right: false,
			up: false,
			down: false
		},
		actionQueue: [],
		jumpQueued: false,
		elapsed: 0,
		stageWidth: STAGE_WIDTH,
		riffPulse: 0,
		riffPulseLife: 0,
		smokePuffTimer: 0
	};
}
function startGame(state) {
	nextId = 1;
	Object.assign(state, createGameState());
	state.phase = "playing";
	state.player = makePlayer();
	sfx.uiConfirm();
	beginWave(state, 1);
}
function queueAction(state, kind) {
	if (state.phase !== "playing") return;
	state.actionQueue = [kind];
}
function queueJump(state) {
	if (state.phase !== "playing") return;
	state.jumpQueued = true;
}
function beginSmokeBreak(state, message, duration) {
	const p = state.player;
	p.vx = 0;
	p.vy = 0;
	p.z = 0;
	p.zVel = 0;
	p.attackTimer = 0;
	p.attackKind = null;
	p.attackActive = false;
	p.anim = "smoke";
	p.animTime = 0;
	p.animFrame = 0;
	p.hurtTimer = 0;
	state.message = message;
	state.messageTimer = duration;
	state.smokePuffTimer = .35;
	state.actionQueue = [];
	state.jumpQueued = false;
	state.keys.clear();
	state.speechBubble = null;
	sfx.smokeBreak();
}
function spawnCigSmoke(state, f) {
	const face = f.facing;
	const mouthX = f.x + face * 18;
	const mouthY = f.y - f.bodyH * f.scale * .72 - f.z;
	for (let i = 0; i < 4; i++) state.particles.push({
		x: mouthX + (Math.random() - .5) * 10,
		y: mouthY + (Math.random() - .5) * 6,
		vx: face * (12 + Math.random() * 28) + (Math.random() - .5) * 20,
		vy: -25 - Math.random() * 45,
		life: .7 + Math.random() * .5,
		maxLife: 1.2,
		frame: 0,
		kind: "smoke",
		radius: 4 + Math.random() * 6,
		color: "rgba(180,180,190,0.55)"
	});
}
function updateSmokeBreak(state, dt) {
	const p = state.player;
	p.vx = 0;
	p.vy = 0;
	p.anim = "smoke";
	p.animTime += dt;
	p.animFrame = Math.floor(p.animTime * SMOKE_FRAME_FPS) % 4;
	state.smokePuffTimer -= dt;
	if (state.smokePuffTimer <= 0) {
		spawnCigSmoke(state, p);
		state.smokePuffTimer = p.animFrame === 2 ? .28 : .55;
		if (p.animFrame === 2) sfx.exhale();
	}
}
function beginWave(state, wave) {
	state.wave = wave;
	state.enemies = [];
	const count = 2 + wave;
	state.waveEnemiesLeft = count;
	state.spawnQueue = count;
	state.spawnTimer = .35;
	state.message = wave === state.maxWaves ? "FINAL WAVE" : `WAVE ${wave}`;
	state.messageTimer = 1.6;
	sfx.waveStart(wave);
}
function pressed(state, code) {
	return state.keys.has(code);
}
function moveAxis(state) {
	let mx = 0;
	let my = 0;
	if (pressed(state, "KeyA") || pressed(state, "ArrowLeft") || state.touch.left) mx -= 1;
	if (pressed(state, "KeyD") || pressed(state, "ArrowRight") || state.touch.right) mx += 1;
	if (pressed(state, "KeyW") || pressed(state, "ArrowUp") || state.touch.up) my -= 1;
	if (pressed(state, "KeyS") || pressed(state, "ArrowDown") || state.touch.down) my += 1;
	if (mx !== 0 && my !== 0) {
		const inv = 1 / Math.SQRT2;
		mx *= inv;
		my *= inv;
	}
	return {
		mx,
		my
	};
}
function canAct(f) {
	return !f.dead && f.hurtTimer <= 0 && f.attackTimer <= 0;
}
function canAttack(f) {
	return !f.dead && f.hurtTimer <= 0 && f.attackTimer <= 0;
}
function pickSlogan() {
	return PUNK_SLOGANS[Math.floor(Math.random() * PUNK_SLOGANS.length)];
}
function spawnPunkBubble(state) {
	state.speechBubble = {
		text: pickSlogan(),
		life: SPEECH_BUBBLE_LIFE,
		maxLife: SPEECH_BUBBLE_LIFE,
		followPlayer: true
	};
}
function startAttack(state, f, kind) {
	f.attackKind = kind;
	f.attackTimer = ATTACK_DURATION[kind];
	f.attackActive = false;
	f.attackHit = false;
	f.specialHitIds = [];
	f.anim = "attack";
	f.animTime = 0;
	f.animFrame = 0;
	if (kind === "special") {
		f.vx = 0;
		f.vy = 0;
		f.invulnTimer = Math.max(f.invulnTimer, ATTACK_DURATION.special * .85);
		if (f.kind === "player" && state) spawnPunkBubble(state);
	} else if (grounded(f)) {
		f.vy = 0;
		f.vx = f.facing * (kind === "kick" ? 220 : 140);
	} else f.vx *= .85;
	const isPlayer = f.kind === "player";
	if (kind === "kick") sfx.kick(isPlayer);
	else if (kind === "special") sfx.special(isPlayer);
	else sfx.punch(isPlayer);
}
function spawnRiffBurst(state, x, y, radius) {
	state.riffPulse = radius;
	state.riffPulseLife = .22;
	state.particles.push({
		x,
		y: y - 40,
		vx: 0,
		vy: 0,
		life: .35,
		maxLife: .35,
		frame: 0,
		kind: "wave",
		radius,
		color: "#ff2d8a"
	});
	state.particles.push({
		x,
		y: y - 40,
		vx: 0,
		vy: 0,
		life: .28,
		maxLife: .28,
		frame: 0,
		kind: "wave",
		radius: radius * .65,
		color: "#2de2e6"
	});
	for (let i = 0; i < 10; i++) {
		const a = Math.PI * 2 * i / 10 + Math.random() * .3;
		const s = 120 + Math.random() * 180;
		state.particles.push({
			x,
			y: y - 50 - Math.random() * 30,
			vx: Math.cos(a) * s,
			vy: Math.sin(a) * s * .55 - 40,
			life: .45 + Math.random() * .25,
			maxLife: .7,
			frame: i % 4,
			kind: "note",
			color: i % 2 === 0 ? "#ff2d8a" : "#2de2e6"
		});
	}
}
function riffRadiusAt(t) {
	return RIFF_RADIUS_MIN + 120 * Math.max(0, Math.min(1, (t - .15) / .7));
}
function inRiffRange(attacker, target, radius) {
	const dx = target.x - attacker.x;
	const dy = (target.y - attacker.y) * 1.35;
	return Math.hypot(dx, dy) <= radius && Math.abs(attacker.z - target.z) < 80;
}
function tryJump(f) {
	if (!grounded(f) || f.dead || f.hurtTimer > 0) return false;
	f.zVel = JUMP_VEL;
	f.z = 1;
	f.anim = "jump";
	f.animTime = 0;
	f.animFrame = 1;
	sfx.jump();
	return true;
}
function updatePhysics(f, dt) {
	if (!grounded(f) || f.zVel > 0) {
		f.zVel -= GRAVITY * dt;
		f.z += f.zVel * dt;
		if (f.z <= 0) {
			f.z = 0;
			f.zVel = 0;
			if (f.kind === "player" && f.attackTimer <= 0 && f.hurtTimer <= 0) sfx.land();
		}
	} else {
		f.z = 0;
		f.zVel = 0;
	}
}
function spawnImpact(state, x, y) {
	state.particles.push({
		x,
		y,
		vx: 0,
		vy: -20,
		life: .28,
		maxLife: .28,
		frame: 0,
		kind: "impact"
	});
	for (let i = 0; i < 5; i++) {
		const a = Math.random() * Math.PI * 2;
		const s = 80 + Math.random() * 120;
		state.particles.push({
			x,
			y,
			vx: Math.cos(a) * s,
			vy: Math.sin(a) * s - 40,
			life: .25 + Math.random() * .2,
			maxLife: .4,
			frame: 0,
			kind: "spark"
		});
	}
}
function floatText(state, x, y, text, color) {
	state.floats.push({
		x,
		y,
		text,
		life: .7,
		color
	});
}
function bodyBox(f) {
	return {
		x: f.x - f.bodyW / 2,
		y: f.y - f.bodyH - f.z,
		w: f.bodyW,
		h: f.bodyH
	};
}
function attackBox(f) {
	const kind = f.attackKind ?? "punch";
	const reach = kind === "special" ? 82 : kind === "kick" ? 78 : 54;
	const h = kind === "kick" ? 42 : 40;
	const yOff = kind === "kick" ? 52 : 44;
	return {
		x: f.facing === 1 ? f.x + 10 : f.x - 10 - reach,
		y: f.y - yOff - h / 2 - f.z,
		w: reach,
		h
	};
}
function depthClose(a, b, tol = 28) {
	return Math.abs(a.y - b.y) <= tol;
}
function applyHit(state, attacker, victim, damage, knock) {
	if (victim.dead || victim.invulnTimer > 0) return false;
	victim.hp = Math.max(0, victim.hp - damage);
	victim.hurtTimer = HURT_DURATION;
	victim.invulnTimer = INVULN_AFTER_HIT;
	victim.anim = "hurt";
	victim.animTime = 0;
	victim.animFrame = 0;
	victim.attackTimer = 0;
	victim.attackActive = false;
	victim.flash = .12;
	if (attacker.attackKind === "special") {
		let dirX = victim.x - attacker.x;
		let dirY = victim.y - attacker.y;
		const len = Math.hypot(dirX, dirY) || 1;
		dirX /= len;
		dirY /= len;
		victim.vx = dirX * knock;
		victim.vy = dirY * knock * .55;
		victim.zVel = Math.max(victim.zVel, 220);
		victim.facing = dirX >= 0 ? -1 : 1;
	} else {
		victim.vx = attacker.facing * knock;
		victim.facing = attacker.facing === 1 ? -1 : 1;
		if (!grounded(victim)) victim.zVel = Math.max(victim.zVel, 180);
	}
	attacker.combo += 1;
	attacker.comboTimer = COMBO_WINDOW;
	if (attacker.kind === "player") {
		state.score += damage * 10 + Math.max(0, attacker.combo - 1) * 15;
		if (attacker.attackKind !== "special") state.specialMeter = Math.min(100, state.specialMeter + damage * 1.8);
	}
	const ab = attackBox(attacker);
	spawnImpact(state, attacker.attackKind === "special" ? victim.x : ab.x + ab.w / 2, attacker.attackKind === "special" ? victim.y - victim.bodyH * .5 : ab.y + ab.h / 2);
	floatText(state, victim.x, victim.y - victim.bodyH - victim.z - 10, attacker.attackKind === "special" ? `RIFF ${damage}` : attacker.combo > 1 ? `${damage}! x${attacker.combo}` : `${damage}`, attacker.attackKind === "special" ? "#ff2d8a" : attacker.combo > 3 ? "#ffd56a" : "#fff");
	state.shake = Math.min(10, state.shake + 4 + (attacker.attackKind === "special" ? 4 : 0));
	state.hitStop = attacker.attackKind === "special" ? .05 : attacker.attackKind === "kick" ? .06 : .045;
	sfx.hit(attacker.attackKind, attacker.combo);
	if (victim.kind === "player") sfx.hurt();
	if (victim.hp <= 0) {
		victim.dead = true;
		victim.deathTimer = .9;
		victim.anim = "hurt";
		if (victim.kind === "enemy") {
			state.score += victim.scoreValue;
			state.waveEnemiesLeft = Math.max(0, state.waveEnemiesLeft - 1);
			floatText(state, victim.x, victim.y - victim.bodyH - 28, `+${victim.scoreValue}`, "#2de2e6");
			sfx.ko();
		} else sfx.playerDown();
	}
	return true;
}
function updateAttack(state, f, dt) {
	if (f.attackTimer <= 0 || !f.attackKind) return;
	const kind = f.attackKind;
	const total = ATTACK_DURATION[kind];
	f.attackTimer -= dt;
	const t = 1 - f.attackTimer / total;
	f.animFrame = Math.min(3, Math.floor(t * 4));
	if (grounded(f) && kind !== "special") f.vx *= Math.pow(.02, dt);
	if (kind === "special") {
		f.vx = 0;
		f.vy = 0;
	}
	const [activeStart, activeEnd] = ATTACK_ACTIVE[kind];
	f.attackActive = f.attackTimer > 0 && t >= activeStart && t <= activeEnd;
	if (kind === "special" && f.kind === "player" && f.attackActive) {
		const radius = riffRadiusAt(t);
		for (const m of [
			.22,
			.4,
			.58,
			.75
		]) if (t >= m && t - dt / total < m) {
			spawnRiffBurst(state, f.x, f.y, radius);
			state.shake = Math.min(14, state.shake + 6);
		}
		state.riffPulse = radius;
		state.riffPulseLife = Math.max(state.riffPulseLife, .08);
		for (const target of state.enemies) {
			if (target.dead) continue;
			if (f.specialHitIds.includes(target.id)) continue;
			if (!inRiffRange(f, target, radius)) continue;
			if (applyHit(state, f, target, RIFF_DAMAGE, RIFF_KNOCK)) f.specialHitIds.push(target.id);
		}
	} else if (f.attackActive && !f.attackHit && kind !== "special") {
		const targets = f.kind === "player" ? state.enemies : [state.player];
		const ab = attackBox(f);
		const depthTol = kind === "kick" ? 36 : 28;
		for (const target of targets) {
			if (target.dead || !depthClose(f, target, depthTol)) continue;
			if (Math.abs(f.z - target.z) > 70) continue;
			const bb = bodyBox(target);
			if (ab.x < bb.x + bb.w && ab.x + ab.w > bb.x && ab.y < bb.y + bb.h && ab.y + ab.h > bb.y) {
				const airBonus = !grounded(f) && kind === "kick" ? 4 : 0;
				if (applyHit(state, f, target, (kind === "kick" ? 18 : 11) + airBonus, kind === "kick" ? 220 : 120)) f.attackHit = true;
			}
		}
	}
	if (f.attackTimer <= 0) {
		f.attackActive = false;
		f.attackKind = null;
		f.specialHitIds = [];
		if (!grounded(f)) f.anim = "jump";
		else f.anim = "idle";
		f.animTime = 0;
		if (grounded(f)) f.vx = 0;
	}
}
function updateFighterAnim(f, dt, moving, walkFrames = 4, walkFps = ENEMY_WALK_FPS) {
	if (f.dead) {
		f.anim = "hurt";
		f.animFrame = Math.min(3, Math.floor((1 - f.deathTimer / .9) * 4));
		return;
	}
	if (f.hurtTimer > 0) {
		f.anim = "hurt";
		f.animTime += dt;
		f.animFrame = Math.min(3, Math.floor((1 - f.hurtTimer / HURT_DURATION) * 4));
		return;
	}
	if (f.attackTimer > 0) return;
	if (!grounded(f)) {
		f.anim = "jump";
		f.animTime += dt;
		if (f.zVel > 120) f.animFrame = 1;
		else if (f.zVel > -80) f.animFrame = 2;
		else f.animFrame = 3;
		return;
	}
	if (moving) {
		f.anim = "walk";
		f.animTime += dt;
		f.animFrame = Math.floor(f.animTime * walkFps) % walkFrames;
	} else {
		f.anim = "idle";
		f.animTime += dt;
		f.animFrame = Math.floor(f.animTime * 5) % 4;
	}
}
function clampFighter(f, stageW) {
	f.x = Math.max(60, Math.min(stageW - 60, f.x));
	f.y = Math.max(LANE_TOP, Math.min(LANE_BOTTOM, f.y));
}
function consumePlayerAction(state) {
	const p = state.player;
	if (!canAttack(p)) return;
	while (state.actionQueue.length > 0) {
		const kind = state.actionQueue.shift();
		if (kind === "special") {
			if (state.specialMeter < 40) continue;
			if (!grounded(p)) continue;
			state.specialMeter -= 40;
		}
		startAttack(state, p, kind);
		return;
	}
	if (pressed(state, "KeyJ") || pressed(state, "KeyZ")) {
		startAttack(state, p, "punch");
		state.keys.delete("KeyJ");
		state.keys.delete("KeyZ");
	} else if (pressed(state, "KeyK") || pressed(state, "KeyX")) {
		startAttack(state, p, "kick");
		state.keys.delete("KeyK");
		state.keys.delete("KeyX");
	} else if (grounded(p) && (pressed(state, "KeyL") || pressed(state, "KeyC")) && state.specialMeter >= 40) {
		state.specialMeter -= 40;
		startAttack(state, p, "special");
		state.keys.delete("KeyL");
		state.keys.delete("KeyC");
	}
}
function updatePlayer(state, dt) {
	const p = state.player;
	if (p.dead) {
		p.deathTimer -= dt;
		updatePhysics(p, dt);
		updateFighterAnim(p, dt, false, 8, PLAYER_WALK_FPS);
		if (p.deathTimer <= 0) {
			if (state.phase !== "gameover") sfx.gameOver();
			state.phase = "gameover";
		}
		return;
	}
	if (p.hurtTimer > 0) p.hurtTimer -= dt;
	if (p.invulnTimer > 0) p.invulnTimer -= dt;
	if (p.comboTimer > 0) {
		p.comboTimer -= dt;
		if (p.comboTimer <= 0) p.combo = 0;
	}
	if (p.flash > 0) p.flash -= dt;
	updateAttack(state, p, dt);
	if (state.jumpQueued) {
		state.jumpQueued = false;
		tryJump(p);
	} else if (grounded(p) && (pressed(state, "Space") || pressed(state, "ShiftLeft") || pressed(state, "ShiftRight"))) {
		if (tryJump(p)) {
			state.keys.delete("Space");
			state.keys.delete("ShiftLeft");
			state.keys.delete("ShiftRight");
		}
	}
	let moving = false;
	const air = !grounded(p);
	const { mx, my } = moveAxis(state);
	if (canAct(p) || air && p.attackTimer <= 0 && p.hurtTimer <= 0) {
		const speedMul = air ? AIR_CONTROL : 1;
		if (p.attackTimer <= 0) {
			p.vx = mx * PLAYER_SPEED * speedMul;
			p.vy = air ? 0 : my * PLAYER_DEPTH_SPEED;
			if (mx !== 0) p.facing = mx > 0 ? 1 : -1;
			moving = !air && (mx !== 0 || my !== 0);
		}
		consumePlayerAction(state);
	} else if (p.attackTimer <= 0 && grounded(p)) p.vx *= Math.pow(.05, dt);
	p.x += p.vx * dt;
	p.y += p.vy * dt;
	updatePhysics(p, dt);
	clampFighter(p, state.stageWidth);
	updateFighterAnim(p, dt, moving && canAct(p) && grounded(p), 8, PLAYER_WALK_FPS);
}
function updateEnemyAI(state, e, dt) {
	if (e.dead) {
		e.deathTimer -= dt;
		updatePhysics(e, dt);
		updateFighterAnim(e, dt, false, 4, ENEMY_WALK_FPS);
		return;
	}
	if (e.hurtTimer > 0) e.hurtTimer -= dt;
	if (e.invulnTimer > 0) e.invulnTimer -= dt;
	if (e.flash > 0) e.flash -= dt;
	updateAttack(state, e, dt);
	const p = state.player;
	let moving = false;
	if (canAct(e) && !p.dead) {
		e.aiCooldown -= dt;
		const dx = p.x - e.x;
		const dy = p.y - e.y;
		e.facing = dx >= 0 ? 1 : -1;
		const distX = Math.abs(dx);
		if (distX > 50 || Math.abs(dy) > 22) {
			const nx = dx === 0 ? 0 : dx / distX;
			const ny = dy === 0 ? 0 : dy / Math.abs(dy);
			e.vx = nx * ENEMY_SPEED * (.85 + Math.random() * .2);
			e.vy = ny * ENEMY_DEPTH_SPEED;
			moving = true;
		} else {
			e.vx = 0;
			e.vy = 0;
			if (e.aiCooldown <= 0) {
				startAttack(null, e, Math.random() < .4 ? "kick" : "punch");
				e.aiCooldown = .7 + Math.random() * .9;
			}
		}
	} else if (e.attackTimer <= 0) e.vx *= Math.pow(.05, dt);
	e.x += e.vx * dt;
	e.y += e.vy * dt;
	updatePhysics(e, dt);
	clampFighter(e, state.stageWidth);
	updateFighterAnim(e, dt, moving && canAct(e), 4, ENEMY_WALK_FPS);
}
function updateSpawns(state, dt) {
	if (state.spawnQueue <= 0) return;
	state.spawnTimer -= dt;
	if (state.spawnTimer > 0) return;
	state.spawnTimer = .55 + Math.random() * .35;
	state.spawnQueue -= 1;
	const side = Math.random() < .5 ? -1 : 1;
	const cam = state.cameraX;
	const x = side < 0 ? cam - 40 + Math.random() * 30 : cam + 960 + 20 + Math.random() * 40;
	const y = 340 + Math.random() * 130;
	const type = ENEMY_TYPES[(state.waveEnemiesLeft + state.spawnQueue + state.wave) % ENEMY_TYPES.length];
	state.enemies.push(makeEnemy(Math.max(80, Math.min(state.stageWidth - 80, x)), y, state.wave, type));
}
function updateParticles(state, dt) {
	for (const p of state.particles) {
		p.life -= dt;
		p.x += p.vx * dt;
		p.y += p.vy * dt;
		if (p.kind === "wave" && p.radius != null) p.radius += 280 * dt;
		if (p.kind === "note") p.vy += 120 * dt;
		if (p.kind === "smoke") {
			p.vx *= Math.pow(.9, dt * 60);
			if (p.radius != null) p.radius += 8 * dt;
		}
		p.frame = Math.min(3, Math.floor((1 - p.life / p.maxLife) * 4));
	}
	state.particles = state.particles.filter((p) => p.life > 0);
	for (const f of state.floats) {
		f.life -= dt;
		f.y -= 40 * dt;
	}
	state.floats = state.floats.filter((f) => f.life > 0);
	if (state.riffPulseLife > 0) {
		state.riffPulseLife -= dt;
		if (state.riffPulseLife <= 0) state.riffPulse = 0;
	}
	if (state.speechBubble) {
		state.speechBubble.life -= dt;
		if (state.speechBubble.life <= 0) state.speechBubble = null;
	}
}
function updateGame(state, dt) {
	const capped = Math.min(dt, .05);
	state.elapsed += capped;
	if (state.phase === "title" || state.phase === "paused" || state.phase === "gameover") return;
	if (state.phase === "victory") {
		if (state.messageTimer > 0 && state.messageTimer < 98) state.messageTimer -= capped;
		updateSmokeBreak(state, capped);
		updateParticles(state, capped);
		return;
	}
	if (state.hitStop > 0) {
		state.hitStop -= capped;
		return;
	}
	if (state.messageTimer > 0) state.messageTimer -= capped;
	if (state.shake > 0) state.shake = Math.max(0, state.shake - capped * 28);
	if (state.phase === "waveClear") {
		updateSmokeBreak(state, capped);
		for (const e of state.enemies) if (e.dead) e.deathTimer -= capped;
		state.enemies = state.enemies.filter((e) => !(e.dead && e.deathTimer <= 0));
		updateParticles(state, capped);
		const target = state.player.x - 364.8;
		state.cameraX += (target - state.cameraX) * Math.min(1, capped * 4);
		state.cameraX = Math.max(0, Math.min(state.stageWidth - 960, state.cameraX));
	} else {
		updatePlayer(state, capped);
		for (const e of state.enemies) updateEnemyAI(state, e, capped);
		state.enemies = state.enemies.filter((e) => !(e.dead && e.deathTimer <= 0));
		updateSpawns(state, capped);
		updateParticles(state, capped);
		const target = state.player.x - 364.8;
		state.cameraX += (target - state.cameraX) * Math.min(1, capped * 6);
		state.cameraX = Math.max(0, Math.min(state.stageWidth - 960, state.cameraX));
	}
	if (state.phase === "playing" && state.spawnQueue <= 0 && state.enemies.length === 0 && state.waveEnemiesLeft <= 0) if (state.wave >= state.maxWaves) {
		state.phase = "victory";
		beginSmokeBreak(state, "STREET CLEARED", 99);
		sfx.victory();
	} else {
		state.phase = "waveClear";
		beginSmokeBreak(state, "WAVE CLEAR — SMOKE BREAK", WAVE_CLEAR_DURATION);
		sfx.waveClear();
	}
	if (state.phase === "waveClear" && state.messageTimer <= 0) {
		state.player.anim = "idle";
		state.player.animTime = 0;
		state.player.animFrame = 0;
		state.phase = "playing";
		beginWave(state, state.wave + 1);
	}
}
function enemySheet(type, anim, assets) {
	return assets[`${type ?? "biz"}${anim.charAt(0).toUpperCase()}${anim.slice(1)}`] ?? assets.bizIdle;
}
function sheetFor(f, assets) {
	if (f.kind === "player") {
		if (f.anim === "attack") {
			if (f.attackKind === "special") return assets.jjSpecial;
			if (f.attackKind === "kick") return assets.jjKick;
			return assets.jjAttack;
		}
		if (f.anim === "hurt" || f.dead) return assets.jjHurt;
		if (f.anim === "jump") return assets.jjJump;
		if (f.anim === "smoke") return assets.jjSmoke;
		if (f.anim === "walk") return assets.jjWalk;
		return assets.jjIdle;
	}
	if (f.anim === "attack") return enemySheet(f.enemyType, "attack", assets);
	if (f.anim === "walk") return enemySheet(f.enemyType, "walk", assets);
	return enemySheet(f.enemyType, "idle", assets);
}
function walkBob(f) {
	if (f.anim !== "walk" || f.kind !== "player") return 0;
	const phase = f.animFrame % 8;
	if (phase === 1 || phase === 5) return 3;
	if (phase === 0 || phase === 4) return 1;
	if (phase === 3 || phase === 7) return -2;
	return 0;
}
function drawFighter(ctx, f, assets, camX) {
	const sheet = sheetFor(f, assets);
	const scaleBoost = f.kind === "player" && f.attackKind === "special" ? 1.12 : 1;
	const drawH = f.bodyH * f.scale * .95 * scaleBoost;
	const drawW = drawH * (sheet.frameW / sheet.frameH);
	const bob = walkBob(f);
	const dx = f.x - camX - drawW / 2;
	const dy = f.y - drawH - f.z + bob;
	const shadowScale = Math.max(.35, 1 - f.z / 220);
	ctx.save();
	ctx.fillStyle = `rgba(0,0,0,${.35 * shadowScale})`;
	ctx.beginPath();
	ctx.ellipse(f.x - camX, f.y - 4, drawW * .28 * shadowScale, 8 * shadowScale, 0, 0, Math.PI * 2);
	ctx.fill();
	ctx.restore();
	if (f.kind === "player" && f.attackKind === "special") {
		const g = ctx.createRadialGradient(f.x - camX, f.y - drawH * .45, 8, f.x - camX, f.y - drawH * .45, drawW * .85);
		g.addColorStop(0, "rgba(255,45,138,0.45)");
		g.addColorStop(.55, "rgba(45,226,230,0.18)");
		g.addColorStop(1, "rgba(255,45,138,0)");
		ctx.fillStyle = g;
		ctx.beginPath();
		ctx.ellipse(f.x - camX, f.y - drawH * .4, drawW * .7, drawH * .55, 0, 0, Math.PI * 2);
		ctx.fill();
	}
	if (f.dead) ctx.globalAlpha = Math.max(0, f.deathTimer / .9);
	if (f.invulnTimer > 0 && Math.floor(f.invulnTimer * 20) % 2 === 0 && f.kind === "player" && f.attackKind !== "special") ctx.globalAlpha = .55;
	if (f.flash > 0) ctx.filter = "brightness(2.2)";
	const flip = f.facing === -1;
	drawFrame(ctx, sheet, f.animFrame, dx, dy, drawW, drawH, flip);
	ctx.filter = "none";
	ctx.globalAlpha = 1;
	if (f.kind === "enemy" && !f.dead && f.hp < f.maxHp) {
		const bw = 40;
		const bx = f.x - camX - bw / 2;
		const by = dy - 10;
		ctx.fillStyle = "rgba(0,0,0,0.55)";
		ctx.fillRect(bx - 1, by - 1, 42, 6);
		ctx.fillStyle = "#ff2d8a";
		ctx.fillRect(bx, by, bw * (f.hp / f.maxHp), 4);
	}
}
function drawParallax(ctx, assets, camX) {
	const sky = assets.sky.img;
	ctx.drawImage(sky, 0, 0, 960, 540);
	const far = assets.farBg.img;
	const farOff = camX * .12 % 960;
	for (let i = -1; i <= 1; i++) ctx.drawImage(far, -farOff + i * 960, 40, 960, 388.8);
	const mid = assets.midBg.img;
	const midOff = camX * .4 % 960;
	const srcH = mid.naturalHeight * .62;
	const dstH = 320;
	for (let i = -1; i <= 1; i++) ctx.drawImage(mid, 0, 0, mid.naturalWidth, srcH, -midOff + i * 960, 0, 960, dstH);
	const beltTop = 302;
	const g = ctx.createLinearGradient(0, beltTop, 0, 540);
	g.addColorStop(0, "rgba(22,16,36,0.35)");
	g.addColorStop(.2, "rgba(14,10,24,0.92)");
	g.addColorStop(1, "rgba(8,4,14,1)");
	ctx.fillStyle = g;
	ctx.fillRect(0, beltTop, 960, 238);
	ctx.strokeStyle = "rgba(255,45,138,0.22)";
	ctx.lineWidth = 2;
	ctx.setLineDash([16, 20]);
	const lineY = 423;
	const lineOff = camX * .85 % 36;
	ctx.beginPath();
	ctx.moveTo(-lineOff, lineY);
	ctx.lineTo(1e3, lineY);
	ctx.stroke();
	ctx.setLineDash([]);
	ctx.fillStyle = "rgba(45,226,230,0.12)";
	ctx.fillRect(0, 304, 960, 3);
	ctx.fillStyle = "rgba(255,45,138,0.1)";
	ctx.fillRect(0, 508, 960, 2);
}
function drawHud(ctx, state) {
	const p = state.player;
	ctx.fillStyle = "rgba(10,6,18,0.72)";
	roundRect$1(ctx, 16, 14, 260, 58, 10);
	ctx.fill();
	ctx.strokeStyle = "rgba(255,45,138,0.45)";
	ctx.lineWidth = 2;
	roundRect$1(ctx, 16, 14, 260, 58, 10);
	ctx.stroke();
	ctx.fillStyle = "#f4eef8";
	ctx.font = "bold 14px Segoe UI, sans-serif";
	ctx.fillText("JJ", 28, 34);
	ctx.fillStyle = "rgba(0,0,0,0.45)";
	roundRect$1(ctx, 28, 42, 200, 14, 6);
	ctx.fill();
	const hpPct = Math.max(0, p.hp / p.maxHp);
	const hpGrad = ctx.createLinearGradient(28, 0, 228, 0);
	hpGrad.addColorStop(0, "#ff2d8a");
	hpGrad.addColorStop(1, "#ff6bb5");
	ctx.fillStyle = hpGrad;
	roundRect$1(ctx, 28, 42, 200 * hpPct, 14, 6);
	ctx.fill();
	ctx.fillStyle = "rgba(10,6,18,0.72)";
	roundRect$1(ctx, 16, 78, 200, 18, 8);
	ctx.fill();
	ctx.fillStyle = "rgba(0,0,0,0.4)";
	roundRect$1(ctx, 22, 82, 188, 10, 5);
	ctx.fill();
	const sp = state.specialMeter / 100;
	ctx.fillStyle = sp >= .4 ? "#2de2e6" : "rgba(45,226,230,0.45)";
	roundRect$1(ctx, 22, 82, 188 * sp, 10, 5);
	ctx.fill();
	ctx.fillStyle = "#a89bb8";
	ctx.font = "10px Segoe UI, sans-serif";
	ctx.fillText("RIFF SPECIAL (L)", 28, 110);
	ctx.textAlign = "right";
	ctx.fillStyle = "#f4eef8";
	ctx.font = "bold 18px Segoe UI, sans-serif";
	ctx.fillText(`${state.score}`, 940, 34);
	ctx.fillStyle = "#a89bb8";
	ctx.font = "12px Segoe UI, sans-serif";
	ctx.fillText(`WAVE ${state.wave}/${state.maxWaves}`, 940, 52);
	ctx.textAlign = "left";
	if (p.combo > 1) {
		ctx.fillStyle = "#ffd56a";
		ctx.font = "bold 22px Segoe UI, sans-serif";
		ctx.fillText(`${p.combo} HIT COMBO`, 16, 140);
	}
	if (state.messageTimer > 0 && state.message) {
		ctx.save();
		ctx.globalAlpha = Math.min(1, state.messageTimer);
		ctx.textAlign = "center";
		ctx.fillStyle = "#ff2d8a";
		ctx.font = "bold 36px Segoe UI, sans-serif";
		ctx.shadowColor = "rgba(0,0,0,0.8)";
		ctx.shadowBlur = 12;
		ctx.fillText(state.message, 960 / 2, 540 * .28);
		ctx.restore();
	}
}
function roundRect$1(ctx, x, y, w, h, r) {
	const rr = Math.min(r, w / 2, h / 2);
	ctx.beginPath();
	ctx.moveTo(x + rr, y);
	ctx.arcTo(x + w, y, x + w, y + h, rr);
	ctx.arcTo(x + w, y + h, x, y + h, rr);
	ctx.arcTo(x, y + h, x, y, rr);
	ctx.arcTo(x, y, x + w, y, rr);
	ctx.closePath();
}
function wrapSloganLines(text, maxChars = 16) {
	const words = text.split(" ");
	const lines = [];
	let cur = "";
	for (const w of words) {
		const next = cur ? `${cur} ${w}` : w;
		if (next.length > maxChars && cur) {
			lines.push(cur);
			cur = w;
		} else cur = next;
	}
	if (cur) lines.push(cur);
	return lines;
}
function drawSpeechBubble(ctx, state, camX) {
	const b = state.speechBubble;
	if (!b) return;
	const p = state.player;
	const t = 1 - b.life / b.maxLife;
	let scale = 1;
	let alpha = 1;
	if (t < .12) scale = .4 + t / .12 * .7;
	else if (t < .2) scale = 1.1 - (t - .12) / .08 * .1;
	if (b.life < .2) alpha = Math.max(0, b.life / .2);
	const lines = wrapSloganLines(b.text, 18);
	ctx.save();
	ctx.globalAlpha = alpha;
	ctx.font = "bold 13px Segoe UI, sans-serif";
	let maxW = 0;
	for (const line of lines) maxW = Math.max(maxW, ctx.measureText(line).width);
	const padY = 8;
	const lineH = 16;
	const bw = maxW + 24;
	const bh = lines.length * lineH + 16;
	const headY = p.y - p.bodyH * p.scale * .95 - p.z - 18;
	const cx = p.x - camX;
	const bx = cx - bw / 2;
	const by = headY - bh - 18;
	ctx.translate(cx, by + bh);
	ctx.scale(scale, scale);
	ctx.translate(-cx, -(by + bh));
	ctx.fillStyle = "#fff8fc";
	ctx.strokeStyle = "#1a0a14";
	ctx.lineWidth = 2.5;
	roundRect$1(ctx, bx, by, bw, bh, 10);
	ctx.fill();
	ctx.stroke();
	const tailX = cx + (p.facing === 1 ? -6 : 6);
	const tailTop = by + bh - 1;
	ctx.beginPath();
	ctx.moveTo(tailX - 8, tailTop);
	ctx.lineTo(tailX + 8, tailTop);
	ctx.lineTo(tailX + (p.facing === 1 ? 4 : -4), tailTop + 14);
	ctx.closePath();
	ctx.fillStyle = "#fff8fc";
	ctx.fill();
	ctx.strokeStyle = "#1a0a14";
	ctx.beginPath();
	ctx.moveTo(tailX - 8, tailTop);
	ctx.lineTo(tailX + (p.facing === 1 ? 4 : -4), tailTop + 14);
	ctx.lineTo(tailX + 8, tailTop);
	ctx.stroke();
	ctx.fillStyle = "#1a0a14";
	ctx.textAlign = "center";
	ctx.textBaseline = "middle";
	lines.forEach((line, i) => {
		ctx.fillText(line, cx, by + padY + lineH * i + lineH / 2);
	});
	ctx.textAlign = "left";
	ctx.textBaseline = "alphabetic";
	ctx.restore();
}
function renderGame(ctx, state, assets) {
	const shakeX = state.shake > 0 ? (Math.random() - .5) * state.shake * 2 : 0;
	const shakeY = state.shake > 0 ? (Math.random() - .5) * state.shake * 2 : 0;
	ctx.save();
	ctx.translate(shakeX, shakeY);
	drawParallax(ctx, assets, state.cameraX);
	const fighters = [state.player, ...state.enemies].filter(Boolean);
	fighters.sort((a, b) => a.y - b.y || a.z - b.z);
	for (const f of fighters) drawFighter(ctx, f, assets, state.cameraX);
	drawSpeechBubble(ctx, state, state.cameraX);
	for (const p of state.particles) {
		const alpha = Math.max(0, p.life / p.maxLife);
		if (p.kind === "impact") {
			const size = 48;
			drawFrame(ctx, assets.fxImpact, p.frame, p.x - state.cameraX - size / 2, p.y - size / 2, size, size);
		} else if (p.kind === "wave") {
			const r = p.radius ?? 40;
			ctx.save();
			ctx.globalAlpha = alpha * .85;
			ctx.strokeStyle = p.color ?? "#ff2d8a";
			ctx.lineWidth = 4;
			ctx.beginPath();
			ctx.ellipse(p.x - state.cameraX, p.y, r, r * .38, 0, 0, Math.PI * 2);
			ctx.stroke();
			ctx.lineWidth = 2;
			ctx.globalAlpha = alpha * .45;
			ctx.beginPath();
			ctx.ellipse(p.x - state.cameraX, p.y, r * .82, r * .3, 0, 0, Math.PI * 2);
			ctx.stroke();
			ctx.restore();
		} else if (p.kind === "note") {
			ctx.save();
			ctx.globalAlpha = alpha;
			ctx.fillStyle = p.color ?? "#ff2d8a";
			ctx.font = "bold 18px Segoe UI, sans-serif";
			ctx.fillText(p.frame % 2 === 0 ? "♪" : "♫", p.x - state.cameraX, p.y);
			ctx.restore();
		} else if (p.kind === "smoke") {
			const r = (p.radius ?? 6) * (.6 + (1 - alpha) * 1.4);
			ctx.save();
			ctx.globalAlpha = alpha * .5;
			ctx.fillStyle = "rgba(200,200,210,0.9)";
			ctx.beginPath();
			ctx.ellipse(p.x - state.cameraX, p.y, r, r * .75, 0, 0, Math.PI * 2);
			ctx.fill();
			ctx.restore();
		} else {
			ctx.fillStyle = `rgba(255,213,106,${alpha})`;
			ctx.fillRect(p.x - state.cameraX - 2, p.y - 2, 4, 4);
		}
	}
	if (state.riffPulseLife > 0 && state.riffPulse > 0 && state.player.attackKind === "special") {
		const pl = state.player;
		const a = Math.min(1, state.riffPulseLife * 4) * .35;
		ctx.save();
		ctx.globalAlpha = a;
		ctx.strokeStyle = "#ff2d8a";
		ctx.lineWidth = 3;
		ctx.setLineDash([8, 10]);
		ctx.beginPath();
		ctx.ellipse(pl.x - state.cameraX, pl.y - 8, state.riffPulse, state.riffPulse * .42, 0, 0, Math.PI * 2);
		ctx.stroke();
		ctx.setLineDash([]);
		ctx.restore();
	}
	for (const f of state.floats) {
		ctx.globalAlpha = Math.max(0, f.life / .7);
		ctx.fillStyle = f.color;
		ctx.font = "bold 16px Segoe UI, sans-serif";
		ctx.textAlign = "center";
		ctx.fillText(f.text, f.x - state.cameraX, f.y);
		ctx.globalAlpha = 1;
	}
	ctx.restore();
	if (state.phase !== "title") drawHud(ctx, state);
}
function setKey(state, code, down) {
	if (down) {
		state.keys.add(code);
		if (code === "KeyJ" || code === "KeyZ") queueAction(state, "punch");
		else if (code === "KeyK" || code === "KeyX") queueAction(state, "kick");
		else if (code === "KeyL" || code === "KeyC") queueAction(state, "special");
		else if (code === "Space" || code === "ShiftLeft" || code === "ShiftRight") queueJump(state);
	} else state.keys.delete(code);
}
function GameCanvas() {
	const canvasRef = (0, import_react.useRef)(null);
	const wrapRef = (0, import_react.useRef)(null);
	const stateRef = (0, import_react.useRef)(createGameState());
	const assetsRef = (0, import_react.useRef)(null);
	const rafRef = (0, import_react.useRef)(0);
	const lastRef = (0, import_react.useRef)(0);
	const [ready, setReady] = (0, import_react.useState)(false);
	const [error, setError] = (0, import_react.useState)(null);
	const [phase, setPhase] = (0, import_react.useState)("title");
	const [hud, setHud] = (0, import_react.useState)({
		score: 0,
		wave: 0,
		combo: 0,
		special: 0,
		hp: 100
	});
	const [muted, setMutedUi] = (0, import_react.useState)(false);
	const syncHud = (0, import_react.useCallback)(() => {
		const s = stateRef.current;
		setPhase(s.phase);
		setHud({
			score: s.score,
			wave: s.wave,
			combo: s.player.combo,
			special: Math.floor(s.specialMeter),
			hp: Math.max(0, Math.floor(s.player.hp))
		});
	}, []);
	(0, import_react.useEffect)(() => {
		let cancelled = false;
		loadAssets().then((a) => {
			if (cancelled) return;
			assetsRef.current = a;
			setReady(true);
		}).catch((e) => {
			if (!cancelled) setError(e.message || "Failed to load assets");
		});
		return () => {
			cancelled = true;
		};
	}, []);
	(0, import_react.useEffect)(() => {
		const unlock = () => {
			unlockAudio();
		};
		window.addEventListener("pointerdown", unlock, { once: true });
		window.addEventListener("keydown", unlock, { once: true });
		return () => {
			window.removeEventListener("pointerdown", unlock);
			window.removeEventListener("keydown", unlock);
		};
	}, []);
	(0, import_react.useEffect)(() => {
		if (!ready) return;
		const canvas = canvasRef.current;
		if (!canvas) return;
		const ctx = canvas.getContext("2d");
		if (!ctx) return;
		const onKeyDown = (e) => {
			if ([
				"ArrowUp",
				"ArrowDown",
				"ArrowLeft",
				"ArrowRight",
				"Space"
			].includes(e.code)) e.preventDefault();
			if (e.repeat) return;
			unlockAudio();
			const s = stateRef.current;
			if (e.code === "KeyM") {
				setMutedUi(toggleMute());
				return;
			}
			if (e.code === "Enter") {
				if (s.phase === "title" || s.phase === "gameover" || s.phase === "victory") {
					startGame(s);
					syncHud();
					return;
				}
			}
			if (e.code === "Space" && (s.phase === "title" || s.phase === "gameover" || s.phase === "victory")) {
				startGame(s);
				syncHud();
				return;
			}
			if (e.code === "Escape" || e.code === "KeyP") {
				if (s.phase === "playing") {
					s.phase = "paused";
					sfx.pause();
				} else if (s.phase === "paused") {
					s.phase = "playing";
					sfx.resume();
				}
				syncHud();
				return;
			}
			setKey(s, e.code, true);
		};
		const onKeyUp = (e) => setKey(stateRef.current, e.code, false);
		const onBlur = () => {
			stateRef.current.keys.clear();
		};
		window.addEventListener("keydown", onKeyDown);
		window.addEventListener("keyup", onKeyUp);
		window.addEventListener("blur", onBlur);
		lastRef.current = performance.now();
		const loop = (now) => {
			const dt = Math.min(.05, (now - lastRef.current) / 1e3);
			lastRef.current = now;
			const s = stateRef.current;
			const assets = assetsRef.current;
			if (assets) {
				updateGame(s, dt);
				ctx.imageSmoothingEnabled = false;
				ctx.clearRect(0, 0, 960, 540);
				renderGame(ctx, s, assets);
				if (s.phase === "title") drawTitle(ctx, assets, now);
				else if (s.phase === "paused") drawCenterBanner(ctx, "PAUSED", "Press Esc to resume");
				else if (s.phase === "gameover") drawCenterBanner(ctx, "KNOCKED OUT", `Score ${s.score} — Enter to retry`);
				else if (s.phase === "victory") drawCenterBanner(ctx, "STREET CLEARED", `Score ${s.score} — Enter to play again`);
			}
			if (now % 200 < 20) syncHud();
			rafRef.current = requestAnimationFrame(loop);
		};
		rafRef.current = requestAnimationFrame(loop);
		window.__controlsTest = {
			getX: () => stateRef.current.player.x,
			getFacing: () => stateRef.current.player.facing,
			getPhase: () => stateRef.current.phase,
			getAnim: () => stateRef.current.player.anim,
			getAttackKind: () => stateRef.current.player.attackKind,
			getAnimFrame: () => stateRef.current.player.animFrame,
			setKeys: (codes) => {
				stateRef.current.keys = new Set(codes);
			},
			queue: (kind) => queueAction(stateRef.current, kind),
			jump: () => queueJump(stateRef.current),
			getZ: () => stateRef.current.player.z,
			getEnemyTypes: () => stateRef.current.enemies.map((e) => e.enemyType),
			setMeter: (n) => {
				stateRef.current.specialMeter = n;
			},
			getMeter: () => stateRef.current.specialMeter,
			getEnemyHp: () => stateRef.current.enemies.map((e) => ({
				id: e.id,
				hp: e.hp,
				type: e.enemyType,
				x: e.x
			})),
			getRiff: () => ({
				pulse: stateRef.current.riffPulse,
				hits: stateRef.current.player.specialHitIds.length,
				kind: stateRef.current.player.attackKind
			}),
			getBubble: () => stateRef.current.speechBubble?.text ?? null,
			forceWaveClear: () => {
				const s = stateRef.current;
				s.enemies = [];
				s.spawnQueue = 0;
				s.waveEnemiesLeft = 0;
				s.wave = Math.min(s.wave || 1, s.maxWaves - 1);
				s.phase = "playing";
			},
			warpEnemiesNear: () => {
				const p = stateRef.current.player;
				for (const e of stateRef.current.enemies) {
					e.x = p.x + 50 + Math.random() * 70;
					e.y = p.y + (Math.random() - .5) * 50;
					e.invulnTimer = 0;
				}
			},
			start: () => {
				startGame(stateRef.current);
			},
			playSfx: (name) => {
				const fn = sfx[name];
				if (typeof fn === "function") fn();
			}
		};
		return () => {
			cancelAnimationFrame(rafRef.current);
			window.removeEventListener("keydown", onKeyDown);
			window.removeEventListener("keyup", onKeyUp);
			window.removeEventListener("blur", onBlur);
		};
	}, [ready, syncHud]);
	const setTouch = (key, v) => {
		stateRef.current.touch[key] = v;
	};
	const fireAction = (kind) => {
		unlockAudio();
		queueAction(stateRef.current, kind);
	};
	const onStart = () => {
		unlockAudio();
		startGame(stateRef.current);
		syncHud();
	};
	const onMute = () => {
		unlockAudio();
		setMutedUi(toggleMute());
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref: wrapRef,
		className: "relative flex h-full w-full flex-col items-center justify-center bg-bg",
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "relative w-full max-w-[1100px] px-2 sm:px-4",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "relative mx-auto aspect-video w-full overflow-hidden rounded-xl border border-border bg-surface shadow-[0_0_40px_rgba(255,45,138,0.12)]",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("canvas", {
							ref: canvasRef,
							width: 960,
							height: 540,
							className: "pixelated h-full w-full touch-none",
							tabIndex: 0,
							"aria-label": "JJ Beat-em-up game canvas"
						}),
						!ready && !error && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "absolute inset-0 flex items-center justify-center bg-bg/90 text-muted",
							children: "Loading JJ's night shift…"
						}),
						error && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "absolute inset-0 flex items-center justify-center bg-bg/90 text-danger",
							children: error
						}),
						ready && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
							type: "button",
							onClick: onMute,
							className: "absolute right-3 top-3 rounded-full border border-border bg-surface/90 px-3 py-1.5 text-xs font-bold text-fg shadow-md hover:brightness-110",
							"aria-label": muted ? "Unmute" : "Mute",
							children: muted || isMuted() ? "SOUND OFF" : "SOUND ON"
						}),
						ready && phase === "title" && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "pointer-events-none absolute inset-x-0 bottom-6 flex justify-center",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								type: "button",
								onClick: onStart,
								className: "pointer-events-auto rounded-full bg-primary px-8 py-3 text-sm font-bold tracking-wide text-primary-fg shadow-lg transition hover:brightness-110 active:scale-95",
								children: "START BRAWL"
							})
						}),
						ready && (phase === "gameover" || phase === "victory") && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "pointer-events-none absolute inset-x-0 bottom-8 flex justify-center",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								type: "button",
								onClick: onStart,
								className: "pointer-events-auto rounded-full bg-primary px-8 py-3 text-sm font-bold tracking-wide text-primary-fg shadow-lg",
								children: phase === "victory" ? "PLAY AGAIN" : "RETRY"
							})
						})
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-3 hidden justify-between gap-3 text-xs text-muted sm:flex",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Move: WASD / Arrows" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Punch: J / Z" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Kick: K / X" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Jump: Space / Shift" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Riff: L (full meter)" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Mute: M" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Pause: Esc" })
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-3 grid grid-cols-[1fr_auto] gap-3 sm:hidden",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "grid grid-cols-3 grid-rows-3 gap-1.5 place-items-center",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "▲",
								onDown: () => setTouch("up", true),
								onUp: () => setTouch("up", false)
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "◀",
								onDown: () => setTouch("left", true),
								onUp: () => setTouch("left", false)
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "h-12 w-12" }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "▶",
								onDown: () => setTouch("right", true),
								onUp: () => setTouch("right", false)
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "▼",
								onDown: () => setTouch("down", true),
								onUp: () => setTouch("down", false)
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "flex flex-col justify-end gap-2",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "flex gap-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "JUMP",
								onDown: () => {
									unlockAudio();
									queueJump(stateRef.current);
								}
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "RIFF",
								accent: true,
								onDown: () => fireAction("special")
							})]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "flex gap-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "KICK",
								onDown: () => fireAction("kick")
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(TouchBtn, {
								label: "PUNCH",
								primary: true,
								onDown: () => fireAction("punch")
							})]
						})]
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-2 flex justify-between text-[11px] text-muted sm:hidden",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", { children: ["HP ", hud.hp] }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", { children: ["Wave ", hud.wave] }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", { children: ["Score ", hud.score] }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", { children: ["SP ", hud.special] })
					]
				})
			]
		})
	});
}
function TouchBtn({ label, onDown, onUp, primary, accent, wide }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
		type: "button",
		className: [
			"select-none rounded-2xl border border-border text-sm font-bold text-fg active:scale-95",
			wide ? "h-12 min-w-[7.5rem] px-4" : "h-12 min-w-12 px-2",
			primary ? "bg-primary text-primary-fg" : accent ? "bg-accent text-accent-fg" : "bg-surface-2"
		].join(" "),
		onPointerDown: (e) => {
			e.preventDefault();
			e.currentTarget.setPointerCapture?.(e.pointerId);
			onDown();
		},
		onPointerUp: (e) => {
			e.preventDefault();
			onUp?.();
		},
		onPointerCancel: () => onUp?.(),
		children: label
	});
}
function drawTitle(ctx, assets, now) {
	ctx.fillStyle = "rgba(8,4,16,0.62)";
	ctx.fillRect(0, 0, 960, 540);
	ctx.fillStyle = "rgba(10,6,18,0.78)";
	roundRect(ctx, 36, 72, 520, 200, 16);
	ctx.fill();
	ctx.strokeStyle = "rgba(255,45,138,0.4)";
	ctx.lineWidth = 2;
	roundRect(ctx, 36, 72, 520, 200, 16);
	ctx.stroke();
	ctx.fillStyle = "#ff2d8a";
	ctx.font = "bold 48px Segoe UI, sans-serif";
	ctx.shadowColor = "rgba(255,45,138,0.55)";
	ctx.shadowBlur = 16;
	ctx.fillText("JJ: NIGHT BRAWL", 56, 130);
	ctx.shadowBlur = 0;
	ctx.fillStyle = "#f4eef8";
	ctx.font = "16px Segoe UI, sans-serif";
	ctx.fillText("32-bit side-scrolling beat-em-up", 60, 162);
	ctx.fillStyle = "#a89bb8";
	ctx.font = "13px Segoe UI, sans-serif";
	ctx.fillText("Clear five waves — suits, MAGA bros & goths. Chain combos.", 60, 190);
	ctx.fillText("Jump: Space. Full meter + L = guitar riff blast!", 60, 210);
	ctx.globalAlpha = .65 + Math.sin(now / 280) * .35;
	ctx.fillStyle = "#2de2e6";
	ctx.font = "bold 15px Segoe UI, sans-serif";
	ctx.fillText("Press ENTER or tap START BRAWL", 60, 246);
	ctx.globalAlpha = 1;
	const idle = assets.jjIdle;
	const drawH = 200;
	const drawW = drawH * (idle.frameW / idle.frameH);
	const frame = Math.floor(now / 200) % idle.frameCount;
	ctx.imageSmoothingEnabled = false;
	ctx.fillStyle = "rgba(255,45,138,0.12)";
	ctx.beginPath();
	ctx.ellipse(800, 470, 70, 14, 0, 0, Math.PI * 2);
	ctx.fill();
	drawFrameLocal(ctx, idle, frame, 800 - drawW / 2, 270, drawW, drawH);
}
function drawFrameLocal(ctx, sheet, frame, dx, dy, dw, dh) {
	const total = sheet.frameCount;
	const f = (frame % total + total) % total;
	const col = f % sheet.cols;
	const row = Math.floor(f / sheet.cols);
	ctx.drawImage(sheet.img, col * sheet.frameW, row * sheet.frameH, sheet.frameW, sheet.frameH, dx, dy, dw, dh);
}
function roundRect(ctx, x, y, w, h, r) {
	const rr = Math.min(r, w / 2, h / 2);
	ctx.beginPath();
	ctx.moveTo(x + rr, y);
	ctx.arcTo(x + w, y, x + w, y + h, rr);
	ctx.arcTo(x + w, y + h, x, y + h, rr);
	ctx.arcTo(x, y + h, x, y, rr);
	ctx.arcTo(x, y, x + w, y, rr);
	ctx.closePath();
}
function drawCenterBanner(ctx, title, sub) {
	ctx.fillStyle = "rgba(8,4,16,0.62)";
	ctx.fillRect(0, 0, 960, 540);
	ctx.textAlign = "center";
	ctx.fillStyle = "#ff2d8a";
	ctx.font = "bold 42px Segoe UI, sans-serif";
	ctx.fillText(title, 960 / 2, 540 / 2 - 10);
	ctx.fillStyle = "#f4eef8";
	ctx.font = "16px Segoe UI, sans-serif";
	ctx.fillText(sub, 960 / 2, 298);
	ctx.textAlign = "left";
}
function GamePage() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
		className: "flex h-full min-h-0 flex-col bg-bg",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
			className: "flex shrink-0 items-center justify-between border-b border-border px-4 py-3 sm:px-6",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex items-center gap-3",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "h-2.5 w-2.5 rounded-full bg-primary shadow-[0_0_12px_#ff2d8a]" }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
					className: "text-sm font-bold tracking-wide text-fg sm:text-base",
					children: "JJ: Night Brawl"
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-[11px] text-muted sm:text-xs",
					children: "Side-scrolling beat-em-up · 32-bit style"
				})] })]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "hidden text-xs text-muted md:block",
				children: "Punch through five waves of street thugs"
			})]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			className: "min-h-0 flex-1",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(GameCanvas, {})
		})]
	});
}
var SplitComponent = GamePage;
//#endregion
export { SplitComponent as component };
