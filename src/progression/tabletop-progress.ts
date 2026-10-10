import type {TabletopWin} from '../reference/tabletop-games';
import type {ChallengeId} from './challenges';

/** Five distinct rounds survive mode switches and reloads; replaying one cannot fill the set. */
export function recordTabletopWin(best:Record<string,number>,progress:(id:ChallengeId,value:number)=>void,result:TabletopWin){
 const {mode,level,attempts,failures,stars}=result;
 if(!['balance','ricochet','maze'].includes(mode)||!Number.isInteger(level)||level<0||level>=5)return;
 const key=`tabletop:${mode}:cleared`,mask=((best[key]||0)|(1<<level))&31;
 best[key]=mask;
 const count=Array.from({length:5},(_,i)=>(mask>>i)&1).reduce((a,b)=>a+b,0);
 progress(`${mode}1` as ChallengeId,1);progress(`${mode}5` as ChallengeId,count);
 if(mode==='balance'&&failures===0)progress('balanceClean',1);
 if(mode==='ricochet'&&attempts===1&&failures===0)progress('ricochetAce',1);
 if(mode==='maze'&&stars===3&&failures===0)progress('mazeClean',1);
}

export function clearTabletopProgress(best:Record<string,number>){
 for(const key of Object.keys(best))if(key.startsWith('tabletop:'))delete best[key];
}
