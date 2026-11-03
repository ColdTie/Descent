import { useLayoutEffect, useReducer } from 'preact/hooks';
import type { Command } from '../sim/commands';
import type { Game } from '../sim/game';
import type { GalaxyState } from '../sim/state';

type Listener = () => void;

/** Hands sim state to Preact. Views read it and dispatch commands; they never mutate it (CLAUDE.md rule 2). */
export class GameStore {
  private readonly listeners = new Set<Listener>();
  /** Bumped whenever the state changed; views re-render on it. */
  version = 0;
  /** Transient UI messages (save status, refused commands). */
  notice = '';
  private noticeTimer = 0;

  constructor(readonly game: Game) {}

  get state(): GalaxyState {
    return this.game.state;
  }

  dispatch(cmd: Command): void {
    this.game.dispatch(cmd);
  }

  /** Call once per frame after the game ticked. */
  notify(): void {
    this.version += 1;
    for (const l of this.listeners) l();
  }

  say(text: string, ms = 2500): void {
    this.notice = text;
    this.noticeTimer = ms;
    this.notify();
  }

  /** Fades the notice; call from the frame loop with real dt. */
  age(dtSeconds: number): void {
    if (this.noticeTimer <= 0) return;
    this.noticeTimer -= dtSeconds * 1000;
    if (this.noticeTimer <= 0) {
      this.notice = '';
      this.notify();
    }
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }
}

/** Re-renders the component whenever the store notifies. */
export function useGame(store: GameStore): GalaxyState {
  const [, bump] = useReducer((n: number) => n + 1, 0);
  const seen = store.version;
  useLayoutEffect(() => {
    const unsub = store.subscribe(() => bump(0));
    // A notify between render and subscribe (e.g. a boot notice) would otherwise be lost.
    if (store.version !== seen) bump(0);
    return unsub;
  }, [store]);
  return store.state;
}
