import {describe,it,expect} from 'vitest';
import {ballImpactSpeed} from '../../src/reference/ball-impact';
const v=(x=0,y=0,z=0)=>({x,y,z});
describe('world Dahrooj collision cleanup',()=>{
 it('detects a fast head-on pass even when the balls no longer overlap at the end',()=>{
  expect(ballImpactSpeed(v(.6),v(30),v(-.6),v(-30),.48,.04)).toBeCloseTo(60);
 });
 it('leaves gentle contact and glancing near misses below the pop threshold',()=>{
  expect(ballImpactSpeed(v(0),v(.2),v(.47),v(-.2),.48,.04)).toBeCloseTo(.4);
  expect(ballImpactSpeed(v(.6,0),v(30),v(-.6,.6),v(-30),.48,.04)).toBe(0);
 });
 it('does not pop overlapping balls that are separating or travelling together',()=>{
  expect(ballImpactSpeed(v(0),v(-1),v(.4),v(1),.48,.02)).toBe(0);
  expect(ballImpactSpeed(v(0),v(5),v(.3),v(5),.48,.02)).toBe(0);
 });
 it('uses the vertical separation and actual combined radius of Rain balls',()=>{
  expect(ballImpactSpeed(v(0,.15),v(0,-5),v(0),v(),.2,.05)).toBeCloseTo(5);
  expect(ballImpactSpeed(v(0,.3),v(0,-5),v(0),v(),.2,.01)).toBe(0);
 });
});
