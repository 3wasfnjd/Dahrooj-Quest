// Keep Rain in a forward fan when regenerating the owner-authorized port.
const replacements=[
  [
    "src/reference/xr-runtime.js",
    "import {menuDepth}",
    "import {rainSpawn,guideRain} from './rain-field';\nimport {menuDepth}"
  ],
  [
    "src/reference/xr-runtime.js",
    "// One ball dropping from above somewhere in the ring around you, at a random moment and size.",
    "// Rain falls in front; the separate opening keeps its original ring."
  ],
  [
    "src/reference/xr-runtime.js",
    "born:I.t+delay,gx:Math.cos(dirA)*sp,",
    "pending:I.rain,born:I.t+delay,gx:Math.cos(dirA)*sp,"
  ],
  [
    "src/reference/xr-runtime.js",
    "live=I.balls.filter(b=>I.t>=b.born),{pos:head}=headLocal(),c=I.centre;",
    "live=I.balls.filter(b=>I.t>=b.born),{pos:head,dir}=headLocal(),c=I.centre;"
  ],
  [
    "src/reference/xr-runtime.js",
    "      for(const b of live){\n        const r=b.R,grounded=",
    "      for(const b of live){\n        if(b.pending){rainSpawn(b.p,head,dir,ROOM,Math.random(),Math.random());b.p.y=head.y+.6+Math.random()*1.8;b.pending=false;}\n        const r=b.R,grounded="
  ],
  [
    "src/reference/xr-runtime.js",
    "        // Wander anywhere in the ring around you: off its edge, or right at your feet, head back in.\n        const ox=b.p.x-c.x,oz=b.p.z-c.z,od=Math.hypot(ox,oz)||1,hd=Math.hypot(b.p.x-head.x,b.p.z-head.z);\n        if(od>ROOM||hd<.45){\n          const a=Math.random()*Math.PI*2,rr=.7+Math.sqrt(Math.random())*(ROOM-.9),sp=.25+Math.random()*.4;\n          const tx=c.x+Math.sin(a)*rr-b.p.x,tz=c.z-Math.cos(a)*rr-b.p.z,tl=Math.hypot(tx,tz)||1;b.gx=tx/tl*sp;b.gz=tz/tl*sp;\n        }\n        if(od>ROOM+.4){b.p.x=c.x+ox/od*(ROOM+.4);b.p.z=c.z+oz/od*(ROOM+.4);}",
    "        if(I.rain){\n          // Keep most of the crowd ahead while allowing gentle sideways wandering and physical bounces.\n          guideRain(b.p,b,head,dir,ROOM);\n        }else{\n          const ox=b.p.x-c.x,oz=b.p.z-c.z,od=Math.hypot(ox,oz)||1,hd=Math.hypot(b.p.x-head.x,b.p.z-head.z);\n          if(od>ROOM||hd<.45){\n            const a=Math.random()*Math.PI*2,rr=.7+Math.sqrt(Math.random())*(ROOM-.9),sp=.25+Math.random()*.4;\n            const tx=c.x+Math.sin(a)*rr-b.p.x,tz=c.z-Math.cos(a)*rr-b.p.z,tl=Math.hypot(tx,tz)||1;b.gx=tx/tl*sp;b.gz=tz/tl*sp;\n          }\n          if(od>ROOM+.4){b.p.x=c.x+ox/od*(ROOM+.4);b.p.z=c.z+oz/od*(ROOM+.4);}\n        }"
  ],
  [
    "src/reference/xr-runtime.js",
    "        if(intro.t<b.born)continue;\n        const falling=",
    "        if(intro.t<b.born||b.pending)continue;\n        const falling="
  ],
  [
    "src/reference/xr-runtime.js",
    "intro.balls.filter(b=>intro.t>=b.born).map(b=>b.p.toArray())",
    "intro.balls.filter(b=>intro.t>=b.born&&!b.pending).map(b=>b.p.toArray())"
  ],
  [
    "src/reference/xr-runtime.js",
    "...(import.meta.env.DEV?{testDrop(P,v)",
    "...(import.meta.env.DEV?{rainSnapshot:()=>intro?.rain?intro.balls.filter(b=>intro.t>=b.born&&!b.pending).map(b=>({id:b.id,age:intro.t-b.born,p:b.p.toArray()})):[],testDrop(P,v)"
  ]
];
export function frontRainOverrides(file,source){
 for(const [path,before,after] of replacements){if(path!==file)continue;if(!source.includes(before))throw Error('Missing front Rain marker: '+before.slice(0,90));source=source.replace(before,after);}
 return source;
}
