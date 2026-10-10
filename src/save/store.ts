import {jellyColor,playableStyle} from '../core/appearance';
import type {JellyColorId} from '../core/appearance';
import { ACCESSORIES, SHOTS, STYLES, THROWS } from '../core/config';
import type { AccessoryId, Language, ShotId, StyleId, ThrowId, TimeOfDay, Weather } from '../core/config';
import { CHALLENGES, accessoryAvailable } from '../progression/challenges';
import type { ChallengeId } from '../progression/challenges';
export interface SaveData {
    version: 2;
    language: Language;
    style: StyleId;
    jellyColor: JellyColorId;
    throwType: ThrowId;
    shot: ShotId;
    accessory: AccessoryId;
    challenges: Record<string, number>;
    stylesUsed: StyleId[];
    best: Record<string, number>;
    time: TimeOfDay;
    weather: Weather;
    master: number;
    music: number;
    sfx: number;
    ambience: number;
    ui: number;
}
export function defaults(): SaveData { return { version: 2, language: 'ar', style: 'fur', jellyColor:'pink', throwType: 'physical', shot: 'bolt', accessory: '', challenges: {}, stylesUsed: [], best: {}, time: 'day', weather: 'clear', master: 0.7, music: 0.12, sfx: 0.65, ambience: 0.25, ui: 0.4 }; }
function record(value: unknown): Record<string, unknown> { return value && typeof value === 'object' ? value as Record<string, unknown> : {}; }
function numericRecord(value: unknown) { const out: Record<string, number> = {}; for (const [k, v] of Object.entries(record(value)))
    if (typeof v === 'number' && Number.isFinite(v) && v >= 0)
        out[k] = Math.min(v, 1e9); return out; }
export function migrate(value: unknown): SaveData {
    const raw = record(value), d = defaults();
    if (raw.version !== 1 && raw.version !== 2)
        return d;
    if (raw.language === 'en')
        d.language = 'en';
    if (STYLES.includes(raw.style as StyleId))
        d.style = playableStyle(raw.style);
    d.jellyColor = jellyColor(raw.jellyColor).id;
    if (THROWS.includes(raw.throwType as ThrowId))
        d.throwType = raw.throwType as ThrowId;
    if (SHOTS.includes(raw.shot as ShotId))
        d.shot = raw.shot as ShotId;
    d.challenges = numericRecord(raw.challenges);
    d.best = numericRecord(raw.best);
    d.stylesUsed = [...new Set(Array.isArray(raw.stylesUsed) ? raw.stylesUsed.filter((s): s is StyleId => STYLES.includes(s)) : [])];
    // Preserve earned legacy style rewards; partial progress counts only remaining styles.
    d.stylesUsed = [...new Set(d.stylesUsed.filter(s=>s==='jelly'||s==='fur'||s==='bubble'))];
    d.challenges.styles5 = (d.challenges.styles5||0)>=3?3:d.stylesUsed.length;
    const done = CHALLENGES.filter(([id, goal]) => (d.challenges[id] || 0) >= goal).length;
    if (ACCESSORIES.includes(raw.accessory as AccessoryId) && accessoryAvailable(String(raw.accessory),done,d.challenges))
        d.accessory = raw.accessory as AccessoryId;
    if (['day', 'dusk', 'night', 'dawn', 'auto'].includes(String(raw.time)))
        d.time = raw.time as TimeOfDay;
    if (['clear', 'rain', 'snow', 'auto'].includes(String(raw.weather)))
        d.weather = raw.weather as Weather;
    for (const k of ['master', 'music', 'sfx', 'ambience', 'ui'] as const)
        if (typeof raw[k] === 'number' && Number.isFinite(raw[k]))
            d[k] = Math.max(0, Math.min(1, raw[k]));
    return d;
}
export class SaveStore {
    data = defaults();
    private db?: IDBDatabase;
    private timer = 0;
    warning = '';
    onChange: () => void = () => { };
    async open() {
        try {
            this.db = await new Promise<IDBDatabase>((resolve, reject) => { const r = indexedDB.open('aboden-dahrooj-quest', 2); r.onupgradeneeded = () => { if (!r.result.objectStoreNames.contains('save'))
                r.result.createObjectStore('save'); }; r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); r.onblocked = () => reject(new Error('storage blocked')); });
            const raw = await new Promise<unknown>((resolve, reject) => { const r = this.db!.transaction('save').objectStore('save').get('player'); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
            this.data = migrate(raw);
            if (raw === undefined)
                this.data.language = navigator.language.toLowerCase().startsWith('ar') ? 'ar' : 'en';
        }
        catch {
            this.warning = 'تعذّر حفظ التقدم على هذا المتصفح / Storage unavailable';
        }
        return this;
    }
    touch() { this.onChange(); clearTimeout(this.timer); this.timer = window.setTimeout(() => void this.flush(), 250); }
    async flush() {
        if (!this.db)
            return;
        try {
            await new Promise<void>((resolve, reject) => { const tx = this.db!.transaction('save', 'readwrite'); tx.objectStore('save').put(structuredClone(this.data), 'player'); tx.oncomplete = () => resolve(); tx.onerror = () => reject(tx.error); });
        }
        catch {
            this.warning = 'تعذّر حفظ التقدم / Save failed';
        }
    }
    progress(id: ChallengeId, amount = 1, maximum = false) { const goal = CHALLENGES.find(c => c[0] === id)![1]; const old = this.data.challenges[id] || 0; this.data.challenges[id] = Math.min(goal, maximum ? Math.max(old, amount) : old + amount); if (this.data.challenges[id] !== old)
        this.touch(); return old < goal && this.data.challenges[id] >= goal; }
    noteStyle() { if (!this.data.stylesUsed.includes(this.data.style))
        this.data.stylesUsed.push(this.data.style); this.progress('styles5', this.data.stylesUsed.length, true); }
    get completed() { return CHALLENGES.filter(([id, goal]) => (this.data.challenges[id] || 0) >= goal).length; }
    canWear(id: AccessoryId) { return accessoryAvailable(id,this.completed,this.data.challenges); }
    reset() { this.data = defaults(); this.touch(); return this.flush(); }
}
