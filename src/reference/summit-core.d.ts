export interface SummitState {time:number;won:boolean;checkpoint:number;ball:{x:number;y:number;hearts:number;dead:boolean};events:{type:string;x:number;y:number}[]; shots:unknown[];}
declare const core:{createState(width:number):SummitState;step(state:SummitState,dt:number):void;setDir(state:SummitState,d:number):void;jump(state:SummitState):void;throwBall(state:SummitState):void;G:number;RUN:number;JUMP:number;SHOT_MAX:number;MAX_HEARTS:number;TOP:number;};
export default core;
