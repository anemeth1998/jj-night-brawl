import { useEffect, useRef, useState } from "react";
import { fadeInMenuTheme, fadeOutMenuTheme, sfx } from "../audio";
import { loadAssets, type GameAssets } from "../assets";
import { GameEngine } from "../engine";
import { renderFrame } from "../renderer";
import { VIEW_H, VIEW_W, type StageId } from "../types";

type Props = {
  startStage?: StageId;
  onQuit: () => void;
};

export function GameView({ startStage, onQuit }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const engineRef = useRef<GameEngine | null>(null);
  const assetsRef = useRef<GameAssets | null>(null);
  const [ready, setReady] = useState(false);
  const [hud, setHud] = useState({ phase: "playing", score: 0, wave: 1 });

  useEffect(() => {
    fadeOutMenuTheme(500);
    let cancelled = false;
    let raf = 0;
    let last = performance.now();

    const engine = new GameEngine(startStage);
    engineRef.current = engine;

    const mapKey = (e: KeyboardEvent): string | null => {
      if (e.code === "KeyA" || e.code === "ArrowLeft") return "left";
      if (e.code === "KeyD" || e.code === "ArrowRight") return "right";
      if (e.code === "KeyW" || e.code === "ArrowUp") return "up";
      if (e.code === "KeyS" || e.code === "ArrowDown") return "down";
      if (e.code === "KeyJ" || e.code === "KeyZ") return "punch";
      if (e.code === "KeyK" || e.code === "KeyX") return "kick";
      if (e.code === "KeyL" || e.code === "KeyC") return "special";
      if (e.code === "Space") return "jump";
      return null;
    };

    const onDown = (e: KeyboardEvent) => {
      if (e.code === "KeyP" || e.code === "Escape") {
        e.preventDefault();
        engine.togglePause();
        return;
      }
      const code = mapKey(e);
      if (!code) return;
      e.preventDefault();
      engine.setKey(code, true);
    };
    const onUp = (e: KeyboardEvent) => {
      const code = mapKey(e);
      if (!code) return;
      engine.setKey(code, false);
    };

    window.addEventListener("keydown", onDown);
    window.addEventListener("keyup", onUp);

    loadAssets().then((assets) => {
      if (cancelled) return;
      assetsRef.current = assets;
      engine.start(startStage);
      setReady(true);
      last = performance.now();

      if (import.meta.env.DEV || new URLSearchParams(window.location.search).has("qa")) {
        window.__controlsTest = {
          getX: () => engine.state.player.x,
          getFacing: () => engine.state.player.facing,
          setKeys: (codes: string[]) => {
            engine.state.keys.clear();
            for (const c of codes) engine.state.keys.add(c);
          },
        };
      }

      const tick = (now: number) => {
        const dt = Math.min(0.05, (now - last) / 1000);
        last = now;
        engine.update(dt);
        const canvas = canvasRef.current;
        const assetsNow = assetsRef.current;
        if (canvas && assetsNow) {
          const ctx = canvas.getContext("2d");
          if (ctx) {
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            const dpr = Math.min(2, window.devicePixelRatio || 1);
            const cssW = canvas.clientWidth;
            const cssH = canvas.clientHeight;
            if (canvas.width !== Math.floor(cssW * dpr) || canvas.height !== Math.floor(cssH * dpr)) {
              canvas.width = Math.floor(cssW * dpr);
              canvas.height = Math.floor(cssH * dpr);
            }
            const scale = Math.min(canvas.width / VIEW_W, canvas.height / VIEW_H);
            const ox = (canvas.width - VIEW_W * scale) / 2;
            const oy = (canvas.height - VIEW_H * scale) / 2;
            ctx.fillStyle = "#07060c";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.translate(ox, oy);
            ctx.scale(scale, scale);
            renderFrame(ctx, engine.state, assetsNow);
          }
        }
        setHud((prev) => {
          if (prev.phase === engine.state.phase && prev.score === engine.state.score && prev.wave === engine.state.wave) {
            return prev;
          }
          return {
            phase: engine.state.phase,
            score: engine.state.score,
            wave: engine.state.wave,
          };
        });
        raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
    });

    return () => {
      cancelled = true;
      cancelAnimationFrame(raf);
      window.removeEventListener("keydown", onDown);
      window.removeEventListener("keyup", onUp);
      window.__controlsTest = undefined;
    };
  }, [startStage]);

  const hold = (dir: "left" | "right" | "up" | "down", down: boolean) => {
    engineRef.current?.setTouch({ [dir]: down });
  };

  const overlay =
    hud.phase === "paused" || hud.phase === "gameover" || hud.phase === "victory";

  return (
    <div
      ref={wrapRef}
      className="relative flex h-dvh w-full flex-col bg-ink text-fg"
      style={{ touchAction: "none" }}
    >
      <canvas ref={canvasRef} className="h-full w-full flex-1" />

      {!ready && (
        <div className="absolute inset-0 flex items-center justify-center bg-ink font-display text-[10px] tracking-widest text-muted">
          LOADING STREETS…
        </div>
      )}

      {overlay && (
        <div className="absolute inset-0 flex items-center justify-center bg-ink/70 px-6">
          <div className="w-full max-w-sm rounded-panel border border-line bg-night/90 p-6 text-center backdrop-blur-sm">
            <h2 className="font-display text-sm leading-7 text-hot">
              {hud.phase === "paused" && "Paused"}
              {hud.phase === "gameover" && "Knocked Out"}
              {hud.phase === "victory" && "Street Cleared"}
            </h2>
            <p className="mt-3 text-sm text-muted">Score {hud.score}</p>
            <div className="mt-6 flex flex-col gap-2">
              {hud.phase === "paused" && (
                <button
                  type="button"
                  className="min-h-11 rounded-md bg-hot px-4 font-display text-[10px] tracking-widest text-ink uppercase"
                  onClick={() => engineRef.current?.togglePause()}
                >
                  Resume
                </button>
              )}
              {(hud.phase === "gameover" || hud.phase === "victory") && (
                <button
                  type="button"
                  className="min-h-11 rounded-md bg-hot px-4 font-display text-[10px] tracking-widest text-ink uppercase"
                  onClick={() => engineRef.current?.start(startStage)}
                >
                  Play Again
                </button>
              )}
              <button
                type="button"
                className="min-h-11 rounded-md border border-line px-4 font-display text-[10px] tracking-widest text-fg uppercase"
                onClick={() => {
                  fadeInMenuTheme(400);
                  onQuit();
                }}
              >
                Menu
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="pointer-events-none absolute inset-x-0 bottom-0 flex items-end justify-between gap-3 p-3 sm:p-4">
        <div className="pointer-events-auto grid grid-cols-3 grid-rows-3 gap-1">
          <span />
          <Pad onHold={(d) => hold("up", d)}>▲</Pad>
          <span />
          <Pad onHold={(d) => hold("left", d)}>◀</Pad>
          <span />
          <Pad onHold={(d) => hold("right", d)}>▶</Pad>
          <span />
          <Pad onHold={(d) => hold("down", d)}>▼</Pad>
          <span />
        </div>
        <div className="pointer-events-auto flex gap-2">
          <Act label="J" sub="PUNCH" onPress={() => engineRef.current?.queueAction("punch")} />
          <Act label="K" sub="KICK" onPress={() => engineRef.current?.queueAction("kick")} />
          <Act label="L" sub="RIFF" hot onPress={() => engineRef.current?.queueAction("special")} />
          <Act
            label="▲"
            sub="JUMP"
            onPress={() => {
              engineRef.current?.setKey("jump", true);
              sfx.uiMove();
            }}
          />
        </div>
      </div>
    </div>
  );
}

function Pad({ children, onHold }: { children: string; onHold: (down: boolean) => void }) {
  return (
    <button
      type="button"
      className="flex size-12 items-center justify-center rounded-md border border-line bg-night/75 text-sm text-fg backdrop-blur-sm"
      onPointerDown={(e) => {
        e.preventDefault();
        onHold(true);
      }}
      onPointerUp={() => onHold(false)}
      onPointerLeave={() => onHold(false)}
      onPointerCancel={() => onHold(false)}
    >
      {children}
    </button>
  );
}

function Act({
  label,
  sub,
  hot,
  onPress,
}: {
  label: string;
  sub: string;
  hot?: boolean;
  onPress: () => void;
}) {
  return (
    <button
      type="button"
      className={
        "flex size-14 flex-col items-center justify-center rounded-full border text-[10px] backdrop-blur-sm " +
        (hot ? "border-hot bg-hot/25 text-fg" : "border-line bg-night/75 text-fg")
      }
      onPointerDown={(e) => {
        e.preventDefault();
        onPress();
      }}
    >
      <span className="font-display text-[9px]">{label}</span>
      <span className="text-[8px] tracking-wider text-muted">{sub}</span>
    </button>
  );
}

declare global {
  interface Window {
    __controlsTest?: {
      getX: () => number;
      getFacing: () => number;
      setKeys: (codes: string[]) => void;
    };
  }
}
