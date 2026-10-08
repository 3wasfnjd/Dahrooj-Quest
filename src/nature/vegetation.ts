import { BufferGeometry, Float32BufferAttribute, InstancedMesh, Matrix4, Quaternion, Vector3, MeshStandardMaterial } from '@iwsdk/core';
import { seeded } from '../core/config';
import type { GameContext } from '../core/context';
import type { ModeScope } from '../modes/scope';
export class Vegetation {
    readonly patches: InstancedMesh[] = [];
    readonly time = { value: 0 };
    private p = new Vector3();
    constructor(readonly c: GameContext, scope: ModeScope) {
        const random = seeded(51), geometry = new BufferGeometry();
        const vertices: number[] = [];
        // Eight crossed triangular leaves per patch, never an entity per blade.
        for (let i = 0; i < 8; i++) {
            const x = (random() - 0.5) * 0.8, z = (random() - 0.5) * 0.8, h = 0.1 + random() * 0.18;
            vertices.push(x - 0.025, 0, z, x + 0.02, h, z + 0.02, x + 0.025, 0, z);
        }
        geometry.setAttribute('position', new Float32BufferAttribute(vertices, 3));
        geometry.computeVertexNormals();
        scope.geometry.push(geometry);
        const mat = new MeshStandardMaterial({ color: 0x6e9157, roughness: 1, side: 2 });
        mat.onBeforeCompile = s => { s.uniforms.windTime = this.time; s.vertexShader = 'uniform float windTime;\n' + s.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\ntransformed.x+=sin(windTime*1.6+instanceMatrix[3].x*.8+position.y*4.)*position.y*.14;'); };
        scope.materials.push(mat);
        const matrix = new Matrix4(), q = new Quaternion(), size = new Vector3();
        for (let quadrant = 0; quadrant < 4; quadrant++) {
            const mesh = scope.add(new InstancedMesh(geometry, mat, 220));
            const sx = quadrant % 2 ? 1 : -1, sz = quadrant > 1 ? 1 : -1;
            for (let i = 0; i < 220; i++) {
                const x = sx * (4.3 + random() * 9), z = sz * random() * 16 - 5;
                this.p.set(x, -0.02, z);
                q.setFromAxisAngle(size.set(0, 1, 0), random() * Math.PI * 2);
                size.setScalar(0.7 + random() * 0.5);
                matrix.compose(this.p, q, size);
                mesh.setMatrixAt(i, matrix);
            }
            mesh.computeBoundingSphere();
            this.patches.push(mesh);
        }
        for (const [count, color, radius, height] of [[90, 0xa79378, 0.07, 0.02], [70, 0xe6b279, 0.035, 0.09], [70, 0xb477a6, 0.04, 0.12], [40, 0x52785b, 0.27, 0.18]]) {
            const mesh = scope.add(new InstancedMesh(c.resources.lowSphere, c.resources.mat(color), count));
            for (let i = 0; i < count; i++) {
                const x = (random() < 0.5 ? -1 : 1) * (4.2 + random() * 7);
                this.p.set(x, height, -random() * 17 + 3);
                size.set(radius, radius * 0.65, radius);
                matrix.compose(this.p, q.identity(), size);
                mesh.setMatrixAt(i, matrix);
            }
            mesh.computeBoundingSphere();
        }
    }
    update(time: number) { this.time.value = time; for (const p of this.patches) {
        this.p.copy(p.boundingSphere!.center).applyMatrix4(p.matrixWorld);
        const distance = this.p.distanceToSquared(this.c.input.head);
        p.visible = distance < 35 ** 2;
        p.count = Math.floor((distance > 22 ** 2 ? 55 : distance > 14 ** 2 ? 110 : 220) * this.c.quality.decorFactor);
    } }
}
