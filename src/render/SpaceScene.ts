import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { palette } from './palette';
import { makeVessel } from './primitives';
import { makeStarField } from './StarField';

/** Phase 0 placeholder: a Vessel in a star field with an orbit camera. Reads no sim state yet. */
export class SpaceScene {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.PerspectiveCamera;
  private readonly controls: OrbitControls;
  private readonly vessel: THREE.Group;
  private readonly onResize = (): void => this.resize();

  constructor(private readonly canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.scene.background = new THREE.Color(palette.space);

    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 5000);
    this.camera.position.set(9, 4, 12);

    this.controls = new OrbitControls(this.camera, canvas);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;
    this.controls.enablePan = false;
    this.controls.minDistance = 4;
    this.controls.maxDistance = 80;

    const sun = new THREE.DirectionalLight(palette.sun, 3);
    sun.position.set(20, 12, 8);
    this.scene.add(sun);
    this.scene.add(new THREE.HemisphereLight(palette.sky, palette.ground, 0.8));

    this.vessel = makeVessel();
    this.scene.add(this.vessel);
    this.scene.add(makeStarField());

    window.addEventListener('resize', this.onResize);
    this.resize();
  }

  resize(): void {
    const width = window.innerWidth;
    const height = window.innerHeight;
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
  }

  update(dt: number): void {
    this.vessel.rotation.z += dt * 0.15;
    this.controls.update();
  }

  render(): void {
    this.renderer.render(this.scene, this.camera);
  }

  dispose(): void {
    window.removeEventListener('resize', this.onResize);
    this.controls.dispose();
    this.renderer.dispose();
    void this.canvas;
  }
}
