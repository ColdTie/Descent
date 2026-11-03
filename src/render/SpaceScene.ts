import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { palette } from './palette';
import { makeVessel } from './primitives';
import { makeStarField } from './StarField';
import { transitSummary } from '../sim/ledger';
import { focusedVessel, starById, type GalaxyState } from '../sim/state';
import { BODY_COLORS, spectralColor } from './palette';
import type { ViewScene } from './ViewScene';

/** The Vessel in space: transit, arrival and orbit. Reads sim state; never writes it. */
export class SpaceScene implements ViewScene {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.PerspectiveCamera;
  private readonly controls: OrbitControls;
  private readonly vessel: THREE.Group;
  private readonly plume: THREE.Object3D | undefined;
  private readonly target: THREE.Mesh;
  private readonly origin: THREE.Mesh;
  private readonly track: THREE.Line;
  private systemGroup: THREE.Group | null = null;
  private systemKey = '';
  private readonly onResize = (): void => this.resize();

  constructor(canvas: HTMLCanvasElement, renderer: THREE.WebGLRenderer) {
    this.renderer = renderer;
    this.scene.background = new THREE.Color(palette.space);

    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 5000);
    // Three-quarter view from aft, looking a little ahead so the plume and the destination are both in frame.
    this.camera.position.set(10, 5, -11);

    this.controls = new OrbitControls(this.camera, canvas);
    this.controls.target.set(0, 0, 3);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;
    this.controls.enablePan = false;
    this.controls.minDistance = 11;
    this.controls.maxDistance = 80;

    const sun = new THREE.DirectionalLight(palette.sun, 3);
    sun.position.set(20, 12, 8);
    this.scene.add(sun);
    this.scene.add(new THREE.HemisphereLight(palette.sky, palette.ground, 0.8));

    this.vessel = makeVessel();
    this.plume = this.vessel.getObjectByName('driveGlow');
    this.scene.add(this.vessel);
    this.scene.add(makeStarField());

    // Destination ahead (+Z) and the star left behind (-Z); sync() slides them with transit progress.
    this.target = new THREE.Mesh(new THREE.OctahedronGeometry(0.9), new THREE.MeshBasicMaterial({ color: palette.star }));
    this.target.name = 'target';
    this.origin = new THREE.Mesh(new THREE.OctahedronGeometry(0.5), new THREE.MeshBasicMaterial({ color: palette.star, transparent: true, opacity: 0.6 }));
    this.origin.name = 'origin';
    this.track = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, 0, 4.5), new THREE.Vector3(0, 0, 60)]),
      new THREE.LineDashedMaterial({ color: palette.ring, dashSize: 0.8, gapSize: 0.8, transparent: true, opacity: 0.45 }),
    );
    this.track.computeLineDistances();
    this.track.name = 'track';
    this.scene.add(this.target, this.origin, this.track);
    this.target.visible = this.origin.visible = this.track.visible = false;

    window.addEventListener('resize', this.onResize);
    this.resize();
  }

  /** The renderer belongs to the SceneHost; the scene only frees its own objects. */

  resize(): void {
    const width = window.innerWidth;
    const height = window.innerHeight;
    // Browser zoom and moving between displays change the DPR along with the size.
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
  }

  /** Reads the focused Vessel's transit from the ledger. Views never write state. */
  sync(state: GalaxyState): void {
    const v = focusedVessel(state);
    const s = transitSummary(state, v);
    const inTransit = v.phase === 'transit' && s !== null && v.transit !== null;
    // The drive glows only while it is burning.
    if (this.plume) this.plume.visible = inTransit && s.burn !== 'coast';
    this.vessel.visible = v.phase !== 'lost';
    this.target.visible = inTransit || v.phase === 'arrival';
    this.origin.visible = this.track.visible = inTransit;
    this.syncSystem(state, v.phase === 'arrival' || v.phase === 'planetside' ? v.starId : null, v.worldId === null ? null : (state.worlds[v.worldId]?.bodyId ?? null));
    if (!inTransit) {
      this.target.visible = false;
      return;
    }
    const far = 60;
    const near = 10;
    this.target.position.set(0, 0, near + (far - near) * (1 - s.progress));
    // The star left behind sits well behind the camera; orbit around to see it recede.
    this.origin.position.set(0, 0, -(40 + 40 * s.progress));
    const to = starById(state, v.transit!.toStarId);
    const from = starById(state, v.transit!.fromStarId);
    (this.target.material as THREE.MeshBasicMaterial).color.set(spectralColor(to?.spectral ?? 'G'));
    (this.origin.material as THREE.MeshBasicMaterial).color.set(spectralColor(from?.spectral ?? 'G'));
    const positions = this.track.geometry.getAttribute('position') as THREE.BufferAttribute;
    positions.setZ(1, this.target.position.z - 1.2);
    positions.needsUpdate = true;
    this.track.computeLineDistances();
    const pulse = 1 + 0.08 * Math.sin(performance.now() / 400);
    this.target.scale.setScalar(pulse);
  }

  /** Star and bodies ahead of the Vessel while it is in a system; rebuilt only when what they show changes. */
  private syncSystem(state: GalaxyState, starId: number | null, landedBodyId: number | null): void {
    const system = starId === null ? undefined : state.starSystems[starId];
    const key = system ? `${starId}:${system.bodies.map((b) => (b.surveyed ? 1 : 0)).join('')}:${landedBodyId ?? '-'}` : '';
    if (key === this.systemKey) return;
    this.systemKey = key;
    if (this.systemGroup) {
      this.scene.remove(this.systemGroup);
      this.systemGroup.traverse((o) => {
        const m = o as THREE.Mesh;
        m.geometry?.dispose();
        (m.material as THREE.Material | undefined)?.dispose();
      });
      this.systemGroup = null;
    }
    if (!system || starId === null) return;
    const group = new THREE.Group();
    group.name = 'system';
    const star = starById(state, starId);
    const sun = new THREE.Mesh(new THREE.IcosahedronGeometry(3, 1), new THREE.MeshBasicMaterial({ color: spectralColor(star?.spectral ?? 'G') }));
    sun.position.set(-34, 12, 80);
    group.add(sun);
    const n = system.bodies.length;
    system.bodies.forEach((b, i) => {
      // Unsurveyed bodies share one size so the scene does not give their kind away.
      const size = !b.surveyed ? 0.9 : b.kind === 'gasGiant' ? 1.6 : b.kind === 'icy' ? 0.8 : 0.7;
      const color = b.surveyed ? BODY_COLORS[b.kind] : 0x3a4157;
      const mesh = new THREE.Mesh(new THREE.IcosahedronGeometry(size, 1), new THREE.MeshStandardMaterial({ color, flatShading: true, roughness: 0.9 }));
      const along = n > 1 ? i / (n - 1) : 0.5;
      // Spread across the open sky left of the Vessel, nearest orbit closest to the star.
      mesh.position.set(-22 + along * 18, 5 - along * 6 + Math.sin(i * 1.7), 40 - along * 16);
      mesh.name = `body-${b.id}`;
      group.add(mesh);
      if (b.id === landedBodyId) {
        const ring = new THREE.Mesh(new THREE.TorusGeometry(size + 0.6, 0.06, 6, 32), new THREE.MeshBasicMaterial({ color: palette.driveGlow }));
        ring.position.copy(mesh.position);
        ring.lookAt(this.camera.position);
        group.add(ring);
      }
    });
    this.scene.add(group);
    this.systemGroup = group;
  }

  update(dt: number): void {
    this.vessel.rotation.z += dt * 0.15;
    this.target.rotation.y += dt * 0.6;
    this.controls.update();
  }

  render(): void {
    this.renderer.render(this.scene, this.camera);
  }

  dispose(): void {
    window.removeEventListener('resize', this.onResize);
    this.controls.dispose();
    this.scene.traverse((o) => {
      const m = o as THREE.Mesh;
      m.geometry?.dispose();
      const mat = m.material as THREE.Material | THREE.Material[] | undefined;
      if (Array.isArray(mat)) mat.forEach((x) => x.dispose());
      else mat?.dispose();
    });
  }
}
