import { del, get, set } from 'idb-keyval';
import { deserialize, serialize } from '../sim/migrations';
import type { GalaxyState } from '../sim/state';

export const SAVE_KEY = 'vessel.galaxy';
export const AUTOSAVE_MS = 2 * 60 * 1000;

export const UNREADABLE_KEY = 'vessel.galaxy.unreadable';

export interface LoadResult {
  state: GalaxyState | null;
  reason: string;
  /** The stored text when it could not be loaded, so it can be kept aside. */
  raw?: string;
}

export async function saveGalaxy(state: GalaxyState): Promise<boolean> {
  try {
    await set(SAVE_KEY, serialize(state));
    return true;
  } catch {
    return false;
  }
}

export async function loadGalaxy(): Promise<LoadResult> {
  try {
    const text = await get<string>(SAVE_KEY);
    if (!text) return { state: null, reason: 'no save' };
    const r = deserialize(text);
    return r.state ? r : { ...r, raw: text };
  } catch (err) {
    return { state: null, reason: String(err) };
  }
}

/** Copies a save this build cannot read to a side slot, so the autosave cannot destroy it. */
export async function keepUnreadable(raw: string): Promise<boolean> {
  try {
    await set(UNREADABLE_KEY, raw);
    return true;
  } catch {
    return false;
  }
}

export async function clearGalaxy(): Promise<void> {
  try {
    await del(SAVE_KEY);
  } catch {
    /* nothing to clear */
  }
}

/** Triggers a browser download of the save as JSON. */
export function exportGalaxy(state: GalaxyState): void {
  const blob = new Blob([serialize(state)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `vessel-galaxy-${state.seed}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export async function importGalaxy(file: File): Promise<LoadResult> {
  try {
    return deserialize(await file.text());
  } catch (err) {
    return { state: null, reason: String(err) };
  }
}

/** Saves every AUTOSAVE_MS and whenever the tab is hidden. */
export class Autosaver {
  private timer: number | null = null;
  private readonly onHide = (): void => {
    if (document.visibilityState === 'hidden') void this.saveNow();
  };

  constructor(private readonly getState: () => GalaxyState, private readonly onSaved: (ok: boolean) => void = () => {}) {}

  start(): void {
    this.stop();
    this.timer = window.setInterval(() => void this.saveNow(), AUTOSAVE_MS);
    document.addEventListener('visibilitychange', this.onHide);
  }

  stop(): void {
    if (this.timer !== null) window.clearInterval(this.timer);
    this.timer = null;
    document.removeEventListener('visibilitychange', this.onHide);
  }

  async saveNow(): Promise<boolean> {
    const ok = await saveGalaxy(this.getState());
    this.onSaved(ok);
    return ok;
  }
}
