import { GameCanvas } from "./game/GameCanvas";

export function App() {
  return (
    <main className="flex min-h-dvh items-center justify-center bg-bg p-2 sm:p-4">
      <div className="h-[min(100dvh-1rem,720px)] w-full max-w-[1100px]">
        <GameCanvas />
      </div>
    </main>
  );
}
