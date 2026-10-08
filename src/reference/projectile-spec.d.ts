import type { Vector3 } from '@iwsdk/core';
import type { ShotId } from '../core/config';
export const SHOT_STYLE:Record<ShotId,{speed:number;grav:number;life:number;r:number;cool:number;burst?:number}>;
export const FIRE_COLS:number[];
export interface ReferenceShot {kind:ShotId;p:Vector3;v:Vector3;wob:number;r:number;}
export function advanceShot(s:ReferenceShot,dt:number,scale:number):void;
export function groundMini(s:ReferenceShot,dt:number,floor:number,scale:number):void;
