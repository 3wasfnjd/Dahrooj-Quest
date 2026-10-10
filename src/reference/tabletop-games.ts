/** Isolated tabletop solvers. No changes to the existing throw/world physics. */
export type Point={x:number;z:number};
export type Mode='balance'|'ricochet'|'rings';
export type TabletopWin={mode:Mode;level:number;attempts:number;failures:number;passed:number};
type Phase='ready'|'playing'|'falling'|'won';
export const TABLE_RADIUS=.14;
export const MIRROR_ANGLE_STEP=Math.PI/36;
const snapMirrorAngle=(angle:number)=>Math.round(Math.atan2(Math.sin(angle),Math.cos(angle))/MIRROR_ANGLE_STEP)*MIRROR_ANGLE_STEP;
const STEP=1/120,LIMIT_X=1.5,LIMIT_Z=1.7;
const p=(x:number,z:number):Point=>({x,z});
const clamp=(v:number,a:number,b:number)=>Math.max(a,Math.min(b,v));
const dist=(a:Point,b:Point)=>Math.hypot(a.x-b.x,a.z-b.z);
export type BalanceLevel={path:Point[];width:number;holes:{p:Point;r:number}[];stars:Point[];gate?:Point;gateTravel?:number};
export const BALANCE_LEVELS:readonly BalanceLevel[]=[
 {path:[p(-1,1.25),p(-1,0),p(1,0),p(1,-1.25)],width:.49,holes:[{p:p(-.72,.5),r:.14},{p:p(.35,-.25),r:.14}],stars:[p(-1,.6),p(0,0),p(1,-.65)]},
 {path:[p(-1,1.25),p(-1,.55),p(.85,.55),p(.85,-.6),p(-.85,-.6),p(-.85,-1.25),p(1,-1.25)],width:.33,holes:[{p:p(-.5,.82),r:.16},{p:p(.36,-.85),r:.16}],stars:[p(0,.55),p(.85,-.15),p(-.85,-.95)]},
 {path:[p(-1,1.25),p(-1,.5),p(1,.5),p(1,-.5),p(-1,-.5),p(-1,-1.25),p(1,-1.25)],width:.30,holes:[],stars:[p(-.5,.5),p(1,-.5),p(-1,-1.25)],gate:p(0,.5)},
 {path:[p(-1.12,1.27),p(-.1,1.27),p(-.1,.45),p(1.05,.45),p(1.05,-.4),p(-1.05,-.4),p(-1.05,-1.22),p(1.05,-1.22)],width:.27,holes:[{p:p(-.34,1.01),r:.13}],stars:[p(-.1,.75),p(1.05,-.1),p(-1.05,-.85)],gate:p(0,-.4)},
 {path:[p(-1.05,1.25),p(0,.6),p(-1.05,-.1),p(0,-.75),p(1.05,-.1),p(1.05,-1.25)],width:.24,holes:[],stars:[p(0,.6),p(-1.05,-.1),p(0,-.75)],gate:p(0,-.75),gateTravel:.74},
];
export type Mirror={x:number;z:number;angle:number;length:number};
export type Block={x:number;z:number;hx:number;hz:number};
export type RicochetLevel={start:Point;goal:Point;mirrors:Mirror[];solution:number[];obstacles:Block[];required:number};
// Put the reflecting face behind the intended sphere-centre contact point.
function mirror(contact:Point,incoming:Point,outgoing:Point):Mirror{
 const nx=outgoing.x-incoming.x,nz=outgoing.z-incoming.z,k=Math.hypot(nx,nz),r=TABLE_RADIUS+.045;
 return {x:contact.x-nx/k*r,z:contact.z-nz/k*r,angle:Math.atan2(-nx,nz),length:.91};
}
// Leave enough space for the full paddle (including its wooden caps) to rotate
// inside the tray, not merely for its centre to lie on the play surface.
const A=mirror(p(-.82,-1.02),p(0,-1),p(1,0)),B=mirror(p(.82,-1.02),p(1,0),p(0,1)),C=mirror(p(.82,1.02),p(0,1),p(-1,0));
function reflectionRoute(route:Point[],obstacles:Block[],length:number):RicochetLevel{
 const direction=(a:Point,b:Point)=>{const d=dist(a,b);return p((b.x-a.x)/d,(b.z-a.z)/d);};
 const mirrors=route.slice(1,-1).map((q,i)=>({...mirror(q,direction(route[i],q),direction(q,route[i+2])),length}));
 return {start:route[0],goal:route[route.length-1],mirrors,solution:mirrors.map(m=>m.angle),obstacles,required:mirrors.length};
}
export const RICOCHET_LEVELS:readonly RicochetLevel[]=[
 {start:p(-.82,1.25),goal:p(.82,-1.02),mirrors:[A],solution:[A.angle],obstacles:[{x:0,z:.18,hx:.16,hz:.6}],required:1},
 {start:p(-.82,1.25),goal:p(.82,1.25),mirrors:[A,B],solution:[A.angle,B.angle],obstacles:[{x:0,z:.08,hx:.30,hz:.62}],required:2},
 {start:p(-.82,1.25),goal:p(-.42,1.02),mirrors:[A,B,C],solution:[A.angle,B.angle,C.angle],obstacles:[{x:0,z:0,hx:.30,hz:.55}],required:3},
 reflectionRoute([p(-.95,1.25),p(-.95,-1.06),p(.9,-1.06),p(.9,.8),p(-.7,.8)],[{x:0,z:-.1,hx:.27,hz:.40}],.7),
 reflectionRoute([p(-.9,1.32),p(-.9,-1.15),p(.9,-1.15),p(.9,1),p(-.2,1),p(-.2,-.35)],[{x:.44,z:0,hx:.14,hz:.42}],.73),
];
export type Ring={x:number;z:number;radius:number;amplitude:number;speed:number;phase:number};
export type RingsLevel={start:Point;goal:Point;rings:Ring[]};
function ringRoute(start:Point,goal:Point,zs:number[],radius:number,amplitude=0):RingsLevel{
 const distance=dist(start,goal);
 return {start,goal,rings:zs.map((z,i)=>{const t=(z-start.z)/(goal.z-start.z),speed=1.25+i*.35;
  return {x:start.x+(goal.x-start.x)*t,z,radius,amplitude,speed,phase:-distance*t/3.4*speed};
 })};
}
export const RINGS_LEVELS:readonly RingsLevel[]=[
 ringRoute(p(0,1.3),p(0,-1.35),[0],.52),
 ringRoute(p(-.75,1.3),p(.75,-1.35),[.45,-.55],.48),
 ringRoute(p(.7,1.3),p(-.7,-1.35),[.65,-.1,-.85],.44),
 ringRoute(p(0,1.3),p(0,-1.35),[.65,-.1,-.85],.43,.32),
 ringRoute(p(-.65,1.3),p(.65,-1.35),[.7,.1,-.5,-1.05],.40,.32),
];
function segmentDistance(q:Point,a:Point,b:Point){const x=b.x-a.x,z=b.z-a.z,t=clamp(((q.x-a.x)*x+(q.z-a.z)*z)/(x*x+z*z||1),0,1);return Math.hypot(q.x-a.x-x*t,q.z-a.z-z*t);}

type Contact={t:number;nx:number;nz:number};
/** Continuous expanded-box sweep; handles a ball already inside as well. */
export function sweepBox(start:Point,delta:Point,box:Block,angle=0,radius=TABLE_RADIUS):Contact|null{
 const c=Math.cos(angle),s=Math.sin(angle),x=(start.x-box.x)*c+(start.z-box.z)*s,z=-(start.x-box.x)*s+(start.z-box.z)*c;
 const dx=delta.x*c+delta.z*s,dz=-delta.x*s+delta.z*c,hx=box.hx+radius,hz=box.hz+radius;
 let enter=0,leave=1,nx=0,nz=0;
 for(const [a,d,h,isX] of [[x,dx,hx,1],[z,dz,hz,0]]){
  if(Math.abs(d)<1e-10){if(Math.abs(a)>h)return null;continue;}
  let near=(-h-a)/d,far=(h-a)/d;if(near>far)[near,far]=[far,near];
  if(near>enter){enter=near;nx=isX?-Math.sign(d):0;nz=isX?0:-Math.sign(d);}
  leave=Math.min(leave,far);if(enter>leave)return null;
 }
 if(leave<0||enter>1)return null;
 if(!nx&&!nz){
  if(Math.abs(x)>=hx||Math.abs(z)>=hz)return null;
  if(hx-Math.abs(x)<hz-Math.abs(z))nx=Math.sign(x)||-Math.sign(dx)||1;else nz=Math.sign(z)||-Math.sign(dz)||1;
  if(dx*nx+dz*nz>=0)return null;
 }
 return {t:enter,nx:nx*c-nz*s,nz:nx*s+nz*c};
}
export function createTabletopGame(mode:Mode,onWin:(points:number,result:TabletopWin)=>void=()=>{}){
 let level=0,phase:Phase='ready',elapsed=0,flightTime=0,delay=0,accumulator=0,attempts=0,failures=0,score=0,rounds=0,fall=0;
 const ball=p(0,0),velocity=p(0,0),tilt=p(0,0),stars=new Set<number>(),bounces=new Set<number>(),passed=new Set<number>();
 let angles:number[]=[];
 const balance=()=>BALANCE_LEVELS[level],ricochet=()=>RICOCHET_LEVELS[level],rings=()=>RINGS_LEVELS[level];
 const levelCount=mode==='balance'?BALANCE_LEVELS.length:mode==='ricochet'?RICOCHET_LEVELS.length:RINGS_LEVELS.length;
 const start=()=>mode==='balance'?balance().path[0]:mode==='ricochet'?ricochet().start:rings().start;
 const ringX=(r:Ring,t:number)=>r.x+Math.sin(t*r.speed+r.phase)*r.amplitude;
 function reset(nextLevel=level){
  level=((Math.trunc(Number.isFinite(nextLevel)?nextLevel:0)%levelCount)+levelCount)%levelCount;phase='ready';elapsed=flightTime=delay=accumulator=fall=0;velocity.x=velocity.z=tilt.x=tilt.z=0;stars.clear();bounces.clear();passed.clear();attempts=failures=0;
  Object.assign(ball,start());
  angles=mode==='ricochet'?ricochet().mirrors.map((m,i)=>snapMirrorAngle(m.angle+(i%2?-.32:.32))):[];
 }
 function retry(){phase='ready';elapsed=flightTime=delay=fall=0;velocity.x=velocity.z=0;stars.clear();bounces.clear();passed.clear();Object.assign(ball,start());}
 function win(){if(phase==='won')return;phase='won';delay=1.7;const points=mode==='balance'?3:Math.max(1,4-attempts);score+=points;rounds++;onWin(points,{mode,level,attempts,failures,passed:passed.size});}
 function fail(){phase='falling';delay=.8;fall=0;failures++;velocity.x=velocity.z=0;}
 function gate(){const g=mode==='balance'?balance().gate:null;return g?{x:g.x,z:g.z+Math.sin(elapsed*1.5)*(balance().gateTravel??.43),hx:.08,hz:.21}:null;}
 function stepBalance(dt:number){
  const l=balance();velocity.x+=Math.sin(tilt.x)*7*dt;velocity.z+=Math.sin(tilt.z)*7*dt;
  const f=Math.exp(-1.8*dt);velocity.x*=f;velocity.z*=f;
  const previous={...ball};ball.x+=velocity.x*dt;ball.z+=velocity.z*dt;
  const g=gate(),hit=g&&sweepBox(previous,{x:ball.x-previous.x,z:ball.z-previous.z},g);
  if(hit){ball.x=previous.x+(ball.x-previous.x)*hit.t+hit.nx*.002;ball.z=previous.z+(ball.z-previous.z)*hit.t+hit.nz*.002;const v=velocity.x*hit.nx+velocity.z*hit.nz;if(v<0){velocity.x-=hit.nx*v*1.3;velocity.z-=hit.nz*v*1.3;}}
  const supported=l.path.slice(1).some((b,i)=>segmentDistance(ball,l.path[i],b)<=l.width);
  if(!supported||l.holes.some(h=>dist(h.p,ball)<h.r*.8)){fail();return;}
  l.stars.forEach((s,i)=>{if(dist(s,ball)<.24)stars.add(i);});
  if(stars.size===l.stars.length&&dist(ball,l.path[l.path.length-1])<.24)win();
 }
 function stepRicochet(dt:number){
  const l=ricochet();let left=dt;
  // Several contacts in one fixed tick remain ordered along the actual travelled path.
  for(let iteration=0;iteration<5&&left>1e-7&&phase==='playing';iteration++){
   const delta={x:velocity.x*left,z:velocity.z*left};let nearest:Contact|null=null,board=-1;
   const consider=(hit:Contact|null,i:number)=>{if(hit&&(!nearest||hit.t<nearest.t)){nearest=hit;board=i;}};
   l.mirrors.forEach((m,i)=>consider(sweepBox(ball,delta,{x:m.x,z:m.z,hx:m.length/2,hz:.045},angles[i]),i));
   l.obstacles.forEach(b=>consider(sweepBox(ball,delta,b),-1));
   const hit=nearest as Contact|null,travel=hit?hit.t:1,end={x:ball.x+delta.x*travel,z:ball.z+delta.z*travel};
   if(bounces.size>=l.required&&segmentDistance(l.goal,ball,end)<.24){Object.assign(ball,l.goal);velocity.x=velocity.z=0;win();break;}
   Object.assign(ball,end);
   if(!hit)break;
   ball.x+=hit.nx*.001;ball.z+=hit.nz*.001;const v=velocity.x*hit.nx+velocity.z*hit.nz;
   if(v<0){velocity.x-=2*hit.nx*v;velocity.z-=2*hit.nz*v;if(board>=0)bounces.add(board);else{velocity.x*=.8;velocity.z*=.8;}}
   left*=1-hit.t;
  }
  if(phase==='playing'&&(Math.abs(ball.x)>LIMIT_X+TABLE_RADIUS||Math.abs(ball.z)>LIMIT_Z+TABLE_RADIUS||elapsed>8))fail();
 }
 function stepRings(dt:number){
  const l=rings(),previous={...ball};ball.x+=velocity.x*dt;ball.z+=velocity.z*dt;
  // Sweep every crossed ring plane, using its position at the instant of crossing.
  for(let i=0;i<l.rings.length;i++){
   const r=l.rings[i];if(passed.has(i)||previous.z<r.z||ball.z>r.z||ball.z===previous.z)continue;
   const t=(r.z-previous.z)/(ball.z-previous.z),x=previous.x+(ball.x-previous.x)*t;
   if(i!==passed.size||Math.abs(x-ringX(r,elapsed-dt+dt*t))>r.radius-.035-TABLE_RADIUS){ball.x=x;ball.z=r.z;fail();return;}
   passed.add(i);
  }
  if(passed.size===l.rings.length&&segmentDistance(l.goal,previous,ball)<.24){Object.assign(ball,l.goal);velocity.x=velocity.z=0;win();return;}
  if(Math.abs(ball.x)>LIMIT_X+TABLE_RADIUS||Math.abs(ball.z)>LIMIT_Z+TABLE_RADIUS||flightTime>8)fail();
 }
 reset();
 return {
  mode,ball,velocity,tilt,stars,bounces,passed,levelCount,
  get level(){return level;},get phase(){return phase;},get attempts(){return attempts;},get failures(){return failures;},get score(){return score;},get rounds(){return rounds;},get fall(){return fall;},get angles(){return angles;},get gate(){return gate();},
  get rings(){return mode==='rings'?rings().rings.map(r=>({...r,x:ringX(r,elapsed)})):[];},
  get definition(){return mode==='balance'?balance():mode==='ricochet'?ricochet():rings();},
  reset,
  retry(){failures++;retry();accumulator=0;},
  setTilt(x:number,z:number){tilt.x=clamp(Number.isFinite(x)?x:0,-.32,.32);tilt.z=clamp(Number.isFinite(z)?z:0,-.32,.32);},
  turnMirror(index:number,angle:number){if(mode!=='ricochet'||phase==='playing'||phase==='won'||!Number.isFinite(angle)||index<0||index>=angles.length)return false;angles[index]=snapMirrorAngle(angle);return true;},
  launch(direction:Point){
   if(mode==='balance'||phase!=='ready'||!Number.isFinite(direction.x)||!Number.isFinite(direction.z))return false;
   const d=Math.hypot(direction.x,direction.z);if(d<.001)return false;
   attempts++;bounces.clear();passed.clear();phase='playing';flightTime=0;if(mode==='ricochet')elapsed=0;velocity.x=direction.x/d*3.4;velocity.z=direction.z/d*3.4;return true;
  },
  step(dt:number,active=true){
   // Freeze exactly during menus, tracking loss and a released balance grip. No catch-up burst.
   if(!active||!Number.isFinite(dt)||dt<=0){accumulator=0;return;}
   accumulator+=Math.min(dt,.05);
   while(accumulator>=STEP){
    accumulator-=STEP;
    if(phase==='won'||phase==='falling'){
     delay-=STEP;if(phase==='falling')fall+=STEP*1.6;
     if(delay<=0){if(phase==='won')reset(level+1);else retry();}continue;
    }
    if(mode==='balance'){phase='playing';elapsed+=STEP;stepBalance(STEP);}
    else if(mode==='rings'){elapsed+=STEP;if(phase==='playing'){flightTime+=STEP;stepRings(STEP);}}
    else if(phase==='playing'){elapsed+=STEP;stepRicochet(STEP);}
   }
  },
 };
}
