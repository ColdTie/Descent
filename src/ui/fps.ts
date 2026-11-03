type Listener = (fps: number) => void;

/** Rolling FPS meter. Publishes a rounded value every `window` seconds of sampled frames. */
export class FpsMeter {
  fps = 0;
  private frames = 0;
  private elapsed = 0;
  private readonly listeners = new Set<Listener>();

  constructor(private readonly window = 0.5) {}

  sample(dt: number): void {
    this.frames += 1;
    this.elapsed += dt;
    if (this.elapsed >= this.window) {
      this.fps = Math.round(this.frames / this.elapsed);
      this.frames = 0;
      this.elapsed = 0;
      for (const listener of this.listeners) listener(this.fps);
    }
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }
}
