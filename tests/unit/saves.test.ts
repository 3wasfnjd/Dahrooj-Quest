import { expect, it } from 'vitest';
import { defaults, migrate } from '../../src/save/store';
import { CHALLENGES } from '../../src/progression/challenges';
it('keeps original colour and unlocks the wool hat only after a clean maze completion',()=>{
 for(const style of ['jelly','fur','bubble']){
  const saved=migrate({version:2,style,jellyColor:'original',accessory:'beanie',challenges:{mazeClean:1}});
  expect(saved.jellyColor).toBe('original');expect(saved.accessory).toBe('beanie');expect(migrate(saved)).toEqual(saved);
 }
 expect(migrate({version:2,jellyColor:'original',accessory:'beanie',challenges:{maze5:5}}).accessory).toBe('');
 expect(defaults().jellyColor).toBe('pink');
});
it('migrates version 1 and repairs corrupt fields', () => { const save = migrate({ version: 1, language: 'en', master: 8, sfx: -1, style: 'unknown', challenges: { keeper3: 3, bad: Infinity }, accessory: 'crown', stylesUsed: ['fur', 'fur', 'unknown'] }); expect(save.version).toBe(2); expect(save.language).toBe('en'); expect(save.master).toBe(1); expect(save.sfx).toBe(0); expect(save.style).toBe('fur'); expect(save.accessory).toBe(''); expect(save.stylesUsed).toEqual(['fur']); expect(save.challenges.bad).toBeUndefined(); });
it('preserves legitimately unlocked accessories and highscores', () => { const challenges = Object.fromEntries(CHALLENGES.map(([id, goal]) => [id, goal])); expect(migrate({ version: 2, challenges, accessory: 'crown', best: { fair: 82 } }).accessory).toBe('crown'); });
it('uses safe defaults for unknown versions', () => { expect(migrate({ version: 200 })).toEqual(defaults()); expect(migrate(null)).toEqual(defaults()); });

it('migrates retired styles without losing completed rewards and persists jelly colour',()=>{
 for(const [old,next] of [['fabric','fur'],['clay','jelly'],['bubble','bubble']]){
  const save=migrate({version:2,style:old,jellyColor:'blue',stylesUsed:['fabric','clay','fur','jelly','bubble'],challenges:{styles5:5}});
  expect(save.style).toBe(next);expect(save.jellyColor).toBe('blue');expect(save.challenges.styles5).toBe(3);
  expect(migrate(save)).toEqual(save);
 }
 expect(migrate({version:2,jellyColor:'bad'}).jellyColor).toBe('pink');
 expect(migrate({version:2,stylesUsed:['fabric','fur','fur'],challenges:{styles5:2}}).challenges.styles5).toBe(1);
});
it('keeps new accessory unlocks gated and preserves them after reload',()=>{
 const challenges=Object.fromEntries(CHALLENGES.map(([id,goal])=>[id,goal]));
 for(const accessory of ['headphones','scarf']){
  expect(migrate({version:2,accessory,challenges}).accessory).toBe(accessory);
  expect(migrate({version:2,accessory,challenges:{}}).accessory).toBe('');
 }
});
it('replaces an earned legacy balance accessory without losing progress or unlocking it early',()=>{
 const raw={version:2,accessory:'laurel',challenges:{balance5:5},best:{'tabletop:balance:cleared':31,fair:82}};
 const save=migrate(raw);expect(save.accessory).toBe('aviator');expect(save.challenges.balance5).toBe(5);expect(save.best).toEqual(raw.best);expect(migrate(save)).toEqual(save);
 expect(migrate({...raw,challenges:{balance5:4}}).accessory).toBe('');
});
