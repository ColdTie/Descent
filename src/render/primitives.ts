import * as THREE from 'three';
import { palette } from './palette';

function flat(color: number, extra: Partial<THREE.MeshStandardMaterialParameters> = {}): THREE.MeshStandardMaterial {
  return new THREE.MeshStandardMaterial({ color, flatShading: true, roughness: 0.75, metalness: 0.1, ...extra });
}

/**
 * Placeholder Vessel: long hull (cylinder), ring (torus), drive (cone). Nose points +Z.
 * Length about 8 units. Everything is a colored primitive by design; see CLAUDE.md.
 */
export function makeVessel(): THREE.Group {
  const group = new THREE.Group();
  group.name = 'vessel';

  const hull = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.6, 6, 10), flat(palette.hull));
  hull.rotation.x = Math.PI / 2;
  hull.name = 'hull';
  group.add(hull);

  const nose = new THREE.Mesh(new THREE.ConeGeometry(0.45, 1.2, 10), flat(palette.hullDark));
  nose.rotation.x = Math.PI / 2;
  nose.position.z = 3.6;
  nose.name = 'nose';
  group.add(nose);

  const ring = new THREE.Mesh(new THREE.TorusGeometry(1.7, 0.14, 8, 28), flat(palette.ring, { metalness: 0.4 }));
  ring.position.z = -1.2;
  ring.name = 'ring';
  group.add(ring);

  const drive = new THREE.Mesh(new THREE.ConeGeometry(0.9, 1.6, 10, 1, true), flat(palette.drive, { side: THREE.DoubleSide }));
  drive.rotation.x = Math.PI / 2;
  drive.position.z = -3.8;
  drive.name = 'drive';
  group.add(drive);

  // Exhaust plume: base flush with the bell mouth (z = -4.6), apex pointing aft.
  const glow = new THREE.Mesh(
    new THREE.ConeGeometry(0.7, 1.4, 10),
    new THREE.MeshBasicMaterial({ color: palette.driveGlow, transparent: true, opacity: 0.85 }),
  );
  glow.rotation.x = -Math.PI / 2;
  glow.position.z = -4.6 - 0.7;
  glow.name = 'driveGlow';
  group.add(glow);

  return group;
}
