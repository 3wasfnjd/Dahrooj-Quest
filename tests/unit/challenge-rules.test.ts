import {describe,it,expect} from 'vitest';
import {createThrowAttempt,challengeValue} from '../../src/reference/challenge-rules.js';
describe('one-throw can clear and bowling strike',()=>{
 it('accepts one ball and its later chain of falling targets',()=>{const a=createThrowAttempt();a.launch(1);a.contact(1,true);a.contact(1,false);expect(a.complete()).toBe(true);});
 it('rejects two partial throws, including overlapping balls',()=>{const a=createThrowAttempt();a.launch(1);a.contact(1,true);a.launch(2);a.contact(2,false);expect(a.complete()).toBe(false);a.reset();a.launch(3);a.launch(4);a.contact(3,true);a.contact(4,true);expect(a.complete()).toBe(false);});
 it('rejects blaster assistance before or after a throw',()=>{const a=createThrowAttempt();a.invalidate();a.launch(1);a.contact(1,true);expect(a.complete()).toBe(false);a.reset();a.launch(2);a.contact(2,true);a.invalidate();expect(a.complete()).toBe(false);});
 it('requires a full rack and a real impact, then permits a fresh rack',()=>{const a=createThrowAttempt();a.launch(1);expect(a.complete()).toBe(false);a.contact(1,false);expect(a.complete()).toBe(false);a.reset();a.launch(2);a.contact(2,true);expect(a.complete()).toBe(true);});
});
describe('challenge progress follows its scope',()=>{
 it('resets a missed hoop streak without forgetting an earned achievement',()=>{expect(challengeValue('hoop3',2,3,0)).toBe(0);expect(challengeValue('hoop3',3,3,0)).toBe(3);});
 it('does not sum scores from two fair rounds',()=>{let n=challengeValue('fair25',0,25,15);n=challengeValue('fair25',n,25,0);n=challengeValue('fair25',n,25,12);expect(n).toBe(12);});
 it('preserves cumulative challenges',()=>{expect(challengeValue('bricks20',12,20,3)).toBe(12);expect(challengeValue('bricks20',12,20,13)).toBe(13);});
});
