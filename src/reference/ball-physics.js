/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export function referenceBallPhysics(ctx){const {S,GRAV,BR,UP,V,hit,waterHook,splash,miss}=ctx;const xrOn=()=>true;const outsideView=()=>false;return function step(dt){const stage=ctx.stage;function ballStepAt(dt,extra){
    // In the headset a finished throw can stay in the world (restHook) instead of vanishing.
    const P=S.pos, v=S.vel, end=()=>{ S.shot=false;return false; };
    S.prevZ=P.z; S.prevY=P.y;
    if(!S.grounded){ v.y-=GRAV*dt; v.x+=S.side.x*dt; v.z+=S.side.z*dt; }
    v.multiplyScalar(Math.pow(0.9,dt));
    P.addScaledVector(v,dt);
    // The headset world's pond: Dahrooj drops in with a splash, sinks about half way and bobs there, slowed by the water.
    const wet=waterHook&&xrOn()&&waterHook.depth(P.x,P.z)>0;
    if(wet&&P.y<BR){
      if(!S.wet){ S.wet=true; waterHook.splash(P,Math.min(1,(-v.y+Math.hypot(v.x,v.z)*.3)/12)); splash(Math.min(1,-v.y/10)); S.side.set(0,0,0); }
      S.grounded=false;
      v.y+=(GRAV+(-BR*0.2-P.y)*38-v.y*4.5)*dt;
      const f=Math.pow(0.3,dt); v.x*=f; v.z*=f;
      if(P.y<-BR*0.85){ P.y=-BR*0.85; if(v.y<0) v.y=0; }
    }else{
    if(P.y>BR*1.2) S.wet=false;
    if(P.y<BR){
      P.y=BR;
      if(v.y<-1.4){ hit(UP,-v.y,V(P.x,0,P.z)); v.y=-v.y*0.55; v.x*=0.85; v.z*=0.85; S.side.set(0,0,0); }
      else { v.y=0; S.grounded=true; }
    } else if(S.grounded && P.y>BR+0.01) S.grounded=false;
    }
    // In the headset Dahrooj rolls on longer before he settles.
    // The bowling lane is slick, so Dahrooj rolls all the way to the pins.
    if(S.grounded){ const f=Math.pow(stage.friction||(xrOn()?0.7:0.35),dt); v.x*=f; v.z*=f; S.side.set(0,0,0); }
    stage.collide();
    if(extra){ if(stage.ballContact) stage.ballContact(); } else stage.update(dt);
    if(S.shot){
      S.shotT+=dt;
      const still=(S.grounded||S.wet) && v.length()<0.35;
      S.restT=still?S.restT+dt:0;
      if(!xrOn()&&outsideView()){
        if(S.scoredT<=0) miss(); // Keep each mode's miss bookkeeping.
        return end();
      }
      else if(S.scoredT>0){ S.scoredT-=dt; if(S.scoredT<=0) return end(); }
      else if(S.missT>0){ S.missT-=dt; if(S.missT<=0) return end(); }
      else if(S.restT>0.5 || S.shotT>(stage.shotTime||5) || Math.abs(P.x)>S.xMax || P.z<-34 || P.z>S.zMax) miss();
    }
    return false;
  }return ballStepAt(dt,true);};}
