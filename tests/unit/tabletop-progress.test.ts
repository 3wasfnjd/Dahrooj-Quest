import {describe,expect,it} from 'vitest';
import {CHALLENGES,accessoryAvailable,UNLOCKS} from '../../src/progression/challenges';
import {recordTabletopWin,clearTabletopProgress} from '../../src/progression/tabletop-progress';
import {migrate,defaults} from '../../src/save/store';
import type {TabletopWin} from '../../src/reference/tabletop-games';

const result=(mode:TabletopWin['mode'],level:number):TabletopWin=>({mode,level,attempts:1,failures:0,passed:3});
describe('tabletop achievements and specific accessory rewards',()=>{
 it.each(['balance','ricochet','rings'] as const)('counts five distinct %s rounds across reloads and never substitutes old achievements',mode=>{
  let save=defaults();const accessory=Object.entries(UNLOCKS).find(([,need])=>need===`${mode}5`)![0];
  save.challenges=Object.fromEntries(CHALLENGES.filter(([id])=>!/^(balance|ricochet|rings)/.test(id)).map(([id,goal])=>[id,goal]));
  const progress=(id:string,value:number)=>{save.challenges[id]=Math.max(save.challenges[id]||0,value);};
  expect(accessoryAvailable(accessory,25,save.challenges)).toBe(false);
  for(let i=0;i<5;i++)recordTabletopWin(save.best,progress,result(mode,0));
  expect(save.challenges[`${mode}5`]).toBe(1);save=migrate(save);
  for(let level=1;level<5;level++)recordTabletopWin(save.best,progress,result(mode,level));
  expect(save.challenges[`${mode}5`]).toBe(5);expect(accessoryAvailable(accessory,0,save.challenges)).toBe(true);
  const loaded=migrate({...save,accessory});expect(loaded.accessory).toBe(accessory);expect(loaded.best[`tabletop:${mode}:cleared`]).toBe(31);
  expect(migrate({...loaded,challenges:{}}).accessory).toBe('');
 });
 it('requires clean first attempts and three rings for the precision achievements',()=>{
  const save=defaults(),progress=(id:string,value:number)=>{save.challenges[id]=value;};
  recordTabletopWin(save.best,progress,{...result('balance',0),failures:1});
  recordTabletopWin(save.best,progress,{...result('ricochet',0),attempts:2});
  recordTabletopWin(save.best,progress,{...result('rings',0),passed:1});
  for(const id of ['balanceClean','ricochetAce','ringsClean'])expect(save.challenges[id]).toBeUndefined();
  for(const mode of ['balance','ricochet','rings'] as const)recordTabletopWin(save.best,progress,result(mode,2));
  for(const id of ['balanceClean','ricochetAce','ringsClean'])expect(save.challenges[id]).toBe(1);
 });
 it('clears only tabletop completion masks when resetting achievements and rejects invalid rounds',()=>{
  const save=defaults();save.best.fair=72;const progress=(id:string,value:number)=>{save.challenges[id]=value;};
  recordTabletopWin(save.best,progress,result('balance',5));expect(save.challenges).toEqual({});
  recordTabletopWin(save.best,progress,result('balance',0));clearTabletopProgress(save.best);expect(save.best).toEqual({fair:72});
  save.challenges={};recordTabletopWin(save.best,progress,result('balance',1));expect(save.challenges.balance5).toBe(1);
  expect(accessoryAvailable('unknown',99,{})).toBe(false);expect(accessoryAvailable('scarf',14,{})).toBe(true);
 });
});
