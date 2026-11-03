import { h, render } from 'preact';
import './style.css';
import { installHotkeys } from './input/hotkeys';
import { Autosaver, clearGalaxy, exportGalaxy, importGalaxy, keepUnreadable, loadGalaxy, saveGalaxy, UNREADABLE_KEY } from './persist/store';
import { SceneHost } from './render/SceneHost';
import { Game } from './sim/game';
import { createGalaxy } from './sim/state';
import { Dashboard, type AppActions } from './ui/Dashboard';
import { ErrorBoundary } from './ui/ErrorBoundary';
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
  const store = new GameStore(game);
  // A resumed galaxy starts paused so the player can look before time runs.
  if (loaded.state) {
    store.dispatch({ type: 'pause', paused: true });
    store.say(`Resumed galaxy ${loaded.state.seed}, paused. Space to run.`, 5000);
  }
  // Autosave only once nothing on disk is at risk: a read error or a save we failed to set aside stays untouched
  // until the player saves, imports or starts a new galaxy by hand.
  let autosaveSafe = true;
  if (!loaded.state && loaded.readFailed) {
    autosaveSafe = false;
    store.say(`Could not read the save (${loaded.reason}). Playing a new galaxy; autosave is off so the old save is not overwritten.`, 10000);
  } else if (!loaded.state && loaded.raw !== undefined) {
    const kept = await keepUnreadable(loaded.raw);
    autosaveSafe = kept;
    store.say(
      kept
        ? `Could not load the save (${loaded.reason}). It is kept under ${UNREADABLE_KEY}; started a new galaxy.`
        : `Could not load the save (${loaded.reason}) or set it aside. Autosave is off so it is not overwritten.`,
      10000,
    );
  }
  const scene = new SceneHost(canvas);
  const fps = new FpsMeter();
  const autosaver = new Autosaver(
    () => game.state,
    (ok) => store.say(ok ? 'Saved.' : 'Save failed: this browser blocked storage.'),
  );

  const actions: AppActions = {
    async save() {
      await autosaver.saveNow();
      autosaver.start();
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
      store.dispatch({ type: 'pause', paused: true });
      store.say(`Imported galaxy ${r.state.seed}, paused. Space to run.`, 5000);
      await saveGalaxy(game.state);
      autosaver.start();
    },
    async newGalaxy() {
      await clearGalaxy();
      game.load(createGalaxy(randomSeed()));
      store.say(`New galaxy, seed ${game.state.seed}.`);
      await saveGalaxy(game.state);
      autosaver.start();
    },
  };

  render(
    h(ErrorBoundary, { actions }, h('div', null, h(Dashboard, { store, actions }), h(Hud, { fps }))),
    uiRoot,
  );
  installHotkeys(() => game.state, (cmd) => store.dispatch(cmd));
  if (autosaveSafe) autosaver.start();

  let last = performance.now();
  (window as unknown as { __vesselScene?: () => string }).__vesselScene = () => scene.current;
  function frame(now: number): void {
    const dt = Math.min((now - last) / 1000, 0.25);
    last = now;
    const report = game.tick(dt);
    for (const reason of game.takeRefusals()) store.say(`Refused: ${reason}.`);
    if (report.changed) store.notify();
    store.age(dt);
    scene.frame(game.state, dt);
    fps.sample(dt);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

void boot();
