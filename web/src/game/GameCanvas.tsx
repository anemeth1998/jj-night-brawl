import { useEffect, useRef, useState, useCallback } from "react";
import {
  VIEW_W,
  VIEW_H,
  createGameState,
  startGame,
  snapshotSlot,
  updateGame,
  renderGame,
  setKey,
  queueAction,
  queueJump,
  type StartOpts,
} from "./engine";
import type { AttackKind, GameState } from "./types";
import { loadAssets, type AssetMap } from "./assets";
import { sfx, unlockAudio, toggleMute, isMuted, setMuted, stopTrack, playMenuTheme, fadeOutMenuTheme, fadeInMenuTheme } from "./audio";
import { MainMenu, type MenuScreen } from "./MainMenu";
import {
  lastPlayedSlot,
  loadProfile,
  saveProfile,
  unlockAchievement,
  SHOP_ITEMS,
  type CharacterId,
  type PlayMode,
  type Profile,
} from "./save";

type Overlay = "title" | "playing" | "paused" | "waveClear" | "victory" | "gameover";

function applyRunRewards(p: Profile, s: GameState) {
  p.records.highScore = Math.max(p.records.highScore, s.score);
  p.records.enemiesDefeated += s.sessionKills;
  p.records.wavesCleared += s.sessionWavesCleared;
  p.records.playtimeSec += Math.floor(s.elapsed);
  if (s.mode === "endless") {
    p.records.bestEndlessWave = Math.max(p.records.bestEndlessWave, s.wave);
  }
  p.shop.cred += Math.floor(s.sessionKills * 12 + s.sessionWavesCleared * 25);
  if (s.sessionKills > 0) {
    p.unlocks.gallery = Array.from(new Set([...p.unlocks.gallery, "biz", "maga", "gothm", "gothf", "fx"]));
    unlockAchievement(p, "first_blood");
  }
  if (s.wave >= 3) unlockAchievement(p, "wave_three");
  if (s.hasGun) unlockAchievement(p, "packing_heat");
  if (s.score >= 10000) unlockAchievement(p, "ten_k");
  if (s.mode === "endless" && s.wave >= 5) unlockAchievement(p, "endless_five");
  if (s.phase === "victory" && s.mode === "story") {
    p.records.storyClears += 1;
    p.unlocks.endings = Array.from(new Set([...p.unlocks.endings, "street"]));
    p.unlocks.stages = [1, 2, 3, 4, 5];
    unlockAchievement(p, "street_cleared");
  }
  if (s.wave >= 2 && !p.unlocks.stages.includes(2)) p.unlocks.stages.push(2);
  if (s.wave >= 3 && !p.unlocks.stages.includes(3)) p.unlocks.stages.push(3);
  if (s.wave >= 4 && !p.unlocks.stages.includes(4)) p.unlocks.stages.push(4);
  if (s.wave >= 5 && !p.unlocks.stages.includes(5)) p.unlocks.stages.push(5);
  p.unlocks.gallery = Array.from(
    new Set([...p.unlocks.gallery, "jjIdle", "jjWalk", "jjAttack", "jjKick", "jjJump", "jjSpecial", "jjSmoke"]),
  );
  s.sessionKills = 0;
  s.sessionWavesCleared = 0;
}

function persistSlot(p: Profile, s: GameState) {
  const i = Math.max(0, Math.min(2, s.slotIndex));
  p.slots[i] = snapshotSlot(s);
  p.lastSlot = i;
}

export function GameCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const stateRef = useRef<GameState>(createGameState());
  const assetsRef = useRef<AssetMap | null>(null);
  const menuLoopRef = useRef<HTMLImageElement[]>([]);
  const menuVideoRef = useRef<HTMLVideoElement>(null);
  const titleCardRef = useRef(true);
  const rafRef = useRef(0);
  const lastRef = useRef(0);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [phase, setPhase] = useState<Overlay>("title");
  const [hud, setHud] = useState({ score: 0, wave: 0, combo: 0, special: 0, hp: 100 });
  const [muted, setMutedUi] = useState(() => loadProfile().settings.muted);
  const [menuScreen, setMenuScreen] = useState<MenuScreen>("menu");
  const [menuIndex, setMenuIndex] = useState(0);
  const [profile, setProfile] = useState<Profile>(() => loadProfile());
  const profileRef = useRef(profile);
  profileRef.current = profile;
  const [pendingChar, setPendingChar] = useState<CharacterId>("jj");
  const [pendingMode, setPendingMode] = useState<PlayMode>("story");
  const [titleCard, setTitleCard] = useState(true);
  const lastPhase = useRef<Overlay>("title");

  useEffect(() => {
    if (phase !== "title") return;
    const kick = () => playMenuTheme();
    window.addEventListener("pointerdown", kick);
    window.addEventListener("keydown", kick);
    return () => {
      window.removeEventListener("pointerdown", kick);
      window.removeEventListener("keydown", kick);
    };
  }, [phase]);

  const syncHud = useCallback(() => {
    const s = stateRef.current;
    const prev = lastPhase.current;
    setPhase(s.phase);
    setHud({
      score: s.score,
      wave: s.wave,
      combo: s.player.combo,
      special: Math.floor(s.specialMeter),
      hp: Math.max(0, Math.floor(s.player.hp)),
    });
    if (prev !== s.phase && (s.phase === "waveClear" || s.phase === "victory" || s.phase === "gameover")) {
      const p = profileRef.current;
      persistSlot(p, s);
      applyRunRewards(p, s);
      saveProfile(p);
      setProfile({
        ...p,
        shop: { ...p.shop },
        records: { ...p.records },
        unlocks: { ...p.unlocks, stages: [...p.unlocks.stages] },
      });
    }
    lastPhase.current = s.phase;
  }, []);

  useEffect(() => {
    let cancelled = false;
    loadAssets()
      .then((a) => {
        if (cancelled) return;
        assetsRef.current = a;
        setReady(true);
      })
      .catch((e: Error) => {
        if (!cancelled) setError(e.message || "Failed to load assets");
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    setMuted(profile.settings.muted);
    setMutedUi(profile.settings.muted);
  }, []);

  useEffect(() => {
    const flush = () => {
      const p = profileRef.current;
      const s = stateRef.current;
      if (s.phase === "playing" || s.phase === "waveClear" || s.phase === "paused") {
        persistSlot(p, s);
        applyRunRewards(p, s);
      }
      saveProfile(p);
    };
    const onHide = () => {
      if (document.visibilityState === "hidden") flush();
    };
    document.addEventListener("visibilitychange", onHide);
    return () => document.removeEventListener("visibilitychange", onHide);
  }, []);

  useEffect(() => {
    const unlock = () => {
      void unlockAudio();
    };
    window.addEventListener("pointerdown", unlock, { once: true });
    window.addEventListener("keydown", unlock, { once: true });
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
    };
  }, []);

  useEffect(() => {
    if (!ready) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const onKeyDown = (e: KeyboardEvent) => {
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(e.code)) {
        e.preventDefault();
      }
      if (e.repeat) return;
      void unlockAudio();
      const s = stateRef.current;
      if (s.phase === "title") {
        if (titleCardRef.current) {
          if (e.code === "Enter" || e.code === "Space") {
            e.preventDefault();
            playMenuTheme();
            titleCardRef.current = false;
            setTitleCard(false);
            sfx.uiConfirm();
          }
        }
        if (e.code === "KeyM") {
          const next = toggleMute();
          setMutedUi(next);
          profileRef.current.settings.muted = next;
          saveProfile(profileRef.current);
        }
        return;
      }
      if (e.code === "KeyM") {
        const next = toggleMute();
        setMutedUi(next);
        profileRef.current.settings.muted = next;
        saveProfile(profileRef.current);
        return;
      }
      if (e.code === "Enter") {
        if (s.phase === "gameover" || s.phase === "victory") {
          startGame(s, { profile: profileRef.current, mode: s.mode, characterId: s.characterId });
          syncHud();
          return;
        }
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
    const onKeyUp = (e: KeyboardEvent) => setKey(stateRef.current, e.code, false);
    const onBlur = () => {
      stateRef.current.keys.clear();
    };

    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    window.addEventListener("blur", onBlur);

    lastRef.current = performance.now();
    const loop = (now: number) => {
      const dt = Math.min(0.05, (now - lastRef.current) / 1000);
      lastRef.current = now;
      const s = stateRef.current;
      const assets = assetsRef.current;
      try {
        if (assets) {
          updateGame(s, dt);
          ctx.imageSmoothingEnabled = false;
          ctx.clearRect(0, 0, VIEW_W, VIEW_H);
          if (s.phase === "title") {
            if (titleCardRef.current) drawTitleBackdrop(ctx, assets, now);
            else {
              ctx.clearRect(0, 0, VIEW_W, VIEW_H);
            }
          } else {
            renderGame(ctx, s, assets);
          }

          if (s.phase === "paused") {
            drawCenterBanner(ctx, "PAUSED", "Esc to resume · Save & Menu below");
          } else if (s.phase === "gameover") {
            drawCenterBanner(ctx, "KNOCKED OUT", `Score ${s.score} — Enter to retry`);
          } else if (s.phase === "victory") {
            drawCenterBanner(ctx, "STREET CLEARED", `Score ${s.score} — Enter to play again`);
          }
        }
        if (now % 200 < 20) syncHud();
      } catch (err) {
        console.error("[JJ] frame error", err);
        if (s.player.attackKind === "special") {
          s.player.attackTimer = 0;
          s.player.attackKind = null;
          s.player.attackActive = false;
          s.player.anim = "idle";
          s.hitStop = 0;
        }
      }
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);

    (window as unknown as { __controlsTest?: object }).__controlsTest = {
      getX: () => stateRef.current.player.x,
      getFacing: () => stateRef.current.player.facing,
      getPhase: () => stateRef.current.phase,
      getAnim: () => stateRef.current.player.anim,
      getAttackKind: () => stateRef.current.player.attackKind,
      getAnimFrame: () => stateRef.current.player.animFrame,
      setKeys: (codes: string[]) => {
        stateRef.current.keys = new Set(codes);
      },
      queue: (kind: AttackKind) => queueAction(stateRef.current, kind),
      jump: () => queueJump(stateRef.current),
      getZ: () => stateRef.current.player.z,
      getEnemyTypes: () => stateRef.current.enemies.map((e) => e.enemyType),
      setMeter: (n: number) => {
        stateRef.current.specialMeter = n;
      },
      getMeter: () => stateRef.current.specialMeter,
      getEnemyHp: () =>
        stateRef.current.enemies.map((e) => ({ id: e.id, hp: e.hp, type: e.enemyType, x: e.x })),
      getRiff: () => ({
        pulse: stateRef.current.riffPulse,
        hits: stateRef.current.player.specialHitIds.length,
        kind: stateRef.current.player.attackKind,
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
      grantGun: () => {
        stateRef.current.hasGun = true;
      },
      hasGun: () => stateRef.current.hasGun,
      bulletCount: () => stateRef.current.bullets.length,
      spawnOneNear: () => {
        const s = stateRef.current;
        const p = s.player;
        s.enemies = [
          {
            id: 9001,
            kind: "enemy",
            enemyType: "biz",
            x: p.x + 90,
            y: p.y,
            z: 0,
            zVel: 0,
            vx: 0,
            vy: 0,
            facing: -1,
            hp: 20,
            maxHp: 20,
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
            aiCooldown: 9,
            flash: 0,
            scoreValue: 100,
            scale: 1.5,
            bodyW: 48,
            bodyH: 90,
          },
        ];
        s.waveEnemiesLeft = 1;
        s.spawnQueue = 0;
        s.phase = "playing";
      },
      warpEnemiesNear: () => {
        const p = stateRef.current.player;
        for (const e of stateRef.current.enemies) {
          e.x = p.x + 50 + Math.random() * 70;
          e.y = p.y + (Math.random() - 0.5) * 50;
          e.invulnTimer = 0;
        }
      },
      start: () => {
        startGame(stateRef.current, { profile: profileRef.current });
      },
      playSfx: (name: keyof typeof sfx) => {
        const fn = sfx[name];
        if (typeof fn === "function") (fn as () => void)();
      },
    };

    return () => {
      cancelAnimationFrame(rafRef.current);
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
      window.removeEventListener("blur", onBlur);
    };
  }, [ready, syncHud]);

  const setTouch = (key: keyof GameState["touch"], v: boolean) => {
    stateRef.current.touch[key] = v;
  };

  const fireAction = (kind: AttackKind) => {
    void unlockAudio();
    queueAction(stateRef.current, kind);
  };

  const onStart = (opts?: Partial<StartOpts>) => {
    void unlockAudio();
    stopTrack();
    fadeOutMenuTheme(500);
    setMenuScreen("menu");
    startGame(stateRef.current, {
      profile: profileRef.current,
      mode: opts?.mode ?? pendingMode,
      characterId: opts?.characterId ?? pendingChar,
      startWave: opts?.startWave,
      slotIndex: opts?.slotIndex,
      slot: opts?.slot,
    });
    lastPhase.current = "playing";
    syncHud();
  };

  const goMenu = () => {
    void unlockAudio();
    stopTrack();
    fadeInMenuTheme(400);
    const s = stateRef.current;
    if (s.phase === "playing" || s.phase === "paused" || s.phase === "waveClear") {
      const p = profileRef.current;
      persistSlot(p, s);
      applyRunRewards(p, s);
      saveProfile(p);
      setProfile({ ...p });
    }
    s.phase = "title";
    s.keys.clear();
    titleCardRef.current = false;
    setTitleCard(false);
    setMenuScreen("menu");
    setMenuIndex(0);
    lastPhase.current = "title";
    syncHud();
  };

  const onMute = () => {
    void unlockAudio();
    const next = toggleMute();
    setMutedUi(next);
    const p = profileRef.current;
    p.settings.muted = next;
    saveProfile(p);
  };

  const onContinue = () => {
    const p = profileRef.current;
    const last = lastPlayedSlot(p);
    if (!last) return;
    const idx = p.slots.findIndex((s) => s && s.updatedAt === last.updatedAt);
    onStart({ mode: last.mode, characterId: last.characterId, slot: last, slotIndex: idx < 0 ? 0 : idx });
  };

  const onBuy = (id: string) => {
    const p = profileRef.current;
    const item = SHOP_ITEMS.find((x) => x.id === id);
    if (!item) return;
    const lv = p.shop.levels[id] ?? 0;
    if (lv >= item.max) return;
    const price = item.prices[Math.min(lv, item.prices.length - 1)] ?? 0;
    if (p.shop.cred < price) return;
    p.shop.cred -= price;
    p.shop.levels[id] = lv + 1;
    if (id === "char_andrew" && !p.shop.ownedChars.includes("andrew")) p.shop.ownedChars.push("andrew");
    if (id === "char_han" && !p.shop.ownedChars.includes("han")) p.shop.ownedChars.push("han");
    unlockAchievement(p, "shopaholic");
    if (p.shop.ownedChars.includes("andrew") && p.shop.ownedChars.includes("han")) {
      unlockAchievement(p, "full_roster");
    }
    saveProfile(p);
    setProfile({
      ...p,
      shop: { ...p.shop, levels: { ...p.shop.levels }, ownedChars: [...p.shop.ownedChars] },
    });
    sfx.uiConfirm();
  };

  const onFeedback = (text: string) => {
    const p = profileRef.current;
    p.feedback = [...p.feedback, { at: Date.now(), text }].slice(-20);
    saveProfile(p);
    setProfile({ ...p, feedback: [...p.feedback] });
    sfx.uiConfirm();
  };

  const showMenu = ready && phase === "title" && !titleCard;
  const showCombatHud = ready && (phase === "playing" || phase === "waveClear" || phase === "paused");

  useEffect(() => {
    const v = menuVideoRef.current;
    if (!v) return;
    if (showMenu) {
      v.currentTime = 0;
      void v.play().catch(() => {});
    } else {
      v.pause();
    }
  }, [showMenu]);

  return (
    <div
      ref={wrapRef}
      className="relative flex h-full w-full flex-col items-center justify-center bg-bg"
    >
      <div className="relative w-full max-w-[1100px] px-2 sm:px-4">
        <div className="relative mx-auto aspect-video w-full overflow-hidden rounded-xl border border-border bg-black shadow-[0_0_40px_rgba(255,45,138,0.12)]">
          {ready && phase === "title" && titleCard && (
            <img
              src="/assets/ui/title-screen.png"
              alt=""
              className="absolute inset-0 z-[1] h-full w-full object-contain"
            />
          )}
          <video
            ref={menuVideoRef}
            className={`absolute inset-0 z-[1] h-full w-full origin-left scale-125 object-cover object-left ${showMenu ? "block" : "hidden"}`}
            src="/assets/ui/menu-select-loop.mp4?v=16"
            muted
            loop
            playsInline
            preload="auto"
          />
          <canvas
            ref={canvasRef}
            width={VIEW_W}
            height={VIEW_H}
            className={`pixelated relative z-[2] h-full w-full touch-none ${showMenu ? "pointer-events-none opacity-0" : ""}`}
            tabIndex={0}
            aria-label="JJ Beat-em-up game canvas"
          />

          {!ready && !error && (
            <div className="absolute inset-0 flex items-center justify-center bg-bg/90 text-muted">
              Loading JJ's night shift…
            </div>
          )}
          {error && (
            <div className="absolute inset-0 flex items-center justify-center bg-bg/90 text-danger">
              {error}
            </div>
          )}

          {ready && phase === "title" && titleCard && (
            <button
              type="button"
              onClick={() => {
                void unlockAudio();
                playMenuTheme();
                titleCardRef.current = false;
                setTitleCard(false);
                sfx.uiConfirm();
              }}
              className="absolute inset-0 z-20 bg-transparent"
              aria-label="Press start"
            />
          )}

          {ready && !showMenu && !titleCard && (
            <button
              type="button"
              onClick={onMute}
              className="absolute right-3 top-3 z-20 rounded-full border border-border bg-surface/90 px-3 py-1.5 text-xs font-bold text-fg shadow-md hover:brightness-110"
              aria-label={muted ? "Unmute" : "Mute"}
            >
              {muted || isMuted() ? "SOUND OFF" : "SOUND ON"}
            </button>
          )}

          {showMenu && (
            <MainMenu
              screen={menuScreen}
              selected={menuIndex}
              muted={muted || isMuted()}
              assets={assetsRef.current}
              profile={profile}
              pendingChar={pendingChar}
              pendingMode={pendingMode}
              onSelect={setMenuIndex}
              onMove={(dir) => setMenuIndex((i) => (i + dir + 15) % 15)}
              onOpen={(s) => {
                setMenuScreen(s);
                sfx.uiClick();
              }}
              onBack={() => setMenuScreen("menu")}
              onToggleMute={onMute}
              onContinue={onContinue}
              onStart={onStart}
              onLoadSlot={(i) => {
                const slot = profileRef.current.slots[i];
                if (slot) onStart({ slot, slotIndex: i, mode: slot.mode, characterId: slot.characterId });
              }}
              onBuy={onBuy}
              onSetChar={setPendingChar}
              onSetMode={setPendingMode}
              onFeedback={onFeedback}
            />
          )}

          {ready && phase === "paused" && (
            <div className="absolute inset-x-0 bottom-8 z-20 flex justify-center gap-3">
              <button
                type="button"
                onClick={() => {
                  stateRef.current.phase = "playing";
                  sfx.resume();
                  syncHud();
                }}
                className="min-h-12 rounded-full bg-primary px-6 py-3 text-sm font-bold text-primary-fg"
              >
                Resume
              </button>
              <button
                type="button"
                onClick={goMenu}
                className="min-h-12 rounded-full border border-border bg-surface px-6 py-3 text-sm font-bold text-fg"
              >
                Save & Menu
              </button>
            </div>
          )}

          {ready && (phase === "gameover" || phase === "victory") && (
            <div className="pointer-events-none absolute inset-x-0 bottom-8 z-20 flex justify-center gap-3">
              <button
                type="button"
                onClick={() => onStart({ mode: stateRef.current.mode, characterId: stateRef.current.characterId })}
                className="pointer-events-auto min-h-12 rounded-full bg-primary px-8 py-3 text-sm font-bold tracking-wide text-primary-fg shadow-lg"
              >
                {phase === "victory" ? "PLAY AGAIN" : "RETRY"}
              </button>
              <button
                type="button"
                onClick={goMenu}
                className="pointer-events-auto min-h-12 rounded-full border border-border bg-surface px-8 py-3 text-sm font-bold tracking-wide text-fg"
              >
                MENU
              </button>
            </div>
          )}
        </div>

        {showCombatHud && (
          <>
            <div className="mt-3 hidden justify-between gap-3 text-xs text-muted sm:flex">
              <span>Move: WASD / Arrows</span>
              <span>Punch: J / Z</span>
              <span>Kick: K / X</span>
              <span>Jump: Space / Shift</span>
              <span>Riff: L (full meter)</span>
              <span>Gun: F (after wave 3)</span>
              <span>Mute: M</span>
              <span>Pause: Esc</span>
            </div>

            <div className="mt-3 grid grid-cols-[1fr_auto] gap-3 sm:hidden">
              <div className="grid grid-cols-3 grid-rows-3 gap-1.5 place-items-center">
                <div />
                <TouchBtn label="▲" onDown={() => setTouch("up", true)} onUp={() => setTouch("up", false)} />
                <div />
                <TouchBtn label="◀" onDown={() => setTouch("left", true)} onUp={() => setTouch("left", false)} />
                <div className="h-12 w-12" />
                <TouchBtn label="▶" onDown={() => setTouch("right", true)} onUp={() => setTouch("right", false)} />
                <div />
                <TouchBtn label="▼" onDown={() => setTouch("down", true)} onUp={() => setTouch("down", false)} />
                <div />
              </div>
              <div className="flex flex-col justify-end gap-2">
                <div className="flex gap-2">
                  <TouchBtn
                    label="JUMP"
                    onDown={() => {
                      void unlockAudio();
                      queueJump(stateRef.current);
                    }}
                  />
                  <TouchBtn label="RIFF" accent onDown={() => fireAction("special")} />
                  <TouchBtn
                    label="GUN"
                    accent
                    onDown={() => {
                      if (stateRef.current.hasGun) fireAction("gun");
                    }}
                  />
                </div>
                <div className="flex gap-2">
                  <TouchBtn label="KICK" onDown={() => fireAction("kick")} />
                  <TouchBtn label="PUNCH" primary onDown={() => fireAction("punch")} />
                </div>
              </div>
            </div>

            <div className="mt-2 flex justify-between text-[11px] text-muted sm:hidden">
              <span>HP {hud.hp}</span>
              <span>Wave {hud.wave}</span>
              <span>Score {hud.score}</span>
              <span>SP {hud.special}</span>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function TouchBtn({
  label,
  onDown,
  onUp,
  primary,
  accent,
  wide,
}: {
  label: string;
  onDown: () => void;
  onUp?: () => void;
  primary?: boolean;
  accent?: boolean;
  wide?: boolean;
}) {
  return (
    <button
      type="button"
      className={[
        "select-none rounded-2xl border border-border text-sm font-bold text-fg active:scale-95",
        wide ? "h-12 min-w-[7.5rem] px-4" : "h-12 min-w-12 px-2",
        primary ? "bg-primary text-primary-fg" : accent ? "bg-accent text-accent-fg" : "bg-surface-2",
      ].join(" ")}
      onPointerDown={(e) => {
        e.preventDefault();
        (e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId);
        onDown();
      }}
      onPointerUp={(e) => {
        e.preventDefault();
        onUp?.();
      }}
      onPointerCancel={() => onUp?.()}
    >
      {label}
    </button>
  );
}

function coverImage(
  ctx: CanvasRenderingContext2D,
  img: HTMLImageElement,
  biasRight = false,
  mode: "cover" | "contain" = "cover",
) {
  const iw = img.naturalWidth || img.width;
  const ih = img.naturalHeight || img.height;
  if (!iw || !ih) return;
  const scale = mode === "contain" ? Math.min(VIEW_W / iw, VIEW_H / ih) : Math.max(VIEW_W / iw, VIEW_H / ih);
  const dw = iw * scale;
  const dh = ih * scale;
  const dx = biasRight && mode === "cover" ? VIEW_W - dw : (VIEW_W - dw) / 2;
  const dy = (VIEW_H - dh) / 2;
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  ctx.drawImage(img, dx, dy, dw, dh);
}

function drawTitleBackdrop(ctx: CanvasRenderingContext2D, assets: AssetMap, _now: number) {
  const art = assets.titleArt?.img;
  if (art && art.naturalWidth) coverImage(ctx, art, false, "contain");
}

function drawMenuLoop(ctx: CanvasRenderingContext2D, frames: HTMLImageElement[], now: number) {
  if (!frames.length) {
    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    return;
  }
  const fps = 15;
  const i = Math.floor((now / 1000) * fps) % frames.length;
  const frame = frames[i]!;
  coverImage(ctx, frame, false, "cover");
}

function drawCenterBanner(ctx: CanvasRenderingContext2D, title: string, sub: string) {
  ctx.fillStyle = "rgba(8,4,16,0.62)";
  ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  ctx.textAlign = "center";
  ctx.fillStyle = "#ff2d8a";
  ctx.font = "bold 42px Segoe UI, sans-serif";
  ctx.fillText(title, VIEW_W / 2, VIEW_H / 2 - 10);
  ctx.fillStyle = "#f4eef8";
  ctx.font = "16px Segoe UI, sans-serif";
  ctx.fillText(sub, VIEW_W / 2, VIEW_H / 2 + 28);
  ctx.textAlign = "left";
}
