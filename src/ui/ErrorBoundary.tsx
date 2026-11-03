import { Component, type ComponentChildren } from 'preact';
import type { AppActions } from './Dashboard';

interface Props {
  actions: AppActions;
  children?: ComponentChildren;
}

/** If the dashboard ever fails to render, keep a way out on screen instead of a blank page. */
export class ErrorBoundary extends Component<Props, { error: string }> {
  state = { error: '' };

  componentDidCatch(error: unknown): void {
    this.setState({ error: error instanceof Error ? error.message : String(error) });
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div class="dash">
        <section class="modal fallback" role="alert">
          <div class="modal-kicker">▲ The dashboard failed to draw</div>
          <p class="modal-text">{this.state.error}</p>
          <p class="modal-sub">The save may be damaged. Export it to keep a copy, then start a new galaxy.</p>
          <div class="pill pills">
            <button onClick={() => this.props.actions.exportJson()}>export</button>
            <button class="danger" onClick={() => void this.props.actions.newGalaxy().then(() => this.setState({ error: '' }))}>
              new galaxy
            </button>
          </div>
        </section>
      </div>
    );
  }
}
