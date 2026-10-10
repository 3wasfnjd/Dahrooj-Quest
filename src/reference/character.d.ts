import type * as T from '@iwsdk/core';
import type { StyleId } from '../core/config';
export interface ReferenceModel {
    group: T.Group; style: StyleId; dispose():void; setAccessory(id: string): void;
    update(options: {pos:T.Vector3; toward?:T.Vector3; faceName?:string; look?:number[]; blink?:boolean; squash?:number[]}):void;
}
export interface ReferenceFactory {
    crowd(max:number,withAccessories?:boolean):ReferenceCrowd;
    make(style:StyleId, options?:{face?:boolean;lite?:boolean}):ReferenceModel;
    setJellyColor(id:string):void;
    mats: Record<StyleId,T.Material> & {jelly:T.ShaderMaterial}; time:{value:number}; forget(group:T.Group):void;
    updateProbe(...args:unknown[]):void;
}
export function createReferenceCharacter(three:typeof T, options:{radius:number;drawFace:typeof import("./face.js").drawReferenceFace;renderer?:T.WebGLRenderer}):ReferenceFactory;
export interface ReferenceCrowd {group:T.Group;count:number;begin():void;end():void;add(style:StyleId,pos:T.Vector3,radius:number,toward:T.Vector3|null,squash:number[],eyes:string|null,accessoryId?:string,color?:number):void;}
