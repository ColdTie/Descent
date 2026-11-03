import { h, render } from 'preact';
import './style.css';
import { SpaceScene } from './render/SpaceScene';
import { FpsMeter } from './ui/fps';
import { Hud } from './ui/Hud';

const canvas = document.getElementById('scene') as HTMLCanvasElement;
const uiRoot = document.getElementById('ui') as HTMLDivElement;

const scene = new SpaceScene(canvas);
const fps = new FpsMeter();
render(h(Hud, { fps }), uiRoot);

let last = performance.now();
function frame(now: number): void {
  const dt = Math.min((now - last) / 1000, 0.25);
  last = now;
  scene.update(dt);
  scene.render();
  fps.sample(dt);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
