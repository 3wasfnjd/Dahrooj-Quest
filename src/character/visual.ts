import { Group, Mesh, MeshStandardMaterial, ShaderMaterial, SphereGeometry, TorusGeometry, Vector3 } from '@iwsdk/core';
import type { Material, BufferGeometry } from '@iwsdk/core';
import type { StyleId, AccessoryId } from '../core/config';
import type { Resources } from '../rendering/resources';
export type Expression = 'open' | 'focus' | 'wide' | 'joy' | 'closed' | 'squint' | 'laugh' | 'dizzy' | 'hurt';
const vertex = `varying vec3 n;varying vec3 v;varying vec3 p;void main(){vec4 mv=modelViewMatrix*vec4(position,1.);n=normalize(normalMatrix*normal);v=normalize(-mv.xyz);p=position;gl_Position=projectionMatrix*mv;}`;
export class CharacterFactory {
    readonly time = { value: 0 };
    readonly mats: Record<StyleId, Material>;
    private ring = new TorusGeometry(0.44, 0.018, 4, 40);
    private smile = new TorusGeometry(0.26, 0.025, 5, 16, Math.PI);
    private hatGeo = new SphereGeometry(1, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2);
    constructor(readonly r: Resources) {
        this.mats = {
            jelly: new ShaderMaterial({ vertexShader: vertex, fragmentShader: `varying vec3 n;varying vec3 v;varying vec3 p;void main(){float f=pow(1.-max(0.,dot(normalize(n),normalize(v))),3.);vec3 light=normalize(vec3(-.5,.8,.8));float spec=pow(max(0.,dot(reflect(-light,normalize(n)),normalize(v))),64.);vec3 absorbed=mix(vec3(.16,.20,.26),vec3(.55,.66,.72),smoothstep(-1.,1.,p.y));gl_FragColor=vec4(absorbed*(1.-.35*(1.-f))+vec3(.48,.57,.64)*f+spec*.7,1.);}` }),
            fabric: this.textured(0x7c2941, 'fabric'), clay: this.textured(0x825637, 'clay'), fur: this.textured(0xf1eeea, 'fur'),
            bubble: new ShaderMaterial({ transparent: true, depthWrite: false, uniforms: { t: this.time }, vertexShader: vertex, fragmentShader: `uniform float t;varying vec3 n;varying vec3 v;varying vec3 p;void main(){float f=pow(1.-abs(dot(normalize(n),normalize(v))),2.);float h=p.y*2.+sin(p.x*5.+t*.4)*.3;vec3 film=.5+.5*cos(6.283*(h+vec3(0.,.33,.67)));gl_FragColor=vec4(mix(vec3(.87,.94,1.),film,.7)+f*.35,.12+f*.65);}` }),
        };
    }
    private textured(color: number, kind: 'fabric' | 'clay' | 'fur') {
        const m = new MeshStandardMaterial({ color, roughness: kind === 'clay' ? 0.92 : 1 });
        m.onBeforeCompile = shader => {
            shader.vertexShader = 'varying vec3 dp;\n' + shader.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\ndp=position;');
            const pattern = kind === 'fabric' ? `float knit=sin(dp.y*100.)*sin(dp.x*80.+abs(sin(dp.y*50.))*1.8);diffuseColor.rgb*=.87+.13*knit;` : kind === 'clay' ? `float dent=sin(dp.x*19.+sin(dp.z*8.))*sin(dp.y*23.)*.07;diffuseColor.rgb*=.92+dent;` : `float furMask=smoothstep(.25,.5,sin(dp.x*4.+1.)*cos(dp.y*3.-.4)*sin(dp.z*4.));diffuseColor.rgb=mix(diffuseColor.rgb,vec3(.48,.28,.13),furMask);diffuseColor.rgb*=.93+.07*sin(dp.x*120.)*sin(dp.y*160.);`;
            shader.fragmentShader = 'varying vec3 dp;\n' + shader.fragmentShader.replace('#include <color_fragment>', '#include <color_fragment>\n' + pattern);
        };
        m.customProgramCacheKey = () => kind;
        return m;
    }
    create() { return new CharacterVisual(this); }
    accessory(id: AccessoryId, parent: Group) {
        const r = this.r, add = (geo: BufferGeometry, col: number, x: number, y: number, z: number, sx: number, sy = sx, sz = sx) => r.mesh(geo, col, x, y, z, sx, sy, sz, parent);
        if (id === 'party') {
            add(r.cone, 0xe2603f, 0, 1.28, 0, 0.32, 0.75);
            add(r.lowSphere, 0xf2c14e, 0, 1.68, 0, 0.09);
        }
        if (id === 'glasses') {
            for (const x of [-0.3, 0.3])
                add(r.lowSphere, 0x161c2e, x, 0.18, 0.99, 0.27, 0.19, 0.05);
            add(r.box, 0x2c2d3d, 0, 0.18, 1.02, 0.28, 0.04, 0.04);
        }
        if (id === 'cap') {
            add(this.hatGeo, 0xc8442f, 0, 0.42, 0, 0.9, 0.65, 0.9);
            add(r.lowSphere, 0xc8442f, 0, 0.54, 0.65, 0.72, 0.08, 0.68);
        }
        if (id === 'flower') {
            for (let i = 0; i < 5; i++)
                add(r.lowSphere, 0xff7f9a, 0.5 + Math.sin(i * 1.257) * 0.15, 0.83 + Math.cos(i * 1.257) * 0.15, 0.55, 0.14, 0.14, 0.07);
            add(r.lowSphere, 0xf2c14e, 0.5, 0.83, 0.63, 0.09);
        }
        if (id === 'crown') {
            add(r.cylinder, 0xe5ad2e, 0, 0.96, 0, 0.44, 0.18, 0.44);
            for (let i = 0; i < 5; i++)
                add(r.cone, 0xf2c14e, Math.sin(i * 1.257) * 0.36, 1.19, Math.cos(i * 1.257) * 0.36, 0.12, 0.35, 0.12);
        }
    }
    makeSmile() { const m = new Mesh(this.smile, this.r.mat(0x252335)); m.rotation.z = Math.PI; m.position.set(0, -0.19, 0.96); return m; }
    makeSeam() { const m = new Mesh(this.ring, this.r.mat(0xe5c5c5)); m.scale.setScalar(2.27); m.rotation.set(0.4, 0.7, 0.2); return m; }
}
export class CharacterVisual {
    readonly root = new Group();
    readonly deform = new Group();
    private body: Mesh;
    private face = new Group();
    private eyes: Mesh[] = [];
    private pupils: Mesh[] = [];
    private mouth: Mesh;
    private seam: Mesh;
    private bow = new Group();
    private accessory = new Group();
    style: StyleId = 'fabric';
    expression: Expression = 'open';
    private accessoryId: AccessoryId = '';
    private sq = 0;
    constructor(readonly factory: CharacterFactory) {
        const r = factory.r;
        this.root.add(this.deform);
        this.deform.add(this.face, this.bow, this.accessory);
        this.body = new Mesh(r.sphere, factory.mats.fabric);
        this.deform.add(this.body);
        for (const x of [-0.31, 0.31]) {
            const e = r.mesh(r.lowSphere, 0xfffaf2, x, 0.19, 0.88, 0.23, 0.26, 0.12, this.face);
            this.eyes.push(e);
            const p = r.mesh(r.lowSphere, 0x222238, x, 0.19, 0.99, 0.12, 0.14, 0.065, this.face);
            this.pupils.push(p);
        }
        this.mouth = factory.makeSmile();
        this.face.add(this.mouth);
        this.seam = factory.makeSeam();
        this.deform.add(this.seam);
        for (const x of [-0.57, 0.57])
            r.mesh(r.lowSphere, 0xd99095, x, -0.14, 0.79, 0.15, 0.07, 0.035, this.face);
        for (const x of [-0.19, 0.19]) {
            const b = r.mesh(r.lowSphere, 0xd8452f, x - 0.08, 0.98, 0.35, 0.22, 0.16, 0.12, this.bow);
            b.rotation.z = x;
        }
        r.mesh(r.lowSphere, 0xaf3027, -0.08, 0.98, 0.4, 0.08, 0.09, 0.1, this.bow);
        this.setStyle('fabric');
    }
    setStyle(style: StyleId) { this.style = style; this.body.material = this.factory.mats[style]; this.seam.visible = style === 'fabric'; this.bow.visible = style === 'fur'; }
    wear(id: AccessoryId) { if (id === this.accessoryId)
        return; this.accessoryId = id; this.accessory.clear(); this.factory.accessory(id, this.accessory); }
    eyeless(on: boolean) { this.face.visible = !on; this.accessory.visible = !on; }
    impact(power: number) { this.sq = Math.min(0.35, this.sq + power * 0.23); this.expression = power > 0.7 ? 'hurt' : 'wide'; }
    update(dt: number, t: number, look: Vector3) {
        this.sq *= Math.exp(-dt * 9);
        const wob = (this.style === 'jelly' ? 0.024 : 0.01) * Math.sin(t * 6);
        this.deform.scale.set(1 + this.sq * 0.6 + wob, 1 - this.sq - wob, 1 + this.sq * 0.4);
        const blink = t % 3.7 > 3.57, closed = blink || (this.expression === 'closed' || this.expression === 'laugh' || this.expression === 'joy'), squeeze = this.expression === 'focus' || this.expression === 'squint' || this.expression === 'hurt';
        for (let i = 0; i < 2; i++) {
            this.eyes[i].scale.y = closed ? 0.035 : squeeze ? 0.13 : this.expression === 'wide' ? 0.3 : 0.26;
            this.pupils[i].visible = !closed;
            this.pupils[i].position.x = (i ? 0.31 : -0.31) + Math.max(-0.05, Math.min(0.05, look.x * 0.015));
            this.pupils[i].position.y = 0.19 + Math.max(-0.05, Math.min(0.05, look.y * 0.015));
            this.pupils[i].rotation.z = this.expression === 'dizzy' ? t * 7 : 0;
        }
        this.mouth.scale.y = this.expression === 'laugh' ? 1.8 : this.expression === 'hurt' ? -0.6 : 1;
    }
}
