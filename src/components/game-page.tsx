import { GameCanvas } from "@/game/GameCanvas";

export function GamePage() {
  return (
    <main className="flex h-full min-h-0 flex-col bg-bg">
      <header className="flex shrink-0 items-center justify-between border-b border-border px-4 py-3 sm:px-6">
        <div className="flex items-center gap-3">
          <div className="h-2.5 w-2.5 rounded-full bg-primary shadow-[0_0_12px_#ff2d8a]" />
          <div>
            <h1 className="text-sm font-bold tracking-wide text-fg sm:text-base">
              JJ: Night Brawl
            </h1>
            <p className="text-[11px] text-muted sm:text-xs">
              Side-scrolling beat-em-up · 32-bit style
            </p>
          </div>
        </div>
        <p className="hidden text-xs text-muted md:block">
          Punch through five waves of street thugs
        </p>
      </header>
      <div className="min-h-0 flex-1">
        <GameCanvas />
      </div>
    </main>
  );
}
