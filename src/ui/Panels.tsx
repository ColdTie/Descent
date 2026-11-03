import { RESOURCE_IDS, RESOURCE_NAMES } from '../content/resources';
import { SYSTEM_DEFS, SYSTEM_IDS } from '../content/systems';
import { REPAIR_PARTS } from '../content/transit';
import { repairBlocker, repairGain } from '../sim/commands';
import { transitSummary } from '../sim/ledger';
import { alertCountFor, flattenLineage, lineageTree } from '../sim/lineage';
import { focusedVessel, starById } from '../sim/state';
import { colonyOf } from '../sim/commands';
import { rateText } from './colonyView';
import { formatClock, formatDuration } from '../sim/time';
import { Card } from './Card';
import { formatInteger, formatStock, integrityLevel } from './gauges';
import { type GameStore, useGame } from './store';

export function SystemsCard({ store }: { store: GameStore }) {
  const state = useGame(store);
  const v = focusedVessel(state);
  const worst = Math.min(...SYSTEM_IDS.map((id) => v.systems[id].integrity));
  return (
    <Card id="systems" title="SYSTEMS" badge={`${formatInteger(worst)} min`}>
      <ul class="gauges">
        {SYSTEM_IDS.map((id) => {
          const integrity = v.systems[id].integrity;
          return (
            <li key={id} class={`gauge ${integrityLevel(integrity)}`} title={`${SYSTEM_DEFS[id].name}: wears ${SYSTEM_DEFS[id].wearPerHour} per game hour in transit`}>
              <span class="gauge-name">{SYSTEM_DEFS[id].name}</span>
              <span class="gauge-bar"><span class="gauge-fill" style={{ width: `${Math.max(0, Math.min(100, integrity))}%` }} /></span>
              <span class="gauge-num">{formatInteger(integrity)}</span>
              <RepairButton store={store} system={id} />
            </li>
          );
        })}
      </ul>
      <div class="card-foot">
        Parts {formatStock(v.stock.parts)} · Fuel {formatStock(v.stock.fuel)}
      </div>
    </Card>
  );
}

function RepairButton({ store, system }: { store: GameStore; system: (typeof SYSTEM_IDS)[number] }) {
  const v = focusedVessel(store.state);
  const blocker = repairBlocker(v, system);
  const gain = repairGain(v, system);
  return (
    <button
      class="repair"
      disabled={blocker !== ''}
      onClick={() => store.dispatch({ type: 'repair', vesselId: v.id, system })}
      title={blocker ? `Repair: ${blocker}` : `Repair ${SYSTEM_DEFS[system].name} +${gain.toFixed(1)} for ${REPAIR_PARTS} Parts (scaled by Fabricator integrity)`}
      aria-label={`Repair ${SYSTEM_DEFS[system].name}`}
    >
      +
    </button>
  );
}

export function StockpileCard({ store }: { store: GameStore }) {
  const state = useGame(store);
  const v = focusedVessel(state);
  const c = colonyOf(state, v);
  return (
    <Card id="stockpile" title="STOCKPILE" defaultOpen={c !== null}>
      <ul class="rows">
        {RESOURCE_IDS.map((id) => (
          <li key={id}>
            <span>{RESOURCE_NAMES[id]}</span>
            <span class="num">
              {id === 'power' && c ? `${formatStock(c.power.supply)} / ${formatStock(c.power.demand)}` : formatStock(v.stock[id])}
              {c && id !== 'power' ? <span class="rate"> {rateText(c.rates[id])}</span> : null}
            </span>
          </li>
        ))}
      </ul>
      {c ? <div class="card-foot">Rates are what the colony made per game hour over the last step.</div> : null}
    </Card>
  );
}

export function LineageCard({ store }: { store: GameStore }) {
  const state = useGame(store);
  const nodes = flattenLineage(lineageTree(state));
  const alerts = state.alerts.length;
  return (
    <Card id="lineage" title="LINEAGE" badge={alerts ? `● ${alerts}` : `${nodes.length}`} defaultOpen={false}>
      <ul class="tree">
        {nodes.map((n) => {
          const v = n.vessel;
          const focused = v.id === state.focusedVesselId;
          const count = alertCountFor(state, v.id);
          return (
            <li key={v.id} style={{ paddingLeft: `${n.depth * 12}px` }}>
              <button class={focused ? 'tree-node focused' : 'tree-node'} onClick={() => store.dispatch({ type: 'focusVessel', vesselId: v.id })} title={focused ? 'focused' : 'focus this Vessel'}>
                <span class="tree-dot" />
                <span class="tree-name">{v.name}</span>
                <span class="tree-phase">{v.phase}</span>
                {count ? <span class="tree-alert">● {count}</span> : null}
              </button>
            </li>
          );
        })}
      </ul>
      <div class="card-foot">click a Vessel to focus it</div>
    </Card>
  );
}

export function LogCard({ store }: { store: GameStore }) {
  const state = useGame(store);
  const v = focusedVessel(state);
  const entries = v.log.slice(-40).reverse();
  return (
    <Card id="log" title="LOG" badge={`${v.log.length}`} defaultOpen={false}>
      <ul class="log">
        {entries.map((e, i) => (
          <li key={`${e.time}-${i}`}>
            <span class="log-time">{formatClock(e.time)}</span>
            <span>{e.text}</span>
          </li>
        ))}
      </ul>
    </Card>
  );
}

/** The last three log lines, newest brightest, bottom left. */
export function FadingLog({ store }: { store: GameStore }) {
  const state = useGame(store);
  const v = focusedVessel(state);
  const last = v.log.slice(-3).reverse();
  return (
    <div class="fading-log" aria-live="polite">
      {last.map((e, i) => (
        <div key={`${e.time}-${i}`} style={{ opacity: 1 - i * 0.32 }}>
          <span class="log-time">{formatClock(e.time)}</span> {e.text}
        </div>
      ))}
    </div>
  );
}

export function DestinationReadout({ store }: { store: GameStore }) {
  const state = useGame(store);
  const v = focusedVessel(state);
  const s = transitSummary(state, v);
  if (!s) {
    const star = v.starId === null ? undefined : starById(state, v.starId);
    const sys = v.starId === null ? undefined : state.starSystems[v.starId];
    let main = `${v.name} · ${v.phase}`;
    let sub = '';
    if (v.phase === 'lost') {
      main = `${v.name} · lost`;
      sub = 'The hull failed. This Vessel is gone.';
    } else if (v.phase === 'arrival') {
      main = `In orbit at ${star?.name ?? 'a star'}`;
      const body = v.survey ? sys?.bodies[v.survey.bodyId] : undefined;
      sub = body && v.survey
        ? `Surveying ${body.name} · ${Math.round((1 - v.survey.remainingSeconds / v.survey.totalSeconds) * 100)}% · ${formatDuration(v.survey.remainingSeconds)} left`
        : 'Survey a body in the SYSTEM card, then land.';
    } else if (v.phase === 'planetside') {
      const world = v.worldId === null ? undefined : state.worlds[v.worldId];
      const body = world ? state.starSystems[world.starId]?.bodies[world.bodyId] : undefined;
      main = `Landed on ${body?.name ?? 'a world'}`;
      const col = colonyOf(state, v);
      sub = col
        ? `${col.robots.length} robots · ${col.buildings.filter((b) => b.progress >= 1).length} buildings · ${col.fabricatorOnline ? 'Fabricator online' : 'no Fabricator yet'}`
        : 'Setting up the colony.';
    }
    return (
      <div class={v.phase === 'lost' ? 'readout lost' : 'readout'}>
        <div class="readout-main">{main}</div>
        <div class="readout-sub">{sub}</div>
      </div>
    );
  }
  const burn = s.burn === 'accel' ? 'launch burn' : s.burn === 'decel' ? 'braking' : 'coasting';
  return (
    <div class="readout" title={`${s.fromName} → ${s.targetName}, ${s.distanceLy.toFixed(1)} ly in all`}>
      <div class="readout-main">
        {s.targetName} · {s.remainingLy.toFixed(2)} ly · {s.speedC.toFixed(3)}c
      </div>
      <div class="readout-sub">
        ETA {formatDuration(s.etaSeconds)} · {Math.round(s.progress * 100)}% · {burn} · fuel {formatStock(v.stock.fuel)}
      </div>
    </div>
  );
}

export function AlertBanner({ store }: { store: GameStore }) {
  const state = useGame(store);
  const alert = state.alerts[state.alerts.length - 1];
  if (!alert) return null;
  const v = state.vessels[alert.vesselId];
  const more = state.alerts.length - 1;
  return (
    <div class={`alert ${alert.level}`} role="status">
      <span class="alert-text">
        ▲ {v?.name ?? `Vessel ${alert.vesselId}`} · {alert.text}
        {more > 0 ? ` (+${more} more)` : ''}
      </span>
      {v && v.id !== state.focusedVesselId ? (
        <button onClick={() => store.dispatch({ type: 'focusVessel', vesselId: v.id })}>focus</button>
      ) : null}
      <button onClick={() => store.dispatch({ type: 'dismissAlert', alertId: alert.id })}>dismiss</button>
    </div>
  );
}
