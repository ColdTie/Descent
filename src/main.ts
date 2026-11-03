import { h, render } from 'preact';
import './style.css';
import { installHotkeys } from './input/hotkeys';
import { Autosaver, clearGalaxy, exportGalaxy, importGalaxy, loadGalaxy, saveGalaxy } from './persist/store';
import { SpaceScene } from './render/SpaceScene';
import { Game } from './sim/game';
import { createGalaxy } from './sim/state';
import { Dashboard, type AppActions } from './ui/Dashboard';
import { FpsMeter } from './ui/fps';
import { Hud } from './ui/Hud';
import { GameStore } from './ui/store';

function randomSeed(): number {
  return Math.floor(Math.random() * 0x100000000) >>> 0;
}

async function boot(): Promise<void> {
  const canvas = document.getElementById('scene') as HTMLCanvasElement;
  const uiRoot = document.getElementById('ui') as HTMLDivElement;

  const loaded = await loadGalaxy();
  const game = new Game(loaded.state ?? createGalaxy(randomSeed()));
  // A resumed galaxy starts paused so the player can look before time runs.
  if (loaded.state) game.state.paused = true;
  const store = new GameStore(game);
  const scene = new SpaceScene(canvas);
  const fps = new FpsMeter();
  const autosaver = new Autosaver(
    () => game.state,
    (ok) => store.say(ok ? 'Saved.' : 'Save failed: this browser blocked storage.'),
  );

  const actions: AppActions = {
    async save() {
      await autosaver.saveNow();
    },
    exportJson() {
      exportGalaxy(game.state);
      store.say('Exported.');
    },
    async importFile(file) {
      const r = await importGalaxy(file);
      if (!r.state) {
        store.say(`Import failed: ${r.reason}.`);
        return;
      }
      game.load(r.state);
      await saveGalaxy(game.state);
      store.say(`Imported galaxy ${r.state.seed}.`);
    },
    async newGalaxy() {
      await clearGalaxy();
      game.load(createGalaxy(randomSeed()));
      await saveGalaxy(game.state);
      store.say(`New galaxy, seed ${game.state.seed}.`);
    },
  };

  render(
    h('div', null, h(Dashboard, { store, actions }), h(Hud, { fps })),
    uiRoot,
  );
  installHotkeys(() => game.state, (cmd) => store.dispatch(cmd));
  autosaver.start();
  if (loaded.state) store.say(`Resumed galaxy ${loaded.state.seed}, paused. Space to run.`, 5000);
  else if (loaded.reason !== 'no save') store.say(`Could not load the save (${loaded.reason}); started a new galaxy.`);

  let last = performance.now();
  function frame(now: number): void {
    const dt = Math.min((now - last) / 1000, 0.25);
    last = now;
    const report = game.tick(dt);
    for (const reason of game.takeRefusals()) store.say(`Refused: ${reason}.`);
    if (report.changed) store.notify();
    store.age(dt);
    scene.update(dt);
    scene.render();
    fps.sample(dt);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

void boot();
