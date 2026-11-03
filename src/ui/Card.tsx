import type { ComponentChildren } from 'preact';
import { useState } from 'preact/hooks';

const PREFIX = 'vessel.ui.card.';

function readOpen(key: string, fallback: boolean): boolean {
  try {
    const v = localStorage.getItem(PREFIX + key);
    return v === null ? fallback : v === '1';
  } catch {
    return fallback;
  }
}

function writeOpen(key: string, open: boolean): void {
  try {
    localStorage.setItem(PREFIX + key, open ? '1' : '0');
  } catch {
    /* per-viewer convenience only */
  }
}

export interface CardProps {
  id: string;
  title: string;
  /** Small text at the right of the header, e.g. a count. */
  badge?: string;
  defaultOpen?: boolean;
  children: ComponentChildren;
}

/** A foldable overlay card. Open state is remembered per browser. */
export function Card({ id, title, badge, defaultOpen = true, children }: CardProps) {
  const [open, setOpen] = useState(() => readOpen(id, defaultOpen));
  const toggle = (): void => {
    const next = !open;
    setOpen(next);
    writeOpen(id, next);
  };
  return (
    <section class={open ? 'card open' : 'card'} id={`card-${id}`}>
      <button class="card-head" onClick={toggle} aria-expanded={open}>
        <span class="card-title">{title}</span>
        {badge ? <span class="card-badge">{badge}</span> : null}
        <span class="card-caret">{open ? '◂' : '▸'}</span>
      </button>
      {open ? <div class="card-body">{children}</div> : null}
    </section>
  );
}
