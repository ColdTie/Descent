import { useEffect, useState } from 'preact/hooks';
import type { FpsMeter } from './fps';

export function Hud({ fps }: { fps: FpsMeter }) {
  const [value, setValue] = useState(fps.fps);
  useEffect(() => fps.subscribe(setValue), [fps]);
  return (
    <div class="hud">
      <div class="hud-title">
        VESSEL<span class="hud-sub">working title · phase 0 placeholder</span>
      </div>
      <div class="hud-fps">{value} fps</div>
      <div class="hud-hint">drag to orbit · wheel to zoom</div>
    </div>
  );
}
