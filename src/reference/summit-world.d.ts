import type * as T from '@iwsdk/core';
import type core from './summit-core.js';
import type { SummitState } from './summit-core.js';
import type { ReferenceFactory } from './character.js';
import type { StyleId } from '../core/config';
export function createReferenceMountain(three:typeof T,options:{core:typeof core;models:ReferenceFactory;BR:number;renderer:T.WebGLRenderer;width?:number;unit?:number;onBurst:(p:T.Vector3,colors:number[],count:number,speed:number)=>void}):{group:T.Group;state:SummitState;start():void;dispose():void;setBase(n:number):void;setDir(n:number):void;jump():void;throwBall():void;update(dt:number,options:{style:StyleId;eye:T.Vector3;onEvent:(e:{type:string})=>void}):void;};
