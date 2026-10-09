const replacements=[
  [
    "src/reference/game-state.js",
    "stageName='goal',hoopStreak=0",
    "stageName='goal',nextShotId=0,hoopStreak=0"
  ],
  [
    "src/reference/game-state.js",
    "VOLLEY_KEYS=['zMax'",
    "VOLLEY_KEYS=['shotId','throwCurve','zMax'"
  ],
  [
    "src/reference/game-state.js",
    "S.shot=true; S.shotT=0;",
    "S.shotId=++nextShotId; S.throwCurve=Math.abs(curve)>.12; ctx.noteStyle?.(); S.shot=true; S.shotT=0;"
  ],
  [
    "src/reference/game-state.js",
    "if(stageName==='goal'||stageName==='hoop'||stageName==='window') addCount(stageName);",
    "if(stageName==='goal'||stageName==='hoop'||stageName==='window') addCount(stageName); if(stageName==='goal'&&S.throwCurve)ctx.curvedGoal?.();"
  ],
  [
    "src/reference/game-state.js",
    "VOLLEY_MAX=6",
    "VOLLEY_MAX=3"
  ],
  [
    "src/reference/stages/cans.js",
    "let cleared=false, clangT=0, touched=false, fullShot=false, autoT=0;",
    "const attempt=createThrowAttempt();let cleared=false, clangT=0, touched=false, autoT=0;"
  ],
  [
    "src/reference/stages/cans.js",
    "cleared=false;\n    }",
    "cleared=false;attempt.reset();\n    }"
  ],
  [
    "src/reference/stages/cans.js",
    "if(!c) return false; wakeAll();",
    "if(!c) return false; attempt.invalidate();wakeAll();"
  ],
  [
    "src/reference/stages/cans.js",
    "onRespawn(){ if(cleared) resetCans(); touched=false; fullShot=false; },",
    "onRespawn(){ if(cleared) resetCans(); touched=false; },\n      onThrow(){attempt.launch(S.shotId);},"
  ],
  [
    "src/reference/stages/cans.js",
    "if(j>0){ hit(n,Math.max(0,-before)*0.7",
    "if(j>0){attempt.contact(S.shot?S.shotId:0,cans.every(c=>!c.down)); hit(n,Math.max(0,-before)*0.7"
  ],
  [
    "src/reference/stages/cans.js",
    "touched=true; fullShot=cans.every(onTable);",
    "touched=true;"
  ],
  [
    "src/reference/stages/cans.js",
    "if(S.shot && fullShot) chProgress('cansOne',1);",
    "if(attempt.complete()) chProgress('cansOne',1);"
  ],
  [
    "src/reference/stages/bowling.js",
    "let roll=0, knocked=0",
    "const attempt=createThrowAttempt();let roll=0, knocked=0"
  ],
  [
    "src/reference/stages/bowling.js",
    "if(all){ roll=0; knocked=0; }",
    "if(all){ roll=0; knocked=0; attempt.reset(); }"
  ],
  [
    "src/reference/stages/bowling.js",
    "if(!p) return false; for(const q of pins)",
    "if(!p) return false; attempt.invalidate();for(const q of pins)"
  ],
  [
    "src/reference/stages/bowling.js",
    "onRespawn(){\n",
    "onThrow(){attempt.launch(S.shotId);},\n      onRespawn(){\n"
  ],
  [
    "src/reference/stages/bowling.js",
    "if(j>0){ hit(n,Math.max(0,-before)*0.5",
    "if(j>0){attempt.contact(S.shot?S.shotId:0,pins.every(p=>!p.down&&!p.gone)); hit(n,Math.max(0,-before)*0.5"
  ],
  [
    "src/reference/stages/bowling.js",
    "if(roll===0) chProgress('strike1',1);",
    "if(roll===0&&attempt.complete()) chProgress('strike1',1);"
  ],
  [
    "src/reference/complete-game.js",
    "import * as Core",
    "import {challengeValue} from './challenge-rules.js';\nimport * as Core"
  ],
  [
    "src/reference/complete-game.js",
    "if(value<=before)return;store.data.challenges[id]=Math.min(c.goal,value);",
    "const next=challengeValue(id,before,c.goal,value);if(next===before)return;store.data.challenges[id]=next;"
  ],
  [
    "src/reference/complete-game.js",
    "const ctx={T,",
    "for(const id of ['hoop3','fair25'])chProgress(id,0);\n const resetStreak=()=>{hoopStreak=0;chProgress('hoop3',0);};\n const noteStyle=()=>{if(!store.data.stylesUsed.includes(style))store.data.stylesUsed.push(style);chProgress('styles5',store.data.stylesUsed.length);store.touch();};\n const ctx={noteStyle,curvedGoal:()=>chProgress('curve3',(store.data.challenges.curve3||0)+1),T,"
  ],
  [
    "src/reference/complete-game.js",
    "if(mode==='hoop')hoopStreak=0;miss();",
    "if(mode==='hoop')resetStreak();miss();"
  ],
  [
    "src/reference/complete-game.js",
    "function setMode(id){if(!builders[id])return;",
    "function setMode(id){if(!builders[id])return;if(mode!==id)resetStreak();"
  ],
  [
    "src/reference/complete-game.js",
    "if(!store.data.stylesUsed.includes(id))store.data.stylesUsed.push(id);chProgress('styles5',store.data.stylesUsed.length);",
    ""
  ],
  [
    "src/reference/complete-game.js",
    "ctx.onHoopMiss=()=>{hoopStreak=0;};",
    "ctx.onHoopMiss=resetStreak;"
  ],
  [
    "src/reference/complete-game.js",
    "mode==='hoop')hoopStreak=0;state.respawn();",
    "mode==='hoop')resetStreak();state.respawn();"
  ],
  [
    "src/reference/complete-game.js",
    "challenges:()=>challenges.map",
    "noteStyle,\n challenges:()=>challenges.map"
  ],
  [
    "src/reference/stages/fair.js",
    "function score(pts){\n      const curved=S.side.lengthSq()>1;",
    "function score(pts,curved=false){\n      if(!F.on||F.time<=0)return;"
  ],
  [
    "src/reference/stages/fair.js",
    "F.score=0; counts.fair=0;",
    "F.score=0; counts.fair=0;chProgress('fair25',0);"
  ],
  [
    "src/reference/stages/fair.js",
    "shoot(obj,point,dir){",
    "shoot(obj,point,dir){\n        if(!F.on&&F.over<=0){F.on=true;F.time=ROUND;F.score=0;counts.fair=0;chProgress('fair25',0);}if(!F.on)return false;"
  ],
  [
    "src/reference/stages/fair.js",
    "      collide(){\n        const P=S.pos;\n        if(!S.shot) return;\n        if(!F.on&&F.over<=0){ F.on=true; F.time=ROUND; F.score=0; counts.fair=0;chProgress('fair25',0); }\n        for(const d of ducks){ if(d.down>0) continue; d.g.getWorldPosition(wp); wp.y+=0.08;\n          if(sphereHit(wp,d.r,true)){ launchDuck(d,S.vel.clone().normalize(),Math.min(9,S.vel.length()*.55)+3); F.touched=true; squeak(1.35); thump(0.4); score(1); } }\n        for(const b of balloons){ if(b.popT>0) continue; if(sphereHit(b.m.position,b.r,false)){ b.popT=2.2; F.touched=true; startPopSound(); confetti.celebrate(b.m.position.clone()); score(2); } }\n        bellM.getWorldPosition(wp); if(F.swing<0.3&&sphereHit(wp,0.3,true)){ F.swing=1; F.touched=true; ding(); F.bellHits++; chProgress('bell3',(chState.bell3||0)+1); score(5); }\n        // The stall: the back panel and the counter bounce him back.\n        if(P.z-BR<FZ-0.97&&P.z>FZ-1.6&&Math.abs(P.x)<3.2&&P.y<2.6){ P.z=FZ-0.97+BR; if(S.vel.z<0){ hit(V(0,0,1),-S.vel.z,V(P.x,P.y,FZ-0.97)); S.vel.z=-S.vel.z*0.5; S.side.set(0,0,0); } }\n        if(Math.abs(P.x)<3.3&&P.z>FZ-0.3&&P.z<FZ+0.7&&P.y-BR<CY+0.08&&P.y>CY-0.3){ P.y=CY+0.08+BR; if(S.vel.y<0){ hit(UP,-S.vel.y,V(P.x,CY+0.08,P.z)); S.vel.y=-S.vel.y*0.45; } }\n      },\n",
    "      collide(){\n        const P=S.pos;\n        if(!S.shot||F.over>0) return;\n        if(!F.on&&F.over<=0){ F.on=true; F.time=ROUND; F.score=0; counts.fair=0;chProgress('fair25',0); }\n        for(const d of ducks){ if(d.down>0) continue; d.g.getWorldPosition(wp); wp.y+=0.08;\n          if(sphereHit(wp,d.r,true)){ launchDuck(d,S.vel.clone().normalize(),Math.min(9,S.vel.length()*.55)+3); F.touched=true; squeak(1.35); thump(0.4); score(1,S.throwCurve); } }\n        for(const b of balloons){ if(b.popT>0) continue; if(sphereHit(b.m.position,b.r,false)){ b.popT=2.2; F.touched=true; startPopSound(); confetti.celebrate(b.m.position.clone()); score(2,S.throwCurve); } }\n        bellM.getWorldPosition(wp); if(F.swing<0.3&&sphereHit(wp,0.3,true)){ F.swing=1; F.touched=true; ding(); F.bellHits++; chProgress('bell3',(chState.bell3||0)+1); score(5,S.throwCurve); }\n        // The stall: the back panel and the counter bounce him back.\n        if(P.z-BR<FZ-0.97&&P.z>FZ-1.6&&Math.abs(P.x)<3.2&&P.y<2.6){ P.z=FZ-0.97+BR; if(S.vel.z<0){ hit(V(0,0,1),-S.vel.z,V(P.x,P.y,FZ-0.97)); S.vel.z=-S.vel.z*0.5; S.side.set(0,0,0); } }\n        if(Math.abs(P.x)<3.3&&P.z>FZ-0.3&&P.z<FZ+0.7&&P.y-BR<CY+0.08&&P.y>CY-0.3){ P.y=CY+0.08+BR; if(S.vel.y<0){ hit(UP,-S.vel.y,V(P.x,CY+0.08,P.z)); S.vel.y=-S.vel.y*0.45; } }\n      },\n"
  ],
  [
    "src/reference/celebration.js",
    "{id:'pet5',     title:'ربّت على دحروج ٥ مرات في النظارة', en:'Pat Dahrooj 5 times in the headset', goal:5}",
    "{id:'skyPop5',  title:'فجّر ٥ دحاريج في السماء', en:'Pop 5 Dahroojs above your head', goal:5}"
  ],
  [
    "src/progression/challenges.ts",
    "['pet5', 5, 'ربّت على دحروج ٥ مرات', 'Pat Dahrooj 5 times']",
    "['skyPop5', 5, 'فجّر ٥ دحاريج في السماء', 'Pop 5 Dahroojs above your head']"
  ],
  [
    "src/reference/xr-runtime.js",
    "let chOpen=false,menuFresh=false,curved=false;",
    "let chOpen=false,chPage=0,menuFresh=false;\n    const CH_PAGE_SIZE=8,challengePages=[{x:PAD,y:874,w:190,h:54},{x:MW-PAD-190,y:874,w:190,h:54}];"
  ],
  [
    "src/reference/xr-runtime.js",
    "curved=Math.abs(c)>.3;",
    ""
  ],
  [
    "src/reference/xr-runtime.js",
    "if(curved&&g.mode()==='goal')g.chAdd?.('curve3');",
    ""
  ],
  [
    "src/reference/xr-runtime.js",
    "g.chAdd?.('pet5');",
    ""
  ],
  [
    "src/reference/xr-runtime.js",
    "chs.map(c=>c.value).join(',')",
    "chPage,chs.map(c=>c.value).join(',')"
  ],
  [
    "src/reference/xr-runtime.js",
    "const rowH=Math.min(64,740/Math.max(1,chs.length));\n        chs.forEach((x,k)=>{",
    "const rowH=84;\n        chs.slice(chPage*CH_PAGE_SIZE,(chPage+1)*CH_PAGE_SIZE).forEach((x,k)=>{"
  ],
  [
    "src/reference/xr-runtime.js",
    "c.font=font(700,Math.min(28,rowH*.46));c.fillText((ok?'✓ ':'')+title,rtl?MW-PAD-24:PAD+24,y+rowH*.5+2);",
    "c.font=font(700,36);const words=((ok?'✓ ':'')+title).split(' '),lines=[];let line='';for(const word of words){const next=line?line+' '+word:word;if(line&&c.measureText(next).width>IN-136){lines.push(line);line=word;}else line=next;}if(line)lines.push(line);lines.forEach((line,i)=>c.fillText(line,rtl?MW-PAD-24:PAD+24,y+rowH/2+12+(i-(lines.length-1)/2)*36));"
  ],
  [
    "src/reference/xr-runtime.js",
    "Math.min(26,rowH*.42)",
    "32"
  ],
  [
    "src/reference/xr-runtime.js",
    "// The rewards, under the list.",
    "challengePages.forEach((b,i)=>{c.fillStyle=hover.includes(3000+i)?'#e7d8bd':'#fffaf2';round(c,b.x,b.y,b.w,b.h,22);c.fill();c.fillStyle=INK;c.font=font(700,30);c.fillText(i?tr('التالي','Next'):tr('السابق','Previous'),b.x+b.w/2,b.y+36);});c.font=font(700,30);c.fillStyle=INK;c.fillText(tr(`${chPage+1} من ${Math.ceil(chs.length/CH_PAGE_SIZE)}`,`${chPage+1} of ${Math.ceil(chs.length/CH_PAGE_SIZE)}`),MW/2,910);\n        // The rewards, under the list."
  ],
  [
    "src/reference/xr-runtime.js",
    "if(chOpen&&x>=resetBtn.x",
    "if(chOpen){const i=challengePages.findIndex(b=>x>=b.x&&x<=b.x+b.w&&y>=b.y&&y<=b.y+b.h);if(i>=0)return 3000+i;}\n      if(chOpen&&x>=resetBtn.x"
  ],
  [
    "src/reference/xr-runtime.js",
    "if(i===2000){resetPress();return;}",
    "if(i===3000||i===3001){chPage=clamp(chPage+(i===3001?1:-1),0,Math.ceil(headsetChallenges().length/CH_PAGE_SIZE)-1);menu.key='';return;}\n      if(i===2000){resetPress();return;}"
  ],
  [
    "src/reference/xr-runtime.js",
    "...accButtons,resetBtn].map",
    "...accButtons,resetBtn,...challengePages.map((b,i)=>({...b,kind:'challengePage',id:String(i)}))].map"
  ],
  [
    "src/reference/xr-runtime.js",
    "function burst(p,style){",
    "function skyPop(p){if(p.y>eyeNow().y+.25*scaleNow())g.chAdd?.('skyPop5');}\n    function burst(p,style){\n      skyPop(p);"
  ],
  [
    "src/reference/xr-runtime.js",
    "const I=intro;I.balls.splice(I.balls.indexOf(b),1);I.popped++;",
    "const I=intro;skyPop(roomPoint(b.p));I.balls.splice(I.balls.indexOf(b),1);I.popped++;"
  ],
  [
    "src/reference/xr-runtime.js",
    "h.lastShot=clock;blast.fired++;",
    "h.lastShot=clock;blast.fired++;g.noteStyle?.();"
  ],
  [
    "src/reference/xr-runtime.js",
    "CROWD_MAX=300",
    "CROWD_MAX=120"
  ],
  [
    "src/reference/xr-runtime.js",
    "{n:130,R:2.6}:{n:220,R:4.4}",
    "{n:72,R:2.6}:{n:100,R:4.4}"
  ],
  [
    "src/reference/xr-runtime.js",
    "RESTS_MAX=36,REST_ROOM=26",
    "RESTS_MAX=8,REST_LIFE=12,REST_ROOM=26"
  ],
  [
    "src/reference/xr-runtime.js",
    "rests.push({m,style:",
    "rests.push({age:0,bornAt:performance.now(),m,style:"
  ],
  [
    "src/reference/xr-runtime.js",
    "models.forget?.(o.m.group);",
    "o.m.dispose();"
  ],
  [
    "src/reference/xr-runtime.js",
    "models.forget?.(r.m.group);",
    "r.m.dispose();"
  ],
  [
    "src/reference/xr-runtime.js",
    "function stepRests(dt){\n",
    "function stepRests(dt){\n      const now=performance.now();\n      for(let i=rests.length-1;i>=0;i--){const r=rests[i];r.age=(now-r.bornAt)/1000;if(r.age>=REST_LIFE){r.m?.dispose();rests.splice(i,1);}}\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "squash:[1+r.d*.75,1-r.d]});",
    "squash:[1+r.d*.75,1-r.d]});r.m.group.scale.multiplyScalar(Math.min(1,(REST_LIFE-r.age)/.75));"
  ],
  [
    "src/reference/xr-runtime.js",
    "blast.shots.length>=32",
    "blast.shots.length>=16"
  ],
  [
    "src/reference/xr-runtime.js",
    "for(let i=0;i<26;i++){",
    "for(let i=0;i<26&&blast.sparks.length<128;i++){"
  ],
  [
    "src/reference/xr-runtime.js",
    "for(let i=0;i<14;i++){",
    "for(let i=0;i<14&&blast.sparks.length<128;i++){"
  ],
  [
    "src/reference/xr-runtime.js",
    "for(let i=0;i<8;i++){\n        const m=new T.Mesh(SPARK",
    "for(let i=0;i<8&&blast.sparks.length<128;i++){\n        const m=new T.Mesh(SPARK"
  ],
  [
    "src/reference/xr-runtime.js",
    "for(let k=0;k<10;k++){\n        const m=new T.Mesh(SPARK",
    "for(let k=0;k<10&&I.sparks.length<80;k++){\n        const m=new T.Mesh(SPARK"
  ],
  [
    "src/reference/xr-runtime.js",
    "if(kind_!=='bubble'){const f=",
    "if(kind_!=='bubble'&&blast.sparks.length<128){const f="
  ],
  [
    "src/reference/xr-runtime.js",
    "if(s.kind==='firework'&&s.m&&!done&&Math.random()<.6)",
    "if(s.kind==='firework'&&s.m&&!done&&blast.sparks.length<128&&Math.random()<.6)"
  ],
  [
    "src/reference/xr-runtime.js",
    "for(const s of intro.sparks)rig.remove(s.m);",
    "for(const s of intro.sparks){rig.remove(s.m);s.m.material.dispose();}"
  ],
  [
    "src/reference/xr-runtime.js",
    "function clearBlast(){for(const s of [...blast.shots,...blast.sparks])if(s.m)scene.remove(s.m);",
    "function clearBlast(){for(const s of blast.shots)if(s.m)scene.remove(s.m);for(const s of blast.sparks){scene.remove(s.m);s.m.material.dispose();}"
  ]
];
export function challengeOverrides(file,s){
 for(const [path,before,after] of replacements)if(file===path){if(!s.includes(before))throw Error("Missing owner override: "+path+" "+before.slice(0,50));s=s.replaceAll(before,after);}
 if(["src/reference/stages/cans.js","src/reference/stages/bowling.js"].includes(file))s="import {createThrowAttempt} from '../challenge-rules.js';\n"+s;
 if(file==='src/reference/xr-runtime.js')s=s.replace('models.forget?.(slot.group);','slot.dispose();');
 return s;
}
