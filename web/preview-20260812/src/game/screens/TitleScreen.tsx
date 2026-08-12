import { useEffect } from "react";
import { playMenuTheme, toggleMute, unlockAudio } from "../audio";

type Props = {
  muted: boolean;
  onMuteChange: (m: boolean) => void;
  onStart: () => void;
};

export function TitleScreen({ muted, onMuteChange, onStart }: Props) {
  useEffect(() => {
    // Best-effort autoplay; browsers that block it unlock on the first tap.
    playMenuTheme();
    const kick = () => {
      unlockAudio();
      playMenuTheme();
    };
    window.addEventListener("pointerdown", kick);
    window.addEventListener("keydown", kick);
    return () => {
      window.removeEventListener("pointerdown", kick);
      window.removeEventListener("keydown", kick);
    };
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.code === "Enter" || e.code === "Space" || e.code === "KeyZ") {
        e.preventDefault();
        playMenuTheme();
        onStart();
      }
      if (e.code === "KeyM") {
        onMuteChange(toggleMute());
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onStart, onMuteChange]);

  return (
    <section className="relative flex h-dvh w-full items-end justify-center overflow-hidden bg-ink text-fg">
      <img
        src="/ui/title-screen.jpg"
        alt="JJ Night Brawl title — JJ on a midnight bench under a Junction City water tower"
        className="absolute inset-0 h-full w-full object-cover object-[center_42%]"
        draggable={false}
      />
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-ink via-ink/25 to-transparent" />
      <div className="pointer-events-none absolute inset-x-0 top-0 h-20 bg-gradient-to-b from-ink/50 to-transparent" />

      <button
        type="button"
        onClick={() => onMuteChange(toggleMute())}
        className="absolute top-4 right-4 z-20 min-h-11 min-w-11 rounded-full border border-line bg-night/70 px-3 font-display text-[9px] tracking-widest text-fg backdrop-blur-sm"
        aria-label={muted ? "Unmute" : "Mute"}
      >
        {muted ? "MUTE" : "BGM"}
      </button>

      <div className="relative z-10 mb-8 flex w-full max-w-xl flex-col items-center gap-3 px-6 text-center sm:mb-12">
        <button
          type="button"
          onClick={() => {
            playMenuTheme();
            onStart();
          }}
          className="press-start min-h-12 px-6 font-display text-[11px] tracking-[0.35em] text-cyan uppercase sm:text-[13px]"
        >
          Press Start
        </button>
        <p className="text-xs text-muted">Tap, click, or hit Enter</p>
      </div>
    </section>
  );
}
