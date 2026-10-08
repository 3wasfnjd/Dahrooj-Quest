import { expect, it } from 'vitest';
import { defaults, migrate } from '../../src/save/store';
import { CHALLENGES } from '../../src/progression/challenges';
it('migrates version 1 and repairs corrupt fields', () => { const save = migrate({ version: 1, language: 'en', master: 8, sfx: -1, style: 'unknown', challenges: { keeper3: 3, bad: Infinity }, accessory: 'crown', stylesUsed: ['fur', 'fur', 'unknown'] }); expect(save.version).toBe(2); expect(save.language).toBe('en'); expect(save.master).toBe(1); expect(save.sfx).toBe(0); expect(save.style).toBe('fabric'); expect(save.accessory).toBe(''); expect(save.stylesUsed).toEqual(['fur']); expect(save.challenges.bad).toBeUndefined(); });
it('preserves legitimately unlocked accessories and highscores', () => { const challenges = Object.fromEntries(CHALLENGES.map(([id, goal]) => [id, goal])); expect(migrate({ version: 2, challenges, accessory: 'crown', best: { fair: 82 } }).accessory).toBe('crown'); });
it('uses safe defaults for unknown versions', () => { expect(migrate({ version: 200 })).toEqual(defaults()); expect(migrate(null)).toEqual(defaults()); });
