import { BoxGeometry, SphereGeometry, CylinderGeometry, ConeGeometry, MeshStandardMaterial, MeshBasicMaterial, Mesh, Group, Color, BufferGeometry, Material, Vector3, PointsMaterial } from '@iwsdk/core';
export class Resources {
    readonly starMaterial = new PointsMaterial({ color: 0xe9e4d7, size: 0.045 });
    readonly hiddenMaterial = new MeshBasicMaterial({ visible: false });
    box = new BoxGeometry(1, 1, 1);
    sphere = new SphereGeometry(1, 24, 16);
    lowSphere = new SphereGeometry(1, 12, 8);
    cylinder = new CylinderGeometry(1, 1, 1, 16);
    cone = new ConeGeometry(1, 1, 12);
    private materials = new Map<string, MeshStandardMaterial | MeshBasicMaterial>();
    mat(color: number, basic = false) { const key = color + '/' + basic; let m = this.materials.get(key); if (!m) {
        m = basic ? new MeshBasicMaterial({ color }) : new MeshStandardMaterial({ color, roughness: 0.8 });
        this.materials.set(key, m);
    } return m; }
    mesh(geo: BufferGeometry, color: number, x: number, y: number, z: number, sx = 1, sy = sx, sz = sx, parent?: Group) { const m = new Mesh(geo, this.mat(color)); m.position.set(x, y, z); m.scale.set(sx, sy, sz); parent?.add(m); return m; }
    dispose() { for (const g of [this.box, this.sphere, this.lowSphere, this.cylinder, this.cone])
        g.dispose(); for (const m of this.materials.values())
        m.dispose(); }
}
export function recolor(mesh: Mesh, color: number) { const m = mesh.material as Material & {
    color?: Color;
}; m.color?.setHex(color); }
export const UP = new Vector3(0, 1, 0);
