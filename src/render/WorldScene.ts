import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import type { BodyKind } from '../content/bodies';
import { BUILDING_DEFS, type BuildingType, type RobotType } from '../content/colony';
import { colonyTerrain } from '../sim/colony/colony';
import { cellX, cellY, type Terrain } from '../sim/colony/terrain';
import type { Colony, Robot } from '../sim/colony/types';
import type { GalaxyState } from '../sim/state';
import { palette } from './palette';
import { makeVessel } from './primitives';
import type { ViewScene } from './ViewScene';

const HEIGHT = 7;

/** Ground colours by body kind: low, mid and high ground. */
const GROUND: Record<BodyKind, [number, number, number]> = {
  molten: [0x3a1a12, 0x6b2e1a, 0x9a4a2a],
  rocky: [0x3b3a33, 0x6a6150, 0x9a8f78],
  icy: [0x5f7487, 0x9db4c6, 0xdbe7ef],
  gasGiant: [0x444444, 0x666666, 0x888888],
};
const SKY: Record<BodyKind, number> = { molten: 0x1a0c0a, rocky: 0x0e1018, icy: 0x0d1522, gasGiant: 0x0a0a0a };

const BUILDING_COLORS: Record<BuildingType, number> = {
  solar: 0x3b6fd1,
  oreMiner: 0xc47a2a,
  iceMiner: 0x7fc4dc,
  refinery: 0x9aa7b8,
  cracker: 0x6fb38a,
  fabricator: 0xc8a24a,
  depot: 0x6b6f7c,
  shipyard: 0xd6d6d6,
};
const BUILDING_SIZE: Record<BuildingType, [number, number, number]> = {
  solar: [1.6, 0.25, 1.2],
  oreMiner: [0.9, 1.4, 0.9],
  iceMiner: [0.9, 1.4, 0.9],
  refinery: [1.4, 1.2, 1.4],
  cracker: [1.2, 1.3, 1.2],
  fabricator: [1.6, 1.4, 1.6],
  depot: [1.3, 0.8, 1.3],
  shipyard: [3, 2, 3],
};
const ROBOT_COLORS: Record<RobotType, number> = { surveyor: 0x4fd1ff, builder: 0xffb84d, hauler: 0x9cdb6a };

/** The landed Vessel's world: terrain, nodes, buildings and robots, with an RTS camera. */
export class WorldScene implements ViewScene {
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.PerspectiveCamera;
  private readonly controls: OrbitControls;
  private readonly terrain: Terrain;
  private readonly ground: THREE.Mesh;
  private readonly nodeMeshes = new Map<number, THREE.Mesh>();
  private readonly buildingMeshes = new Map<number, THREE.Mesh>();
  private readonly robotMeshes = new Map<number, THREE.Mesh>();
  private revealedKey = -1;
  private readonly onResize = (): void => this.resize();
  private readonly half: number;

  constructor(
    canvas: HTMLCanvasElement,
    private readonly renderer: THREE.WebGLRenderer,
    readonly worldId: number,
    colony: Colony,
    private readonly kind: BodyKind,
  ) {
    this.terrain = colonyTerrain(colony);
    this.half = (this.terrain.size - 1) / 2;
    this.scene.background = new THREE.Color(SKY[kind]);
    this.camera = new THREE.PerspectiveCamera(45, 1, 0.1, 400);
    this.camera.position.set(14, 22, 26);
    this.controls = new OrbitControls(this.camera, canvas);
    this.controls.target.set(0, HEIGHT * 0.4, 0);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.1;
    this.controls.screenSpacePanning = false;
    this.controls.minDistance = 8;
    this.controls.maxDistance = 70;
    this.controls.maxPolarAngle = 1.35;
    // RTS feel: left drag orbits, right drag pans across the ground, wheel zooms.
    this.controls.mouseButtons = { LEFT: THREE.MOUSE.ROTATE, MIDDLE: THREE.MOUSE.DOLLY, RIGHT: THREE.MOUSE.PAN };

    const sun = new THREE.DirectionalLight(palette.sun, 2.6);
    sun.position.set(-20, 30, 10);
    this.scene.add(sun, new THREE.HemisphereLight(palette.sky, palette.ground, 0.9));

    this.ground = this.makeGround();
    this.scene.add(this.ground);

    const lander = makeVessel();
    lander.rotation.x = -Math.PI / 2;
    lander.scale.setScalar(0.32);
    lander.position.set(0, this.heightAt(Math.floor(this.terrain.size / 2), Math.floor(this.terrain.size / 2)) + 1.4, 0);
    const plume = lander.getObjectByName('driveGlow');
    if (plume) plume.visible = false;
    this.scene.add(lander);

    window.addEventListener('resize', this.onResize);
    this.resize();
    this.sync(undefined, colony);
  }

  private heightAt(x: number, y: number): number {
    const i = Math.max(0, Math.min(this.terrain.size - 1, y)) * this.terrain.size + Math.max(0, Math.min(this.terrain.size - 1, x));
    return this.terrain.height[i]! * HEIGHT;
  }

  private cellPos(cell: number, out = new THREE.Vector3()): THREE.Vector3 {
    const x = cellX(this.terrain.size, cell);
    const y = cellY(this.terrain.size, cell);
    return out.set(x - this.half, this.heightAt(x, y), y - this.half);
  }

  private makeGround(): THREE.Mesh {
    const n = this.terrain.size;
    const geo = new THREE.PlaneGeometry(n - 1, n - 1, n - 1, n - 1);
    geo.rotateX(-Math.PI / 2);
    const pos = geo.getAttribute('position') as THREE.BufferAttribute;
    for (let i = 0; i < pos.count; i++) pos.setY(i, this.terrain.height[i]! * HEIGHT);
    const flat = geo.toNonIndexed();
    geo.dispose();
    flat.computeVertexNormals();
    flat.setAttribute('color', new THREE.BufferAttribute(new Float32Array(flat.getAttribute('position').count * 3), 3));
    // Lambert: the ground fills the screen, and per-pixel PBR shading costs a lot on weak GPUs for no visible gain on matte rock.
    const mesh = new THREE.Mesh(flat, new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true }));
    mesh.name = 'ground';
    return mesh;
  }

  /** Recolours the ground by height; unsurveyed ground is drawn dark. */
  private paintGround(c: Colony): void {
    const geo = this.ground.geometry;
    const pos = geo.getAttribute('position') as THREE.BufferAttribute;
    const col = geo.getAttribute('color') as THREE.BufferAttribute;
    const [lo, mid, hi] = GROUND[this.kind].map((h) => new THREE.Color(h));
    const tmp = new THREE.Color();
    const n = this.terrain.size;
    for (let tri = 0; tri < pos.count; tri += 3) {
      let hy = 0;
      let cx = 0;
      let cz = 0;
      for (let k = 0; k < 3; k++) {
        hy += pos.getY(tri + k) / HEIGHT;
        cx += pos.getX(tri + k);
        cz += pos.getZ(tri + k);
      }
      hy /= 3;
      const gx = Math.round(cx / 3 + this.half);
      const gy = Math.round(cz / 3 + this.half);
      const cell = Math.max(0, Math.min(n - 1, gy)) * n + Math.max(0, Math.min(n - 1, gx));
      if (hy < 0.4) tmp.copy(lo!).lerp(mid!, hy / 0.4);
      else tmp.copy(mid!).lerp(hi!, Math.min(1, (hy - 0.4) / 0.4));
      if (this.terrain.blocked[cell]) tmp.multiplyScalar(1.15);
      if (!c.revealed[cell]) tmp.multiplyScalar(0.28);
      for (let k = 0; k < 3; k++) col.setXYZ(tri + k, tmp.r, tmp.g, tmp.b);
    }
    col.needsUpdate = true;
  }

  sync(state: GalaxyState | undefined, colonyOverride?: Colony): void {
    const c = colonyOverride ?? state?.worlds[this.worldId]?.colony;
    if (!c) return;
    const revealed = c.revealed.reduce((a, b) => a + b, 0);
    if (revealed !== this.revealedKey) {
      this.revealedKey = revealed;
      this.paintGround(c);
    }
    for (const n of c.nodes) {
      let m = this.nodeMeshes.get(n.id);
      if (!m) {
        m = new THREE.Mesh(new THREE.ConeGeometry(0.45, 0.9, 5), new THREE.MeshStandardMaterial({ color: n.kind === 'ore' ? 0xd98a3a : 0xbfe6f5, flatShading: true }));
        this.cellPos(n.cell, m.position).y += 0.45;
        this.scene.add(m);
        this.nodeMeshes.set(n.id, m);
      }
      m.visible = n.revealed;
    }
    const live = new Set<number>();
    for (const b of c.buildings) {
      if (b.cell < 0) continue;
      live.add(b.id);
      let m = this.buildingMeshes.get(b.id);
      const [sx, sy, sz] = BUILDING_SIZE[b.type];
      if (!m) {
        m = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), new THREE.MeshStandardMaterial({ color: BUILDING_COLORS[b.type], flatShading: true, transparent: true }));
        m.name = `building-${b.id}`;
        this.scene.add(m);
        this.buildingMeshes.set(b.id, m);
      }
      const mat = m.material as THREE.MeshStandardMaterial;
      const done = b.progress >= 1;
      const grow = done ? 1 : Math.max(0.08, b.progress);
      m.scale.set(1, grow, 1);
      this.cellPos(b.cell, m.position).y += (sy * grow) / 2 + (BUILDING_DEFS[b.type].node ? 0.3 : 0);
      mat.opacity = done ? 1 : b.paid ? 0.55 : 0.25;
      mat.emissive.setHex(done && b.working ? 0x222211 : 0x000000);
    }
    for (const [id, m] of this.buildingMeshes) {
      if (live.has(id)) continue;
      this.scene.remove(m);
      m.geometry.dispose();
      (m.material as THREE.Material).dispose();
      this.buildingMeshes.delete(id);
    }
    for (const r of c.robots) {
      let m = this.robotMeshes.get(r.id);
      if (!m) {
        m = new THREE.Mesh(new THREE.CapsuleGeometry(0.22, 0.45, 3, 8), new THREE.MeshStandardMaterial({ color: ROBOT_COLORS[r.type], flatShading: true }));
        m.name = `robot-${r.id}`;
        this.scene.add(m);
        this.robotMeshes.set(r.id, m);
      }
      this.placeRobot(r, m);
    }
  }

  private readonly a = new THREE.Vector3();
  private readonly b = new THREE.Vector3();

  private placeRobot(r: Robot, m: THREE.Mesh): void {
    this.cellPos(r.cell, this.a);
    if (r.path.length && r.edge > 0) {
      this.cellPos(r.path[0]!, this.b);
      this.a.lerp(this.b, r.edge);
    }
    // Several robots on one cell would overlap; fan them out a little by id.
    const ang = r.id * 2.39996;
    m.position.set(this.a.x + Math.cos(ang) * 0.25, this.a.y + 0.45, this.a.z + Math.sin(ang) * 0.25);
  }

  update(): void {
    this.controls.update();
    // Keep the camera over the map.
    const t = this.controls.target;
    const lim = this.half;
    t.x = Math.max(-lim, Math.min(lim, t.x));
    t.z = Math.max(-lim, Math.min(lim, t.z));
  }

  render(): void {
    this.renderer.render(this.scene, this.camera);
  }

  resize(): void {
    const width = window.innerWidth;
    const height = window.innerHeight;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
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
