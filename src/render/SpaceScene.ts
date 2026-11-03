import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { palette } from './palette';
import { makeVessel } from './primitives';
import { makeStarField } from './StarField';
import { transitSummary } from '../sim/ledger';
import { focusedVessel, starById, type GalaxyState } from '../sim/state';
import { spectralColor } from './palette';

/** Phase 0 placeholder: a Vessel in a star field with an orbit camera. Reads no sim state yet. */
export class SpaceScene {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.PerspectiveCamera;
  private readonly controls: OrbitControls;
  private readonly vessel: THREE.Group;
  private readonly plume: THREE.Object3D | undefined;
  private readonly target: THREE.Mesh;
  private readonly origin: THREE.Mesh;
  private readonly track: THREE.Line;
  private readonly onResize = (): void => this.resize();

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
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
    if (!inTransit) {
      const here = v.starId === null ? undefined : starById(state, v.starId);
      this.target.position.set(0, 0, 10);
      (this.target.material as THREE.MeshBasicMaterial).color.set(spectralColor(here?.spectral ?? 'G'));
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
    this.renderer.dispose();
  }
}
