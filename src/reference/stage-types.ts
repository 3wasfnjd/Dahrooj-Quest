import type { Group, Mesh, Object3D, Quaternion, Vector3 } from '@iwsdk/core';
export interface RefBody { mesh: Object3D; x: Vector3; v: Vector3; w: Vector3; q: Quaternion; gone?: boolean; sleep?:boolean; invM:number; }
export interface RefBrick { mesh:Mesh; alive:boolean; }
export interface RefDuck { g:Group; down:number; r:number; fly?:{v:Vector3;spin:Vector3;gone?:number;fresh?:boolean}; }
export interface RefStage {
 grp:Group; update(dt:number):void; collide?():void; onThrow?():void; onRespawn?():void;
 shoot?(object:Object3D, point:Vector3,direction:Vector3):boolean;
 fair?:{on:boolean;time:number;score:number;best:number};
 bridge?:{ bodies?:RefBody[];radius?:number;height?:number;shape?:'Cylinder'|'ConvexHull';contact?:()=>void;
 kinematics?:Mesh[];rim?:{mesh:Mesh;radius:number;tube:number};bricks?:RefBrick[];
 towers?:{c:Vector3;h:Vector3}[];stall?:{c:Vector3;h:Vector3}[];
 ducks?:RefDuck[];balloons?:{m:Mesh;r:number;popT:number}[];bell?:Mesh; };
}
