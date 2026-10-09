// Preserve Summit scaling and the shared court during reference regeneration.
const replacements=[
  [
    "src/reference/xr-runtime.js",
    "import {createChallengeList}",
    "import {GOAL_AIM_Z} from './court-layout.js';\nimport {createChallengeList}"
  ],
  [
    "src/reference/xr-runtime.js",
    "const CLIMB_Z=-20,CLIMB_VR=.14,CLIMB_AR=CLIMB_VR*2/8;",
    "const CLIMB_Z=GOAL_AIM_Z,CLIMB_VR=.14,CLIMB_AR=CLIMB_VR*2/8;"
  ],
  [
    "src/reference/xr-runtime.js",
    "let climbOn=false,climb3=null,climbSpot=null,climbUnit=CLIMB_AR;",
    "let climbOn=false,climb3=null,climbSpot=null,climbUnit=CLIMB_AR,climbZoom=1;"
  ],
  [
    "src/reference/xr-runtime.js",
    "const targetPoint=()=>V(0,0,g.stage().aimZ||-10);",
    "const targetPoint=()=>V(0,0,climbOn?GOAL_AIM_Z:(g.stage().aimZ||-10));"
  ],
  [
    "src/reference/xr-runtime.js",
    "// Bowling keeps its own lane (farZ), the Summit its own spot. The wall and the fair keep their",
    "// Bowling keeps its own lane (farZ); Summit shares the goal court. The wall and the fair keep their"
  ],
  [
    "src/reference/xr-runtime.js",
    "const st=g.stage(),back=st&&(st.farZ==null||st.reachZ!=null)&&!climbOn?Math.max(0,(st.aimZ??-10)-(st.reachZ??FAR_Z)):0;",
    "const st=g.stage(),back=climbOn?Math.max(0,GOAL_AIM_Z-FAR_Z):st&&(st.farZ==null||st.reachZ!=null)?Math.max(0,(st.aimZ??-10)-(st.reachZ??FAR_Z)):0;"
  ],
  [
    "src/reference/xr-runtime.js",
    "// Re-place the rig either way: the Summit doesn't use the step back the other modes take.",
    "// Summit uses the same court transform as Goal, independent of the previous mode."
  ],
  [
    "src/reference/xr-runtime.js",
    "// The mountain keeps the same size against the court as in VR, so pinning (and the stick before it) sizes it.\n        const u=CLIMB_VR*VR_SCALE/arScale;",
    "// Surface scale supplies the initial size; preserve the player's right-stick zoom after placement.\n        const u=clamp(CLIMB_VR*VR_SCALE/arScale*climbZoom,.012,.2);"
  ],
  [
    "src/reference/xr-runtime.js",
    "climbSpot=null;climbUnit=mode==='immersive-ar'?CLIMB_AR:CLIMB_VR;",
    "climbSpot=null;climbZoom=1;climbUnit=mode==='immersive-ar'?CLIMB_AR:CLIMB_VR;"
  ],
  [
    "src/reference/xr-runtime.js",
    "nature.setPitch?.(g.stage().farZ??targetPoint().z,rig.position.z+3)",
    "nature.setPitch?.(climbOn?GOAL_AIM_Z:(g.stage().farZ??targetPoint().z),rig.position.z+3)"
  ],
  [
    "src/reference/xr-runtime.js",
    "// The right stick up and down resizes the mountain (in VR; in AR the surface sets the size).\n          if(kind!=='immersive-ar'&&h!==leftHand()&&Math.abs(axes[3])>.4){climbUnit=clamp(climbUnit*Math.exp(-axes[3]*dt*.9),.012,.2);climb3.setUnit(climbUnit);hud.key='';}",
    "// Right stick up/down resizes in VR and AR without moving the rig or the confirmed anchor.\n          if(h!==leftHand()&&Math.abs(axes[3])>.4){const next=clamp(climbUnit*Math.exp(-axes[3]*dt*.9),.012,.2);if(kind==='immersive-ar')climbZoom=next*arScale/(CLIMB_VR*VR_SCALE);if(next!==climbUnit){climbUnit=next;climb3.setUnit(climbUnit);hud.key='';}}"
  ],
  [
    "src/reference/xr-runtime.js",
    "tr('الزناد للرمي · Y الأنماط · X التحديات','Trigger to throw · Y modes · X challenges')",
    "tr('العصا اليمنى للحجم · الزناد للرمي','Right stick to resize · trigger to throw')"
  ],
  [
    "src/reference/stages/goal.js",
    "export default function create(ctx)",
    "import {GOAL_Z,GOAL_AIM_Z} from '../court-layout.js';\nexport default function create(ctx)"
  ],
  [
    "src/reference/stages/goal.js",
    "GD=1.8, GZ=-11, PR=",
    "GD=1.8, GZ=GOAL_Z, PR="
  ],
  [
    "src/reference/stages/goal.js",
    "grp, aimZ:GZ-0.3,",
    "grp, aimZ:GOAL_AIM_Z,"
  ]
];
export function summitOverrides(file,source){for(const [path,before,after] of replacements){if(path!==file)continue;if(!source.includes(before))throw new Error("Missing Summit override: "+file+" "+before.slice(0,50));source=source.replaceAll(before,after);}return source;}
