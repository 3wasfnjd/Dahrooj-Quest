import * as T from '@iwsdk/core';
import type { StyleId, AccessoryId } from '../core/config';
import type { Resources } from '../rendering/resources';
import { createReferenceCharacter } from '../reference/character.js';
import type { ReferenceModel } from '../reference/character.js';
import { drawReferenceFace } from '../reference/face.js';
export type Expression = 'open' | 'focus' | 'wide' | 'joy' | 'closed' | 'squint' | 'laugh' | 'dizzy' | 'hurt';
export class CharacterFactory {
    readonly reference;
    readonly time;
    readonly mats;
    constructor(readonly r: Resources, renderer?: T.WebGLRenderer) {
        this.reference = createReferenceCharacter(T, {radius: 1, drawFace: drawReferenceFace, renderer});
        this.time = this.reference.time; this.mats = this.reference.mats;
    }
    create() { return new CharacterVisual(this); }
}
export class CharacterVisual {
    readonly root = new T.Group();
    readonly deform = new T.Group();
    style: StyleId = 'fabric';
    expression: Expression = 'open';
    private models = new Map<string, ReferenceModel>();
    private model!: ReferenceModel;
    private accessory: AccessoryId = '';
    private noEyes = false;
    private sq = 0;
    private options = {pos: new T.Vector3(), faceName: 'open', look: [0,0], blink: false, squash: [1,1]};
    constructor(readonly factory: CharacterFactory) { this.root.add(this.deform); this.setStyle('fabric'); }
    setStyle(style: StyleId) {
        this.style = style;
        const key = style + (this.noEyes ? '-mini' : '');
        let model = this.models.get(key);
        if (!model) { model = this.factory.reference.make(style,{face: !this.noEyes}); this.models.set(key, model); this.deform.add(model.group); }
        if (this.model) this.model.group.visible = false;
        this.model = model; model.group.visible = true; model.setAccessory(this.noEyes ? '' : this.accessory);
    }
    wear(id: AccessoryId) { this.accessory = id; this.model.setAccessory(this.noEyes ? '' : id === 'party' ? 'party' : id); }
    eyeless(on: boolean) { if (on === this.noEyes) return; this.noEyes = on; this.setStyle(this.style); }
    impact(power: number) { this.sq = Math.min(.35, this.sq + power * .23); this.expression = power > .7 ? 'hurt' : 'wide'; }
    update(dt: number, t: number, look: T.Vector3) {
        this.sq *= Math.exp(-dt*9);
        const wob = (this.style === 'jelly' ? .024 : .01)*Math.sin(t*6), o = this.options;
        o.squash[0] = 1 + this.sq*.6+wob; o.squash[1] = 1-this.sq-wob;
        o.faceName = this.expression; o.look[0] = T.MathUtils.clamp(look.x*.15,-1,1); o.look[1] = T.MathUtils.clamp(-look.y*.15,-1,1);
        o.blink = t%3.7>3.57; this.model.update(o);
    }
}
