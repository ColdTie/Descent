import { EVENT_DEFS } from '../content/events';
import { choiceBlocker, choicesFor, describeEffect } from '../sim/events';
import { formatClock } from '../sim/time';
import { type GameStore, useGame } from './store';

/** The oldest open event, as one card with its choices. The galaxy holds still until it is answered. */
export function EventModal({ store }: { store: GameStore }) {
  const state = useGame(store);
  const event = state.events[0];
  if (!event) return null;
  const def = EVENT_DEFS[event.kind];
  const vessel = state.vessels[event.vesselId];
  const more = state.events.length - 1;
  return (
    <div class="modal-scrim">
      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="event-title">
        <div class="modal-kicker">
          ▲ {vessel?.name ?? `Vessel ${event.vesselId}`} · {formatClock(event.time)}
          {more > 0 ? ` · ${more} more waiting` : ''}
        </div>
        <h2 id="event-title" class="modal-title">
          {def.title}
        </h2>
        <p class="modal-text">{def.text(Math.round(event.damage))}</p>
        <p class="modal-sub">Time is holding until you choose.</p>
        <ol class="choices">
          {choicesFor(event).map((c, i) => {
            const blocker = vessel ? choiceBlocker(vessel, c.effect) : '';
            return (
              <li key={c.label}>
                <button
                  id={`choice-${i + 1}`}
                  class="choice"
                  disabled={blocker !== ''}
                  onClick={() => store.dispatch({ type: 'resolveEvent', eventId: event.id, choice: i })}
                  title={blocker || `press ${i + 1}`}
                >
                  <span class="choice-key">{i + 1}</span>
                  <span class="choice-label">{c.label}</span>
                  <span class="choice-cost">{blocker || describeEffect(event, c.effect)}</span>
                </button>
              </li>
            );
          })}
        </ol>
      </section>
    </div>
  );
}
