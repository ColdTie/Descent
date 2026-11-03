import { useLayoutEffect, useRef } from 'preact/hooks';
import { EVENT_DEFS } from '../content/events';
import { choiceBlocker, choicesFor, describeEffect } from '../sim/events';
import { formatClock } from '../sim/time';
import { type GameStore, useGame } from './store';

/** The oldest open event, as one card with its choices. The galaxy holds still until it is answered. */
export function EventModal({ store }: { store: GameStore }) {
  const state = useGame(store);
  const event = state.events[0];
  const dialog = useRef<HTMLElement>(null);
  const eventId = event?.id ?? 0;
  // Move focus into the dialog when an event opens, so keys land on its choices.
  useLayoutEffect(() => {
    if (!eventId) return;
    const first = dialog.current?.querySelector<HTMLButtonElement>('.choice:not([disabled])');
    first?.focus();
  }, [eventId]);
  if (!event) return null;
  const def = EVENT_DEFS[event.kind];
  const vessel = state.vessels[event.vesselId];
  const more = state.events.length - 1;
  return (
    <div class="modal-scrim">
      <section
        ref={dialog}
        class="modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="event-title"
        onKeyDown={(e) => {
          // Keep Tab inside the dialog.
          if (e.key !== 'Tab' || !dialog.current) return;
          const items = Array.from(dialog.current.querySelectorAll<HTMLButtonElement>('.choice:not([disabled])'));
          if (items.length === 0) return;
          const i = items.indexOf(document.activeElement as HTMLButtonElement);
          const next = e.shiftKey ? (i <= 0 ? items.length - 1 : i - 1) : (i + 1) % items.length;
          e.preventDefault();
          items[next]!.focus();
        }}
      >
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
