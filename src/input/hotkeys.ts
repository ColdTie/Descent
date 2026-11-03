import type { Command } from '../sim/commands';
import type { GalaxyState } from '../sim/state';
import { WARP_LEVELS } from '../sim/time';

export interface Hotkey {
  keys: string;
  action: string;
}

export const HOTKEYS: Hotkey[] = [
  { keys: 'Space', action: 'pause / resume' },
  { keys: '] or +', action: 'warp up' },
  { keys: '[ or -', action: 'warp down' },
  { keys: '1 to 8', action: 'warp level' },
];

/** Maps a keydown to a command, or null. Pure, so it is testable without a DOM. */
export function commandForKey(key: string, state: GalaxyState): Command | null {
  const idx = WARP_LEVELS.indexOf(state.warp as (typeof WARP_LEVELS)[number]);
  switch (key) {
    case ' ':
      return { type: 'pause', paused: !state.paused };
    case ']':
    case '+':
    case '=':
      return { type: 'setWarp', warp: WARP_LEVELS[Math.min(WARP_LEVELS.length - 1, idx + 1)]! };
    case '[':
    case '-':
    case '_':
      return { type: 'setWarp', warp: WARP_LEVELS[Math.max(0, idx - 1)]! };
    default: {
      const n = Number(key);
      if (Number.isInteger(n) && n >= 1 && n <= WARP_LEVELS.length) return { type: 'setWarp', warp: WARP_LEVELS[n - 1]! };
      return null;
    }
  }
}

function isTyping(target: EventTarget | null): boolean {
  return target instanceof HTMLElement && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable);
}

export function installHotkeys(getState: () => GalaxyState, dispatch: (cmd: Command) => void): () => void {
  const onKey = (e: KeyboardEvent): void => {
    if (e.ctrlKey || e.metaKey || e.altKey || isTyping(e.target)) return;
    const cmd = commandForKey(e.key, getState());
    if (!cmd) return;
    e.preventDefault();
    dispatch(cmd);
  };
  window.addEventListener('keydown', onKey);
  return () => window.removeEventListener('keydown', onKey);
}
