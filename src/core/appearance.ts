// Legacy style IDs remain readable; selectable styles are now these three.
export const PLAYABLE_STYLES = ['jelly','fur','bubble'] as const;
// Legacy name retained for saved games; these are the colours of all three looks.
export const JELLY_COLORS = [
 {id:'pink',ar:'وردي',en:'Pink',hex:0xff69b4},
 {id:'red',ar:'أحمر',en:'Red',hex:0xff505c},
 {id:'orange',ar:'برتقالي',en:'Orange',hex:0xff9b3d},
 {id:'yellow',ar:'أصفر',en:'Yellow',hex:0xffdf45},
 {id:'green',ar:'أخضر',en:'Green',hex:0x58db83},
 {id:'blue',ar:'أزرق',en:'Blue',hex:0x58b9ff},
 {id:'purple',ar:'بنفسجي',en:'Purple',hex:0xb878ff},
] as const;
// Keep the seven explicit rain colours separate from the player's no-override option.
export const DAHROOJ_COLOR_CHOICES=[{id:'original',ar:'اللون الأصلي',en:'Original colour',hex:null},...JELLY_COLORS] as const;
export type JellyColorId = typeof DAHROOJ_COLOR_CHOICES[number]['id'];
export function jellyColor(value:unknown){return DAHROOJ_COLOR_CHOICES.find(c=>c.id===value)??JELLY_COLORS[0];}
export function playableStyle(value:unknown):typeof PLAYABLE_STYLES[number]{return value==='fur'||value==='fabric'?'fur':value==='bubble'?'bubble':'jelly';}
