/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export const SHOT_STYLE={
      bolt:{speed:45,grav:0,life:1.2,r:.02,cool:.12},
      mini:{speed:11,grav:1,life:3.2,r:.022,cool:.12},
      bubble:{speed:4.2,grav:-.06,life:3.6,r:.06,cool:.16},
      firework:{speed:20,grav:.35,life:.85,r:.025,cool:.2,burst:.55}
    };
export const FIRE_COLS=[0xe2603f,0xf2c14e,0x6fa8d6,0x7bbf8a,0xc9a2e6,0xfffaf2];
export function advanceShot(s,dt,k){s.v.y-=9.8*k*SHOT_STYLE[s.kind].grav*dt;if(s.kind==='bubble'){s.wob+=dt*3;s.v.x+=Math.sin(s.wob)*.25*k*dt;s.v.z+=Math.cos(s.wob*.8)*.25*k*dt;}s.p.addScaledVector(s.v,dt);}
export function groundMini(s,dt,floor,k){s.p.y=floor+s.r;if(s.v.y<-.8*k)s.v.y*=-.45;else s.v.y=0;const f=Math.pow(.55,dt);s.v.x*=f;s.v.z*=f;}
