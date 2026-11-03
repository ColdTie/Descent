import { useRef } from 'preact/hooks';
import { formatClock, formatWarp, WARP_LEVELS } from '../sim/time';
import { type GameStore, useGame } from './store';

export interface AppActions {
  save(): Promise<void>;
  exportJson(): void;
  importFile(file: File): Promise<void>;
  newGalaxy(): Promise<void>;
}

export interface DashboardProps {
  store: GameStore;
  actions: AppActions;
}

function ClockPill({ store }: { store: GameStore }) {
  const state = useGame(store);
  return (
    <div class="pill clock" title="Galactic clock: Year · Day · Hour">
      {formatClock(state.time)}
    </div>
  );
}

function WarpPills({ store }: { store: GameStore }) {
  const state = useGame(store);
  return (
    <div class="pill pills" role="group" aria-label="Warp">
      <button class={state.paused ? 'active pause' : 'pause'} onClick={() => store.dispatch({ type: 'pause', paused: !state.paused })} title="Space">
        {state.paused ? '▶' : '❚❚'}
      </button>
      {WARP_LEVELS.map((w) => (
        <button key={w} class={w === state.warp ? 'active' : ''} onClick={() => store.dispatch({ type: 'setWarp', warp: w })} title={`warp ${w}x`}>
          {formatWarp(w)}
        </button>
      ))}
    </div>
  );
}

function SaveMenu({ store, actions }: DashboardProps) {
  const fileInput = useRef<HTMLInputElement>(null);
  const armedRef = useRef(false);
  const state = useGame(store);
  return (
    <div class="pill pills" role="group" aria-label="Save">
      <button onClick={() => void actions.save()} title="Save to this browser (autosaves every 2 minutes)">
        save
      </button>
      <button onClick={() => actions.exportJson()} title="Download the galaxy as JSON">
        export
      </button>
      <button onClick={() => fileInput.current?.click()} title="Load a galaxy JSON file">
        import
      </button>
      <input
        ref={fileInput}
        id="import-file"
        type="file"
        accept="application/json,.json"
        hidden
        onChange={(e) => {
          const file = (e.currentTarget as HTMLInputElement).files?.[0];
          if (file) void actions.importFile(file);
          (e.currentTarget as HTMLInputElement).value = '';
        }}
      />
      <button
        class="danger"
        onClick={() => {
          if (!armedRef.current) {
            armedRef.current = true;
            store.say('Click NEW GALAXY again to abandon this one.');
            window.setTimeout(() => (armedRef.current = false), 3000);
            return;
          }
          armedRef.current = false;
          void actions.newGalaxy();
        }}
        title={`Start over with a new seed (current seed ${state.seed})`}
      >
        new galaxy
      </button>
    </div>
  );
}

function Notice({ store }: { store: GameStore }) {
  useGame(store);
  if (!store.notice) return null;
  return <div class="notice">{store.notice}</div>;
}

export function Dashboard({ store, actions }: DashboardProps) {
  return (
    <div class="dash">
      <div class="strip top">
        <ClockPill store={store} />
        <WarpPills store={store} />
        <span class="spacer" />
        <SaveMenu store={store} actions={actions} />
      </div>
      <Notice store={store} />
    </div>
  );
}
