import {menuDepth} from './menu-depth';
import {ballImpactSpeed} from './ball-impact';
import {createScorePopup} from './score-popup';
import {GOAL_AIM_Z} from './court-layout.js';
import {createChallengeList} from './challenge-list.js';
import {DAHROOJ_COLORS,DAHROOJ_SWATCHES} from './palette.js';
/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
import {createReferenceCharacter} from './character.js';
import {createReferenceNature} from './nature.js';
import {createReferenceAmbience} from './ambience.js';
import {createReferenceMountain} from './mountain-complete.js';
/* Dahrooj on Meta Quest: WebXR VR and AR for the 3D modes. Aboden Games.
   The courts are built in game metres; the headset shows them smaller (VR at a half, AR as a model on a
   surface you pick) and speeds time up to match, so falls look like real gravity.
   Dahrooj waits by your hand: grab with the trigger (or a pinch), swing and let go, or pull him back in
   the slingshot, and grab again at once for the next throw. Flip or raise the left hand for the menu. */
export const createReferenceXR=(() => {
  'use strict';
  // AR: the surface you aim at sets the court's size (the floor or a wall at an eighth, a table at a sixteenth), and while
  // you choose the spot the right stick makes it bigger or smaller. Once pinned, the size stays.
  const VR_SCALE=2, AR_SCALE=8, AR_TABLE=16, AR_ZOOM_MIN=.35, AR_ZOOM_MAX=2.6, REAL_G=9.8;
  // Throw speed per metre per second of hand speed, slingshot speed per metre of pull, and limits (m/s, m).
  // Strong enough to reach targets at the cans' distance (about ten real metres in VR).
  const GAIN=2, SLING_K=23, SLING_MIN=.06, SLING_MAX=.65, MIN_THROW=1, MAX_SPEED=46, SPAN=.04;
  // Headset texts in Arabic and English: [id, Arabic, English].
  const MODES=[['goal','مرمى','Goal'],['hoop','سلة','Hoop'],['window','شباك','Window'],['cans','علب','Cans'],['bowling','بولينغ','Bowling'],['bricks','الطوب','Bricks'],['fair','ملاهي','Fair'],['climb','الجبل','Summit'],['rain','مطر دحاريج','Dahrooj Rain']];
  const STYLES=[['jelly','جيلي','Jelly'],['fabric','قماش','Fabric'],['clay','صلصال','Clay'],['fur','فرو','Fur'],['bubble','فقاعة','Bubble']];
  const XR_MODES=new Set(MODES.map(m=>m[0]));
  let lang='ar';try{if(localStorage.getItem('dahrooj-lang')==='en')lang='en';}catch(_){}
  const tr=(ar,en)=>lang==='en'?en:ar;
  const LABEL=id=>{const m=MODES.find(m=>m[0]===id);return m?tr(m[1],m[2]):'';};
  const INK='#2c2d3d',PAPER='#fffaf2';
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));

  return g=>{
    const {T,renderer,scene,camera,S,BR,V}=g;
    let session=null,kind=null,lastTime=0,holder=null,holdT=0,clock=0,paper='',arScale=AR_SCALE,arZoom=1,popT=1,frames=0;
    // Throw styles: 'trigger' (aim, hold to charge, let go), 'hand' (a real swing), 'sling'.
    let throwStyle='trigger',menuToggled=false,parked=false,placing=false,anchor=null,placedFor='',menuOpen=false,intro=null;
    // Summit: a model mountain on the table (AR) or on a plinth in front of you (VR).
    // The Summit's size in metres per game unit: life-size in the VR world, tabletop in AR; the right stick changes it.
    // VR: the mountain stands as far off as the goal and the other targets (about 10.5 m), a little larger to suit.
    const CLIMB_Z=GOAL_AIM_Z,CLIMB_VR=.14,CLIMB_AR=CLIMB_VR*2/8; // AR: the VR size against the court (scale 2 there, 8 here), until pinning sets it
    let climbOn=false,climb3=null,climbSpot=null,climbUnit=CLIMB_AR,climbZoom=1;
    const modeNow=()=>rainOn?'rain':climbOn?'climb':g.mode();
    const rig=g.player;rig.name='xr-rig';
    const ray=new T.Raycaster(),wp=V(0,0,0),wq=new T.Quaternion(),fwd=V(0,0,0),eye=V(0,0,0),UP=V(0,1,0);
    const scaleNow=()=>rig.scale.x;
    // Game seconds per real second, so a ball falls at 9.8 m/s² in the room.
    const timeK=()=>Math.sqrt(REAL_G*scaleNow()/g.GRAV);
    // The eyes in world space, from the last headset pose. Three r128 stores the XR camera's world pose
    // in its local position, so getWorldPosition would apply the rig twice; matrixWorld is right.
    const eyeNow=()=>eye.setFromMatrixPosition(camera.matrixWorld);
    // Where the eyes are and which way they look, in room metres.
    function headLocal(){
      eyeNow();fwd.set(0,0,-1).transformDirection(camera.matrixWorld);
      const a=rig.worldToLocal(eye.clone()),dir=rig.worldToLocal(eye.clone().add(fwd)).sub(a);
      dir.y=0;if(dir.lengthSq()<1e-6)dir.set(0,0,-1);dir.normalize();
      return {pos:a,dir};
    }

    // VR: grass, trees, sky, day and night, rain and snow (paper floor as a fallback). AR shows the room.
    let nature=null,ambience=null;
    // What the game's physics asks about the pond (VR world only).
    const waterApi={depth:(x,z)=>nature?nature.waterAt(x,z):0,splash:(p,k)=>nature?.splash?.(p.x,p.z,k)};
    const natureOn=()=>!!nature&&kind==='immersive-vr';
    const TIMES=[['auto','تلقائي','Auto'],['day','نهار','Day'],['dusk','غروب','Dusk'],['night','ليل','Night'],['dawn','فجر','Dawn']];
    const WEATHERS=[['auto','تلقائي','Auto'],['clear','صافي','Clear'],['rain','مطر','Rain'],['snow','ثلج','Snow']];
    const named=(list,id)=>{const e=list.find(x=>x[0]===id);return e?tr(e[1],e[2]):'';};
    // A paper floor for VR; AR shows the room through passthrough instead.
    const floor=new T.Mesh(new T.CircleGeometry(40,64),new T.MeshBasicMaterial({color:0xddd2c1}));
    floor.rotation.x=-Math.PI/2;floor.position.y=-.004;floor.visible=false;scene.add(floor);

    /* ---------- Dahrooj as a 3D model (a sprite as a fallback) ---------- */
    const textures=new Map();
    function texture(style,face,blink){
      const key=style+'/'+face+'/'+(blink?1:0);
      if(!textures.has(key)){const t=new T.CanvasTexture(g.sprite(style,face,blink));t.anisotropy=4;textures.set(key,t);}
      return textures.get(key);
    }
    function makeSprite(){const s=new T.Sprite(new T.SpriteMaterial({transparent:true,depthWrite:false}));s.visible=false;s.renderOrder=2;scene.add(s);return s;}
    const ballSprite=makeSprite();
    const models=createReferenceCharacter?createReferenceCharacter(T,{radius:BR,drawFace:g.drawFace,renderer}):null;
    let ballModel=null;const volleyModels=[];
    function model(slot,style,face){
      if(!slot||slot.style!==style||slot.face!==face){
        if(slot){scene.remove(slot.group);slot.dispose();}
        slot=models.make(style,{face});slot.face=face;scene.add(slot.group);
      }
      slot.setAccessory?.(wornNow());slot.group.visible=true;return slot;
    }
    function showSprite(s,pos,r,style,face,blink,sx=1,sy=1){
      const map=texture(style,face,blink);
      if(s.material.map!==map){s.material.map=map;s.material.needsUpdate=true;}
      s.position.copy(pos);s.scale.set(r*2.8*sx,r*2.8*sy,1);s.visible=true;
    }

    /* ---------- floating panels drawn on canvases ---------- */
    function panel(w,h,px,py){
      const canvas=document.createElement('canvas');canvas.width=px;canvas.height=py;
      const tex=new T.CanvasTexture(canvas);tex.colorSpace=T.SRGBColorSpace;tex.generateMipmaps=false;tex.minFilter=T.LinearFilter;tex.anisotropy=Math.min(4,renderer.capabilities.getMaxAnisotropy());
      const mesh=new T.Mesh(new T.PlaneGeometry(w,h),new T.MeshBasicMaterial({map:tex,transparent:true,depthTest:false,depthWrite:false,fog:false,toneMapped:false}));
      mesh.renderOrder=3;return {canvas,ctx:canvas.getContext('2d'),tex,mesh,key:''};
    }
    function round(c,x,y,w,h,r){c.beginPath();c.moveTo(x+r,y);c.arcTo(x+w,y,x+w,y+h,r);c.arcTo(x+w,y+h,x,y+h,r);c.arcTo(x,y+h,x,y,r);c.arcTo(x,y,x+w,y,r);c.closePath();}
    const font=(w,s)=>`${w} ${s}px "Dahrooj","Grandstander",Tahoma,sans-serif`;

    // One paper look for every pane (score board, notifications): soft shadow, cream body, a hairline edge and,
    // when given, a coloured band on the reading side.
    function paperCard(c,x,y,w,h,r,accent,rtl){
      c.save();c.shadowColor='rgba(20,20,30,.32)';c.shadowBlur=24;c.shadowOffsetY=7;c.fillStyle='rgba(255,252,246,.96)';round(c,x,y,w,h,r);c.fill();c.restore();
      if(accent){c.save();round(c,x,y,w,h,r);c.clip();c.fillStyle=accent;c.fillRect(rtl?x+w-14:x,y,14,h);c.restore();}
      c.lineWidth=3;c.strokeStyle='rgba(44,45,61,.12)';round(c,x,y,w,h,r);c.stroke();
    }
    // Transient jelly digits; placement instructions and Summit health stay available.
    const hud=panel(1,.3,1024,300),scorePopup=createScorePopup();rig.add(hud.mesh);hud.mesh.add(scorePopup.root);
    function drawHud(){
      const t=g.texts(),ch=climbOn&&climb3?climb3.hud():null;
      scorePopup.observe(placing?'placing':ch?'climb':rainOn?'rain':g.mode(),placing||ch?0:rainOn?(intro?.popped||0):Number(t.count));
      hud.mesh.material.visible=!!(placing||ch);
      if(!placing&&!ch){hud.key='';return;}
      const key=placing?'placing|'+lang:['climb',ch.hearts,ch.height,ch.checkpoint,ch.again,t.title,lang].join('|');if(key===hud.key)return;hud.key=key;
      const c=hud.ctx;c.clearRect(0,0,1024,300);c.textAlign='center';c.direction=tr('rtl','ltr');
      if(placing){
        c.fillStyle='rgba(255,252,246,.88)';round(c,62,30,900,230,46);c.fill();c.fillStyle=INK;
        c.font=font(800,52);c.fillText(tr('وجّه على سطح واضغط الزناد للتثبيت','Aim at a surface and pull the trigger to pin'),512,125);
        c.font=font(700,40);c.fillStyle='rgba(44,45,61,.7)';c.fillText(tr('العصا للأعلى والأسفل تكبّر وتصغّر قبل التثبيت','Stick up and down: bigger and smaller, until you pin'),512,200);
      }else if(ch){
        // Big hearts that read at a glance from the climb.
        paperCard(c,202,14,620,236,60);
        c.font=font(800,112);for(let i=0;i<ch.max;i++){c.fillStyle=i<ch.hearts?'#c8584b':'rgba(44,45,61,.2)';c.fillText('♥',512+(i-(ch.max-1)/2)*128,138);}
        c.font=font(800,46);c.fillStyle='rgba(44,45,61,.8)';c.fillText(ch.again?tr('A للتسلق من جديد','A to climb again'):t.title||tr(`${ch.height} م`,`${ch.height} m`),512,214);
      }
      hud.tex.needsUpdate=true;
    }

    /* ---------- notifications: a banner that slides down from the top of your view ---------- */
    // Every message (a challenge done, a new reward, a strike, a checkpoint...) comes the same way, like a phone's
    // notification: a slim paper banner drops in at the top of your view, stays with your gaze, then slides away
    // up, so it never covers the play.
    const CW=1024,CH=220,card=panel(.46,.46*CH/CW,CW,CH);rig.add(card.mesh);card.mesh.visible=false;card.mesh.renderOrder=6;card.mesh.name='xr-card';
    const cards=[];let cardNow=null,lastToast='';
    // kind: 'challenge' | 'reward' | 'info'; icon: an accessory id for rewards.
    function notify(kind,title,sub='',icon=''){cards.push({kind,title,sub,icon});if(cards.length>4)cards.shift();}
    function drawCard(n){
      const c=card.ctx,rtl=lang!=='en',accent=n.kind==='challenge'?'#3f8f5a':n.kind==='reward'?'#e5ad2e':INK;
      c.clearRect(0,0,CW,CH);
      paperCard(c,20,16,CW-40,CH-40,56,accent,rtl);
      // The badge.
      const bx=rtl?CW-118:118,by=CH/2-4;
      c.fillStyle=accent;c.beginPath();c.arc(bx,by,56,0,7);c.fill();
      if(n.kind==='reward'&&n.icon){c.fillStyle='rgba(255,252,246,.95)';c.beginPath();c.arc(bx,by,47,0,7);c.fill();c.save();c.translate(bx,by+5);c.scale(1.45,1.45);drawAcc(c,n.icon,0,0,false);c.restore();}
      else if(n.kind==='challenge'){c.strokeStyle=PAPER;c.lineWidth=13;c.lineCap='round';c.lineJoin='round';c.beginPath();c.moveTo(bx-25,by+2);c.lineTo(bx-6,by+20);c.lineTo(bx+28,by-19);c.stroke();}
      else{c.fillStyle=PAPER;c.font=font(800,64);c.textAlign='center';c.fillText('!',bx,by+23);}
      // The words: what kind of message, then the message, then a hint.
      const tx=rtl?CW-206:206;c.textAlign=rtl?'right':'left';c.direction=rtl?'rtl':'ltr';
      c.fillStyle=accent;c.font=font(800,28);c.fillText(n.kind==='challenge'?tr('تحدّي مكتمل','Challenge complete'):n.kind==='reward'?tr('مكافأة جديدة','New reward'):tr('دحروج','Dahrooj'),tx,n.sub?66:78);
      const fit=(t,size,maxW)=>{c.font=font(800,size);while(size>24&&c.measureText(t).width>maxW){size-=2;c.font=font(800,size);}};
      c.fillStyle=INK;fit(n.title,46,CW-260);c.fillText(n.title,tx,n.sub?118:136);
      if(n.sub){c.fillStyle='rgba(44,45,61,.68)';c.font=font(700,26);c.fillText(n.sub,tx,160);}
      card.tex.needsUpdate=true;
    }
    const cardSpot=V(0,0,0);
    function stepCards(dt){
      // The game's own messages (challenges, strikes, checkpoints) arrive as its toast text.
      const t=g.texts().toast||'';
      if(t&&t!==lastToast){
        if(t.startsWith('✓ '))notify('challenge',t.slice(2));
        else if(!cards.some(n=>n.title===t)&&cardNow?.title!==t)notify('info',t);
      }
      lastToast=t;
      if(uiBusy()){card.mesh.visible=false;return;}
      if(!cardNow&&cards.length){cardNow=cards.shift();cardNow.t=0;drawCard(cardNow);
        if(cardNow.kind!=='info')for(const h of hands)buzz(h,.35,60);}
      if(!cardNow){card.mesh.visible=false;return;}
      const n=cardNow,life=n.kind==='info'?2.4:3.4;n.t+=dt;
      // Near the top of your view (about 80 cm ahead, tilted up with your head), slid down on the way in and
      // back up on the way out; it keeps up with your gaze.
      eyeNow();camera.getWorldQuaternion(wq);
      const fwdW=V(0,0,-1).applyQuaternion(wq),upW=V(0,1,0).applyQuaternion(wq),s=rig.scale.x;
      const inK=Math.min(1,n.t/.3),outK=Math.max(0,Math.min(1,(life-n.t)/.3)),ease=k=>1-Math.pow(1-k,3);
      const slide=(1-ease(inK))+(1-ease(outK));
      const spot=eye.clone().addScaledVector(fwdW,.8*s).addScaledVector(upW,(.23+.07*slide)*s);
      cardSpot.copy(rig.worldToLocal(spot));
      if(n.t===dt)card.mesh.position.copy(cardSpot);else card.mesh.position.lerp(cardSpot,1-Math.exp(-dt*9));
      card.mesh.lookAt(eye);
      card.mesh.scale.setScalar(1);card.mesh.material.opacity=Math.min(ease(inK),ease(outK));card.mesh.visible=card.mesh.material.opacity>.01;
      if(n.t>=life)cardNow=null;
    }
    // The menu rides on the left hand: flip it palm-up or raise it. Point with the right hand to pick.
    // A tall pane of frosted glass in Dahrooj's ink and paper: the world shows faintly through it.
    const MW=768,MH=1200,MENU_W=.24,MENU_H=MENU_W*MH/MW;
    const menu=panel(MENU_W,MENU_H,MW,MH);rig.add(menu.mesh);menu.mesh.visible=false;menu.mesh.scale.setScalar(.01);menu.mesh.name='xr-menu';menu.mesh.renderOrder=20;
    const challengeList=createChallengeList(T,{parent:menu.mesh,panelWidth:MENU_W,panelHeight:MENU_H,pixelsWidth:MW,pixelsHeight:MH,font});
    const buttons=[],PAD=36,IN=MW-PAD*2;
    // Positions go right to left in Arabic and left to right in English (see layoutMenu).
    // Four modes a row.
    // The modes live on the floating cards (B); the settings keep style, throw, world and the rest. The settings
    // show only the top MENU_VIS pixels of the pane; the challenges (X) use all of it.
    // VR has a world row (time, weather) that the room (AR) doesn't, so its pane is taller.
    const menuVisH=()=>kind==='immersive-ar'?952:1084,menuVis=()=>chOpen?MH:menuVisH();
    // The blaster's shot styles (and the opening's and the rain's shots).
    const SHOTS=[['bolt','برق','Bolt'],['mini','دحروج','Mini'],['bubble','فقاعة','Bubble'],['firework','ألعاب نارية','Firework']];
    let shotStyle='bolt';try{const v=localStorage.getItem('dahrooj-shot');if(SHOTS.some(x=>x[0]===v))shotStyle=v;}catch(_){}
    STYLES.forEach(([id,ar,en],i)=>buttons.push({kind:'style',id,ar,en,i,y:182,w:128,h:140}));
    [['trigger','زناد','Trigger'],['hand','يد','Hand'],['sling','نبيطة','Sling']].forEach(([id,ar,en],i)=>buttons.push({kind:'throw',id,ar,en,i,y:396,w:224,h:92}));
    SHOTS.forEach(([id,ar,en],i)=>buttons.push({kind:'shot',id,ar,en,i,y:562,w:166,h:120}));
    buttons.push({kind:'time',id:'time',i:0,y:736,w:342,h:92});
    buttons.push({kind:'weather',id:'weather',i:1,y:736,w:342,h:92});
    // The last row sits under the world row in VR, straight under the shots in the room (AR): see layoutMenu.
    buttons.push({kind:'place',id:'place',i:0,y:852,w:224,h:92});
    buttons.push({kind:'lang',id:'lang',i:1,y:852,w:224,h:92});
    buttons.push({kind:'exit',id:'exit',ar:'خروج',en:'Exit',i:2,y:852,w:224,h:92});
    function layoutMenu(){
      const rtl=lang!=='en';
      for(const b of buttons){
        const step=b.kind==='mode'?177.3:b.kind==='style'?142:b.kind==='shot'?176.7:b.kind==='throw'||b.kind==='place'||b.kind==='lang'||b.kind==='exit'?236:354,
          n=b.kind==='mode'||b.kind==='shot'?4:b.kind==='style'?5:b.kind==='time'||b.kind==='weather'?2:3,col=b.kind==='mode'?b.i%4:b.i;
        b.x=PAD+(rtl?n-1-col:col)*step;
        if(b.kind==='place'||b.kind==='lang'||b.kind==='exit')b.y=kind==='immersive-ar'?720:866;
      }
    }
    function layoutAcc(){const rtl=lang!=='en';for(const b of accButtons)b.x=PAD+(rtl?accButtons.length-1-b.i:b.i)*118;resetBtn.x=rtl?PAD:MW-PAD-resetBtn.w;}
    layoutMenu();
    const buttonShown=b=>b.kind==='time'||b.kind==='weather'?kind!=='immersive-ar':true;
    // No free play in the headset, so its challenge stays on the web.
    const headsetChallenges=()=>(g.challenges?g.challenges():[]).filter(c=>c.id!=='free25');
    let chOpen=false,menuFresh=false;
    const uiBusy=()=>menuToggled||menuOpen||plazaOn||menu.mesh.visible;
    function stopGameplayInput(){for(const h of hands){release(h,true);h.hover=-1;h.plaza=-1;h.scrollDrag=null;}}
    function toggleMenu(challenges){const on=!(menuToggled&&chOpen===challenges);setPlaza(false);menuToggled=on;chOpen=challenges;menuFresh=on;menu.key='';if(on)stopGameplayInput();}
    // Rewards: every few challenges done unlocks something for Dahrooj to wear, picked under the challenges (X).
    const ACCESSORIES=[['','بدون','None',0],['party','قبعة حفلة','Party hat',1],['glasses','نظارة شمسية','Sunglasses',3],['cap','كاب','Cap',5],['flower','وردة','Flower',7],['crown','تاج','Crown',10]];
    const accButtons=ACCESSORIES.map(([id,ar,en,need],i)=>({kind:'acc',id,ar,en,need,i,y:972,w:106,h:118}));
    // Starting the challenges over takes two presses: the first asks to be sure.
    const resetBtn={kind:'reset',id:'reset',y:132,w:190,h:56};let resetArm=0;
    function resetPress(){
      if(resetArm>0){resetArm=0;g.resetChallenges?.();wearing='';try{localStorage.setItem('dahrooj-acc','');}catch(_){}
        doneNow=challengesDone();notify('info',tr('صفّرت التحديات','Challenges reset'),tr('ابدأ من جديد!','Start again!'));}
      else resetArm=3;
      menu.key='';
    }
    layoutAcc();
    let wearing='';try{wearing=localStorage.getItem('dahrooj-acc')||'';}catch(_){}
    const challengesDone=()=>(g.challenges?g.challenges():[]).filter(c=>c.value>=c.goal).length;
    let doneNow=challengesDone(),doneCheck=0;
    const accOpen=a=>doneNow>=a.need;
    const wornNow=()=>{const a=accButtons.find(b=>b.id===wearing);return a&&accOpen(a)?wearing:'';};
    // A newly unlocked reward gets a toast and the chime, once.
    function watchRewards(dt){
      doneCheck-=dt;if(doneCheck>0)return;doneCheck=.5;
      const before=doneNow;doneNow=challengesDone();
      if(doneNow>before){
        const got=accButtons.filter(b=>b.need>before&&b.need<=doneNow).pop();
        if(got){notify('reward',tr(`فتحت ${got.ar}!`,`${got.en} unlocked!`),tr('البسها لدحروج من قائمة التحديات (X)','Put it on Dahrooj from the challenges (X)'),got.id);g.chime?.();menu.key='';}
      }
    }
    function wear(id){
      const a=accButtons.find(b=>b.id===id);if(!a)return;
      if(!accOpen(a)){notify('info',tr(`${a.ar} مقفلة`,`The ${a.en.toLowerCase()} is locked`),tr(`خلّص ${a.need} تحديات عشان تفتحها`,`Finish ${a.need} challenges to unlock it`));return;}
      wearing=id;try{localStorage.setItem('dahrooj-acc',id);}catch(_){}menu.key='';
    }
    // Little drawings of each reward for the buttons.
    function drawAcc(c,id,cx,cy,locked){
      c.save();c.globalAlpha*=locked?.35:1;
      const bg=c.createRadialGradient(cx-8,cy-8,3,cx,cy,26);bg.addColorStop(0,'#f6ede0');bg.addColorStop(1,'#c9b8a2');c.fillStyle=bg;c.beginPath();c.arc(cx,cy+6,24,0,7);c.fill();
      for(const ex of [-8,8]){c.fillStyle='#fff';c.beginPath();c.arc(cx+ex,cy+3,5,0,7);c.fill();c.fillStyle=INK;c.beginPath();c.arc(cx+ex,cy+4,2.6,0,7);c.fill();}
      if(id==='party'){c.fillStyle='#e2603f';c.beginPath();c.moveTo(cx-12,cy-14);c.lineTo(cx+12,cy-14);c.lineTo(cx+3,cy-40);c.closePath();c.fill();c.fillStyle='#f2c14e';c.beginPath();c.arc(cx+3,cy-41,4,0,7);c.fill();}
      else if(id==='glasses'){c.fillStyle='#1b2233';for(const ex of [-9,9]){c.beginPath();c.ellipse(cx+ex,cy+3,8,6,0,0,7);c.fill();}c.fillRect(cx-2,cy+1,4,2);}
      else if(id==='cap'){c.fillStyle='#c8442f';c.beginPath();c.arc(cx,cy-6,21,Math.PI,0);c.fill();c.fillRect(cx-4,cy-8,28,5);}
      else if(id==='flower'){c.fillStyle='#ff7f9a';for(let k=0;k<5;k++){const a=k/5*Math.PI*2;c.beginPath();c.arc(cx+14+Math.cos(a)*6,cy-14+Math.sin(a)*6,4.5,0,7);c.fill();}c.fillStyle='#f2c14e';c.beginPath();c.arc(cx+14,cy-14,3.5,0,7);c.fill();}
      else if(id==='crown'){c.fillStyle='#e5ad2e';c.beginPath();c.moveTo(cx-15,cy-14);c.lineTo(cx-15,cy-32);c.lineTo(cx-7,cy-22);c.lineTo(cx,cy-36);c.lineTo(cx+7,cy-22);c.lineTo(cx+15,cy-32);c.lineTo(cx+15,cy-14);c.closePath();c.fill();}
      c.restore();
    }
    const STYLE_DOTS=DAHROOJ_SWATCHES;
    // The menus' glass: a soft paper tint, brighter at the top, a white rim and a faint diagonal sheen (W x H, corner R).
    function glassPane(c,W,H,R){
      let gr=c.createLinearGradient(0,0,0,H);gr.addColorStop(0,'rgba(255,252,246,.98)');gr.addColorStop(1,'rgba(240,234,224,.97)');
      c.fillStyle=gr;round(c,6,6,W-12,H-12,R);c.fill();
      c.save();round(c,6,6,W-12,H-12,R);c.clip();
      gr=c.createLinearGradient(0,0,W,H*.55);gr.addColorStop(0,'rgba(255,255,255,.12)');gr.addColorStop(.35,'rgba(255,255,255,0)');gr.addColorStop(.62,'rgba(255,255,255,0)');gr.addColorStop(.7,'rgba(255,255,255,.04)');gr.addColorStop(.78,'rgba(255,255,255,0)');
      c.fillStyle=gr;c.fillRect(0,0,W,H);c.restore();
      c.lineWidth=4;c.strokeStyle='rgba(255,255,255,.85)';round(c,8,8,W-16,H-16,R-2);c.stroke();
      c.lineWidth=2;c.strokeStyle='rgba(44,45,61,.16)';round(c,4,4,W-8,H-8,R+2);c.stroke();
    }
    function drawMenu(hover){
      if(!menu.mesh.visible)return;
      const sky=nature?nature.settings:{time:'auto',weather:'auto'};
      const chs=headsetChallenges();
      const key=[resetArm>0,wornNow(),doneNow,modeNow(),g.style(),throwStyle,kind,sky.time,sky.weather,hover.join(','),chOpen,lang,chs.map(c=>c.value).join(',')].join('|');if(key===menu.key)return;menu.key=key;
      const c=menu.ctx,VH=menuVis();c.clearRect(0,0,MW,MH);
      // Glass (see glassPane). Only the visible height of the pane is drawn (the settings are shorter than the challenges).
      glassPane(c,MW,VH,64);
      // Show just that part of the canvas.
      menu.tex.repeat.set(1,VH/MH);menu.tex.offset.set(0,1-VH/MH);
      // Title and section labels.
      c.textAlign='center';c.direction=tr('rtl','ltr');c.fillStyle=INK;c.font=font(800,60);c.fillText(tr('دحروج','Dahrooj'),MW/2,92);
      c.fillStyle='rgba(44,45,61,.12)';c.fillRect(PAD+40,120,IN-80,2);
      if(chOpen){
        // The challenges, with progress, in place of the options.
        const done=chs.filter(x=>x.value>=x.goal).length;
        c.font=font(700,30);c.fillStyle='rgba(44,45,61,.85)';c.fillText(tr(`التحديات · ${done} من ${chs.length}`,`Challenges · ${done} of ${chs.length}`),MW/2,164);
        // Reset, on the far side of the heading.
        {const b=resetBtn,hot=hover.includes(2000),armed=resetArm>0;
          c.fillStyle=armed?'#c8442f':hot?'rgba(255,255,255,.95)':'rgba(255,255,255,.55)';round(c,b.x,b.y,b.w,b.h,b.h/2);c.fill();
          if(!armed){c.lineWidth=2;c.strokeStyle=hot?'rgba(44,45,61,.35)':'rgba(255,255,255,.9)';c.stroke();}
          c.textAlign='center';c.fillStyle=armed?PAPER:INK;c.font=font(800,armed?24:26);c.fillText(armed?tr('متأكد؟ اضغط ثانية','Sure? Press again'):tr('↺ تصفير','↺ Reset'),b.x+b.w/2,b.y+b.h/2+9);}
        challengeList.rows(chs,lang);
        const v=challengeList.view;c.fillStyle='rgba(44,45,61,.16)';c.fillRect(v.x+v.w+9,v.y,6,v.h);
        c.fillStyle=INK;c.font=font(600,25);c.fillText(tr('حرّك العصا اليسرى أو اسحب القائمة للتمرير','Left stick or drag the list to scroll'),MW/2,911);
        // The rewards, under the list.
        c.textAlign='center';c.font=font(700,26);c.fillStyle='rgba(44,45,61,.85)';
        c.fillText(tr('إكسسوارات دحروج · تنفتح بالتحديات','Dahrooj\'s rewards · unlocked by challenges'),MW/2,950);
        const worn=wornNow();
        accButtons.forEach((b,k)=>{
          const open=accOpen(b),on=b.id===worn,hot=hover.includes(1000+k);
          c.fillStyle=on?INK:hot?'rgba(255,255,255,.95)':'rgba(255,255,255,.55)';round(c,b.x,b.y,b.w,b.h,28);c.fill();
          if(!on){c.lineWidth=2;c.strokeStyle=hot?'rgba(44,45,61,.35)':'rgba(255,255,255,.9)';c.stroke();}
          if(b.id)drawAcc(c,b.id,b.x+b.w/2,b.y+52,!open);
          else{c.fillStyle=on?PAPER:INK;c.font=font(800,40);c.fillText('—',b.x+b.w/2,b.y+66);}
          c.fillStyle=on?PAPER:INK;c.font=font(700,open?21:20);c.fillText(open?tr(b.ar,b.en):tr(`يحتاج ${b.need}`,`needs ${b.need}`),b.x+b.w/2,b.y+106);
        });
      }else{
      c.font=font(700,30);c.fillStyle='rgba(44,45,61,.85)';
      for(const [t,y] of [[tr('الستايل','Style'),164],[tr('الرمي','Throw'),378],[tr('الطلقات','Shots'),544],...(kind==='immersive-ar'?[]:[[tr('العالم','World'),720]])])c.fillText(t,MW/2,y);
      }
      buttons.forEach((b,i)=>{
        if(chOpen||!buttonShown(b))return;
        const label=b.kind==='lang'?(lang==='en'?'العربية':'English'):b.kind==='place'?(kind==='immersive-ar'?tr('ثبّت من جديد','Re-pin'):tr('توسيط','Recentre'))
          :b.kind==='time'?tr('الوقت: ','Time: ')+named(TIMES,sky.time):b.kind==='weather'?tr('الطقس: ','Weather: ')+named(WEATHERS,sky.weather):tr(b.ar,b.en);
        // Time and weather belong to the VR world; the room has its own.
        if((b.kind==='time'||b.kind==='weather')&&!natureOn())c.globalAlpha=.35;
        const on=(b.kind==='mode'&&b.id===modeNow())||(b.kind==='style'&&b.id===g.style())||(b.kind==='shot'&&b.id===shotStyle)||(b.kind==='throw'&&b.id===throwStyle),hot=hover.includes(i);
        const r=b.kind==='style'?36:b.h/2;
        // Glass buttons: lighter panes with a white edge; the chosen one is solid ink.
        if(on){c.fillStyle=INK;round(c,b.x,b.y,b.w,b.h,r);c.fill();}
        else{
          const bg=c.createLinearGradient(0,b.y,0,b.y+b.h);bg.addColorStop(0,hot?'rgba(255,255,255,.95)':'rgba(255,255,255,.62)');bg.addColorStop(1,hot?'rgba(255,255,255,.7)':'rgba(255,255,255,.3)');
          c.fillStyle=bg;round(c,b.x,b.y,b.w,b.h,r);c.fill();
          c.lineWidth=2.5;c.strokeStyle=hot?'rgba(44,45,61,.35)':'rgba(255,255,255,.9)';c.stroke();
        }
        if(b.kind==='style'){
          // A little Dahrooj in that style: a shaded body with two eyes.
          const [a,d]=STYLE_DOTS[b.id]||['#888','#444'],cx=b.x+b.w/2,cy=b.y+52;
          const bg=c.createRadialGradient(cx-10,cy-12,4,cx,cy,32);bg.addColorStop(0,a);bg.addColorStop(1,d);
          c.fillStyle=bg;c.beginPath();c.arc(cx,cy,30,0,7);c.fill();c.lineWidth=2;c.strokeStyle='rgba(44,45,61,.25)';c.stroke();
          for(const ex of [-9,9]){c.fillStyle='#fff';c.beginPath();c.arc(cx+ex,cy-3,6.5,0,7);c.fill();c.fillStyle=INK;c.beginPath();c.arc(cx+ex,cy-2,3.3,0,7);c.fill();}
          c.fillStyle=on?PAPER:INK;c.font=font(800,28);c.fillText(label,cx,b.y+122);
        }else if(b.kind==='shot'){
          // A little picture of the shot: a gold streak, a mini Dahrooj, a bubble, a burst.
          const cx=b.x+b.w/2,cy=b.y+46,ink=on?PAPER:INK;
          if(b.id==='bolt'){const gr=c.createLinearGradient(cx-44,cy+14,cx+40,cy-14);gr.addColorStop(0,'rgba(255,210,122,0)');gr.addColorStop(1,'#ffd27a');
            c.strokeStyle=gr;c.lineWidth=9;c.lineCap='round';c.beginPath();c.moveTo(cx-44,cy+14);c.lineTo(cx+34,cy-12);c.stroke();c.fillStyle='#fff4d6';c.beginPath();c.arc(cx+36,cy-12,8,0,7);c.fill();}
          else if(b.id==='mini'){const bg=c.createRadialGradient(cx-6,cy-8,3,cx,cy,22);bg.addColorStop(0,DAHROOJ_SWATCHES.jelly[0]);bg.addColorStop(1,DAHROOJ_SWATCHES.jelly[1]);c.fillStyle=bg;c.beginPath();c.arc(cx,cy,22,0,7);c.fill();
            c.strokeStyle=ink;c.globalAlpha*=.35;c.lineWidth=3;c.setLineDash([3,7]);c.beginPath();c.moveTo(cx-48,cy+18);c.quadraticCurveTo(cx-34,cy-20,cx-24,cy);c.stroke();c.setLineDash([]);c.globalAlpha=1;}
          else if(b.id==='bubble'){const bg=c.createRadialGradient(cx-8,cy-8,4,cx,cy,26);bg.addColorStop(0,'rgba(255,255,255,.9)');bg.addColorStop(.6,'rgba(190,225,255,.35)');bg.addColorStop(1,'rgba(240,170,255,.55)');
            c.fillStyle=bg;c.beginPath();c.arc(cx,cy,26,0,7);c.fill();c.lineWidth=2.5;c.strokeStyle='rgba(120,160,220,.7)';c.stroke();c.fillStyle='#fff';c.beginPath();c.arc(cx-9,cy-10,5,0,7);c.fill();}
          else{const cols=['#e2603f','#f2c14e','#6fa8d6','#7bbf8a','#c9a2e6'];for(let k=0;k<10;k++){const a=k/10*Math.PI*2;c.strokeStyle=cols[k%5];c.lineWidth=5;c.lineCap='round';
            c.beginPath();c.moveTo(cx+Math.cos(a)*9,cy+Math.sin(a)*9);c.lineTo(cx+Math.cos(a)*26,cy+Math.sin(a)*26);c.stroke();}c.fillStyle='#fff4d6';c.beginPath();c.arc(cx,cy,6,0,7);c.fill();}
          c.fillStyle=ink;c.font=font(800,label.length>8?24:28);c.fillText(label,cx,b.y+104);
        }else{
          c.fillStyle=on?PAPER:INK;c.font=font(800,label.length>10?32:38);c.fillText(label,b.x+b.w/2,b.y+b.h/2+13);
        }
        c.globalAlpha=1;
      });
      c.textAlign='center';c.fillStyle='rgba(44,45,61,.66)';c.font=font(600,27);
      const hint=chOpen?[tr('X لإغلاق التحديات','X closes the challenges'),'']
        :climbOn?[tr('العصا اليسار للحركة · A للقفز','Left stick to move · A to jump'),tr('العصا اليمنى للحجم · الزناد للرمي','Right stick to resize · trigger to throw')]
        :rainOn?[tr('الزنادين يطلقون على الدحاريج','Either trigger shoots at the Dahroojs'),tr('Y الأنماط · X التحديات','Y modes · X challenges')]
        :throwStyle==='sling'?[tr('اسحب دحروج بالزناد اليمين ثم أفلت','Pull Dahrooj back with the right trigger, let go'),tr('A يرجّع دحروج · Y الأنماط · X التحديات','A calls him back · Y modes · X challenges')]
        :[tr('الزناد اليمين للرمي · اليسار يطلق','Right trigger throws · left trigger shoots'),tr('A يرجّع دحروج · Y الأنماط · X التحديات','A calls him back · Y modes · X challenges')];
      const hy=chOpen?1150:menuVisH()-86;c.fillText(hint[0],MW/2,hy);c.fillText(hint[1],MW/2,hy+42);
      menu.tex.needsUpdate=true;
    }
    function menuHit(uv){
      const x=uv.x*MW,y=(1-uv.y)*menuVis();
      if(chOpen&&x>=resetBtn.x&&x<=resetBtn.x+resetBtn.w&&y>=resetBtn.y&&y<=resetBtn.y+resetBtn.h)return 2000;
      if(chOpen){const k=accButtons.findIndex(b=>x>=b.x&&x<=b.x+b.w&&y>=b.y&&y<=b.y+b.h);return k<0?-1:1000+k;}
      return buttons.findIndex(b=>buttonShown(b)&&x>=b.x&&x<=b.x+b.w&&y>=b.y&&y<=b.y+b.h);
    }
    function menuAction(i){
      if(i===2000){resetPress();return;}
      if(i>=1000){const a=accButtons[i-1000];if(a)wear(a.id);return;}
      const b=buttons[i];if(!b)return;
      if(b.kind==='mode'){holder=null;if(b.id==='rain'){setClimb(false);setRain(true);}else{setRain(false);if(b.id==='climb')setClimb(true);else{setClimb(false);g.setMode(b.id);}}}
      else if(b.kind==='style')g.setStyle(b.id);
      else if(b.kind==='throw'){holder=null;throwStyle=b.id;}
      else if(b.kind==='shot'){shotStyle=b.id;shotChosen=true;try{localStorage.setItem('dahrooj-shot',b.id);}catch(_){}}
      else if(b.kind==='exit')session?.end();
      else if(b.kind==='lang'){lang=lang==='en'?'ar':'en';try{localStorage.setItem('dahrooj-lang',lang);}catch(_){}g.setLang?.(lang);layoutMenu();layoutAcc();menu.key=hud.key=start.key='';}
      else if(b.kind==='time'&&natureOn()){const i=TIMES.findIndex(t=>t[0]===nature.settings.time);nature.set({time:TIMES[(i+1)%TIMES.length][0]});}
      else if(b.kind==='weather'&&natureOn()){const i=WEATHERS.findIndex(t=>t[0]===nature.settings.weather);nature.set({weather:WEATHERS[(i+1)%WEATHERS.length][0]});}
      else if(b.kind==='place'){if(kind==='immersive-ar'){holder=null;placing=true;}else{climbSpot=null;place();}}
    }

    /* ---------- the slingshot, held in the left hand ---------- */
    const wood=new T.MeshStandardMaterial({color:0x8a5a34,roughness:.75}),rubber=new T.MeshStandardMaterial({color:0xc8442f,roughness:.5});
    const fork=new T.Group();fork.visible=false;fork.name='xr-slingshot';
    function stick(a,b,r,mat){
      const m=new T.Mesh(new T.CylinderGeometry(r,r,1,10),mat),d=b.clone().sub(a);
      m.position.copy(a).add(b).multiplyScalar(.5);m.scale.y=d.length();m.quaternion.setFromUnitVectors(UP,d.normalize());return m;
    }
    const tipL=V(-.04,.15,-.045),tipR=V(.04,.15,-.045),crotch=V(0,.07,-.03);
    fork.add(stick(V(0,-.06,-.01),crotch,.012,wood),stick(crotch,tipL,.009,wood),stick(crotch,tipR,.009,wood));
    const point=p=>{const o=new T.Object3D();o.position.copy(p);fork.add(o);return o;};
    const tips=[point(tipL),point(tipR)],pouch=point(V(0,.14,.02)),forkCenter=point(V(0,.15,-.045));
    const bands=[0,1].map(()=>{const m=new T.Mesh(new T.CylinderGeometry(.0045,.0045,1,6),rubber);m.visible=false;rig.add(m);return m;});
    function stretch(m,a,b){const d=b.clone().sub(a),l=d.length();m.position.copy(a).add(b).multiplyScalar(.5);m.scale.y=Math.max(l,1e-4);if(l>1e-6)m.quaternion.setFromUnitVectors(UP,d.divideScalar(l));m.visible=true;}
    // Dotted flight preview while pulling the slingshot.
    const DOTS=26,dots=[];
    for(let i=0;i<DOTS;i++){const d=new T.Mesh(new T.SphereGeometry(1,8,6),new T.MeshBasicMaterial({color:0x2c2d3d,transparent:true,opacity:.55}));d.visible=false;scene.add(d);dots.push(d);}

    /* ---------- AR: find surfaces and pin the court on one ---------- */
    const reticle=new T.Mesh(new T.RingGeometry(.07,.09,40).rotateX(-Math.PI/2),new T.MeshBasicMaterial({color:0xfffaf2,transparent:true,opacity:.9,depthTest:false}));
    reticle.renderOrder=4;reticle.visible=false;rig.add(reticle);
    const planesGroup=new T.Group();rig.add(planesGroup);
    const planeLines=new Map(),hitSources=new Map();

    /* ---------- the opening: Dahrooj balls rain all around you, then a start button ---------- */
    // The same rain is a mode of its own, Dahrooj Rain (rain: true): no start button, and it never stops.
    // Every ball and shot is drawn by one crowd (a handful of instanced draws), so there can be lots.
    const INTRO_R=.11,INTRO_STYLES=['jelly','fabric','clay','fur','bubble'],RAIN_ACCESSORIES=['party','glasses','cap','flower','crown'],CROWD_MAX=120;
    const crowd=models?.crowd?models.crowd(CROWD_MAX,true):null;
    const introGroup=crowd?crowd.group:new T.Group();introGroup.name='xr-intro';rig.add(introGroup);
    const start=panel(.56,.28,1024,512);start.mesh.name='xr-start';start.mesh.visible=false;rig.add(start.mesh);
    // In the menus' glass style: the name, a solid ink button and a line under it.
    function drawStart(hot){
      const popped=intro?intro.popped:0,key='start|'+hot+'|'+popped+'|'+lang;if(start.key===key)return;start.key=key;
      const c=start.ctx;c.clearRect(0,0,1024,512);c.textAlign='center';c.direction=tr('rtl','ltr');
      glassPane(c,1024,512,70);
      c.fillStyle=INK;c.font=font(800,96);c.fillText(tr('دحروج','Dahrooj'),512,140);
      c.fillStyle='rgba(44,45,61,.12)';c.fillRect(200,172,624,2);
      c.fillStyle=hot?'#44465a':INK;round(c,232,212,560,150,75);c.fill();
      if(hot){c.lineWidth=4;c.strokeStyle='rgba(242,193,78,.9)';round(c,226,206,572,162,81);c.stroke();}
      c.fillStyle=PAPER;c.font=font(800,62);c.fillText(tr('بدء اللعبة','Play'),540,306);
      c.beginPath();c.moveTo(316,252);c.lineTo(316,322);c.lineTo(368,287);c.closePath();c.fill();
      c.fillStyle='rgba(44,45,61,.85)';c.font=font(700,32);c.fillText(popped?tr(`فجّرت ${popped}`,`Popped ${popped}`):tr('وجّه يدك واضغط الزناد لتفجير الكور','Aim and pull the trigger to pop the balls'),512,430);
      start.tex.needsUpdate=true;
    }
    function beginIntro(rain=false){const st=g.stage();if(st&&st.grp)st.grp.visible=false;intro={t:0,frames:0,balls:[],shots:[],sparks:[],ready:false,leaving:0,popped:0,spawned:false,gap:0,rain,centre:null};}
    const SPARK=new T.SphereGeometry(1,8,6);let ballIds=0,nextAmbientPop=0;
    const rainPropP=V(0,0,0),rainPropV=V(0,0,0),rainRotation=new T.Quaternion(),rainInverse=new T.Quaternion();
    // How many and how far: the room in mixed reality, a wider ring in the open VR world.
    const crowdSize=()=>kind==='immersive-ar'?{n:72,R:2.6}:{n:100,R:4.4};
    const STYLE_COLORS=DAHROOJ_COLORS;
    // One ball dropping from above somewhere in the ring around you, at a random moment and size.
    function dropBall(delay){
      const I=intro,{R}=crowdSize(),c=I.centre,a=Math.random()*Math.PI*2,dist=.55+Math.sqrt(Math.random())*(R-.55);
      const raw=INTRO_R*(.75+Math.random()*.5),rad=I.rain&&raw>INTRO_R?INTRO_R+(raw-INTRO_R)*.5:raw,sp=.2+Math.random()*.5,dirA=Math.random()*Math.PI*2;
      // Pick once per spawn; cosmetics never change the player's unlocks or add physics bodies.
      const accessory=I.rain?RAIN_ACCESSORIES[Math.random()*RAIN_ACCESSORIES.length|0]:'';
      I.balls.push({id:++ballIds,style:INTRO_STYLES[Math.random()*5|0],R:rad,accessory,p:V(c.x+Math.sin(a)*dist,c.y+.6+Math.random()*1.8,c.z-Math.cos(a)*dist),v:V(0,0,0),
        born:I.t+delay,gx:Math.cos(dirA)*sp,gz:Math.sin(dirA)*sp,hop:.5+Math.random()*2.5,d:0,dv:0,hit:0,blink:0,next:1+Math.random()*3});
    }
    function spawnIntro(){
      const I=intro,{pos}=headLocal();I.spawned=true;I.gap=0;I.wall=I.wall||performance.now();I.centre=I.centre||pos.clone();
      // They come down over a few seconds, not all at once.
      for(let i=0,n=crowdSize().n;i<n;i++)dropBall(Math.random()*2.6);
    }
    function endIntro(){
      if(!intro||intro.leaving||intro.rain)return;
      intro.leaving=.001;start.mesh.visible=false;
      for(const s of intro.sparks){rig.remove(s.m);s.m.material.dispose();}intro.sparks.length=0;
      placing=kind==='immersive-ar';g.respawn();
      const st=g.stage();if(st&&st.grp&&!climbOn)st.grp.visible=true;
    }
    function clearIntro(){
      if(!intro)return;
      for(const s of intro.sparks){rig.remove(s.m);s.m.material.dispose();}
      intro=null;if(crowd){crowd.begin();crowd.end();}start.mesh.visible=false;
      const st=g.stage();if(st&&st.grp&&!climbOn)st.grp.visible=true;
    }
    /* ---------- Dahrooj Rain: the opening's rain as a mode, from the plaza ---------- */
    let rainOn=false;
    function setRain(on){
      if(on===rainOn)return;rainOn=on;hud.key='';menu.key='';
      if(on){clearIntro();holder=null;parked=false;beginIntro(true);}else if(intro?.rain)clearIntro();
    }
    /* ---------- feel: controller vibration and sound from where things happen ---------- */
    // buzz: one pulse on that hand's controller (Quest supports it through the gamepad's haptics).
    function buzz(h,k,ms){const a=h?.source?.gamepad?.hapticActuators?.[0];if(a?.pulse)try{a.pulse(clamp(k,0,1),ms);}catch(_){}}
    // at: play a game sound from a point in game space (3D sound around your head).
    const at=(p,fn)=>g.playAt?g.playAt(p,fn):fn();
    const roomPoint=p=>rig.localToWorld(p.clone());
    let lastThrower=null,scoredBefore=false;
    const lm=new T.Vector3(),lf=new T.Vector3(),lu=new T.Vector3();
    function updateListener(){
      if(!g.setListener)return;camera.updateMatrixWorld();const e=camera.matrixWorld.elements;
      lm.set(e[12],e[13],e[14]);lf.set(-e[8],-e[9],-e[10]).normalize();lu.set(e[4],e[5],e[6]).normalize();
      g.setListener(lm,lf,lu,scaleNow());
    }
    // The trigger fires a small shot along the hand's ray: a little eyeless Dahrooj in the next style that
    // flies true, then drops, bounces and rolls, popping the balls it touches.
    // The trigger fires a shot (the blaster's, in the chosen style) along the hand's ray.
    function fireIntro(h){if(!intro||intro.leaving)return;fireBlast(h,true);}
    function popBall(b,byPlayer=true){
      const I=intro;if(!I||b.popped)return;const index=I.balls.indexOf(b);if(index<0)return;
      b.popped=true;if(byPlayer){skyPop(roomPoint(b.p));I.popped++;}I.balls.splice(index,1);
      for(let k=0;k<(byPlayer?10:4)&&I.sparks.length<80;k++){
        const m=new T.Mesh(SPARK,new T.MeshBasicMaterial({color:k%3?STYLE_COLORS[b.style]:0xfffaf2,transparent:true}));m.scale.setScalar(.012+Math.random()*.01);rig.add(m);
        const a=Math.random()*Math.PI*2,e=Math.random()*Math.PI-Math.PI/2,v=1+Math.random()*1.6;
        I.sparks.push({m,p:b.p.clone(),v:V(Math.cos(a)*Math.cos(e)*v,Math.sin(e)*v+1,Math.sin(a)*Math.cos(e)*v),t:0,max:.45+Math.random()*.3});
      }
      if(byPlayer||clock>=nextAmbientPop){at(roomPoint(b.p),()=>g.popSound?.());nextAmbientPop=clock+.12;}
      if(byPlayer){buzz(hands.find(x=>x.lastShot&&clock-x.lastShot<3),.35,40);g.chAdd?.('pop20');}
      // Environmental impacts leave a visible gap instead of immediately filling the crowd again.
      if(I.rain)dropBall(byPlayer?.3+Math.random()*1.5:4+Math.random()*4);
    }
    // Room physics in metres: gravity, the floor, wandering and hopping, and the balls pushing each other.
    function stepIntro(dt){
      const I=intro;
      if(I.leaving){I.leaving+=dt;if(I.leaving>=.35)clearIntro();return;}
      if(!I.spawned){if(++I.frames>=3)spawnIntro();return;}
      I.t+=dt;
      // All popped: a new wave a moment later (the rain tops itself up as it goes).
      if(!I.balls.length){I.gap+=dt;if(I.gap>1)spawnIntro();}
      if(I.rain){const {n}=crowdSize();while(I.balls.length<n)dropBall(Math.random()*2);}
      const {R:ROOM}=crowdSize(),live=I.balls.filter(b=>I.t>=b.born),{pos:head}=headLocal(),c=I.centre;
      const rainProps=I.rain&&natureOn()?nature.props:null,propScale=scaleNow();
      if(rainProps){rig.getWorldQuaternion(rainRotation);rainInverse.copy(rainRotation).invert();}
      for(const b of live){
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
        if(rainProps){
          // Only six crate colliders, with broad-phase rejection; no full prop scan for the crowd.
          rig.localToWorld(rainPropP.copy(b.p));rainPropV.copy(b.v).applyQuaternion(rainRotation).multiplyScalar(propScale);
          rainProps.collideCrates(rainPropP,rainPropV,b.R*propScale,false);
          b.p.copy(rig.worldToLocal(rainPropP));b.v.copy(rainPropV).applyQuaternion(rainInverse).divideScalar(propScale);
        }
      }
      // Pushing apart, on a coarse grid so a big crowd stays cheap.
      const cell=new Map(),key=(x,z)=>(Math.floor(x/.3)*73856093)^(Math.floor(z/.3)*19349663);
      for(const b of live){const k=key(b.p.x,b.p.z);let l=cell.get(k);if(!l)cell.set(k,l=[]);l.push(b);}
      const n=V(0,0,0),rel=V(0,0,0);
      for(const a of live){const gx=Math.floor(a.p.x/.3),gz=Math.floor(a.p.z/.3);
        for(let ix=-1;ix<=1;ix++)for(let iz=-1;iz<=1;iz++){const l=cell.get(((gx+ix)*73856093)^((gz+iz)*19349663));if(!l)continue;
          for(const b of l){if(b===a||a.id>b.id||a.popped||b.popped)continue;
            if(I.rain&&ballImpactSpeed(a.p,a.v,b.p,b.v,a.R+b.R,dt)>=2.4){popBall(a,false);popBall(b,false);continue;}
            n.copy(b.p).sub(a.p);const len=n.length(),min=a.R+b.R;if(!(len>0&&len<min))continue;
            n.divideScalar(len);const push=(min-len)/2;a.p.addScaledVector(n,-push);b.p.addScaledVector(n,push);
            const rv=rel.copy(b.v).sub(a.v).dot(n);if(rv<0){a.v.addScaledVector(n,rv*.8);b.v.addScaledVector(n,-rv*.8);}}}}
      for(let k=I.sparks.length-1;k>=0;k--){
        const s=I.sparks[k];s.t+=dt;s.v.y-=REAL_G*.5*dt;s.p.addScaledVector(s.v,dt);s.m.position.copy(s.p);s.m.material.opacity=1-s.t/s.max;
        if(s.t>=s.max){rig.remove(s.m);s.m.material.dispose();I.sparks.splice(k,1);}
      }
      if(!I.rain&&!I.ready&&(I.t>3.2||performance.now()-I.wall>3200)){
        // Low and a little to the side, tilted up at you like a lectern, so it never hides the balls you're playing with.
        I.ready=true;const {pos,dir}=headLocal(),side=V(-dir.z,0,dir.x).normalize().multiplyScalar(lang==='en'?.3:-.3);
        start.mesh.position.set(pos.x+dir.x*.8+side.x,pos.y-.55,pos.z+dir.z*.8+side.z);start.mesh.scale.setScalar(.85);start.mesh.visible=true;
      }
      if(I.ready){eyeNow();start.mesh.lookAt(eye);}
    }
    function drawIntro(){
      if(!intro||!crowd)return;
      eyeNow();const toward=rig.worldToLocal(eye.clone()),k=intro.leaving?Math.max(.001,1-intro.leaving/.35):1;
      crowd.begin();
      for(const b of intro.balls){
        if(intro.t<b.born)continue;
        const falling=b.p.y>b.R+.02&&b.v.y<-1.5;
        crowd.add(b.style,V(b.p.x,b.p.y-b.R*Math.max(0,b.d),b.p.z),b.R*k,toward,[1+b.d*.75,1-b.d],b.hit>0||b.blink>0?'shut':falling?'wide':'open',b.accessory);
      }
      crowd.end();
    }

    /* ---------- controllers and hands ---------- */
    const hands=[0,1].map(i=>{
      const target=renderer.xr.getController(i),grip=renderer.xr.getControllerGrip(i);
      rig.add(target,grip);
      const h={i,target,grip,source:null,hist:[],hover:-1,buttons:[]};
      h.line=new T.Line(new T.BufferGeometry().setFromPoints([V(0,0,0),V(0,0,-1)]),new T.LineBasicMaterial({color:0x2c2d3d,transparent:true,opacity:.5}));
      target.add(h.line);
      h.dot=new T.Mesh(new T.SphereGeometry(.02,14,10),new T.MeshStandardMaterial({color:0xfffaf2,roughness:.5}));grip.add(h.dot);
      target.addEventListener('connected',e=>{
        const src=e.data;h.source=src;
        if(kind==='immersive-ar'&&session?.requestHitTestSource&&src.targetRaySpace)
          session.requestHitTestSource({space:src.targetRaySpace}).then(s=>{if(h.source===src)hitSources.set(h,s);else s.cancel();},()=>{});
      });
      target.addEventListener('disconnected',()=>{release(h,true);h.source=null;hitSources.get(h)?.cancel();hitSources.delete(h);});
      target.addEventListener('selectstart',()=>press(h,'trigger'));
      target.addEventListener('selectend',()=>release(h));
      target.addEventListener('squeezestart',()=>press(h));
      target.addEventListener('squeezeend',()=>release(h));
      return h;
    });
    const leftHand=()=>hands.find(h=>h.source?.handedness==='left');
    // The hand holding the slingshot (the left), when the slingshot is chosen.
    const forkHand=()=>throwStyle==='sling'?leftHand():null;
    function rayOf(h){
      h.target.getWorldPosition(wp);h.target.getWorldQuaternion(wq);
      return {origin:wp.clone(),dir:V(0,0,-1).applyQuaternion(wq).normalize()};
    }
    // Hand velocity in world units: the fastest ~40 ms stretch of the last 200 ms. Players often
    // let go just after the peak of a swing, so the latest instant alone would feel weak.
    function velocity(h){
      const hist=h.hist,n=hist.length,best=V(0,0,0);if(n<2)return best;
      const now=hist[n-1].t,v=V(0,0,0);
      for(let i=n-1,j=n-1;i>0;i--){
        if(now-hist[i].t>.2)break;
        j=Math.min(j,i-1);while(j>0&&hist[i].t-hist[j].t<SPAN)j--;
        const dt=hist[i].t-hist[j].t;if(dt<.008)continue;
        v.copy(hist[i].p).sub(hist[j].p).divideScalar(dt);
        if(v.lengthSq()>best.lengthSq())best.copy(v);
      }
      return best;
    }
    // Launch velocity in real metres per second (world directions), or null for too gentle a release.
    function launch(h,from){
      const s=scaleNow(),F=forkHand();
      if(F&&F!==h&&F.source){
        forkCenter.getWorldPosition(wp);const pull=wp.clone().sub(from).divideScalar(s);
        if(pull.length()<SLING_MIN)return null;
        if(pull.length()>SLING_MAX)pull.setLength(SLING_MAX);
        return pull.multiplyScalar(SLING_K);
      }
      if(throwStyle==='trigger'){
        // Along the hand's ray, as fast as the charge: real metres per second.
        const d=V(0,0,-1).applyQuaternion(h.target.getWorldQuaternion(wq)).normalize();
        return d.multiplyScalar(CHARGE_MIN+(CHARGE_MAX-CHARGE_MIN)*chargePower(h));
      }
      const u=velocity(h).multiplyScalar(GAIN/s);
      return u.length()<MIN_THROW?null:u;
    }
    // Holding the trigger charges the throw; the power rises and falls so you can pick your moment.
    const CHARGE_MIN=3,CHARGE_MAX=15,CHARGE_TIME=1.1;
    function chargePower(h){const p=((h.chargeT||0)/CHARGE_TIME)%2;return Math.max(.08,p<1?p:2-p);}
    // Real speed to game speed: the world is s times smaller and its time runs timeK times faster.
    const toGame=u=>{const v=u.clone().multiplyScalar(scaleNow()/timeK());if(v.length()>MAX_SPEED)v.setLength(MAX_SPEED);return v;};

    function press(h,how){if(!session||session.visibilityState!=='visible')return;
      if(!session)return;
      if(menuOpen&&chOpen&&h.scrollHit&&how==='trigger'){h.scrollDrag={y:h.menuY,offset:challengeList.offset};return;}
      if(menuOpen&&h.hover>=0&&how==='trigger'){menuAction(h.hover);return;}
      if(plazaOn&&h.plaza>=0&&how==='trigger'){choosePlaza(h.plaza);return;}
      if(uiBusy())return;
      // Holding a shooting trigger keeps firing (see autoFire), in every mode.
      if(intro){if(h.onStart)endIntro();else{fireIntro(h);h.autoT=clock;h.auto={fire:()=>fireIntro(h),every:.13};}return;}
      if(menuOpen&&h===leftHand())return;
      // Controllers: the left trigger is a blaster that pops the Dahroojs around the modes.
      if(how==='trigger'&&h===leftHand()&&h.source?.gamepad&&!placing&&!climbOn&&!forkHand()){fireBlast(h);h.autoT=clock;h.auto={fire:()=>fireBlast(h),every:.13};return;}
      if(placing){if(anchor){placing=false;g.respawn();}return;}
      if(climbOn){if(h===leftHand())climb3.jump();else{climb3.throwBall();h.autoT=clock;h.auto={fire:()=>climb3.throwBall(),every:.3};}return;}
      if(h===forkHand())return; // this hand holds the slingshot
      // Dahrooj in flight keeps going and a fresh one comes to the hand: throw them back to back.
      if(S.shot&&!g.another())g.recall();
      // Dahrooj appears straight in the hand with a little pop, rather than flying over to it.
      if(!holder&&g.canHold()){holder=h;holdT=0;popT=0;h.chargeT=0;parked=false;S.held=true;S.vel.set(0,0,0);S.shot=false;buzz(h,.25,25);}
    }
    function release(h,lost){if(session?.visibilityState!=='visible'||uiBusy())lost=true;
      if(h.scrollDrag){h.scrollDrag=null;h.auto=null;return;}
      h.auto=null;
      if(holder===h){
        holder=null;
        const u=lost?null:launch(h,S.pos);
        if(u){const c=curveOf(h);g.throwWith(toGame(u),c*CURVE_K);lastThrower=h;buzz(h,.35+Math.min(.5,u.length()/MAX_SPEED*.6),45);}else{parked=true;popT=0;S.pos.copy(updateParkSpot(forkHand()));}
      }
    }
    /* ---------- shots: the left-hand blaster, and every shot in the opening and Dahrooj Rain ---------- */
    // Four styles, picked in the settings (Shots):
    //   bolt     a glowing bolt, dead straight and fast, with a muzzle flash;
    //   mini     a little eyeless Dahrooj that flies, drops, bounces and rolls, popping what it touches on the way;
    //   bubble   a slow soap bubble that floats along on a wobble; big, so easy to land;
    //   firework a rocket that bursts at the end of its flight or on a hit, popping everything near it.
    // Shots pop the Dahroojs they reach (resting, in the air, in flight, and the opening's), and hit the modes
    // themselves: cans and pins get knocked, bricks break, the fair's ducks, balloons and bell count; anything
    // else takes a spark. The walls of your room (AR), the world's props (VR) and the ground stop or bounce them.
    // Until a style is picked, the blaster fires bolts and the opening its old mini Dahroojs.
    const SHOT_STYLE={
      bolt:{speed:45,grav:0,life:1.2,r:.02,cool:.12},
      mini:{speed:11,grav:1,life:3.2,r:.022,cool:.12},
      bubble:{speed:4.2,grav:-.06,life:3.6,r:.06,cool:.16},
      firework:{speed:20,grav:.35,life:.85,r:.025,cool:.2,burst:.55}
    };
    let shotChosen=false;try{shotChosen=!!localStorage.getItem('dahrooj-shot');}catch(_){}
    const styleFor=fromIntro=>shotChosen?shotStyle:fromIntro?'mini':'bolt';
    const shotGeo=new T.CylinderGeometry(.006,.006,1,6,1,true).rotateX(Math.PI/2),shotMat=new T.MeshBasicMaterial({color:0xffd27a,transparent:true,opacity:.95,depthWrite:false});
    const headGeo=new T.SphereGeometry(.012,10,8),headMat=new T.MeshBasicMaterial({color:0xfff4d6});
    const rocketMat=new T.MeshBasicMaterial({color:0xffb347});
    // Mini Dahroojs and bubbles are drawn by a crowd in the scene (game units).
    const shotCrowd=models?.crowd?models.crowd(96):null;if(shotCrowd)scene.add(shotCrowd.group);
    const FIRE_COLS=[0xe2603f,0xf2c14e,0x6fa8d6,0x7bbf8a,0xc9a2e6,0xfffaf2];
    const shotRay=new T.Raycaster();
    const blast={shots:[],sparks:[],popped:0,fired:0};
    function fireBlast(h,fromIntro=false){
      const kind_=styleFor(fromIntro),P=SHOT_STYLE[kind_];
      if(clock-(h.lastShot||0)<P.cool)return;
      // Reuse the bounded flight budget instead of stalling a held trigger until old shots expire.
      if(blast.shots.length>=16){const oldest=blast.shots.shift();if(oldest.m)scene.remove(oldest.m);}
      h.lastShot=clock;blast.fired++;g.noteStyle?.();
      const {origin,dir}=rayOf(h),k=scaleNow(),p=origin.addScaledVector(dir,.08*k);
      let m=null;
      if(kind_==='bolt'){m=new T.Group();const tr=new T.Mesh(shotGeo,shotMat),hd=new T.Mesh(headGeo,headMat);
        tr.scale.set(k,k,.35*k);tr.position.z=-.175*k;hd.scale.setScalar(k);m.add(tr,hd);m.position.copy(p);m.lookAt(p.clone().add(dir));scene.add(m);}
      else if(kind_==='firework'){m=new T.Mesh(headGeo,rocketMat);m.scale.setScalar(1.4*k);m.position.copy(p);scene.add(m);}
      const look=INTRO_STYLES[(blast.fired)%INTRO_STYLES.length];
      blast.shots.push({kind:kind_,m,p,v:dir.clone().multiplyScalar(P.speed*k),dir:dir.clone(),t:0,r:P.r*k,look,wob:Math.random()*6,fromIntro});
      // Muzzle flash (not for a bubble).
      if(kind_!=='bubble'&&blast.sparks.length<128){const f=new T.Mesh(SPARK,new T.MeshBasicMaterial({color:0xffe9b0,transparent:true}));f.scale.setScalar(.05*k);f.position.copy(p);scene.add(f);
        blast.sparks.push({m:f,p:p.clone(),v:V(0,0,0),t:0,max:.07,flash:true});}
      at(p,()=>kind_==='bolt'?g.pew?.():kind_==='firework'?g.whoosh(.35):g.whoosh(.18));buzz(h,kind_==='bubble'?.12:.3,22);
    }
    // A little spray of sparks where a shot lands.
    function impact(p,n,color=0xffd27a){
      const k=scaleNow();
      for(let i=0;i<8&&blast.sparks.length<128;i++){
        const m=new T.Mesh(SPARK,new T.MeshBasicMaterial({color:i%2?color:0xfffaf2,transparent:true}));m.scale.setScalar((.008+Math.random()*.008)*k);scene.add(m);
        const d=V(Math.random()-.5,Math.random()-.5,Math.random()-.5).normalize().addScaledVector(n,1.2).normalize().multiplyScalar((1+Math.random()*1.5)*k);
        blast.sparks.push({m,p:p.clone(),v:d,t:0,max:.25+Math.random()*.2});
      }
    }
    // A firework's bloom: coloured sparks every way.
    function bloom(p){
      const k=scaleNow();
      for(let i=0;i<26&&blast.sparks.length<128;i++){
        const m=new T.Mesh(SPARK,new T.MeshBasicMaterial({color:FIRE_COLS[i%FIRE_COLS.length],transparent:true}));m.scale.setScalar((.01+Math.random()*.01)*k);scene.add(m);
        const d=V(Math.random()-.5,Math.random()-.5,Math.random()-.5).normalize().multiplyScalar((1.6+Math.random()*1.6)*k);
        blast.sparks.push({m,p:p.clone(),v:d,t:0,max:.5+Math.random()*.35});
      }
      at(p,()=>g.popSound?.());
    }
    const shown=o=>{for(let x=o;x;x=x.parent)if(!x.visible)return false;return true;};
    function skyPop(p){if(p.y>eyeNow().y+.25*scaleNow())g.chAdd?.('skyPop5');}
    function burst(p,style,byPlayer=true){
      if(byPlayer)skyPop(p);
      const k=scaleNow();
      for(let i=0;i<(byPlayer?14:6)&&blast.sparks.length<128;i++){
        const m=new T.Mesh(SPARK,new T.MeshBasicMaterial({color:i%3?STYLE_COLORS[style]||0xfffaf2:0xfffaf2,transparent:true}));m.scale.setScalar((.012+Math.random()*.012)*k);scene.add(m);
        const a=Math.random()*Math.PI*2,e=Math.random()*Math.PI-Math.PI/2,v=(1.2+Math.random()*1.8)*k;
        blast.sparks.push({m,p:p.clone(),v:V(Math.cos(a)*Math.cos(e)*v,Math.sin(e)*v+k,Math.sin(a)*Math.cos(e)*v),t:0,max:.45+Math.random()*.3});
      }
      blast.popped++;if(byPlayer||clock>=nextAmbientPop){at(p,()=>g.popSound?.());nextAmbientPop=clock+.12;}if(byPlayer){buzz(leftHand(),.35,40);g.chAdd?.('pop20');}
    }
    const ip=V(0,0,0);
    function stepBlast(dt){
      if(shotCrowd)shotCrowd.begin();
      if(!blast.shots.length&&!blast.sparks.length){if(shotCrowd)shotCrowd.end();return;}
      const k=scaleNow(),G=REAL_G*k,a=V(0,0,0),seg=V(0,0,0),q=V(0,0,0),dirN=V(0,0,0);
      // The floor: the room's floor during the opening and the rain, the court's ground otherwise.
      const floorY=intro?rig.localToWorld(ip.set(0,0,0)).y:0;
      const st=g.stage();
      for(let i=blast.shots.length-1;i>=0;i--){
        const s=blast.shots[i],P=SHOT_STYLE[s.kind],R=s.r;s.t+=dt;
        a.copy(s.p);
        s.v.y-=G*P.grav*dt;
        if(s.kind==='bubble'){s.wob+=dt*3;s.v.x+=Math.sin(s.wob)*.25*k*dt;s.v.z+=Math.cos(s.wob*.8)*.25*k*dt;}
        s.p.addScaledVector(s.v,dt);seg.subVectors(s.p,a);const len=seg.length();dirN.copy(seg).divideScalar(len||1);
        // Distance from a point to this frame's stretch of flight.
        const nearSeg=(p,rr)=>{const t=clamp(q.subVectors(p,a).dot(seg)/(len*len||1),0,1);return q.copy(a).addScaledVector(seg,t).distanceTo(p)<rr+R;};
        let done=false,popped=false;
        // Dahroojs it reaches pop.
        for(let j=rests.length-1;j>=0;j--)if(nearSeg(rests[j].p,BR)){const r=rests[j];burst(r.p,r.style);if(r.m){scene.remove(r.m.group);r.m.dispose();}rests.splice(j,1);popped=true;}
        const vol=g.volley();for(let j=vol.length-1;j>=0;j--)if(nearSeg(vol[j].pos,BR)){burst(vol[j].pos,g.style());vol.splice(j,1);popped=true;}
        if(S.shot&&!S.held&&nearSeg(S.pos,BR)){burst(S.pos,g.style());holder=null;g.recall();popped=true;}
        if(intro&&!intro.leaving)for(const b of [...intro.balls]){if(intro.t<b.born)continue;if(nearSeg(rig.localToWorld(ip.copy(b.p)),b.R*k)){popBall(b);popped=true;}}
        // A mini Dahrooj carries on, slowed; anything else stops (a firework bursts).
        if(popped){if(s.kind==='mini')s.v.multiplyScalar(.6);else done=true;}
        // The pond (VR world): every shot meets the water its own way. A bolt plunges in, a mini Dahrooj skips off
        // the surface while it's fast and low, else sinks; a bubble settles on the water and pops; a firework fizzles.
        if(!done&&!intro&&natureOn()&&nature.waterAt&&s.p.y<R*1.05&&a.y>=R*.5&&nature.waterAt(s.p.x,s.p.z)>0){
          const hs=Math.hypot(s.v.x,s.v.z),vs=-s.v.y;
          if(s.kind==='mini'&&hs>2.2*k&&vs<hs*.7&&(s.skips||0)<4){s.skips=(s.skips||0)+1;s.p.y=R;s.v.y=Math.max(.6*k,vs*.55);s.v.x*=.82;s.v.z*=.82;
            nature.splash(s.p.x,s.p.z,.2);at(s.p,()=>g.splash?.(.15));}
          else if(s.kind==='bubble'){s.p.y=R;s.v.set(0,0,0);s.float=(s.float||0);}
          else{nature.splash(s.p.x,s.p.z,s.kind==='firework'?.6:s.kind==='mini'?.35:.25);at(s.p,()=>g.splash?.(s.kind==='firework'?.5:.25));
            if(s.kind==='firework')impact(s.p,UP,0xfffaf2);done=true;s.wet=true;}
        }
        if(s.float!=null&&!done){s.float+=dt;s.p.y=R;nature.waterline?.(s.p.x,0,s.p.z,R);if(s.float>.9){nature.splash(s.p.x,s.p.z,.15);at(s.p,()=>g.popSound?.());done=true;}}
        // The mode itself: the first visible thing along the way.
        if(!done&&st&&st.grp&&st.grp.visible&&!climbOn&&len>0){
          shotRay.set(a,dirN);shotRay.far=len+R;
          const hit=shotRay.intersectObject(st.grp,true).find(h=>h.object.isMesh&&shown(h.object)); // solid things only: the stages' guide lines on the ground don't stop a shot
          if(hit){
            const n=hit.face?hit.face.normal.clone().transformDirection(hit.object.matrixWorld):dirN.clone().negate();
            const took=g.shootStage?.(hit.object,hit.point,dirN.clone());
            impact(hit.point,n,took?0xffd27a:0xfffaf2);if(!took)at(hit.point,()=>g.bump?.(.25));
            if(s.kind==='mini'&&!took){s.p.copy(hit.point).addScaledVector(n,R);const vn=s.v.dot(n);if(vn<0)s.v.addScaledVector(n,-1.5*vn);}
            else done=true;
          }
        }
        // Motri's props (crates go off), the walls of your room, and the floor. A mini Dahrooj bounces off them.
        if(!done&&natureOn()&&nature.props){const v=s.v.clone();if(nature.props.collide(s.p,v,R)){if(s.kind==='mini')s.v.copy(v);else{impact(s.p,dirN.clone().negate());done=true;}}}
        if(!done&&roomPlanes.size){const v=s.v.clone(),hit=roomCollide(s.p,v,R,dt);if(hit>0){if(s.kind==='mini'){s.v.copy(v);if(hit>1.5*k&&s.t-(s.tap||0)>.15){s.tap=s.t;at(s.p,()=>g.bump?.(.15));}}else{impact(s.p,dirN.clone().negate());done=true;}}}
        if(!done&&s.p.y<floorY+R){
          if(s.kind==='mini'){s.p.y=floorY+R;if(s.v.y<-.8*k)s.v.y*=-.45;else s.v.y=0;const f=Math.pow(.55,dt);s.v.x*=f;s.v.z*=f;}
          else{s.p.y=floorY;impact(s.p,UP);done=true;}
        }
        if(s.kind==='firework'&&!s.wet&&(done||s.t>P.life)){
          // The burst pops every Dahrooj near it.
          const RR=P.burst*k;
          for(let j=rests.length-1;j>=0;j--)if(rests[j].p.distanceTo(s.p)<RR+BR){const r=rests[j];burst(r.p,r.style);if(r.m){scene.remove(r.m.group);r.m.dispose();}rests.splice(j,1);}
          if(intro&&!intro.leaving)for(const b of [...intro.balls]){if(intro.t<b.born)continue;if(rig.localToWorld(ip.copy(b.p)).distanceTo(s.p)<RR+b.R*k)popBall(b);}
          bloom(s.p);done=true;
        }
        if(s.kind==='firework'&&s.m&&!done&&blast.sparks.length<128&&Math.random()<.6){const f=new T.Mesh(SPARK,new T.MeshBasicMaterial({color:0xffc070,transparent:true}));f.scale.setScalar(.006*k);scene.add(f);
          blast.sparks.push({m:f,p:s.p.clone(),v:V((Math.random()-.5)*.3*k,(Math.random()-.5)*.3*k,(Math.random()-.5)*.3*k),t:0,max:.25});}
        if(s.m)s.m.position.copy(s.p);
        if(done||(s.t>P.life&&s.float==null)){if(s.m)scene.remove(s.m);if(s.kind==='bubble'&&!done)at(s.p,()=>g.popSound?.());blast.shots.splice(i,1);continue;}
        if(shotCrowd&&(s.kind==='mini'||s.kind==='bubble'))shotCrowd.add(s.kind==='bubble'?'bubble':s.look,s.p,R,null,[1,1],null);
      }
      if(shotCrowd)shotCrowd.end();
      for(let i=blast.sparks.length-1;i>=0;i--){
        const s=blast.sparks[i];s.t+=dt;if(!s.flash)s.v.y-=G*.5*dt;s.p.addScaledVector(s.v,dt);s.m.position.copy(s.p);s.m.material.opacity=1-s.t/s.max;
        if(s.t>=s.max){scene.remove(s.m);s.m.material.dispose();blast.sparks.splice(i,1);}
      }
    }
    function clearBlast(){for(const s of blast.shots)if(s.m)scene.remove(s.m);for(const s of blast.sparks){scene.remove(s.m);s.m.material.dispose();}blast.shots.length=blast.sparks.length=0;if(shotCrowd){shotCrowd.begin();shotCrowd.end();}}
    // A or X: Dahrooj comes back at once.
    function recall(){
      g.clearVolley();if(S.shot){holder=null;g.recall();}
    }

    /* ---------- placing the world ---------- */
    // The point of the court pinned to the surface: the target (goal mouth, hoop, window, cans).
    const targetPoint=()=>V(0,0,climbOn?GOAL_AIM_Z:(g.stage().aimZ||-10));
    // Curve for a throw (-1..1, positive bends right). Trigger: tilt the controller sideways as you let go,
    // like spinning a frisbee. Hand: the ball follows the bend in the hand's path. Slingshot: straight.
    function curveOf(h){
      if(forkHand())return 0;
      if(throwStyle==='trigger'){
        const r=V(1,0,0).applyQuaternion(h.target.getWorldQuaternion(wq)),tilt=-r.y;
        return Math.abs(tilt)<.12?0:clamp((tilt-Math.sign(tilt)*.12)/.45,-1,1);
      }
      const hs=h.hist;if(hs.length<6)return 0;
      const n=hs.length,m=n>>1,e=hs[m].p.clone().sub(hs[0].p),l=hs[n-1].p.clone().sub(hs[m].p);
      if(Math.hypot(e.x,e.z)<.02||Math.hypot(l.x,l.z)<.02)return 0;
      let a=Math.atan2(l.x,-l.z)-Math.atan2(e.x,-e.z);a=Math.atan2(Math.sin(a),Math.cos(a));
      return Math.abs(a)<.08?0:clamp(a/.6,-1,1);
    }
    // Headset flights last longer than a swipe on the web, so the same pull bends them more: scale it down.
    const CURVE_K=.4;
    const FAR_Z=-20;
    function place(){
      const A=targetPoint();placedFor=g.mode();
      if(kind!=='immersive-ar'){
        // Every target stands as far away as the cans: you step back from the nearer ones.
        // Bowling keeps its own lane (farZ); Summit shares the goal court. The wall and the fair keep their
        // backdrop (farZ) but stand back like the rest, a little nearer (reachZ).
        const st=g.stage(),back=climbOn?Math.max(0,GOAL_AIM_Z-FAR_Z):st&&(st.farZ==null||st.reachZ!=null)?Math.max(0,(st.aimZ??-10)-(st.reachZ??FAR_Z)):0;
        rig.scale.setScalar(VR_SCALE);rig.rotation.set(0,0,0);rig.position.set(0,0,.5*VR_SCALE+back);
        // High over the play area, clear of the line of throw, and a little larger so it reads at a glance.
        hud.mesh.position.set(0,2.02,-3.4);hud.mesh.scale.setScalar(1.8);return;
      }
      if(!anchor){const {pos,dir}=headLocal();anchor={P:V(pos.x+dir.x*1.6,0,pos.z+dir.z*1.6),theta:Math.atan2(dir.x,-dir.z)};}
      // The physical spot P becomes the target point, with the court facing the player.
      const s=arScale;rig.scale.setScalar(s);rig.rotation.set(0,anchor.theta,0);
      rig.position.copy(A).sub(anchor.P.clone().multiplyScalar(s).applyAxisAngle(UP,anchor.theta));
      // The score board as in VR: up at a comfortable height just behind the target, out of the line of throw, and large.
      const away=V(Math.sin(anchor.theta),0,-Math.cos(anchor.theta));
      hud.mesh.position.copy(anchor.P).addScaledVector(away,anchor.wall?0:.35).setY(Math.max(anchor.P.y+.75,1.55));hud.mesh.scale.setScalar(.95);
    }
    function aimAtSurface(frame){
      // The headset's own surfaces (hit test) first, the floor otherwise.
      const h=hands.find(x=>x.source&&x!==leftHand())||hands.find(x=>x.source);if(!h)return null;
      const src=hitSources.get(h),space=renderer.xr.getReferenceSpace();
      if(frame&&src&&space){
        const res=frame.getHitTestResults(src);
        if(res.length){const tf=res[0].getPose(space)?.transform;
          if(tf){const q=tf.orientation,n=V(0,1,0).applyQuaternion(new T.Quaternion(q.x,q.y,q.z,q.w));return {P:V(tf.position.x,tf.position.y,tf.position.z),n};}}
      }
      const o=h.target.position,d=V(0,0,-1).applyQuaternion(h.target.quaternion);
      if(d.y<-.05){const t=-o.y/d.y;if(t<8)return {P:o.clone().addScaledVector(d,t),n:V(0,1,0)};}
      return null;
    }
    // Where the court goes for a spot on a surface. On a wall (its normal lies flat) the court stands on
    // the floor below with its back against the wall: the goal's net or the hoop's board touches it.
    function anchorFrom(P,n){
      // A raised surface facing up (a table, a bed) gets the smaller court; the floor and walls the usual one.
      arScale=(n.y>.5&&P.y>.35?AR_TABLE:AR_SCALE)/arZoom;
      if(Math.abs(n.y)<.5){
        const f=V(n.x,0,n.z).normalize(),st=g.stage(),box=new T.Box3().setFromObject(st.grp);
        const back=Math.max(0,((st.aimZ||-10)-box.min.z))/arScale+.03;
        return {P:V(P.x,0,P.z).addScaledVector(f,back),theta:Math.atan2(-f.x,f.z),wall:true};
      }
      const {pos}=headLocal(),dx=P.x-pos.x,dz=P.z-pos.z;
      return {P,theta:Math.hypot(dx,dz)>.05?Math.atan2(dx,-dz):anchor?.theta||0};
    }
    // Outline the surfaces the headset found while choosing a spot.
    /* ---------- mixed reality: the real room's walls and furniture as colliders (AR) ---------- */
    // The headset's detected planes (walls, tables, sofa, ceiling...) are turned into game space every
    // frame. A ball is tested along the path it moved this frame, so a fast throw can't slip through a
    // wall between two frames. The real floor stays the game's own floor.
    const roomPlanes=new Map(),lp=V(0,0,0),lq=V(0,0,0),rn=V(0,0,0);
    function updateRoom(frame){
      if(kind!=='immersive-ar'){if(roomPlanes.size)for(const [k,e] of roomPlanes)if(!e.test)roomPlanes.delete(k);return;}
      const planes=frame&&frame.detectedPlanes,space=renderer.xr.getReferenceSpace();if(!planes||!space)return;
      rig.updateMatrixWorld();const seen=new Set();
      for(const plane of planes){
        const label=(plane.semanticLabel||'').toLowerCase();if(label==='floor')continue;
        const pose=frame.getPose(plane.planeSpace,space);if(!pose)continue;seen.add(plane);
        let e=roomPlanes.get(plane);if(!e){e={m:new T.Matrix4(),inv:new T.Matrix4()};roomPlanes.set(plane,e);}
        if(e.t!==plane.lastChangedTime){e.t=plane.lastChangedTime;e.poly=plane.polygon.map(q=>[q.x,q.z]);}
        e.label=label;e.m.fromArray(pose.transform.matrix).premultiply(rig.matrixWorld);e.inv.copy(e.m).invert();
      }
      for(const [k,e] of roomPlanes)if(!e.test&&!seen.has(k))roomPlanes.delete(k);
    }
    function inPoly(x,z,poly){
      let inside=false;
      for(let i=0,j=poly.length-1;i<poly.length;j=i++){const [xi,zi]=poly[i],[xj,zj]=poly[j];
        if(((zi>z)!==(zj>z))&&(x<(xj-xi)*(z-zi)/(zj-zi)+xi))inside=!inside;}
      return inside;
    }
    // Sphere (game units) against every room plane; bounces off like the game's own walls.
    function roomCollide(p,v,R,step){
      if(!roomPlanes.size)return 0;
      let hit=0;const s=rig.scale.x,r=R/s;
      for(const e of roomPlanes.values()){
        lp.copy(p).applyMatrix4(e.inv);lq.copy(p).addScaledVector(v,-step).applyMatrix4(e.inv);
        const crossed=(lp.y>0)!==(lq.y>0);
        if(!crossed&&Math.abs(lp.y)>=r)continue;
        // Where the path met the plane (or the nearest point), inside the surface's outline?
        const t=crossed?lq.y/(lq.y-lp.y):1,cx=lq.x+(lp.x-lq.x)*t,cz=lq.z+(lp.z-lq.z)*t;
        if(!inPoly(cx,cz,e.poly))continue;
        // Back onto the side it came from, touching the surface, and a bounce that loses a little.
        const side=(crossed?lq.y:lp.y)>=0?1:-1;
        rn.set(0,side,0).transformDirection(e.m);
        if(crossed)p.copy(lp.set(cx,side*r*1.001,cz).applyMatrix4(e.m));
        else p.addScaledVector(rn,(r-Math.abs(lp.y))*s);
        const vn=v.dot(rn);if(vn<0){v.addScaledVector(rn,-1.55*vn);v.multiplyScalar(.92);hit=Math.max(hit,-vn);}
      }
      return hit;
    }
    // For tests: a stand-in wall (matrix in rig space, outline in its own x/z).
    function addTestPlane(matrixArray,poly,label='wall'){rig.updateMatrixWorld();const m=new T.Matrix4().fromArray(matrixArray).premultiply(rig.matrixWorld);
      roomPlanes.set({},{test:true,m,inv:m.clone().invert(),poly,label});}
    function showPlanes(frame){
      const planes=frame&&frame.detectedPlanes,space=renderer.xr.getReferenceSpace(),seen=new Set();
      if(placing&&planes&&space)for(const plane of planes){
        seen.add(plane);let e=planeLines.get(plane);
        if(!e||e.t!==plane.lastChangedTime){
          if(e)planesGroup.remove(e.line);
          const line=new T.LineLoop(new T.BufferGeometry().setFromPoints(plane.polygon.map(p=>V(p.x,p.y,p.z))),new T.LineBasicMaterial({color:0xfffaf2,transparent:true,opacity:.6}));
          line.matrixAutoUpdate=false;planesGroup.add(line);e={line,t:plane.lastChangedTime};planeLines.set(plane,e);
        }
        const pose=frame.getPose(plane.planeSpace,space);
        if(pose){e.line.matrix.fromArray(pose.transform.matrix);e.line.visible=true;}else e.line.visible=false;
      }
      for(const [plane,e] of planeLines)if(!seen.has(plane)){planesGroup.remove(e.line);planeLines.delete(plane);}
    }

    /* ---------- Summit ---------- */
    function setClimb(on){
      if(on)setRain(false);
      if(on&&!climb3){
        if(!createReferenceMountain||!g.climbCore)return;
        climb3=createReferenceMountain(T,{core:g.climbCore,models,BR,renderer,unit:climbUnit});rig.add(climb3.group);climb3.start();
      }
      climbOn=!!on&&!!climb3;
      if(climb3)climb3.show(climbOn);
      const st=g.stage();if(st&&st.grp)st.grp.visible=!climbOn;
      holder=null;parked=false;S.held=false;g.clearVolley();hud.key='';
      // Summit uses the same court transform as Goal, independent of the previous mode.
      if(climbOn)climbSpot=null;
      if(session)place();
    }
    // The mountain stands on the pinned surface (AR) or on a plinth just in front of you (VR).
    function placeClimb(){
      let P,theta;
      if(kind==='immersive-ar'&&anchor){P=anchor.P;theta=anchor.theta;
        // Surface scale supplies the initial size; preserve the player's right-stick zoom after placement.
        const u=clamp(CLIMB_VR*VR_SCALE/arScale*climbZoom,.012,.2);if(Math.abs(u-climbUnit)>1e-6){climbUnit=u;climb3.setUnit(u);hud.key='';}}
      else{
        // VR: the mountain stands on the ground where the goal stands, facing you, like the other modes.
        // A few centimetres up, so its own ground doesn't flicker against the stone floor.
        if(!climbSpot)climbSpot={P:V(0,.04,(CLIMB_Z-rig.position.z)/rig.scale.x),theta:0};
        P=climbSpot.P;theta=climbSpot.theta;
      }
      climb3.group.position.copy(P);climb3.group.rotation.set(0,-theta,0);
      climb3.setBase(kind==='immersive-ar'?0:P.y);
      // The hearts: in VR on the same board, in the same place, as every other mode; in AR over the mountain, larger.
      if(kind==='immersive-ar'){hud.mesh.position.copy(P).add(V(0,24*climbUnit+.16,0));hud.mesh.scale.setScalar(.85);}
      else{hud.mesh.position.set(0,2.75,-3.4);hud.mesh.scale.setScalar(1.8);} // above the mountain, clear of the climb
    }
    function climbEvent(e){
      if(e.type==='land'){if(e.power>.08)g.bump?.(e.power*.8);}
      else if(e.type==='launch')g.whoosh(e.power);
      else if(e.type==='throw')g.whoosh(.25);
      else if(e.type==='hurt')g.bump?.(1);
      g.climbEvent?.(e);
    }

    /* ---------- session ---------- */
    async function enter(mode,{opening=false,climb=false}={}){
      if(session||!navigator.xr)return;
      if(!XR_MODES.has(g.mode()))g.setMode('goal');
      const options=mode==='immersive-ar'
        ?{requiredFeatures:['local-floor'],optionalFeatures:['hand-tracking','hit-test','plane-detection']}
        :{optionalFeatures:['local-floor','bounded-floor','hand-tracking']};
      const s=g.getSession();if(!s)throw new Error('IWSDK session required');
      session=s;kind=mode;lang=g.language();layoutMenu();anchor=null;arScale=AR_SCALE;arZoom=1;placing=mode==='immersive-ar';menuToggled=false;
      renderer.xr.enabled=true;renderer.xr.setReferenceSpaceType('local-floor');
      place();
      if(mode==='immersive-vr'&&!nature&&createReferenceNature)nature=createReferenceNature(T,{scene,hemi:g.hemi,sun:g.sun,lineMat:g.lineMat});
      // The world's own sounds: wind, leaves, rain, the pond, birds by day and crickets at night.
      if(nature&&!ambience&&createReferenceAmbience&&g.audio)ambience=createReferenceAmbience({audio:g.audio,nature});
      // Crate blasts clear nearby characters in a 3D radius, never the ball held by the player.
      if(nature?.props&&!nature.props.onExplode)nature.props.onExplode=(boomAt,R,byPlayer=true)=>{
        at(boomAt,()=>g.boom?.());for(const h of hands)buzz(h,.9,180);if(byPlayer)g.chAdd?.('crates5');
        const reach=(R+BR)*(R+BR);
        for(let i=rests.length-1;i>=0;i--)if(rests[i].p.distanceToSquared(boomAt)<=reach)popRest(i);
        const flying=g.volley();for(let i=flying.length-1;i>=0;i--)if(flying[i].pos.distanceToSquared(boomAt)<=reach){burst(flying[i].pos,g.style(),false);flying.splice(i,1);}
        if(S.shot&&!S.held&&S.pos.distanceToSquared(boomAt)<=reach){burst(S.pos,g.style(),false);holder=null;g.recall();}
        const scale=scaleNow();
        if(intro?.rain)for(let i=intro.balls.length-1;i>=0;i--){const b=intro.balls[i];if(intro.t<b.born)continue;rig.localToWorld(rainPropP.copy(b.p));if(rainPropP.distanceToSquared(boomAt)<=(R+b.R*scale)**2)popBall(b,false);}
        for(let i=blast.shots.length-1;i>=0;i--){const shot=blast.shots[i];if(shot.kind==='mini'&&shot.p.distanceToSquared(boomAt)<=(R+shot.r)**2){burst(shot.p,shot.look,false);if(shot.m)scene.remove(shot.m);blast.shots.splice(i,1);}}
      };
      if(nature)nature.enable(mode==='immersive-vr');
      floor.visible=mode==='immersive-vr'&&!nature;
      s.addEventListener('end',onEnd);
      // IWSDK owns the XR session.
      // Fixed foveation: the headset draws the edges of the view at lower resolution, where the eye doesn't notice.
      renderer.xr.setFoveation(.6);
      lastTime=0;frames=0;
      g.respawn();
      if(opening){placing=false;beginIntro();}
      climbSpot=null;climbZoom=1;climbUnit=mode==='immersive-ar'?CLIMB_AR:CLIMB_VR;climb3?.setUnit(climbUnit);if(climb)setClimb(true);
    }
    function onEnd(){
      // IWSDK keeps its render loop.
      for(const s of hitSources.values())s.cancel?.();hitSources.clear();
      rainOn=false;clearIntro();start.mesh.visible=false;
      cards.length=0;cardNow=null;card.mesh.visible=false;plazaOn=false;plaza.visible=false;plazaK=0;
      setClimb(false);holder=null;parked=false;placing=false;S.held=false;g.clearVolley();g.respawn();
      session=null;kind=null;
      rig.scale.setScalar(1);rig.position.set(0,0,0);rig.quaternion.identity();
      if(nature)nature.enable(false);ambience?.stop();
      scene.background=null;floor.visible=false;ballSprite.visible=false;
      for(const d of dots)d.visible=false;
      if(ballModel)ballModel.group.visible=false;for(const m of volleyModels)if(m)m.group.visible=false;
      clearRests();clearBlast();
      
      g.resize();g.onExit?.();
    }

    /* ---------- thrown balls stay in the world ---------- */
    // When a throw is over, that Dahrooj stays where he stopped instead of vanishing: he rolls on,
    // bumps into the others and now and then sets off on his own. The oldest go when there are many.
    const RESTS_MAX=8,REST_LIFE=12,REST_ROOM=26,rests=[];
    g.setRestHook?.((pos,vel)=>{
      if(!session||climbOn)return;
      // It keeps the reward it was wearing when it was thrown.
      const m=models?models.make(g.style(),{lite:true}):null;if(m){m.setAccessory?.(wornNow());scene.add(m.group);}
      rests.push({age:0,bornAt:performance.now(),m,style:g.style(),p:pos.clone(),v:vel.clone(),d:0,dv:0,wander:1.5+Math.random()*4,blink:0,next:1+Math.random()*3,mood:null,moodT:0,petT:0});
      if(rests.length>RESTS_MAX){const o=rests.shift();if(o.m){scene.remove(o.m.group);o.m.dispose();}}
    });
    function clearRests(){for(const r of rests)if(r.m){scene.remove(r.m.group);r.m.dispose();}rests.length=0;}
    // Tracks on the grass, snow and ground wherever a ball touches down or rolls.
    function markBall(p,v){
      if(!natureOn()||p.y>BR*1.2)return;
      const sp=Math.hypot(v.x,v.z),hit=Math.abs(v.y);
      if(sp<.25&&hit<1)return;
      nature.mark(p.x,p.z,BR*(.85+Math.min(.8,hit*.08)),Math.min(.6,.12+sp*.04+hit*.06));
    }
    const restPrev=V();
    function stepRests(dt){
      const now=performance.now();
      for(let i=rests.length-1;i>=0;i--){const r=rests[i];r.age=(now-r.bornAt)/1000;if(r.age>=REST_LIFE){r.m?.dispose();rests.splice(i,1);}}
      const G=g.GRAV,cx=0,cz=-10;
      for(const r of rests){
        const p=r.p,v=r.v;restPrev.copy(p);v.y-=G*dt;p.addScaledVector(v,dt);g.stage()?.collideBody?.(p,v,BR,restPrev);
        let grounded=false;
        // In the pond it floats half under and paddles slowly back to the shore (the pull back to the field below).
        const wet=natureOn()&&nature.waterAt&&nature.waterAt(p.x,p.z)>0;
        if(wet&&p.y<BR){if(!r.wet){r.wet=true;nature.splash(p.x,p.z,Math.min(1,-v.y/12));at(p,()=>g.splash?.(Math.min(1,-v.y/10)));}
          v.y+=(G+(-BR*.2-p.y)*38-v.y*4.5)*dt;const f=Math.pow(.3,dt);v.x*=f;v.z*=f;}
        else{if(p.y>BR*1.2)r.wet=false;
        if(p.y<BR){p.y=BR;if(v.y<-1.4){r.dv-=Math.min(8,-v.y);v.y*=-.45;}else{v.y=0;grounded=true;}}}
        if(grounded){
          const f=Math.pow(.75,dt);v.x*=f;v.z*=f;
          // A life of their own: every few seconds a roll in a random direction, sometimes a hop.
          r.wander-=dt;
          if(r.wander<=0){const a=Math.random()*Math.PI*2,sp=.6+Math.random()*1.8;v.x+=Math.cos(a)*sp;v.z+=Math.sin(a)*sp;if(Math.random()<.35){v.y=2+Math.random()*2;r.dv-=3;}r.wander=3+Math.random()*7;}
        }
        // Stay on the field.
        const ox=p.x-cx,oz=p.z-cz,od=Math.hypot(ox,oz);if(od>REST_ROOM){v.x-=ox/od*dt*4;v.z-=oz/od*dt*4;}
        r.dv+=(-r.d*300-r.dv*12)*dt;r.d=clamp(r.d+r.dv*dt,-.3,.45);
        r.next-=dt;if(r.next<=0){r.blink=.14;r.next=2+Math.random()*3;}r.blink=Math.max(0,r.blink-dt);
        markBall(p,v);
      }
    }
    function popRest(index){const r=rests[index];burst(r.p,r.style,false);if(r.m){scene.remove(r.m.group);r.m.dispose();}rests.splice(index,1);}
    const contactBodies=[],contactDead=new Uint8Array(12),contactNormal=V(0,0,0);
    function stepWorldContacts(dt){
      // Eight leftovers, three previous throws and the current throw: at most 66 pairs.
      const flying=g.volley(),restCount=rests.length,flyingCount=flying.length;
      contactBodies.length=0;contactDead.fill(0);
      for(const r of rests)contactBodies.push(r);for(const b of flying)contactBodies.push(b);
      if(S.shot&&!S.held)contactBodies.push(S);
      const threshold=2.4*scaleNow()/timeK(); // metres per real second, also at AR scale
      for(let i=0;i<contactBodies.length;i++)for(let j=i+1;j<contactBodies.length;j++){
        if(contactDead[i]||contactDead[j])continue;
        const a=contactBodies[i],b=contactBodies[j],ap=a.p||a.pos,av=a.v||a.vel,bp=b.p||b.pos,bv=b.v||b.vel;
        if(ballImpactSpeed(ap,av,bp,bv,BR*2,dt)>=threshold){contactDead[i]=contactDead[j]=1;continue;}
        contactNormal.copy(bp).sub(ap);const length=contactNormal.length();
        if(length>0&&length<BR*2){
          contactNormal.divideScalar(length);const push=(BR*2-length)/2;ap.addScaledVector(contactNormal,-push);bp.addScaledVector(contactNormal,push);
          const rel=(bv.x-av.x)*contactNormal.x+(bv.y-av.y)*contactNormal.y+(bv.z-av.z)*contactNormal.z;
          if(rel<0){av.addScaledVector(contactNormal,rel*.9);bv.addScaledVector(contactNormal,-rel*.9);}
        }
      }
      // Remove after detection, in reverse order, so a character can pop only once this frame.
      for(let i=contactBodies.length-1;i>=0;i--)if(contactDead[i]){
        const b=contactBodies[i];
        if(i<restCount)popRest(i);
        else{burst(b.pos,g.style(),false);if(i<restCount+flyingCount)flying.splice(i-restCount,1);else{holder=null;g.recall();}}
      }
      contactBodies.length=0;
    }
    /* ---------- Dahrooj feels you: pat one and he giggles; shake the one in your hand and he gets dizzy ---------- */
    const handAt=V(0,0,0);
    function feelHands(dt){
      for(const r of rests){r.moodT=Math.max(0,r.moodT-dt);r.petT=Math.max(0,r.petT-dt);}
      for(const h of hands){
        if(!h.source)continue;h.grip.getWorldPosition(handAt);
        for(const r of rests){
          if(r.petT>0||handAt.distanceTo(r.p)>BR*1.7)continue;
          r.petT=1.4;r.mood='joy';r.moodT=1.3;r.dv-=4;if(r.p.y<=BR*1.05)r.v.y=2.2;r.blink=0;
          at(r.p,()=>g.squeak?.(1+Math.random()*.3));buzz(h,.3,40);
        }
      }
      // Shaking: the holding hand travels a long way over a quarter second but stays in one place.
      if(holder&&holder.hist.length>4){
        const k=scaleNow(),hs=holder.hist;let path=0;for(let i=1;i<hs.length;i++)path+=hs[i].p.distanceTo(hs[i-1].p);
        const net=hs[hs.length-1].p.distanceTo(hs[0].p);
        if(path/k>.55&&net/k<.18&&!(S.mood==='dizzy'&&S.moodT>0)){S.mood='dizzy';S.moodT=1.8;S.moodNext=null;at(S.pos,()=>g.squeak?.(.7));buzz(holder,.5,90);}
      }
    }
    function drawRests(){
      for(const r of rests){
        if(!r.m)continue;r.m.group.visible=!climbOn&&!intro;
        const sp=Math.hypot(r.v.x,r.v.z);
        r.m.update({pos:V(r.p.x,r.p.y-BR*Math.max(0,r.d),r.p.z),toward:eye,faceName:r.moodT>0?r.mood:sp>5?'wide':'open',blink:r.blink>0,squash:[1+r.d*.75,1-r.d]});r.m.group.scale.multiplyScalar(Math.min(1,(REST_LIFE-r.age)/.75));
      }
    }


    /* ---------- the mode plaza: floating cards, one live miniature per mode ---------- */
    // B opens it: eight cards in two arcs around you at chest height. Point at one and it comes forward and its
    // miniature comes alive; pull the trigger on it, or throw Dahrooj into it, to go there.
    const PLAZA=[
      ['goal','مرمى','Goal','سجّل على الحارس','Score past the keeper'],['hoop','سلة','Hoop','سلات ورا بعض','Hoops in a row'],
      ['window','شباك','Window','الشباك يصغر','The window shrinks'],['cans','علب','Cans','طيّحها كلها','Knock them all down'],
      ['bowling','بولينغ','Bowling','سترايك!','Strike!'],['bricks','الطوب','Bricks','اكسر القلعة','Break the castle'],
      ['fair','ملاهي','Fair','٦٠ ثانية نقاط','60 seconds of points'],['climb','الجبل','Summit','اوصل القمة','Reach the top'],
      ['rain','مطر دحاريج','Dahrooj Rain','فجّرها كلها','Pop them all']];
    const plaza=new T.Group();plaza.name='xr-plaza';plaza.visible=false;rig.add(plaza);
    let plazaOn=false,plazaK=0,plazaHot=-1,plazaPick=null;
    const pm=(c,o={})=>menuDepth(new T.MeshStandardMaterial({color:c,roughness:.8,...o,toneMapped:false,fog:false}));
    const PM={cream:pm(0xfffaf2),ink:pm(0x2c2d3d),coral:pm(0xe2603f),gold:pm(0xf2c14e),leaf:pm(0x7bbf8a),wood:pm(0xc98f5c),stone:pm(0xd9a67e),brown:pm(0x7b5536),sky:pm(0x6fa8d6),grey:pm(0xb9ad9c,{metalness:.4})};
    const box=(w,h,d,m,x,y,z)=>{const o=new T.Mesh(new T.BoxGeometry(w,h,d),m);o.position.set(x,y,z);return o;};
    const ball=(r,m,x,y,z)=>{const o=new T.Mesh(new T.SphereGeometry(r,16,12),m);o.position.set(x,y,z);return o;};
    const cyl=(r,h,m,x,y,z)=>{const o=new T.Mesh(new T.CylinderGeometry(r,r,h,14),m);o.position.set(x,y,z);return o;};
    // Each miniature is about 16 cm across, standing on a little round plinth; spin() animates it when pointed at.
    function mini(id){
      const g=new T.Group(),a=[];const add=(...o)=>{for(const x of o)g.add(x);};
      add(Object.assign(cyl(.085,.012,PM.cream,0,0,0)));
      if(id==='goal'){for(const x of [-.06,.06])add(cyl(.004,.06,PM.cream,x,.036,0));const bar=cyl(.004,.124,PM.cream,0,.066,0);bar.rotation.z=Math.PI/2;add(bar);
        const k=ball(.016,PM.coral,0,.025,.01);add(k);a.push(t=>{k.position.x=Math.sin(t*3)*.04;});add(ball(.012,PM.ink,.03,.02,.06));}
      else if(id==='hoop'){add(cyl(.004,.1,PM.grey,0,.056,-.04),box(.07,.05,.004,PM.cream,0,.1,-.035));const r=new T.Mesh(new T.TorusGeometry(.018,.003,6,18),PM.coral);r.rotation.x=Math.PI/2;r.position.set(0,.085,-.015);add(r);
        const b=ball(.011,PM.ink,0,.03,.04);add(b);a.push(t=>{const k=(t*.8)%1;b.position.set(0,.03+Math.sin(k*Math.PI)*.07,.04-k*.055);});}
      else if(id==='window'){const f=new T.Group();for(const [w,h,x,y] of [[.06,.006,0,.03],[.06,.006,0,-.03],[.006,.06,.03,0],[.006,.06,-.03,0]])f.add(box(w,h,.006,PM.ink,x,y,0));
        f.position.y=.08;add(f,cyl(.003,.05,PM.ink,0,.03,0));a.push(t=>{f.position.x=Math.sin(t*1.5)*.025;const s=.8+.2*Math.sin(t*2);f.scale.set(s,s,1);});}
      else if(id==='cans'){add(box(.12,.006,.05,PM.wood,0,.04,0));for(const [x,y] of [[-.03,0],[0,0],[.03,0],[-.015,1],[.015,1],[0,2]])add(cyl(.012,.026,y%2?PM.ink:PM.coral,x,.057+y*.027,0));
        const b=ball(.011,PM.ink,0,.03,.07);add(b);a.push(t=>{const k=(t*.7)%1;b.position.z=.07-k*.07;b.position.y=.03+Math.sin(k*Math.PI)*.04;});}
      else if(id==='bowling'){add(box(.05,.004,.15,PM.wood,0,.008,0));const pins=[];for(const [x,z] of [[0,0],[-.01,-.015],[.01,-.015],[-.02,-.03],[0,-.03],[.02,-.03]]){const p=cyl(.004,.028,PM.cream,x,.025,z-.03);pins.push(p);add(p);}
        const b=ball(.012,PM.ink,0,.02,.06);add(b);a.push(t=>{const k=(t*.5)%1;b.position.z=.06-k*.12;pins.forEach((p,i)=>{p.rotation.x=k>.85?-(k-.85)*8*(i%2?1:.6):0;});});}
      else if(id==='bricks'){const sh=[PM.stone,pm(0xe8b98c),pm(0xc98f6a)];for(let r=0;r<4;r++)for(let c=0;c<5;c++)add(box(.022,.011,.012,sh[(r+c)%3],(c-2)*.023+(r%2?.006:0),.012+r*.012,0));
        for(const x of [-.07,.07]){add(box(.03,.07,.025,PM.stone,x,.04,0));for(const dx of [-.01,.01])add(box(.008,.01,.008,PM.stone,x+dx,.08,.008));
          const fl=box(.022,.012,.002,PM.coral,x+.012,.105,0);add(fl,cyl(.0015,.035,PM.wood,x,.095,0));a.push(t=>{fl.rotation.y=Math.sin(t*5+x*40)*.4;});}}
      else if(id==='fair'){add(box(.13,.05,.03,PM.wood,0,.03,-.01),box(.14,.006,.04,PM.cream,0,.058,0));for(const x of [-.064,.064])add(cyl(.003,.08,PM.cream,x,.08,.012));
        for(let i=0;i<8;i++)add(box(.0175,.006,.045,i%2?PM.cream:PM.coral,-.061+i*.0175,.122,0));
        const ducks=[];for(let i=0;i<4;i++){const d=ball(.009,PM.gold,0,.068,0);ducks.push(d);add(d);}
        const bl=ball(.012,PM.sky,-.03,.095,-.012),bl2=ball(.012,PM.coral,.02,.1,-.012);add(bl,bl2);
        a.push(t=>{ducks.forEach((d,i)=>{d.position.x=((i*.035+t*.03)%.14)-.07;});bl.position.y=.095+Math.sin(t*2)*.004;bl2.position.y=.1+Math.sin(t*2+1)*.004;});}
      else if(id==='climb'){const m=new T.Mesh(new T.ConeGeometry(.07,.13,7),PM.brown);m.position.y=.07;add(m);
        const snow=new T.Mesh(new T.ConeGeometry(.025,.03,7),PM.cream);snow.position.y=.122;add(snow);add(cyl(.0015,.03,PM.wood,0,.15,0));
        const fl=box(.018,.01,.002,PM.coral,.009,.16,0);add(fl);const b=ball(.008,PM.ink,0,0,0);add(b);
        a.push(t=>{fl.rotation.y=Math.sin(t*5)*.4;const k=(t*.25)%1,ang=k*Math.PI*4;b.position.set(Math.cos(ang)*.065*(1-k*.8),.02+k*.11,Math.sin(ang)*.065*(1-k*.8));});}
      else if(id==='rain'){const cloud=new T.Group();for(const [x,y,rr] of [[-.03,0,.022],[0,.008,.028],[.03,0,.022]])cloud.add(ball(rr,PM.cream,x,y,0));cloud.position.y=.13;add(cloud);
        const drops=[PM.ink,PM.coral,PM.brown,PM.sky].map((m,i)=>{const d=ball(.011,m,(i-1.5)*.025,.1,0);add(d);return d;});
        a.push(t=>{drops.forEach((d,i)=>{const k=(t*.7+i*.27)%1;d.position.y=.11-k*.1;d.scale.setScalar(k>.9?Math.max(.01,(1-k)*10):1);});cloud.position.x=Math.sin(t)*.006;});}
      g.traverse(o=>{if(o.isMesh)o.castShadow=false;});
      return {g,step:t=>a.forEach(f=>f(t))};
    }
    // The card: a rounded paper pane with the miniature standing in front of it and its name underneath.
    const CARD_W=.26,CARD_H=.34;
    const cardShape=(()=>{const w=CARD_W,h=CARD_H,r=.035,sh=new T.Shape();sh.moveTo(-w/2+r,-h/2);sh.lineTo(w/2-r,-h/2);sh.quadraticCurveTo(w/2,-h/2,w/2,-h/2+r);sh.lineTo(w/2,h/2-r);sh.quadraticCurveTo(w/2,h/2,w/2-r,h/2);
      sh.lineTo(-w/2+r,h/2);sh.quadraticCurveTo(-w/2,h/2,-w/2,h/2-r);sh.lineTo(-w/2,-h/2+r);sh.quadraticCurveTo(-w/2,-h/2,-w/2+r,-h/2);return new T.ShapeGeometry(sh,8);})();
    const pcards=PLAZA.map(([id,ar,en,subAr,subEn],i)=>{
      // Drawn in a fixed order (ring, pane, label) and the see-through ones don't write depth: otherwise, looking
      // down at a card, the label's clear edges could hide the pane behind them.
      const root=new T.Group(),pane=new T.Mesh(cardShape,menuDepth(new T.MeshBasicMaterial({color:0xf2eddf,transparent:true,opacity:.98,depthWrite:false,fog:false,toneMapped:false})));pane.renderOrder=50;root.add(pane);
      const ring=new T.Mesh(cardShape,menuDepth(new T.MeshBasicMaterial({color:0xf2c14e,transparent:true,opacity:0,depthWrite:false,fog:false,toneMapped:false})));ring.scale.setScalar(1.06);ring.position.z=-.012;ring.renderOrder=49;root.add(ring);
      const m=mini(id);m.g.position.set(0,-.012,.05);m.g.scale.setScalar(1.22);root.add(m.g);
      const lc=document.createElement('canvas');lc.width=512;lc.height=192;const lt=new T.CanvasTexture(lc);lt.colorSpace=T.SRGBColorSpace;lt.anisotropy=Math.min(4,renderer.capabilities.getMaxAnisotropy());
      const label=new T.Mesh(new T.PlaneGeometry(CARD_W*.92,CARD_W*.92*96/256),menuDepth(new T.MeshBasicMaterial({map:lt,transparent:true,depthWrite:false,fog:false,toneMapped:false})));label.position.set(0,-CARD_H/2+.045,.012);label.renderOrder=51;root.add(label);
      plaza.add(root);
      return {id,ar,en,subAr,subEn,root,pane,ring,mini:m,lc,lt,key:'',hot:0,i};
    });
    function drawLabel(c){
      const key=lang;if(c.key===key)return;c.key=key;const x=c.lc.getContext('2d');x.setTransform(2,0,0,2,0,0);x.clearRect(0,0,256,96);x.textAlign='center';x.direction=tr('rtl','ltr');
      x.fillStyle=INK;x.font=font(800,44);x.fillText(tr(c.ar,c.en),128,48);x.fillStyle='rgba(44,45,61,.85)';x.font=font(600,24);x.fillText(tr(c.subAr,c.subEn),128,82);c.lt.needsUpdate=true;
    }
    // Two arcs of four, a little over a metre away, centred on where you look when it opens.
    function placePlaza(){
      const {pos,dir}=headLocal(),yaw=Math.atan2(dir.x,dir.z);
      plaza.position.set(pos.x,0,pos.z);plaza.rotation.set(0,yaw,0);
      // Five over four.
      pcards.forEach((c,i)=>{const row=i<5?0:1,col=row?i-5:i,ang=(col-(row?1.5:2))*.34*(lang==='en'?1:-1),R=1.15;
        c.home=V(Math.sin(ang)*R,pos.y+(row?-.42:.0)-.02,Math.cos(ang)*R);c.root.position.copy(c.home);c.root.rotation.set(0,ang+Math.PI,0);});
    }
    function setPlaza(on){
      if(on===plazaOn&&!plazaPick)return;plazaOn=on;plazaHot=-1;plazaPick=null;
      if(on){stopGameplayInput();menuToggled=menuOpen=false;menu.mesh.visible=false;menu.mesh.scale.setScalar(.01);challengeList.show(false);placePlaza();pcards.forEach(drawLabel);plazaK=0;}
      else{plazaK=0;plaza.visible=false;}
    }
    function choosePlaza(i){
      const c=pcards[i];if(!c)return;plazaPick={c,t:0};
      holder=null;
      if(c.id==='rain'){setClimb(false);setRain(true);}else{setRain(false);if(c.id==='climb')setClimb(true);else{setClimb(false);g.setMode(c.id);}}
      at(rig.localToWorld(c.root.position.clone()),()=>g.whoosh(.5));for(const h of hands)buzz(h,.45,70);
    }
    // Which card the ray of hand h points at (-1 for none).
    function plazaRay(h){
      if(!plazaOn||plazaK<.9)return -1;let best=-1,bd=1e9;
      for(const c of pcards){const hit=ray.intersectObject(c.pane,false)[0];if(hit&&hit.distance<bd){bd=hit.distance;best=c.i;}}
      return best;
    }
    function stepPlaza(dt){
      plazaK=clamp(plazaK+(plazaOn?1:-1)*dt*4,0,1);plaza.visible=plazaK>0;if(!plaza.visible){plazaPick=null;return;}
      // Existing throws never select UI cards. Mode selection requires an explicit trigger press.
      pcards.forEach((c,i)=>{
        const hot=i===plazaHot||(plazaPick&&plazaPick.c===c);c.hot+=((hot?1:0)-c.hot)*Math.min(1,dt*10);
        const appear=clamp(plazaK*1.6-i*.08,0,1),e=appear<1?1-Math.pow(1-appear,3):1;
        c.root.position.copy(c.home);
        // The pointed card comes toward you.
        c.root.position.multiplyScalar(1-.12*c.hot);
        c.root.scale.setScalar(Math.max(.001,e*(1+.14*c.hot)));
        c.ring.material.opacity=.9*c.hot;c.pane.material.opacity=.98*e;
        if(hot||clock<1)c.mini.step(clock);c.mini.g.rotation.y=Math.sin(clock*.6+i)*.35+(hot?clock*.8:0);
      });
      plaza.updateWorldMatrix(true,true);
      if(plazaPick){plazaPick.t+=dt;const c=plazaPick.c;c.root.scale.multiplyScalar(1+plazaPick.t*2.5);c.pane.material.opacity*=Math.max(0,1-plazaPick.t*3);if(plazaPick.t>.35){setPlaza(false);plazaPick=null;}}
    }

    /* ---------- per frame ---------- */
    let grassMesh=null;
    const parkSpot=V(0,0,0);
    // Between throws Dahrooj sits in the slingshot, or floats just in front of you at chest height.
    function updateParkSpot(F){
      if(F?.source){pouch.getWorldPosition(parkSpot);return parkSpot;}
      const {pos,dir}=headLocal();
      parkSpot.set(pos.x+dir.x*.38-dir.z*.1,Math.max(.45,pos.y-.38),pos.z+dir.z*.38+dir.x*.1);
      rig.localToWorld(parkSpot);parkSpot.y=Math.max(parkSpot.y,BR);return parkSpot;
    }
    function menuButtons(){
      for(const h of hands){const pad=h.source?.gamepad;if(!pad)continue;const a=!!pad.buttons[4]?.pressed,b=!!pad.buttons[5]?.pressed,edgeA=a&&!h.buttons[0],edgeB=b&&!h.buttons[1];h.buttons[0]=a;h.buttons[1]=b;
        if(h===leftHand()&&edgeB)setPlaza(!plazaOn);
        else if(h===leftHand()&&edgeA)toggleMenu(true);
        else if(h!==leftHand()&&edgeB)toggleMenu(false);
        else if(h!==leftHand()&&edgeA&&!uiBusy()){if(climbOn)climb3.jump();else recall();}
      }
    }
    function updateMenu(dt){
      const L=leftHand();let want=menuToggled;
      {
        // B: settings; X: challenges. Optional hands use the palm-up gesture.
        if(L?.source?.hand){L.grip.getWorldQuaternion(wq);const up=V(0,1,0).applyQuaternion(wq).y;want=menuOpen?up<.15:up<-.3;}
        if(want){
          if(L?.source?.hand){menu.mesh.position.copy(L.grip.position).add(V(0,.23,0));eyeNow();menu.mesh.lookAt(eye);}
          else if(!menuOpen||menuFresh){
            // With a controller (B for settings, X for challenges) the pane opens in front of your eyes,
            // whole, wherever your hands are; it stays put until you close it.
            const {pos,dir}=headLocal();menuFresh=false;
            menu.mesh.position.set(pos.x+dir.x*.5,pos.y-.06,pos.z+dir.z*.5);eyeNow();menu.mesh.lookAt(eye);
          }
        }
      }
      menuOpen=want;
      // The pane is as tall as what it shows.
      const k=clamp(menu.mesh.scale.x+(want?1:-1)*dt*7,.01,1),hk=menuVis()/MH;menu.mesh.scale.set(k,k*hk,k);menu.mesh.visible=k>.02;challengeList.show(chOpen&&menu.mesh.visible);menu.mesh.updateWorldMatrix(true,true);
    }
    function loop(time,frame){if(!session||session.visibilityState!=='visible'||!frame.getViewerPose(renderer.xr.getReferenceSpace())){lastTime=time;for(const h of hands){release(h,true);h.line.visible=false;h.dot.visible=false;}g.focus(false);return;}g.focus(true);
      const dt=lastTime?clamp((time-lastTime)/1000,0,.05):1/72;lastTime=time;clock+=dt;frames++;
      menuButtons();
      const st=g.stage();
      updateListener();
      watchRewards(dt);
      if(resetArm>0){resetArm-=dt;if(resetArm<=0){resetArm=0;menu.key='';}}
      stepCards(dt);
      stepPlaza(dt);
      // A happy pulse when a throw scores: strong in the throwing hand, softer in the other.
      {const sc=S.scoredT>0;if(sc&&!scoredBefore){buzz(lastThrower,.7,110);for(const h of hands)if(h!==lastThrower)buzz(h,.35,80);}scoredBefore=sc;}
      if(natureOn()){eyeNow();nature.setPitch?.(climbOn?GOAL_AIM_Z:(g.stage().farZ??targetPoint().z),rig.position.z+3);nature.update(dt,eye);
        // The pond: Motri's white line where each Dahrooj meets the water, and now and then a ring as it bobs.
        if(nature.waterline){
          const wl=(p,r)=>{nature.waterline(p.x,p.y,p.z,r);if(nature.waterAt(p.x,p.z)>0&&Math.abs(p.y)<r&&Math.random()<dt*.7)nature.bob(p.x,p.z,r);};
          if(S.shot||S.wet)wl(S.pos,BR);for(const b of g.volley())wl(b.pos,BR);for(const r of rests)wl(r.p,BR);
        }}
      else if(kind==='immersive-vr'){const p=g.paper();if(p!==paper){paper=p;floor.material.color.set(p);scene.background=new T.Color(p);}}
      g.setWater?.(natureOn()&&nature.waterAt?waterApi:null);
      ambience?.update(dt,natureOn()&&!climbOn,eye);
      // Jelly Dahroojs show the world around them: refresh their capture of it (VR only; AR has no world to capture).
      models?.updateProbe?.(renderer,scene,S.pos,{sun:g.sun,on:natureOn()&&g.style()==='jelly',dt,skip:[grassMesh||(grassMesh=scene.getObjectByName('xr-grass'))]});
      if(placedFor!==g.mode())place();
      if(st.useStone){const want=natureOn()&&!!nature.stoneMaterial;if(st.stoneOn!==want){st.stoneOn=want;st.useStone(want?c=>nature.stoneMaterial(c):null);}}
      updateMenu(dt);
      // AR placement: aim at a surface and the court follows; the trigger pins it.
      if(placing){
        const hit=aimAtSurface(frame);
        if(hit){
          anchor=anchorFrom(hit.P,hit.n);place();
          reticle.position.copy(hit.P);reticle.quaternion.setFromUnitVectors(V(0,1,0),hit.n);reticle.visible=true;
        }
      }else reticle.visible=false;
      if(kind==='immersive-ar')showPlanes(frame);
      updateRoom(frame);
      const hover=[],F=climbOn?null:forkHand();let startHot=false,stickX=0;
      for(const h of hands){
        h.grip.getWorldPosition(wp);h.hist.push({p:wp.clone(),t:clock});
        while(h.hist.length&&clock-h.hist[0].t>.25)h.hist.shift();
        const r=rayOf(h);ray.set(r.origin,r.dir);
        const hit=menu.mesh.visible&&h!==leftHand()?ray.intersectObject(menu.mesh,false)[0]:null;
        h.menuY=hit?(1-hit.uv.y)*menuVis():0;h.scrollHit=!!hit&&chOpen&&challengeList.hit(hit.uv.x*MW,h.menuY);
        if(h.scrollDrag&&hit&&menuOpen&&chOpen)challengeList.scrollTo(h.scrollDrag.offset+h.scrollDrag.y-h.menuY);
        h.hover=hit?menuHit(hit.uv):-1;if(h.hover>=0)hover.push(h.hover);
        h.plaza=!hit&&h!==leftHand()?plazaRay(h):-1;if(h.plaza>=0&&h.plaza!==plazaHot){plazaHot=h.plaza;buzz(h,.12,12);at(plaza.localToWorld(pcards[h.plaza].root.position.clone()),()=>g.whoosh(.08));}else if(h!==leftHand()&&h.plaza<0&&plazaHot>=0&&!hands.some(o=>o!==h&&o.plaza>=0))plazaHot=-1;
        h.onStart=!hit&&start.mesh.visible&&!!ray.intersectObject(start.mesh,false)[0];if(h.onStart)startHot=true;
        h.line.scale.z=(hit?hit.distance:.6*scaleNow())/scaleNow();
        h.line.visible=h.dot.visible=!!h.source&&holder!==h&&h!==F;
        const pad=h.source?.gamepad,axes=pad?.axes;
        // A shooting trigger held down fires again and again until it's let go.
        if(h.auto){if(!session||uiBusy()||(h.hover>=0)){h.auto=null;}else if(clock-(h.autoT||0)>=h.auto.every){h.autoT=clock;h.auto.fire();}}
        if(menuOpen&&chOpen&&h===leftHand()&&axes?.length>3&&Math.abs(axes[3])>.22)challengeList.scrollBy(axes[3]*600*dt);
        if(uiBusy())continue;
        if(climbOn&&axes&&axes.length>3){
          if(h===leftHand()||!leftHand())stickX=Math.abs(axes[2])>.25?axes[2]:stickX;
          // Right stick up/down resizes in VR and AR without moving the rig or the confirmed anchor.
          if(h!==leftHand()&&Math.abs(axes[3])>.4){const next=clamp(climbUnit*Math.exp(-axes[3]*dt*.9),.012,.2);if(kind==='immersive-ar')climbZoom=next*arScale/(CLIMB_VR*VR_SCALE);if(next!==climbUnit){climbUnit=next;climb3.setUnit(climbUnit);hud.key='';}}
          continue;
        }
        // AR, while choosing the spot: the right stick up makes the court bigger, down smaller.
        if(kind==='immersive-ar'&&placing&&h!==leftHand()&&axes&&axes.length>3&&Math.abs(axes[3])>.4){
          const z=clamp(arZoom*Math.exp(-axes[3]*dt*.9),AR_ZOOM_MIN,AR_ZOOM_MAX);arScale*=arZoom/z;arZoom=z;place();
        }
      }
      if(climbOn){climb3.setDir(stickX);placeClimb();}
      fork.visible=!!F?.source;if(F?.source&&fork.parent!==F.grip)F.grip.add(fork);
      drawMenu(hover);drawHud();scorePopup.step(dt);if(start.mesh.visible)drawStart(startHot);
      if(intro){stepIntro(dt);drawIntro();}
      stepBlast(dt);
      // Hidden while the mode cards are out, so it never sits over one.
      hud.mesh.visible=(!intro||intro.rain)&&!uiBusy();
      eyeNow();hud.mesh.lookAt(eye);
      // Dahrooj waits by your hand (or in the slingshot) between throws.
      // Only once the headset has reported a few poses, so he doesn't appear somewhere else first.
      if(!S.shot&&!holder&&!placing&&!intro&&!climbOn&&!parked&&frames>3){parked=true;popT=0;S.pos.copy(updateParkSpot(F));}
      if(parked){S.held=true;S.pos.lerp(updateParkSpot(F),1-Math.exp(-dt*10));S.vel.set(0,0,0);S.grounded=false;}
      popT+=dt;
      // The held ball rides in front of the hand (in the pouch with the slingshot), easing in.
      if(holder){
        holdT+=dt;holder.grip.getWorldPosition(wp);holder.grip.getWorldQuaternion(wq);
        fwd.set(0,0,-1).applyQuaternion(wq);
        const target=F?.source?wp:wp.addScaledVector(fwd,BR*1.05);
        S.pos.copy(target);S.vel.set(0,0,0);S.grounded=false;
      }
      // Slingshot bands follow the pouch: Dahrooj, or the rest spot.
      if(F?.source){
        if(holder||parked)wp.copy(S.pos);else pouch.getWorldPosition(wp);
        const end=rig.worldToLocal(wp.clone());
        tips.forEach((o,i)=>{o.getWorldPosition(wp);stretch(bands[i],rig.worldToLocal(wp.clone()),end);});
      }else for(const b of bands)b.visible=false;
      // The flight preview while pulling.
      if(holder)holder.chargeT=(holder.chargeT||0)+dt;
      const u=holder&&(F?.source||throwStyle==='trigger')?launch(holder,S.pos):null;
      if(u){
        const v=toGame(u),p=S.pos.clone(),step=.05,r=.012*scaleNow();
        // The same sideways pull the throw will get, so the dots show the bend.
        const c=curveOf(holder)*CURVE_K,f=V(v.x,0,v.z).normalize(),side=V(-f.z,0,f.x).multiplyScalar(c*9);
        for(const d of dots){
          for(let k=0;k<3;k++){v.y-=g.GRAV*step/3;v.x+=side.x*step/3;v.z+=side.z*step/3;v.multiplyScalar(Math.pow(.9,step/3));p.addScaledVector(v,step/3);}
          d.position.copy(p);d.scale.setScalar(r);d.visible=p.y>0;
        }
      }else for(const d of dots)d.visible=false;
      if(climbOn){eyeNow();climb3.update(dt,{style:g.style(),eye,onEvent:climbEvent});}
      else{
        g.step(dt*timeK());
        stepRests(dt*timeK());stepWorldContacts(dt*timeK());feelHands(dt);
        if(!S.held)markBall(S.pos,S.vel);
        for(const b of g.volley())markBall(b.pos,b.vel);
        // Motri's props: Dahrooj bounces off poles and benches, shoves lanterns and sets off crates.
        // Mixed reality: the real walls and furniture.
        if(roomPlanes.size){
          const k=dt*timeK();
          if(S.shot&&!S.held){const h=roomCollide(S.pos,S.vel,BR,k);if(h>1){at(S.pos,()=>g.bump(Math.min(1,h/12)));buzz(lastThrower,.3,25);}}
          for(const b of g.volley())roomCollide(b.pos,b.vel,BR,k);
          for(const r of rests)roomCollide(r.p,r.v,BR,k);
        }
        if(natureOn()&&nature.props){
          const P=nature.props;
          if(S.shot&&!S.held&&P.collide(S.pos,S.vel,BR)){at(S.pos,()=>g.bump(Math.min(1,Math.hypot(S.vel.x,S.vel.z)/12)));buzz(lastThrower,.3,25);}
          for(const b of g.volley())P.collide(b.pos,b.vel,BR);
          for(const r of rests)P.collide(r.p,r.v,BR);
        }
      }
      // Dahrooj shows only while the trigger holds him or he flies; waiting, he's out of sight (in the slingshot he waits in the pouch).
      const d=S.d,shown=!(placing||intro||climbOn||!((parked&&F?.source)||holder||S.shot));
      const face=parked&&!(S.mood&&S.moodT>0)?'open':g.ballFace();
      if(models){
        ballModel=model(ballModel,g.style(),true);
        ballModel.update({pos:S.pos,toward:eye,faceName:face,blink:S.blink>0,squash:[1+d*.75,1-d]});
        // Pop in: grow from small with a slight overshoot.
        if(popT<.25){const k=popT/.25,e=1+2.2*Math.pow(k-1,3)+1.2*Math.pow(k-1,2);ballModel.group.scale.multiplyScalar(Math.max(.05,e));}
        ballModel.group.visible=shown;
        // Earlier throws still in the air.
        drawRests();
        const flying=g.volley();
        flying.forEach((b,i)=>{
          const m=volleyModels[i]=model(volleyModels[i],g.style(),true);
          m.update({pos:b.pos,toward:eye,faceName:b.hitT>0?'closed':b.mood&&b.moodT>0?b.mood:'wide',blink:false,squash:[1+b.d*.75,1-b.d]});
        });
        for(let i=flying.length;i<volleyModels.length;i++)if(volleyModels[i])volleyModels[i].group.visible=false;
      }else{
        showSprite(ballSprite,S.pos,BR,g.style(),face,S.blink>0,1+d*.75,1-d);ballSprite.visible=shown;
      }
      g.render();
    }

    return {enter,frame:loop,get presenting(){return !!session;},get kind(){return kind;},get holding(){return !!holder;},
      ...(import.meta.env.DEV?{action:menuAction,choosePlaza}:{}),get placing(){return placing;},get rests(){return rests;},get ballShown(){return !!ballModel?.group.visible;},get challengesOpen(){return menuOpen&&chOpen;},get challengeScroll(){return {offset:challengeList.offset,max:challengeList.max};},get challengeIds(){return headsetChallenges().map(c=>c.id);},get lang(){return lang;},get session(){return session;},get chargeNow(){return holder?chargePower(holder):0;},get roomPlanes(){return roomPlanes.size;},...(import.meta.env.DEV?{addTestPlane}:{}),
      // For tests: pin the court as if the hit test found this spot and surface normal.
      // Tests: let go of Dahrooj and drop him at P with velocity v, as if thrown there.
      ...(import.meta.env.DEV?{testDrop(P,v){parked=false;holder=null;S.held=false;S.pos.set(...P);S.vel.set(...v);S.side.set(0,0,0);S.shot=true;S.grounded=false;S.shotT=0;S.scoredT=0;S.missT=0;},
      testPin(P,n){anchor=anchorFrom(V(...P),V(...n));place();rig.updateMatrixWorld(true);placing=false;g.respawn();},}:{}),get anchor(){return anchor;},get menuLayout(){return {w:MW,h:menuVis(),buttons:[...buttons,...accButtons,resetBtn].map(b=>({...b}))};},get wearing(){return wornNow();},get card(){return cardNow&&{kind:cardNow.kind,title:cardNow.title,shown:card.mesh.visible};},get cardsWaiting(){return cards.map(n=>n.kind);},get plaza(){return {open:plazaOn,shown:plaza.visible,hot:plazaHot,ids:PLAZA.map(p=>p[0])};},setPlaza,plazaCardAt(i){return rig.worldToLocal(plaza.localToWorld(pcards[i].root.position.clone())).toArray();},notify,get rewardsDone(){return doneNow;},get blast(){return blast;},get shotStyle(){return shotStyle;},get nature(){return nature;},get ambience(){return ambience;},get climbing(){return climbOn;},get climb(){return climb3;},get opening(){return !!intro&&!intro.rain;},get rain(){return {on:rainOn,balls:intro?.rain?intro.balls.length:0,drawn:crowd?crowd.count:0};},get introBalls(){return intro?intro.balls.filter(b=>intro.t>=b.born).map(b=>b.p.toArray()):[];},get popped(){return intro?intro.popped:0;},get parked(){return parked;},get menuOpen(){return menuOpen;},get throwStyle(){return throwStyle;},
      // For tests: what each hand reports.
      ...(import.meta.env.DEV?{inspect:()=>hands.map(h=>({connected:!!h.source,hand:h.source?.handedness,samples:h.hist.length,velocity:velocity(h).toArray()}))}:{} )};
  };
})();
