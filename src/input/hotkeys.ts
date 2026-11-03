import type { Command } from '../sim/commands';
import { choicesFor } from '../sim/events';
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
  { keys: '1 to 3', action: 'answer an open event' },
];

/** Maps a keydown to a command, or null. Pure, so it is testable without a DOM. */
export function commandForKey(key: string, state: GalaxyState): Command | null {
  const idx = WARP_LEVELS.indexOf(state.warp as (typeof WARP_LEVELS)[number]);
  const n = Number(key);
  const open = state.events[0];
  if (open && key.length === 1 && Number.isInteger(n) && n >= 1) {
    // While an event is open, digits answer it instead of changing warp.
    return n <= choicesFor(open).length ? { type: 'resolveEvent', eventId: open.id, choice: n - 1 } : null;
  }
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
    default:
      if (key.length === 1 && Number.isInteger(n) && n >= 1 && n <= WARP_LEVELS.length) return { type: 'setWarp', warp: WARP_LEVELS[n - 1]! };
      return null;
  }
}

function isTyping(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  // A slider or checkbox keeps focus after a mouse drag but takes no text; hotkeys still apply.
  if (target instanceof HTMLInputElement && ['range', 'checkbox', 'radio', 'button'].includes(target.type)) return false;
  return target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable;
}

function isButton(target: EventTarget | null): boolean {
  return target instanceof HTMLElement && target.closest('button, [role="button"]') !== null;
}

export function installHotkeys(getState: () => GalaxyState, dispatch: (cmd: Command) => void): () => void {
  const onKey = (e: KeyboardEvent): void => {
    if (e.ctrlKey || e.metaKey || e.altKey || isTyping(e.target)) return;
    // A keyboard-focused button keeps its native Space and Enter activation.
    if ((e.key === ' ' || e.key === 'Enter') && isButton(e.target)) return;
    const cmd = commandForKey(e.key, getState());
    if (!cmd) return;
    e.preventDefault();
    dispatch(cmd);
  };
  // Mouse clicks leave a button focused; drop that focus so the next Space pauses instead of re-clicking it.
  const onClick = (e: MouseEvent): void => {
    if (e.detail > 0 && e.target instanceof HTMLElement) e.target.closest('button')?.blur();
  };
  window.addEventListener('keydown', onKey);
  window.addEventListener('click', onClick, true);
  return () => {
    window.removeEventListener('keydown', onKey);
    window.removeEventListener('click', onClick, true);
  };
}
