/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
export function createReferenceState(ctx){const {T,V,UP,BR,GRAV,S,confetti,whoosh,thump,splash,addCount}=ctx;let stage=ctx.stage,time=0,stageName='goal',hoopStreak=0,restHook=null,waterHook=null;const xrOn=()=>true,outsideView=()=>false,aim={down:false},splats3=[],fxDash=[],VOLLEY_KEYS=['zMax','xMax','shot','shotT','scoredT','missT','mood','moodT','moodNext','idle','restT','hitT','blink','nextBlink','grounded','lastHit','prevZ','prevY','d','dv','wet'],VOLLEY_VECS=['pos','vel','side','axis'],volley=[],VOLLEY_MAX=6;function hit(n,speed,contact){const s=Math.min(1,speed/14);if(s<.05)return;S.axis.copy(n);if(S.d<0)S.d*=.3;S.dv+=4+s*16;S.lastHit=time;thump(s);if(s>.55)S.hitT=.28;}
function react(kind,dur,next){ S.mood=kind; S.moodT=dur; S.moodNext=next||null; }
function success(){ if(S.scoredT>0||S.missT>0) return; S.scoredT=1.7; react('joy',1.7); confetti.celebrate(S.pos); if(stageName==='goal'||stageName==='hoop'||stageName==='window') addCount(stageName); }
function miss(){
    if(stageName==='hoop'){hoopStreak=0;ctx.onHoopMiss?.();}
    if(S.scoredT>0||S.missT>0) return;
    if(stage.touched && stage.touched()){ S.missT=1.0; return; }
    S.missT=1.7;
    if(S.mood==='wide' && S.moodT>0) S.moodNext='laugh'; else react('laugh',1.7);
  }
function ooh(){ if(S.shot && S.scoredT<=0 && S.missT<=0 && S.mood!=='wide') react('wide',0.55); }
function respawn(){
    
    S.missT=0; S.mood=null; S.moodT=0; S.idle=0;
    S.pos.set(0,BR+1.0,0); S.vel.set(0,0,0); S.side.set(0,0,0); S.wet=false; S.shot=false; S.scoredT=0; S.restT=0; S.d=0; S.dv=0; S.grounded=false; S.zMax=6; S.xMax=16;
    if(stage && stage.onRespawn) stage.onRespawn();
  }
function throwWith(v,curve=0){
    const sp=v.length();
    S.held=false; S.vel.copy(v); S.side.set(0,0,0);
    if(curve){ const f=V(v.x,0,v.z); if(f.lengthSq()>1e-6){ f.normalize(); S.side.set(-f.z,0,f.x).multiplyScalar(Math.max(-1,Math.min(1,curve))*9); } }
    S.shot=true; S.shotT=0; S.grounded=false; S.prevZ=S.pos.z; S.prevY=S.pos.y;
    // In AR the player can stand far behind the court: the out-of-bounds lines follow the throw.
    S.zMax=Math.max(6,S.pos.z+3); S.xMax=Math.max(16,Math.abs(S.pos.x)+6);
    S.axis.copy(UP); S.dv-=6+Math.min(1,sp/18)*8;
    whoosh(Math.min(1,sp/18));
    if(stage.onThrow) stage.onThrow();
  }
function ballFace(){
    if(S.hitT>0) return 'closed';
    if(S.mood && S.moodT>0) return S.mood;
    if(S.held) return 'focus';
    if(S.shot && !S.grounded && S.vel.length()>9) return 'wide';
    return 'open';
  }
function ballStepAt(dt,extra){
    // In the headset a finished throw can stay in the world (restHook) instead of vanishing.
    const P=S.pos, v=S.vel, end=()=>{ if(restHook&&xrOn()) restHook(P.clone(),v.clone()); if(extra) return true; respawn(); return false; };
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
  }
function snapBall(){ const o={}; for(const k of VOLLEY_KEYS) o[k]=S[k]; for(const k of VOLLEY_VECS) o[k]=S[k].clone(); return o; }
function loadBall(o){ for(const k of VOLLEY_KEYS) S[k]=o[k]; for(const k of VOLLEY_VECS) S[k].copy(o[k]); }
function another(){
    if(!S.shot) return false;
    if(volley.length>=VOLLEY_MAX) volley.shift();
    volley.push(snapBall());
    S.missT=0; S.mood=null; S.moodT=0; S.idle=0; S.shot=false; S.scoredT=0; S.restT=0; S.d=0; S.dv=0; S.vel.set(0,0,0); S.side.set(0,0,0);
    return true;
  }
function stepVolley(dt){
    if(!volley.length) return;
    const main=snapBall(), held=S.held; S.held=false;
    for(let i=volley.length-1;i>=0;i--){
      loadBall(volley[i]);
      const done=ballStepAt(dt,true);
      S.dv+=((0-S.d)*420-S.dv*13)*dt; S.d=Math.max(-0.3,Math.min(0.5,S.d+S.dv*dt));
      if(S.moodT>0) S.moodT-=dt; S.hitT=Math.max(0,S.hitT-dt);
      if(done) volley.splice(i,1); else volley[i]=snapBall();
    }
    loadBall(main); S.held=held;
  }
function update3(dt){
    const P=S.pos, v=S.vel;
    if(S.held){stage.update(dt);stepVolley(dt);}else{
    ballStepAt(dt,false);
    stepVolley(dt);
    }
    if(S.moodT>0){ S.moodT-=dt; if(S.moodT<=0){ if(S.moodNext){ react(S.moodNext,1.4); } else S.mood=null; } }
    if(S.mood==='joy' && S.grounded && S.vel.y===0 && S.moodT>0.5){ S.vel.y=3.6; S.grounded=false; }
    if(!S.shot && !aim.down) S.idle+=dt; else S.idle=0;
    const speed=v.length();
    let target=0;
    if(aim.down && S.grounded){ const pull=Math.max(0,aim.pts[0].y-aim.y); S.axis.copy(UP); target=Math.min(0.22,pull/H*0.9); }
    else if(!S.grounded && speed>2 && time-S.lastHit>0.12){ if(Math.abs(S.d)<0.12) S.axis.copy(v).normalize(); target=-Math.min(0.22,speed/90); }
    else if(S.grounded){ S.axis.copy(UP); target=0.018*Math.sin(time*2.4); }
    S.dv+=((target-S.d)*420-S.dv*13)*dt;
    S.d=Math.max(-0.3,Math.min(0.5,S.d+S.dv*dt));
    S.nextBlink-=dt; if(S.nextBlink<=0){S.blink=0.14; S.nextBlink=2+Math.random()*3.5;}
    S.blink=Math.max(0,S.blink-dt); S.hitT=Math.max(0,S.hitT-dt);
    for(let i=splats3.length-1;i>=0;i--){ const s=splats3[i]; s.life+=dt; const k=s.life/s.max; s.m.material.opacity=0.9*(1-k*k); if(k>=1){scene.remove(s.m); s.m.material.dispose(); splats3.splice(i,1);} }
    for(let i=fxDash.length-1;i>=0;i--){ fxDash[i].life+=dt; if(fxDash[i].life>fxDash[i].max) fxDash.splice(i,1); }
  }
return {react,success,miss,ooh,respawn,throwWith,ballFace,hit,another,volley:()=>volley,clearVolley:()=>{volley.length=0;},setRestHook:fn=>{restHook=fn;},setWater:h=>{waterHook=h;},setStage(s,id){stage=s;stageName=id;volley.length=0;respawn();},step(dt){time+=dt;ctx.time=time;for(let i=0;i<3;i++)update3(dt/3);},get time(){return time;}};}