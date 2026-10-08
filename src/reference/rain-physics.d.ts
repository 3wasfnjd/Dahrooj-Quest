import type * as T from '@iwsdk/core';
import type { StyleId } from '../core/config';
export interface Drop {id:number;style:StyleId;R:number;p:T.Vector3;v:T.Vector3;d:number;blink:number;hit:number;}
export function createReferenceRain(three:typeof T,capacity:number):{balls:Drop[];step(dt:number,head:T.Vector3,count:number):Drop[];reset(drop:Drop):void;};
