/** Isolated tabletop solvers. No changes to the existing throw/world physics. */
export type Point={x:number;z:number};
export type Mode='balance'|'ricochet'|'maze';
export type TabletopWin={mode:Mode;level:number;attempts:number;failures:number;stars:number};
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
export type MazeLevel={start:Point;goal:Point;walls:Block[];stars:Point[];route:Point[]};
export const MAZE_WALL_HEIGHT=.24;
const MAZE_WALL=.09;
/** Fixed seeds define five repeatable mazes. A spanning tree keeps every cell
 * reachable, including dead ends; the farthest cell is the finish. No holes. */
function mazeLevel(cols:number,rows:number,seed:number):MazeLevel{
 const xEdge=LIMIT_X-MAZE_WALL/2,zEdge=LIMIT_Z-MAZE_WALL/2,dx=xEdge*2/cols,dz=zEdge*2/rows;
 const centre=(id:number)=>p(-xEdge+(id%cols+.5)*dx,-zEdge+(Math.floor(id/cols)+.5)*dz);
 const start=(rows-1)*cols,parents=new Map<number,number>([[start,-1]]),stack=[start],open=new Set<string>();
 const edge=(a:number,b:number)=>a<b?`${a}:${b}`:`${b}:${a}`;
 while(stack.length){
  const a=stack[stack.length-1],x=a%cols,z=Math.floor(a/cols);
  const choices=[[x-1,z],[x+1,z],[x,z-1],[x,z+1]].filter(([x,z])=>x>=0&&x<cols&&z>=0&&z<rows).map(([x,z])=>z*cols+x).filter(b=>!parents.has(b));
  if(!choices.length){stack.pop();continue;}
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;const b=choices[seed%choices.length];
  parents.set(b,a);open.add(edge(a,b));stack.push(b);
 }
 const pathTo=(id:number)=>{const ids:number[]=[];while(id>=0){ids.push(id);id=parents.get(id)!;}return ids.reverse();};
 const ids=[...parents.keys()].map(pathTo).reduce((longest,path)=>path.length>longest.length?path:longest,[] as number[]),route=ids.map(centre);
 const walls:Block[]=[{x:-xEdge,z:0,hx:MAZE_WALL/2,hz:LIMIT_Z},{x:xEdge,z:0,hx:MAZE_WALL/2,hz:LIMIT_Z},{x:0,z:-zEdge,hx:LIMIT_X-MAZE_WALL,hz:MAZE_WALL/2},{x:0,z:zEdge,hx:LIMIT_X-MAZE_WALL,hz:MAZE_WALL/2}];
 const joints=new Set<string>();
 const joint=(x:number,z:number)=>{if(x>0&&x<cols&&z>0&&z<rows)joints.add(`${x}:${z}`);};
 for(let z=0;z<rows;z++)for(let x=0;x<cols;x++){
  const a=z*cols+x,c=centre(a);
  if(x<cols-1&&!open.has(edge(a,a+1))){walls.push({x:c.x+dx/2,z:c.z,hx:MAZE_WALL/2,hz:(dz-MAZE_WALL)/2});joint(x+1,z);joint(x+1,z+1);}
  if(z<rows-1&&!open.has(edge(a,a+cols))){walls.push({x:c.x,z:c.z+dz/2,hx:(dx-MAZE_WALL)/2,hz:MAZE_WALL/2});joint(x,z+1);joint(x+1,z+1);}
 }
 // Butt joints fill the junctions exactly once. Overlapping grain-covered tops
 // at the same height would fight in the depth buffer as the board tilts.
 for(const key of joints){const [x,z]=key.split(':').map(Number);walls.push({x:-xEdge+x*dx,z:-zEdge+z*dz,hx:MAZE_WALL/2,hz:MAZE_WALL/2});}
 return {start:route[0],goal:route[route.length-1],walls,route,stars:[.25,.5,.75].map(t=>route[Math.floor((route.length-1)*t)])};
}
export const MAZE_LEVELS:readonly MazeLevel[]=[mazeLevel(3,3,17),mazeLevel(3,4,28),mazeLevel(4,4,39),mazeLevel(4,5,50),mazeLevel(5,5,61)];
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
 let level=0,phase:Phase='ready',elapsed=0,delay=0,accumulator=0,attempts=0,failures=0,score=0,rounds=0,fall=0;
 const ball=p(0,0),velocity=p(0,0),tilt=p(0,0),stars=new Set<number>(),bounces=new Set<number>();
 let angles:number[]=[];
 const balance=()=>BALANCE_LEVELS[level],ricochet=()=>RICOCHET_LEVELS[level],maze=()=>MAZE_LEVELS[level];
 const levelCount=mode==='balance'?BALANCE_LEVELS.length:mode==='ricochet'?RICOCHET_LEVELS.length:MAZE_LEVELS.length;
 const start=()=>mode==='balance'?balance().path[0]:mode==='ricochet'?ricochet().start:maze().start;
 function reset(nextLevel=level){
  level=((Math.trunc(Number.isFinite(nextLevel)?nextLevel:0)%levelCount)+levelCount)%levelCount;phase='ready';elapsed=delay=accumulator=fall=0;velocity.x=velocity.z=tilt.x=tilt.z=0;stars.clear();bounces.clear();attempts=failures=0;
  Object.assign(ball,start());
  angles=mode==='ricochet'?ricochet().mirrors.map((m,i)=>snapMirrorAngle(m.angle+(i%2?-.32:.32))):[];
 }
 function retry(){phase='ready';elapsed=delay=fall=0;velocity.x=velocity.z=0;stars.clear();bounces.clear();Object.assign(ball,start());}
 function win(){if(phase==='won')return;phase='won';delay=1.7;const points=mode==='ricochet'?Math.max(1,4-attempts):3;score+=points;rounds++;onWin(points,{mode,level,attempts,failures,stars:stars.size});}
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
 function stepMaze(dt:number){
  const l=maze(),drag=Math.exp(-2.4*dt);
  velocity.x=(velocity.x+Math.sin(tilt.x)*7*dt)*drag;velocity.z=(velocity.z+Math.sin(tilt.z)*7*dt)*drag;
  let left=dt;
  // Sweep each segment, then slide along the contacted wall. Multiple contacts
  // in a corner cannot skip a wall or transfer the ball through a thin divider.
  for(let i=0;i<6&&left>1e-7;i++){
   const delta=p(velocity.x*left,velocity.z*left);let hit:Contact|null=null;
   for(const wall of l.walls){const contact=sweepBox(ball,delta,wall);if(contact&&(!hit||contact.t<hit.t))hit=contact;}
   const end=p(ball.x+delta.x*(hit?.t??1),ball.z+delta.z*(hit?.t??1));
   l.stars.forEach((s,i)=>{if(segmentDistance(s,ball,end)<.22)stars.add(i);});
   if(stars.size===3&&segmentDistance(l.goal,ball,end)<.22){Object.assign(ball,l.goal);velocity.x=velocity.z=0;win();return;}
   Object.assign(ball,end);if(!hit)break;
   ball.x+=hit.nx*.0001;ball.z+=hit.nz*.0001;
   const inward=velocity.x*hit.nx+velocity.z*hit.nz;if(inward<0){velocity.x-=hit.nx*inward;velocity.z-=hit.nz*inward;}
   left*=1-hit.t;
  }
 }
 reset();
 return {
  mode,ball,velocity,tilt,stars,bounces,levelCount,
  get level(){return level;},get phase(){return phase;},get attempts(){return attempts;},get failures(){return failures;},get score(){return score;},get rounds(){return rounds;},get fall(){return fall;},get angles(){return angles;},get gate(){return gate();},
  get definition(){return mode==='balance'?balance():mode==='ricochet'?ricochet():maze();},
  reset,
  retry(){failures++;retry();accumulator=0;},
  setTilt(x:number,z:number){tilt.x=clamp(Number.isFinite(x)?x:0,-.32,.32);tilt.z=clamp(Number.isFinite(z)?z:0,-.32,.32);},
  turnMirror(index:number,angle:number){if(mode!=='ricochet'||phase==='playing'||phase==='won'||!Number.isFinite(angle)||index<0||index>=angles.length)return false;angles[index]=snapMirrorAngle(angle);return true;},
  launch(direction:Point){
   if(mode!=='ricochet'||phase!=='ready'||!Number.isFinite(direction.x)||!Number.isFinite(direction.z))return false;
   const d=Math.hypot(direction.x,direction.z);if(d<.001)return false;
   attempts++;bounces.clear();phase='playing';elapsed=0;velocity.x=direction.x/d*3.4;velocity.z=direction.z/d*3.4;return true;
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
    else if(mode==='maze'){phase='playing';stepMaze(STEP);}
    else if(phase==='playing'){elapsed+=STEP;stepRicochet(STEP);}
   }
  },
 };
}
