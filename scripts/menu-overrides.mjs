const replacements=[
  [
    "src/reference/xr-runtime.js",
    "import {DAHROOJ_COLORS",
    "import {createChallengeList} from './challenge-list.js';\nimport {DAHROOJ_COLORS"
  ],
  [
    "src/reference/xr-runtime.js",
    "tex.colorSpace=T.SRGBColorSpace;tex.anisotropy",
    "tex.colorSpace=T.SRGBColorSpace;tex.generateMipmaps=false;tex.minFilter=T.LinearFilter;tex.anisotropy"
  ],
  [
    "src/reference/xr-runtime.js",
    "menu.mesh.renderOrder=5;",
    "menu.mesh.renderOrder=20;\n    const challengeList=createChallengeList(T,{parent:menu.mesh,panelWidth:MENU_W,panelHeight:MENU_H,pixelsWidth:MW,pixelsHeight:MH,font});"
  ],
  [
    "src/reference/xr-runtime.js",
    "let chOpen=false,chPage=0,menuFresh=false;\n    const CH_PAGE_SIZE=8,challengePages=[{x:PAD,y:874,w:190,h:54},{x:MW-PAD-190,y:874,w:190,h:54}];",
    "let chOpen=false,menuFresh=false;\n    const uiBusy=()=>menuToggled||menuOpen||plazaOn;\n    function stopGameplayInput(){for(const h of hands){release(h,true);h.hover=-1;h.plaza=-1;h.scrollDrag=null;}}\n    function toggleMenu(challenges){const on=!(menuToggled&&chOpen===challenges);setPlaza(false);menuToggled=on;chOpen=challenges;menuFresh=on;menu.key='';if(on)stopGameplayInput();}"
  ],
  [
    "src/reference/xr-runtime.js",
    "      lastToast=t;\n",
    "      lastToast=t;\n      if(uiBusy()){card.mesh.visible=false;return;}\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "    function drawMenu(hover){\n",
    "    function drawMenu(hover){\n      if(!menu.mesh.visible)return;\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "chOpen,lang,chPage,chs.map",
    "chOpen,lang,chs.map"
  ],
  [
    "src/reference/xr-runtime.js",
    "        const rowH=84;\n        chs.slice(chPage*CH_PAGE_SIZE,(chPage+1)*CH_PAGE_SIZE).forEach((x,k)=>{\n          const y=186+k*rowH,ok=x.value>=x.goal;\n          c.fillStyle=ok?'rgba(44,45,61,.9)':'rgba(255,255,255,.55)';round(c,PAD,y,IN,rowH-8,(rowH-8)/2);c.fill();\n          const title=lang==='en'&&x.en?x.en:x.title,rtl=lang!=='en';\n          c.textAlign=rtl?'right':'left';c.fillStyle=ok?PAPER:INK;c.font=font(700,36);const words=((ok?'✓ ':'')+title).split(' '),lines=[];let line='';for(const word of words){const next=line?line+' '+word:word;if(line&&c.measureText(next).width>IN-136){lines.push(line);line=word;}else line=next;}if(line)lines.push(line);lines.forEach((line,i)=>c.fillText(line,rtl?MW-PAD-24:PAD+24,y+rowH/2+12+(i-(lines.length-1)/2)*36));\n          c.textAlign=rtl?'left':'right';c.font=font(800,32);c.fillText(`${x.value}/${x.goal}`,rtl?PAD+22:MW-PAD-22,y+rowH*.5+2);\n          c.textAlign='center';\n        });\n        challengePages.forEach((b,i)=>{c.fillStyle=hover.includes(3000+i)?'#e7d8bd':'#fffaf2';round(c,b.x,b.y,b.w,b.h,22);c.fill();c.fillStyle=INK;c.font=font(700,30);c.fillText(i?tr('التالي','Next'):tr('السابق','Previous'),b.x+b.w/2,b.y+36);});c.font=font(700,30);c.fillStyle=INK;c.fillText(tr(`${chPage+1} من ${Math.ceil(chs.length/CH_PAGE_SIZE)}`,`${chPage+1} of ${Math.ceil(chs.length/CH_PAGE_SIZE)}`),MW/2,910);\n",
    "        challengeList.rows(chs,lang);\n        const v=challengeList.view;c.fillStyle='rgba(44,45,61,.16)';c.fillRect(v.x+v.w+9,v.y,6,v.h);\n        c.fillStyle=INK;c.font=font(600,25);c.fillText(tr('حرّك العصا اليسرى أو اسحب القائمة للتمرير','Left stick or drag the list to scroll'),MW/2,911);\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "      if(chOpen){const i=challengePages.findIndex(b=>x>=b.x&&x<=b.x+b.w&&y>=b.y&&y<=b.y+b.h);if(i>=0)return 3000+i;}\n",
    ""
  ],
  [
    "src/reference/xr-runtime.js",
    "      if(i===3000||i===3001){chPage=clamp(chPage+(i===3001?1:-1),0,Math.ceil(headsetChallenges().length/CH_PAGE_SIZE)-1);menu.key='';return;}\n",
    ""
  ],
  [
    "src/reference/xr-runtime.js",
    "...accButtons,resetBtn,...challengePages.map((b,i)=>({...b,kind:'challengePage',id:String(i)}))",
    "...accButtons,resetBtn"
  ],
  [
    "src/reference/xr-runtime.js",
    "get challengesOpen(){return chOpen;}",
    "get challengesOpen(){return menuOpen&&chOpen;},get challengeScroll(){return {offset:challengeList.offset,max:challengeList.max};}"
  ],
  [
    "src/reference/xr-runtime.js",
    "      if(h.hover>=0){menuAction(h.hover);return;}\n      if(plazaOn&&h.plaza>=0){choosePlaza(h.plaza);return;}",
    "      if(menuOpen&&chOpen&&h.scrollHit&&how==='trigger'){h.scrollDrag={y:h.menuY,offset:challengeList.offset};return;}\n      if(menuOpen&&h.hover>=0&&how==='trigger'){menuAction(h.hover);return;}\n      if(plazaOn&&h.plaza>=0&&how==='trigger'){choosePlaza(h.plaza);return;}\n      if(uiBusy())return;"
  ],
  [
    "src/reference/xr-runtime.js",
    "    function release(h,lost){if(session?.visibilityState!=='visible')lost=true;",
    "    function release(h,lost){if(session?.visibilityState!=='visible'||uiBusy())lost=true;\n      if(h.scrollDrag){h.scrollDrag=null;h.auto=null;return;}"
  ],
  [
    "src/reference/xr-runtime.js",
    "      if(on===plazaOn)return;plazaOn=on;plazaHot=-1;\n      if(on){menuToggled=false;placePlaza();pcards.forEach(drawLabel);plazaK=0;}",
    "      if(on===plazaOn&&!plazaPick)return;plazaOn=on;plazaHot=-1;plazaPick=null;\n      if(on){stopGameplayInput();menuToggled=menuOpen=false;menu.mesh.visible=false;menu.mesh.scale.setScalar(.01);challengeList.show(false);placePlaza();pcards.forEach(drawLabel);plazaK=0;}\n      else{plazaK=0;plaza.visible=false;}"
  ],
  [
    "src/reference/xr-runtime.js",
    "        if(pad){\n          const now=[4,5].map(i=>!!pad.buttons[i]?.pressed),edge=now.map((b,i)=>b&&!h.buttons[i]);h.buttons=now;\n          // Y (left): the settings. X (left), everywhere: the challenges. B (right), everywhere: the floating mode\n          // cards. A (right): calls Dahrooj back; on the Summit it jumps.\n          if(h===leftHand()&&edge[1]){menuToggled=!menuToggled;if(menuToggled){chOpen=false;setPlaza(false);}menu.key='';menuFresh=true;}\n          else if(h===leftHand()&&edge[0]){if(menuToggled&&chOpen)menuToggled=false;else{menuToggled=true;chOpen=true;}menu.key='';menuFresh=true;}\n          else if(h!==leftHand()&&edge[1]){setPlaza(!plazaOn);if(plazaOn)menuToggled=false;}\n          else if(climbOn){if(h!==leftHand()&&edge[0])climb3.jump();}\n          else if(edge.some(Boolean))recall();\n        }\n",
    ""
  ],
  [
    "src/reference/xr-runtime.js",
    "    function updateMenu(dt){",
    "    function menuButtons(){\n      for(const h of hands){const pad=h.source?.gamepad;if(!pad)continue;const a=!!pad.buttons[4]?.pressed,b=!!pad.buttons[5]?.pressed,edgeA=a&&!h.buttons[0],edgeB=b&&!h.buttons[1];h.buttons[0]=a;h.buttons[1]=b;\n        if(h===leftHand()&&edgeB)setPlaza(!plazaOn);\n        else if(h===leftHand()&&edgeA)toggleMenu(true);\n        else if(h!==leftHand()&&edgeB)toggleMenu(false);\n        else if(h!==leftHand()&&edgeA&&!uiBusy()){if(climbOn)climb3.jump();else recall();}\n      }\n    }\n    function updateMenu(dt){"
  ],
  [
    "src/reference/xr-runtime.js",
    "      const L=leftHand();let want=false;\n      if(L){\n        // Controllers: the Y button. Hands (no buttons): turn the palm up.\n        want=menuToggled;",
    "      const L=leftHand();let want=menuToggled;\n      {\n        // B: settings; X: challenges. Optional hands use the palm-up gesture."
  ],
  [
    "src/reference/xr-runtime.js",
    "if(L.source?.hand)",
    "if(L?.source?.hand)"
  ],
  [
    "src/reference/xr-runtime.js",
    "menu.mesh.visible=k>.02;",
    "menu.mesh.visible=k>.02;challengeList.show(chOpen&&menu.mesh.visible);menu.mesh.updateWorldMatrix(true,true);"
  ],
  [
    "src/reference/xr-runtime.js",
    "      const st=g.stage();\n      updateListener();",
    "      menuButtons();\n      const st=g.stage();\n      updateListener();"
  ],
  [
    "src/reference/xr-runtime.js",
    "if(!session||plazaOn||(h.hover>=0))",
    "if(!session||uiBusy()||(h.hover>=0))"
  ],
  [
    "src/reference/xr-runtime.js",
    "        h.hover=hit?menuHit(hit.uv):-1;",
    "        h.menuY=hit?(1-hit.uv.y)*menuVis():0;h.scrollHit=!!hit&&chOpen&&challengeList.hit(hit.uv.x*MW,h.menuY);\n        if(h.scrollDrag&&hit&&menuOpen&&chOpen)challengeList.scrollTo(h.scrollDrag.offset+h.scrollDrag.y-h.menuY);\n        h.hover=hit?menuHit(hit.uv):-1;"
  ],
  [
    "src/reference/xr-runtime.js",
    "        if(climbOn&&axes&&axes.length>3){",
    "        if(menuOpen&&chOpen&&h===leftHand()&&axes?.length>3&&Math.abs(axes[3])>.22)challengeList.scrollBy(axes[3]*600*dt);\n        if(uiBusy())continue;\n        if(climbOn&&axes&&axes.length>3){"
  ],
  [
    "src/reference/xr-runtime.js",
    "      if(plazaPick){plazaPick.t+=dt;",
    "      plaza.updateWorldMatrix(true,true);\n      if(plazaPick){plazaPick.t+=dt;"
  ],
  [
    "src/reference/xr-runtime.js",
    "hud.mesh.visible=(!intro||intro.rain)&&!plazaOn;",
    "hud.mesh.visible=(!intro||intro.rain)&&!uiBusy();"
  ],
  [
    "src/reference/xr-runtime.js",
    "B الأنماط",
    "Y الأنماط"
  ],
  [
    "src/reference/xr-runtime.js",
    "B modes",
    "Y modes"
  ],
  [
    "src/reference/xr-runtime.js",
    "// With a controller (Y for the menu, X for the challenges)",
    "// With a controller (B for settings, X for challenges)"
  ],
  [
    "src/main.ts",
    "Y: menu. X: challenges.",
    "Y: modes. B: settings. X: challenges."
  ],
  [
    "src/main.ts",
    "زر Y للقائمة وX للتحديات.",
    "زر Y للأنماط وB للإعدادات وX للتحديات."
  ],
  [
    "src/reference/xr-runtime.js",
    "      // Thrown into a card: go there.\n      if(plazaOn&&S.shot&&!plazaPick){const bw=S.pos.clone(),lp=rig.worldToLocal(bw);\n        for(const c of pcards){const cw=plaza.localToWorld(c.root.position.clone()),cl=rig.worldToLocal(cw);if(lp.distanceTo(cl)<.17){choosePlaza(c.i);break;}}}\n",
    "      // Existing throws never select UI cards. Mode selection requires an explicit trigger press.\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "const uiBusy=()=>menuToggled||menuOpen||plazaOn;",
    "const uiBusy=()=>menuToggled||menuOpen||plazaOn||menu.mesh.visible;"
  ]
];
export function menuOverrides(file,s){for(const [path,before,after] of replacements)if(file===path){if(!s.includes(before))throw Error("Missing menu override: "+path+" "+before.slice(0,40));s=s.replaceAll(before,after);}return s;}
