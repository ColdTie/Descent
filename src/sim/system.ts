import { BODY_COUNT_MAX, BODY_COUNT_MIN, BODY_DEFS, type BodyKind, type Hazard } from '../content/bodies';
import type { Rng } from './rng';
import type { Star } from './stars';

export interface BodyProfile {
  /** 0 to 1, how rich the ore deposits are. */
  ore: number;
  /** 0 to 1, how much accessible ice. */
  ice: number;
  /** Surface gravity in g. */
  gravity: number;
  hazard: Hazard;
  /** 1 to 3; 0 when hazard is none. */
  severity: number;
}

export interface Body {
  id: number;
  /** Placeholder names until LORE.md says otherwise. */
  name: string;
  kind: BodyKind;
  orbitAu: number;
  /** Always generated; the UI only shows it once surveyed. */
  profile: BodyProfile;
  surveyed: boolean;
}

export interface StarSystem {
  starId: number;
  bodies: Body[];
}

const LETTERS = 'bcdefgh';
const round2 = (n: number): number => Math.round(n * 100) / 100;

function pickKind(rng: Rng, orbitAu: number): BodyKind {
  const r = rng.next();
  if (orbitAu < 0.6) return r < 0.6 ? 'molten' : 'rocky';
  if (orbitAu < 2.5) return r < 0.75 ? 'rocky' : r < 0.9 ? 'icy' : 'gasGiant';
  return r < 0.45 ? 'gasGiant' : r < 0.85 ? 'icy' : 'rocky';
}

/** 2 to 6 bodies on log-spaced orbits; at least one can be landed on. Drawn from the worlds stream. */
export function generateSystem(rng: Rng, star: Star): StarSystem {
  const count = BODY_COUNT_MIN + rng.int(BODY_COUNT_MAX - BODY_COUNT_MIN + 1);
  const orbits = Array.from({ length: count }, () => round2(Math.exp(rng.range(Math.log(0.2), Math.log(30))))).sort((a, b) => a - b);
  const bodies: Body[] = orbits.map((orbitAu, i) => {
    const kind = pickKind(rng, orbitAu);
    const def = BODY_DEFS[kind];
    const hazard = def.hazards[rng.int(def.hazards.length)]!;
    return {
      id: i,
      name: `${star.name} ${LETTERS[i]}`,
      kind,
      orbitAu,
      profile: {
        ore: round2(rng.range(def.ore[0], def.ore[1])),
        ice: round2(rng.range(def.ice[0], def.ice[1])),
        gravity: round2(rng.range(def.gravity[0], def.gravity[1])),
        hazard,
        severity: hazard === 'none' ? 0 : 1 + rng.int(3),
      },
      surveyed: false,
    };
  });
  if (!bodies.some((b) => BODY_DEFS[b.kind].landable)) {
    const b = bodies[0]!;
    const def = BODY_DEFS.rocky;
    b.kind = 'rocky';
    b.profile = { ...b.profile, ore: round2(rng.range(def.ore[0], def.ore[1])), ice: round2(rng.range(def.ice[0], def.ice[1])), gravity: round2(rng.range(def.gravity[0], def.gravity[1])), hazard: 'none', severity: 0 };
  }
  return { starId: star.id, bodies };
}
