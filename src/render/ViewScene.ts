import type { GalaxyState } from '../sim/state';

/** A 3D view of the focused Vessel. It reads sim state each frame and never writes it (CLAUDE.md rule 2). */
export interface ViewScene {
  sync(state: GalaxyState): void;
  update(dt: number): void;
  render(): void;
  resize(): void;
  dispose(): void;
}
