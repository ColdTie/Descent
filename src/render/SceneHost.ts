import * as THREE from 'three';
import { focusedVessel, type GalaxyState } from '../sim/state';
import { SpaceScene } from './SpaceScene';
import type { ViewScene } from './ViewScene';
import { WorldScene } from './WorldScene';

/**
 * Owns the one WebGL renderer and the active scene. Only the focused Vessel gets a world scene: it is
 * hydrated from ledger state when that Vessel is planetside and torn down on unfocus (CLAUDE.md rule 6).
 */
export class SceneHost {
  private readonly renderer: THREE.WebGLRenderer;
  private active: ViewScene | null = null;
  private key = '';
  /** The colony object the world scene was built from; a load or import replaces it. */
  private builtFrom: object | null = null;

  constructor(private readonly canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  }

  /** Which scene the current state calls for: the focused Vessel's world, or space. */
  private want(state: GalaxyState): { key: string; source: object | null; make: () => ViewScene } {
    const v = focusedVessel(state);
    const world = v.phase === 'planetside' && v.worldId !== null ? state.worlds[v.worldId] : undefined;
    const body = world ? state.starSystems[world.starId]?.bodies[world.bodyId] : undefined;
    if (world?.colony && body) {
      const colony = world.colony;
      return { key: `world:${world.id}`, source: colony, make: () => new WorldScene(this.canvas, this.renderer, world.id, colony, body.kind) };
    }
    return { key: 'space', source: null, make: () => new SpaceScene(this.canvas, this.renderer) };
  }

  frame(state: GalaxyState, dt: number): void {
    const w = this.want(state);
    if (w.key !== this.key || w.source !== this.builtFrom) {
      this.active?.dispose();
      this.active = w.make();
      this.key = w.key;
      this.builtFrom = w.source;
    }
    this.active!.sync(state);
    this.active!.update(dt);
    this.active!.render();
  }

  /** Which scene is showing, for tests and the screenshot script. */
  get current(): string {
    return this.key;
  }
}
