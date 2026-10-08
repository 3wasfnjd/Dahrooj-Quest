/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
  const G=60, MAX_HEARTS=3, MAX_WIDTH=18;
  // Touch controls like the other modes: drag sideways to roll, tap to jump.
  const HIT=.82; // hazard contact radius, smaller than the drawn ball
  const RUN=10, JUMP=28, ACCEL=70, ACCEL_ICE=14, ACCEL_AIR=34, COYOTE=.1, BUFFER=.13;
  // Small thrown balls: aim at the nearest monster ahead, otherwise fly straight ahead.
  const SHOT_SPEED=18, SHOT_LIFE=1.1, SHOT_COOL=.32, SHOT_MAX=3, SHOT_R=.32, AIM_RANGE=10;
  const THEMES=[
    {name:'meadow',top:'#7f9a5b'},{name:'cliffs',top:'#a38b74'},
    {name:'caves',top:'#77728a'},{name:'snow',top:'#e8f1f5'}
  ];
  // [x as a fraction of the playable width, top surface height, width, options]
  const SECTIONS=[
    {from:0,platforms:[
      [.32,4,4.2],[.70,8,4,{crawler:1}],[.36,12,3.6],[.66,16,3.6,{move:[.14,1.1]}],
      [.38,20,3.4,{crawler:1}],[.14,24,3.2],[.50,28,3.6],[.82,32,3.2]],
      bats:[],icicles:[]},
    {from:36,platforms:[
      [.28,40,3.2,{crumble:1}],[.66,44,3.6,{spikes:[0,.45]}],[.36,48,3,{crumble:1}],
      [.74,52,3.2,{spitter:.75}],[.44,56,2.8],[.16,60,3,{crumble:1}],[.56,64,3.4,{crawler:1}],[.84,68,2.8]],
      bats:[[46.5,.12,.62,.7,0],[58.5,.38,.88,.8,2]],icicles:[]},
    {from:72,platforms:[
      [.5,76,3.2,{move:[.2,.9]}],[.2,80,3,{spitter:.3}],[.66,84,2.8,{move:[.16,1.6]}],
      [.38,88,3,{spikes:[.55,1]}],[.78,92,2.6,{crumble:1}],[.5,96,3,{crawler:1}],
      [.2,100,2.8,{move:[.12,1.3]}],[.6,104,2.8,{spitter:.7}]],
      bats:[[86.5,.15,.7,1,1],[98.5,.1,.5,1.1,0],[98.5,.55,.9,1,3]],icicles:[]},
    {from:108,platforms:[
      [.3,112,3.2,{ice:1}],[.7,116,3,{ice:1}],[.4,120,2.8,{ice:1,crumble:1}],[.12,124,2.8,{ice:1}],
      [.5,128,2.8,{ice:1,move:[.15,1.2]}],[.84,132,2.6,{ice:1}],[.52,136,2.8,{ice:1,crawler:1}],
      [.2,140,2.6,{ice:1}],[.6,144,2.6,{ice:1,spitter:.5}]],
      bats:[[122.5,.3,.9,1.1,1],[134.5,.15,.7,1.3,2]],icicles:[[.68,119.5],[.5,131.5],[.22,147.4]]}
  ];
  const TOP=148;
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));

  function buildLevel(width){
    const platforms=[],monsters=[],bats=[],icicles=[];
    const full=(y,theme,extra)=>({x0:0,x1:width,y,theme,full:true,dx:0,...extra});
    platforms.push(full(0,0,{ground:true,checkpoint:0}));
    SECTIONS.forEach((section,s)=>{
      for(const [fx,y,w,o={}] of section.platforms){
        const x0=clamp(fx*width-w/2,.2,width-.2-w);
        const p={x0,x1:x0+w,base:x0,w,y,theme:s,dx:0,ice:!!o.ice,spikes:o.spikes||null,
          move:o.move?{amp:o.move[0]*width,speed:o.move[1],phase:y}:null,
          crumble:o.crumble?{state:'solid',t:0}:null};
        platforms.push(p);
        if(o.crawler)monsters.push({type:'crawler',plat:p,x:p.x0+w/2,dir:y%8?1:-1,speed:1.7,alive:true,t:0});
        if(o.spitter!=null)monsters.push({type:'spitter',plat:p,f:o.spitter,alive:true,cool:1.2+(y%3)*.4,t:0,swell:0});
      }
      for(const [y,a,b,speed,phase] of section.bats)bats.push({type:'bat',y0:y,x0:a*width,x1:b*width,speed,phase,alive:true,x:0,y,t:0});
      for(const [fx,y] of section.icicles)icicles.push({x:clamp(fx*width,.6,width-.6),y0:y,y,state:'hang',t:0,vy:0});
    });
    const ledges=[36,72,108];
    ledges.forEach((y,i)=>platforms.push(full(y,i,{checkpoint:i+1})));
    platforms.push(full(TOP,3,{summit:true}));
    return {width,platforms,monsters:[...monsters,...bats],icicles,seeds:[]};
  }

  function createState(width){
    const level=buildLevel(width);
    return {...level,time:0,events:[],checkpoint:0,won:false,wonAt:0,startedAt:0,
      input:{dir:0,buffer:0},shots:[],
      ball:{x:width/2,y:1,vx:0,vy:0,grounded:true,on:level.platforms[0],hearts:MAX_HEARTS,inv:0,dead:0,d:0,dv:0,best:0,coyote:0,stun:0,facing:1,cool:0}};
  }
  function solid(p){return !p.crumble||p.crumble.state!=='fallen';}
  function checkpointPlatform(state){return state.platforms.find(p=>p.checkpoint===state.checkpoint);}
  function resetHazards(state){
    for(const p of state.platforms)if(p.crumble){p.crumble.state='solid';p.crumble.t=0;}
    for(const m of state.monsters){m.alive=true;m.t=0;if(m.type==='crawler')m.x=(m.plat.x0+m.plat.x1)/2;}
    for(const i of state.icicles){i.state='hang';i.y=i.y0;i.vy=0;i.t=0;}
    state.seeds.length=0;state.shots.length=0;
  }
  function respawn(state){
    const b=state.ball,p=checkpointPlatform(state);
    Object.assign(b,{x:state.width/2,y:p.y+1,vx:0,vy:0,grounded:true,on:p,hearts:MAX_HEARTS,inv:1,dead:0,d:0,dv:0,coyote:0,stun:0});
    state.input.buffer=0;
    resetHazards(state);
  }
  function restart(state){
    state.checkpoint=0;state.won=false;state.startedAt=state.time;state.ball.best=0;respawn(state);state.ball.inv=0;
  }
  function hurt(state,fromX){
    const b=state.ball;
    if(b.inv>0||b.dead||state.won)return;
    b.hearts--;state.events.push({type:'hurt'});
    if(b.hearts<=0){b.dead=.001;b.grounded=false;state.events.push({type:'pop',x:b.x,y:b.y});return;}
    b.inv=1.6;b.stun=.3;b.grounded=false;b.on=null;b.coyote=0;b.vy=14;b.vx=(b.x>=fromX?1:-1)*8;
  }
  // dir: -1 left, 0 stop, 1 right (fractions allowed). jump() is buffered briefly before landing.
  function setDir(state,dir){state.input.dir=clamp(Number(dir)||0,-1,1);}
  function jump(state){if(!state.ball.dead&&!state.won)state.input.buffer=BUFFER;}
  function monsterY(m){return m.type==='crawler'?m.plat.y+.6:m.y;}
  function throwBall(state){
    const b=state.ball;
    if(b.dead||state.won||b.cool>0||state.shots.length>=SHOT_MAX)return false;
    let vx=b.facing*SHOT_SPEED,vy=3,best=AIM_RANGE;
    for(const m of state.monsters){
      if(!m.alive)continue;
      const dx=m.x-b.x,dy=monsterY(m)-b.y,d=Math.hypot(dx,dy);
      // Ahead of Dahrooj, within about 70 degrees of the facing direction; lead for the shot's drop.
      if(d<best&&dx*b.facing>0&&Math.abs(dy)<Math.abs(dx)*2.8){best=d;vx=dx/d*SHOT_SPEED;vy=dy/d*SHOT_SPEED+G*.125*d/SHOT_SPEED;}
    }
    state.shots.push({x:b.x+Math.sign(vx||b.facing)*.9,y:b.y+.2,vx,vy,t:0});
    b.cool=SHOT_COOL;state.events.push({type:'throw'});return true;
  }
  function approach(v,target,rate){return v<target?Math.min(target,v+rate):Math.max(target,v-rate);}
  function land(state,p,impact){
    const b=state.ball;
    b.y=p.y+1;b.on=p;b.dv+=Math.min(18,impact*.9);
    state.events.push({type:'land',power:Math.min(1,impact/30)});
    b.vy=0;b.grounded=true;b.coyote=0;
    if(p.crumble&&p.crumble.state==='solid'){p.crumble.state='shaking';p.crumble.t=0;}
    if(p.checkpoint!=null&&p.checkpoint>state.checkpoint){state.checkpoint=p.checkpoint;state.events.push({type:'checkpoint',index:p.checkpoint});}
    if(p.summit&&!state.won){state.won=true;state.wonAt=state.time;state.events.push({type:'summit',time:state.time-state.startedAt});}
  }
  function onSpikes(p,x){
    if(!p.spikes)return false;
    const a=p.x0+p.spikes[0]*(p.x1-p.x0),c=p.x0+p.spikes[1]*(p.x1-p.x0);
    return x>a-.45&&x<c+.45;
  }

  function stepWorld(state,dt){
    state.time+=dt;
    for(const p of state.platforms){
      if(p.move){const x0=p.base+p.move.amp*Math.sin(state.time*p.move.speed+p.move.phase);p.dx=x0-p.x0;p.x0=x0;p.x1=x0+p.w;}
      if(p.crumble){
        const c=p.crumble;c.t+=dt;
        if(c.state==='shaking'&&c.t>.6){c.state='fallen';c.t=0;}
        else if(c.state==='fallen'&&c.t>3){c.state='solid';c.t=0;}
      }
    }
    const b=state.ball;
    for(const m of state.monsters){
      m.t+=dt;
      if(!m.alive)continue;
      if(m.type==='crawler'){
        m.x+=m.dir*m.speed*dt+m.plat.dx;
        if(m.x<m.plat.x0+.7){m.x=m.plat.x0+.7;m.dir=1;}
        if(m.x>m.plat.x1-.7){m.x=m.plat.x1-.7;m.dir=-1;}
        if(!solid(m.plat))m.alive=false;
      }else if(m.type==='bat'){
        const k=(Math.sin(m.t*m.speed+m.phase)+1)/2;m.x=m.x0+(m.x1-m.x0)*k;m.y=m.y0+.6*Math.sin(m.t*3.1+m.phase);
      }else if(m.type==='spitter'){
        m.x=m.plat.x0+m.f*(m.plat.x1-m.plat.x0);m.y=m.plat.y+.75;
        m.cool-=dt;m.swell=Math.max(0,1-m.cool/.5);
        if(m.cool<=0){
          m.cool=2.4;
          if(!b.dead&&Math.abs(b.y-m.y)<5&&Math.abs(b.x-m.x)<12){
            const dir=b.x>=m.x?1:-1;state.seeds.push({x:m.x+dir*.6,y:m.y+.1,vx:dir*7,t:0});state.events.push({type:'spit'});
          }
        }
      }
    }
    for(const s of state.seeds){s.x+=s.vx*dt;s.t+=dt;}
    state.seeds=state.seeds.filter(s=>s.t<3&&s.x>-1&&s.x<state.width+1);
    for(const i of state.icicles){
      i.t+=dt;
      if(i.state==='hang'&&!b.dead&&Math.abs(b.x-i.x)<1.7&&b.y<i.y&&b.y>i.y-9){i.state='shake';i.t=0;}
      else if(i.state==='shake'&&i.t>.45){i.state='fall';i.t=0;i.vy=0;}
      else if(i.state==='fall'){i.vy-=G*.8*dt;i.y+=i.vy*dt;if(i.y<i.y0-12){i.state='gone';i.t=0;}}
      else if(i.state==='gone'&&i.t>3){i.state='hang';i.y=i.y0;i.t=0;}
    }
  }

  function stepBall(state,dt){
    const b=state.ball,W=state.width;
    b.inv=Math.max(0,b.inv-dt);
    b.dv+=(-b.d*260-b.dv*12)*dt;b.d=clamp(b.d+b.dv*dt,-.25,.4);
    if(b.dead){b.dead+=dt;if(b.dead>1.1)respawn(state);return;}
    b.stun=Math.max(0,b.stun-dt);b.coyote=Math.max(0,b.coyote-dt);
    const input=state.input,dir=b.stun>0||state.won?0:input.dir;
    input.buffer=Math.max(0,input.buffer-dt);b.cool=Math.max(0,b.cool-dt);
    if(dir)b.facing=Math.sign(dir);
    if(b.grounded){
      const p=b.on;
      if(!p||!solid(p)){b.grounded=false;b.on=null;b.coyote=COYOTE;}
      else{
        b.x+=p.dx;b.y=p.y+1;
        b.vx=approach(b.vx,dir*RUN,(p.ice?ACCEL_ICE:ACCEL)*dt);
        b.x+=b.vx*dt;
        if(!p.full&&(b.x<p.x0-.3||b.x>p.x1+.3)){b.grounded=false;b.on=null;b.coyote=COYOTE;}
        else if(onSpikes(p,b.x))hurt(state,(p.x0+p.x1)/2);
      }
    }
    if(input.buffer>0&&(b.grounded||b.coyote>0)&&!b.dead){
      b.vy=JUMP;b.grounded=false;b.on=null;b.coyote=0;input.buffer=0;b.dv-=6;
      state.events.push({type:'launch',power:.6});
    }
    if(!b.grounded){
      const prevBottom=b.y-1;
      b.vy=Math.max(-40,b.vy-G*dt);
      if(b.stun<=0)b.vx=approach(b.vx,dir*RUN,ACCEL_AIR*dt);
      b.x+=b.vx*dt;b.y+=b.vy*dt;
      if(b.vy<=0){
        for(const p of state.platforms){
          if(!solid(p))continue;
          if(prevBottom>=p.y-.001&&b.y-1<=p.y&&b.x>=p.x0-.35&&b.x<=p.x1+.35){
            land(state,p,-b.vy);
            if(onSpikes(p,b.x))hurt(state,(p.x0+p.x1)/2);
            break;
          }
        }
      }
    }
    if(b.x<1){b.x=1;b.vx=Math.abs(b.vx)*.55;}
    if(b.x>W-1){b.x=W-1;b.vx=-Math.abs(b.vx)*.55;}
    b.best=Math.max(b.best,b.y-1);
    // Monsters, seeds and icicles.
    for(const m of state.monsters){
      if(!m.alive||b.dead)continue;
      const my=m.type==='crawler'?m.plat.y+.6:m.y,r=m.type==='bat'?.45:.7;
      if(Math.hypot(b.x-m.x,b.y-my)>HIT+r)continue;
      if(m.type!=='bat'&&b.vy<-2&&b.y>my+.3){
        m.alive=false;m.t=0;b.vy=18;b.grounded=false;b.on=null;state.events.push({type:'stomp',x:m.x,y:my});
      }else hurt(state,m.x);
    }
    for(const s of state.seeds)if(!b.dead&&Math.hypot(b.x-s.x,b.y-s.y)<HIT+.2){s.t=99;hurt(state,s.x);}
    // Thrown balls: one hit defeats any monster and knocks seeds out of the air.
    for(const shot of state.shots){
      shot.t+=dt;shot.vy-=G*.25*dt;shot.x+=shot.vx*dt;shot.y+=shot.vy*dt;
      if(shot.x<0||shot.x>W)shot.t=SHOT_LIFE;
      for(const m of state.monsters){
        if(!m.alive||shot.t>=SHOT_LIFE)continue;
        const r=m.type==='bat'?.55:.75;
        if(Math.hypot(shot.x-m.x,shot.y-monsterY(m))<r+SHOT_R){m.alive=false;m.t=0;shot.t=SHOT_LIFE;state.events.push({type:'kill',x:m.x,y:monsterY(m)});}
      }
      for(const seed of state.seeds)if(shot.t<SHOT_LIFE&&Math.hypot(shot.x-seed.x,shot.y-seed.y)<.3+SHOT_R){seed.t=99;shot.t=SHOT_LIFE;}
    }
    state.shots=state.shots.filter(shot=>shot.t<SHOT_LIFE);
    for(const i of state.icicles)if(i.state==='fall'&&!b.dead&&Math.hypot(b.x-i.x,b.y-(i.y-.6))<HIT+.2){i.state='gone';i.t=0;hurt(state,i.x);}
  }

  function step(state,dt){
    const n=Math.max(1,Math.ceil(dt/(1/240)));
    for(let i=0;i<n;i++){stepWorld(state,dt/n);stepBall(state,dt/n);}
  }

  // Exported for logic tests (reachability and rules) without a browser.
  const api={G,RUN,JUMP,SHOT_COOL,SHOT_MAX,MAX_HEARTS,MAX_WIDTH,TOP,SECTIONS,buildLevel,createState,step,setDir,jump,throwBall,hurt,respawn,restart,solid};

export default api;
