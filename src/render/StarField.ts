import * as THREE from 'three';
import { createRng } from '../sim/rng';
import { palette } from './palette';

/** Stars on a distant shell. Cosmetic only, but seeded so screenshots are stable. */
export function makeStarField(count = 3000, seed = 1, radius = 900): THREE.Points {
  const rng = createRng(seed);
  const positions = new Float32Array(count * 3);
  const colors = new Float32Array(count * 3);
  const base = new THREE.Color(palette.star);
  const tint = new THREE.Color();

  for (let i = 0; i < count; i++) {
    // Uniform direction on the sphere.
    const z = rng.range(-1, 1);
    const theta = rng.range(0, Math.PI * 2);
    const r = Math.sqrt(1 - z * z);
    const dist = radius * rng.range(0.7, 1);
    positions[i * 3] = r * Math.cos(theta) * dist;
    positions[i * 3 + 1] = r * Math.sin(theta) * dist;
    positions[i * 3 + 2] = z * dist;

    // Mostly white, a little blue or amber, varied brightness.
    const warm = rng.next();
    tint.copy(base);
    if (warm < 0.15) tint.offsetHSL(-0.08, 0.3, 0);
    else if (warm > 0.85) tint.offsetHSL(0.5, 0.3, 0);
    tint.multiplyScalar(rng.range(0.45, 1));
    colors[i * 3] = tint.r;
    colors[i * 3 + 1] = tint.g;
    colors[i * 3 + 2] = tint.b;
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  const material = new THREE.PointsMaterial({ size: 2, sizeAttenuation: false, vertexColors: true });
  const points = new THREE.Points(geometry, material);
  points.name = 'stars';
  return points;
}
