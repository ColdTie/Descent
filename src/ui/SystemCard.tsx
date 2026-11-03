import { BODY_DEFS, HAZARD_NAMES, LANDING_FUEL, SURVEY_DAYS } from '../content/bodies';
import { landBlocker, landingCost, surveyBlocker } from '../sim/commands';
import { surveySeconds } from '../sim/ledger';
import { focusedVessel } from '../sim/state';
import type { Body } from '../sim/system';
import { SECONDS_PER_DAY } from '../sim/time';
import { Card } from './Card';
import { type GameStore, useGame } from './store';

const pct = (n: number): string => `${Math.round(n * 100)}%`;

/** Ore, ice, gravity and hazard of a surveyed body, e.g. "ore 82% · ice 4% · 0.9 g · quakes 2". */
export function profileLine(body: Body): string {
  const p = body.profile;
  const hazard = p.hazard === 'none' ? 'no hazard' : `${HAZARD_NAMES[p.hazard]} ${p.severity}`;
  return BODY_DEFS[body.kind].landable ? `ore ${pct(p.ore)} · ice ${pct(p.ice)} · ${p.gravity.toFixed(1)} g · ${hazard}` : `${p.gravity.toFixed(1)} g · ${hazard} · no surface`;
}

/** The bodies around the star the focused Vessel is at: survey them, then land on one. */
export function SystemCard({ store }: { store: GameStore }) {
  const state = useGame(store);
  const v = focusedVessel(state);
  if ((v.phase !== 'arrival' && v.phase !== 'planetside') || v.starId === null) return null;
  const system = state.starSystems[v.starId];
  if (!system) return null;
  const world = v.worldId === null ? undefined : state.worlds[v.worldId];
  const surveyed = system.bodies.filter((b) => b.surveyed).length;
  const days = Math.round(surveySeconds(v, SURVEY_DAYS) / SECONDS_PER_DAY);
  const cost = landingCost(v);
  const landLabel = cost.hull > 0 ? `land · ${cost.fuel.toFixed(0)} fuel · hull −${cost.hull.toFixed(0)}` : `land · ${LANDING_FUEL} fuel`;
  const landTitle = cost.fatal
    ? `This landing would destroy the Vessel: it needs ${LANDING_FUEL} Fuel and a working drive, and the Hull cannot take −${cost.hull.toFixed(0)}.`
    : cost.hull > 0
      ? `Short of Fuel or drive: the Hull takes −${cost.hull.toFixed(0)}.`
      : `Landing burn costs ${LANDING_FUEL} Fuel.`;
  return (
    <Card id="system" title="SYSTEM" badge={`${surveyed}/${system.bodies.length} surveyed`}>
      <ul class="bodies">
        {system.bodies.map((b) => {
          const surveying = v.survey?.bodyId === b.id ? v.survey : null;
          const here = world?.bodyId === b.id;
          const sBlock = surveyBlocker(state, v, b.id);
          const lBlock = landBlocker(state, v, b.id);
          return (
            <li key={b.id} class={`body ${b.kind}${b.surveyed ? ' surveyed' : ''}${here ? ' here' : ''}`}>
              <div class="body-head">
                <span class="body-dot" />
                <span class="body-name">{b.name}</span>
                <span class="body-orbit">{b.orbitAu.toFixed(1)} AU</span>
              </div>
              <div class="body-info">{b.surveyed ? `${BODY_DEFS[b.kind].name} · ${profileLine(b)}` : 'unsurveyed'}</div>
              {here ? <div class="body-info here-note">landed here</div> : null}
              {surveying ? (
                <div class="body-progress" title="survey under way">
                  <span style={{ width: `${Math.round((1 - surveying.remainingSeconds / surveying.totalSeconds) * 100)}%` }} />
                </div>
              ) : null}
              {v.phase === 'arrival' ? (
                <div class="body-actions">
                  {!b.surveyed ? (
                    <button disabled={sBlock !== ''} title={sBlock || `takes ${days} game days`} onClick={() => store.dispatch({ type: 'surveyBody', vesselId: v.id, bodyId: b.id })}>
                      {surveying ? 'surveying…' : `survey · ${days} d`}
                    </button>
                  ) : null}
                  {b.surveyed && BODY_DEFS[b.kind].landable ? (
                    <button class={cost.fatal ? 'land fatal' : 'land'} disabled={lBlock !== ''} title={lBlock || landTitle} onClick={() => store.dispatch({ type: 'land', vesselId: v.id, bodyId: b.id })}>
                      {cost.fatal ? `land · fatal (hull −${cost.hull.toFixed(0)})` : landLabel}
                    </button>
                  ) : null}
                </div>
              ) : null}
            </li>
          );
        })}
      </ul>
      {v.phase === 'arrival' ? <div class="card-foot">One survey at a time. Starting another abandons the current one.</div> : null}
    </Card>
  );
}
