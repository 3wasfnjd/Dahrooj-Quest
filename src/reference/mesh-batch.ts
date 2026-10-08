import { Group, Mesh, Matrix4 } from '@iwsdk/core';
import type { BufferGeometry, Material } from '@iwsdk/core';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
/** Bake the reference's static stitches/ribbon into one draw per material. */
export function batchReferenceMeshes(source: Group) {
    source.updateMatrixWorld(true);
    const groups = new Map<Material, BufferGeometry[]>(), inverse = new Matrix4().copy(source.matrixWorld).invert();
    source.traverse(o => { if (!(o instanceof Mesh) || Array.isArray(o.material)) return;
        const g = o.geometry.clone().applyMatrix4(new Matrix4().multiplyMatrices(inverse, o.matrixWorld));
        const list = groups.get(o.material) ?? []; list.push(g); groups.set(o.material, list);
    });
    const result = new Group();
    for (const [material, geometries] of groups) { const merged = mergeGeometries(geometries, false); if (merged) result.add(new Mesh(merged, material)); for (const g of geometries) g.dispose(); }
    return result;
}
