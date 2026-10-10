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
    for (const [material, geometries] of groups) {
        // Extruded stars are non-indexed; their indexed temple arms share the same material.
        // Preserve indexing for uniform groups, and normalize mixed groups before merging.
        const mixed=geometries.some(g=>g.index)&&geometries.some(g=>!g.index);
        const compatible=mixed?geometries.map(g=>g.index?g.toNonIndexed():g):geometries;
        const merged=mergeGeometries(compatible,false);
        if(merged)result.add(new Mesh(merged,material));
        for(const g of new Set([...geometries,...compatible]))g.dispose();
    }
    return result;
}
