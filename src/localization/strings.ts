import type { ModeId, StyleId, ThrowId, ShotId, AccessoryId, Language } from '../core/config';
export const MODE_NAMES: Record<ModeId, [
    string,
    string
]> = { goal: ['المرمى', 'Goal'], hoop: ['السلة', 'Hoop'], window: ['النافذة', 'Window'], cans: ['العلب', 'Cans'], bowling: ['البولينج', 'Bowling'], bricks: ['الطوب', 'Bricks'], fair: ['المهرجان', 'Fair'], summit: ['القمة', 'Summit'], rain: ['مطر دحروج', 'Dahrooj Rain'] };
export const STYLE_NAMES: Record<StyleId, [
    string,
    string
]> = { jelly: ['جيلي', 'Jelly'], fabric: ['قماش', 'Fabric'], clay: ['طين', 'Clay'], fur: ['فرو', 'Fur'], bubble: ['فقاعة', 'Bubble'] };
export const THROW_NAMES: Record<ThrowId, [
    string,
    string
]> = { physical: ['رمي اليد', 'Physical'], charged: ['شحن', 'Charged'], slingshot: ['مقلاع', 'Slingshot'] };
export const SHOT_NAMES: Record<ShotId, [
    string,
    string
]> = { bolt: ['ومضة', 'Bolt'], mini: ['دحروج صغير', 'Mini Dahrooj'], bubble: ['فقاعة', 'Bubble'], firework: ['ألعاب نارية', 'Firework'] };
export const ACCESSORY_NAMES: Record<AccessoryId, [
    string,
    string
]> = { '': ['بلا زينة', 'None'], party: ['قبعة حفلة', 'Party hat'], glasses: ['نظارة', 'Sunglasses'], cap: ['كاب', 'Cap'], flower: ['زهرة', 'Flower'], crown: ['تاج', 'Crown'], headphones:['سماعات','Headphones'], scarf:['وشاح','Scarf'] };
export function label(pair: readonly [
    string,
    string
], lang: Language) { return pair[lang === 'ar' ? 0 : 1]; }
