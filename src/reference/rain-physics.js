/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export function createReferenceRain(T,capacity){const V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z),clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),REAL_G=9.8,INTRO_R=.11,INTRO_STYLES=['jelly','fur','bubble'];let ballIds=0;const intro={balls:[],t:0,centre:V()},crowdSize=()=>({R:4.4}),g={},at=()=>{},roomPoint=p=>p;    function dropBall(delay){
      const I=intro,{R}=crowdSize(),c=I.centre,a=Math.random()*Math.PI*2,dist=.55+Math.sqrt(Math.random())*(R-.55);
      const rad=INTRO_R*(.75+Math.random()*.5),sp=.2+Math.random()*.5,dirA=Math.random()*Math.PI*2;
      I.balls.push({id:++ballIds,style:INTRO_STYLES[Math.random()*INTRO_STYLES.length|0],R:rad,p:V(c.x+Math.sin(a)*dist,c.y+.6+Math.random()*1.8,c.z-Math.cos(a)*dist),v:V(0,0,0),
        born:I.t+delay,gx:Math.cos(dirA)*sp,gz:Math.sin(dirA)*sp,hop:.5+Math.random()*2.5,d:0,dv:0,hit:0,blink:0,next:1+Math.random()*3});
    }

for(let i=0;i<capacity;i++)dropBall(Math.random()*2.6);return {balls:intro.balls,step(dt,head,count){intro.t+=dt;const ROOM=4.4,c=intro.centre,live=intro.balls.slice(0,count).filter(b=>intro.t>=b.born);      for(const b of live){
        const r=b.R,grounded=b.p.y<=r+.001&&Math.abs(b.v.y)<.01;
        b.v.y-=REAL_G*dt;
        if(grounded){
          b.v.x+=(b.gx-b.v.x)*Math.min(1,dt*2);b.v.z+=(b.gz-b.v.z)*Math.min(1,dt*2);
          b.hop-=dt;if(b.hop<=0){b.v.y=1.6+Math.random()*1.6;b.hop=1+Math.random()*2.5;b.dv-=3;
            if(Math.random()<.5){const a=Math.random()*Math.PI*2,sp=.2+Math.random()*.5;b.gx=Math.cos(a)*sp;b.gz=Math.sin(a)*sp;}}
        }
        b.p.addScaledVector(b.v,dt);
        if(b.p.y<r){
          const sp=-b.v.y;b.p.y=r;
          if(sp>.6){b.v.y=sp*.5;b.dv-=sp*2.2;b.hit=.2;if(sp>2&&g.bump&&Math.random()<.35)at(roomPoint(b.p),()=>g.bump(Math.min(1,sp/6)*.4));}
          else b.v.y=0;
        }
        // Wander anywhere in the ring around you: off its edge, or right at your feet, head back in.
        const ox=b.p.x-c.x,oz=b.p.z-c.z,od=Math.hypot(ox,oz)||1,hd=Math.hypot(b.p.x-head.x,b.p.z-head.z);
        if(od>ROOM||hd<.45){
          const a=Math.random()*Math.PI*2,rr=.7+Math.sqrt(Math.random())*(ROOM-.9),sp=.25+Math.random()*.4;
          const tx=c.x+Math.sin(a)*rr-b.p.x,tz=c.z-Math.cos(a)*rr-b.p.z,tl=Math.hypot(tx,tz)||1;b.gx=tx/tl*sp;b.gz=tz/tl*sp;
        }
        if(od>ROOM+.4){b.p.x=c.x+ox/od*(ROOM+.4);b.p.z=c.z+oz/od*(ROOM+.4);}
        b.dv+=(-b.d*320-b.dv*12)*dt;b.d=clamp(b.d+b.dv*dt,-.3,.45);
        b.hit=Math.max(0,b.hit-dt);b.next-=dt;if(b.next<=0){b.blink=.14;b.next=2+Math.random()*3;}b.blink=Math.max(0,b.blink-dt);
      }
      // Pushing apart, on a coarse grid so a big crowd stays cheap.
      const cell=new Map(),key=(x,z)=>(Math.floor(x/.3)*73856093)^(Math.floor(z/.3)*19349663);
      for(const b of live){const k=key(b.p.x,b.p.z);let l=cell.get(k);if(!l)cell.set(k,l=[]);l.push(b);}
      const n=V(0,0,0),rel=V(0,0,0);
      for(const a of live){const gx=Math.floor(a.p.x/.3),gz=Math.floor(a.p.z/.3);
        for(let ix=-1;ix<=1;ix++)for(let iz=-1;iz<=1;iz++){const l=cell.get(((gx+ix)*73856093)^((gz+iz)*19349663));if(!l)continue;
          for(const b of l){if(b===a||a.id>b.id)continue;
            n.copy(b.p).sub(a.p);const len=n.length(),min=a.R+b.R;if(!(len>0&&len<min))continue;
            n.divideScalar(len);const push=(min-len)/2;a.p.addScaledVector(n,-push);b.p.addScaledVector(n,push);
            const rv=rel.copy(b.v).sub(a.v).dot(n);if(rv<0){a.v.addScaledVector(n,rv*.8);b.v.addScaledVector(n,-rv*.8);}}}}

return live;},reset(b){const index=intro.balls.indexOf(b);dropBall(.3+Math.random()*1.5);const next=intro.balls.pop();Object.assign(intro.balls[index],next);}};}
