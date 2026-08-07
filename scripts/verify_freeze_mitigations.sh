#!/usr/bin/env bash
# Assert freeze/white-screen mitigations remain in shipped Game sources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$ROOT/JJNightBrawl/Game"
fail=0
check() {
  local file="$1" pattern="$2" desc="$3"
  if grep -qE "$pattern" "$file"; then
    echo "OK  $desc"
  else
    echo "FAIL $desc ($file)"
    fail=1
  fi
}
check "$G/GameAudio.swift" 'NEVER detach|main\.async' "audio detach hops to main"
check "$G/GameCanvasView.swift" 'preferredFrameRateRange|preferredFramesPerSecond = 60' "display link capped ~60fps"
check "$G/GameCanvasView.swift" 'contentScaleFactor = min' "content scale capped"
check "$G/GameAssets.swift" 'frameCache' "sprite frame cache present"
check "$G/GameRenderer.swift" 'if let idle = assets.jjIdle' "title jjIdle not force-unwrapped"
check "$G/GameEngine.swift" 'particles.count > 120|min\(max\(rawDt' "engine safety clamps"
check "$G/GameCanvasView.swift" 'JJAutoStart|JJ_AUTO_START' "auto-start hook for sim verification"
if [[ $fail -ne 0 ]]; then exit 1; fi
echo "All freeze-mitigation checks passed."
