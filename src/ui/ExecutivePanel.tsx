import { BUILDING_DEFS, BUILDING_TYPES, JOB_CATEGORIES, JOB_NAMES, PRIORITY_MAX, ROBOT_DEFS, ROBOT_PARTS, ROBOT_TYPES } from '../content/colony';
import { colonyOf } from '../sim/commands';
import { canAfford, robotCount } from '../sim/colony/colony';
import { focusedVessel } from '../sim/state';
import { Card } from './Card';
import { costText, queueState } from './colonyView';
import { type GameStore, useGame } from './store';

/** The executive panel for a landed Vessel: priorities, quotas, the build queue. Every control dispatches a command. */
export function ExecutivePanel({ store }: { store: GameStore }) {
  const state = useGame(store);
  const v = focusedVessel(state);
  const c = colonyOf(state, v);
  if (!c) return null;
  const queued = c.buildings.filter((b) => b.progress < 1);
  const builtCount = c.buildings.filter((b) => b.progress >= 1).length;
  return (
    <div class="right-col">
      <Card id="priorities" title="PRIORITIES" badge={`power ${c.power.supply.toFixed(0)} / ${c.power.demand.toFixed(0)}`}>
        <ul class="sliders">
          {JOB_CATEGORIES.map((job) => (
            <li key={job}>
              <label for={`prio-${job}`}>{JOB_NAMES[job]}</label>
              <input
                id={`prio-${job}`}
                type="range"
                min={0}
                max={PRIORITY_MAX}
                step={1}
                value={c.priorities[job]}
                onInput={(e) => store.dispatch({ type: 'setPriority', vesselId: v.id, job, value: Number((e.currentTarget as HTMLInputElement).value) })}
              />
              <span class="num">{c.priorities[job] === 0 ? 'off' : c.priorities[job]}</span>
            </li>
          ))}
        </ul>
        <div class="card-foot">Robots take the highest-priority job first, then the nearest. Expand adds miners and solar by itself.</div>
      </Card>
      <Card id="workforce" title="WORKFORCE" badge={`${c.robots.length} robots`}>
        <ul class="quotas">
          {ROBOT_TYPES.map((type) => {
            const have = robotCount(c, type);
            const want = c.quotas[type];
            return (
              <li key={type}>
                <span class={`robot-dot ${type}`} />
                <span class="quota-name">{ROBOT_DEFS[type].name}</span>
                <span class="num">
                  {have} / {want}
                </span>
                <button aria-label={`fewer ${type}s`} disabled={want <= 0} onClick={() => store.dispatch({ type: 'setQuota', vesselId: v.id, quota: type, value: want - 1 })}>
                  −
                </button>
                <button aria-label={`more ${type}s`} disabled={want >= 20} onClick={() => store.dispatch({ type: 'setQuota', vesselId: v.id, quota: type, value: want + 1 })}>
                  +
                </button>
              </li>
            );
          })}
        </ul>
        <div class="card-foot">
          {c.fabricatorOnline
            ? c.robotBuild
              ? `Fabricator building a ${ROBOT_DEFS[c.robotBuild.type].name.toLowerCase()}, ${Math.ceil(c.robotBuild.remainingHours)} h left.`
              : `The Fabricator builds robots up to these numbers, ${ROBOT_PARTS} Parts each.`
            : 'Robots are built at a Fabricator. Build one to grow the workforce.'}
        </div>
      </Card>
      <Card id="build" title="BUILD" badge={`${builtCount} built · ${queued.length} queued`}>
        <div class="build-grid">
          {BUILDING_TYPES.filter((t) => !BUILDING_DEFS[t].locked).map((t) => (
            <button
              key={t}
              class={canAfford(v.stock, t) ? 'build-btn' : 'build-btn short'}
              disabled={c.queue.length >= 12}
              onClick={() => store.dispatch({ type: 'queueBuild', vesselId: v.id, building: t })}
              title={`${BUILDING_DEFS[t].name}: ${costText(BUILDING_DEFS[t].cost)}, ${BUILDING_DEFS[t].buildHours} builder-hours${BUILDING_DEFS[t].node ? `, sits on a ${BUILDING_DEFS[t].node} node` : ''}`}
            >
              <span>{BUILDING_DEFS[t].name}</span>
              <span class="build-cost">{costText(BUILDING_DEFS[t].cost)}</span>
            </button>
          ))}
        </div>
        {queued.length ? (
          <ol class="queue">
            {queued.map((b) => (
              <li key={b.id}>
                <span class="queue-name">
                  {BUILDING_DEFS[b.type].name}
                  {b.auto ? <span class="auto"> · auto</span> : null}
                </span>
                <span class="queue-state">{queueState(c, v.stock, b)}</span>
                <button aria-label={`cancel ${BUILDING_DEFS[b.type].name}`} title={b.paid && b.progress === 0 ? 'Cancel and refund' : b.progress > 0 ? 'Cancel (work done is lost, no refund)' : 'Cancel'} onClick={() => store.dispatch({ type: 'cancelBuild', vesselId: v.id, buildingId: b.id })}>
                  ×
                </button>
              </li>
            ))}
          </ol>
        ) : (
          <div class="card-foot">Queue is empty. Pick a building above; it goes on the nearest open ground or node.</div>
        )}
      </Card>
    </div>
  );
}
