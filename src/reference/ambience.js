/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
/* The sounds of Motri's world around Dahrooj in the headset (VR). Aboden Games.
   Everything here is made in the browser with Web Audio (no recorded sounds), and it sits well under the game's
   music and effects: birds in the trees by day, crickets and frogs at night, the pond's odd plop, and a soft
   rain while it rains. They follow nature.js: its time of day, its weather, its pond and its trees.
   Positions are in game space, like the rest of the game's 3D sound. */
export const createReferenceAmbience=(() => {
  'use strict';
  const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),rnd=(a,b)=>a+Math.random()*(b-a);

  return ({audio,nature})=>{
    let ctx=null,out=null,beds=null,offFor=0,lastT=0,calls=0;
    // Each kind of event waits its own random time.
    const wait={bird:2,plop:5,frog:6};

    // Looping noise (white for rain; brown, smoothed, available too). The end is
    // blended into the start so the loop has no click.
    function noise(sec,brown){
      const n=ctx.sampleRate*sec|0,f=ctx.sampleRate*.08|0,m=n-f,raw=new Float32Array(n);let last=0;
      for(let i=0;i<n;i++){const w=Math.random()*2-1;if(brown){last=(last+.02*w)/1.02;raw[i]=last*3.5;}else raw[i]=w;}
      const b=ctx.createBuffer(1,m,ctx.sampleRate),d=b.getChannelData(0);
      for(let i=0;i<m;i++)d[i]=i<f?raw[i]*(i/f)+raw[m+i]*(1-i/f):raw[i];
      return b;
    }
    // Crickets: bursts of three or four quick pulses near 4.6 kHz, a few times a second.
    function crickets(sec){
      const sr=ctx.sampleRate,n=sr*sec|0,b=ctx.createBuffer(1,n,sr),d=b.getChannelData(0);
      for(let t=rnd(.05,.2);t<sec-.3;t+=rnd(.45,.8)){
        const f=rnd(4400,4800),pulses=3+(Math.random()<.5?1:0);
        for(let p=0;p<pulses;p++){const s=(t+p*.045)*sr|0,len=.026*sr|0;
          for(let i=0;i<len&&s+i<n;i++){const e=Math.sin(Math.PI*i/len);d[s+i]+=Math.sin(2*Math.PI*f*i/sr)*e*e*.8;}}
      }
      return b;
    }
    function panner(x,y,z,ref){
      const p=ctx.createPanner();p.panningModel='HRTF';p.distanceModel='inverse';p.refDistance=ref;p.rolloffFactor=1;p.maxDistance=1e4;
      place(p,x,y,z);p.connect(out);return p;
    }
    function place(p,x,y,z){if(p.positionX){p.positionX.value=x;p.positionY.value=y;p.positionZ.value=z;}else p.setPosition(x,y,z);}
    let sources=[];
    function loop(buf,rate=1){const s=ctx.createBufferSource();s.buffer=buf;s.loop=true;s.playbackRate.value=rate;s.start(ctx.currentTime+Math.random()*.1);sources.push(s);return s;}
    function filter(type,freq,q=.7){const f=ctx.createBiquadFilter();f.type=type;f.frequency.value=freq;f.Q.value=q;return f;}
    function gain(v=0){const g=ctx.createGain();g.gain.value=v;return g;}

    function start(){
      const B={};
      // No steady wind or water hiss (it reads as noise in the headset): the world is quiet but for its
      // creatures, the pond's odd plop and, only while it rains, a soft rain.
      B.rain=gain();loop(noise(5,false)).connect(filter('highpass',1200)).connect(filter('lowpass',6000)).connect(B.rain).connect(out);
      // Crickets at night, from three places in the grass around you.
      B.cricket=gain();B.cricket.connect(out);const cb=crickets(3.1);
      B.cricketPans=[[-14,6],[15,-4],[-6,-30]].map(([dx,dz],i)=>{const p=panner(dx,.3,dz,3);p.disconnect();p.connect(B.cricket);loop(cb,[1,.93,1.07][i]).connect(p);return p;});
      return B;
    }

    // One bird call from a tree: a short tweet, a trill, a two-note whistle or a warble.
    function bird(x,y,z){
      calls++;
      const t0=ctx.currentTime+.02,dest=panner(x,y,z,9),kind=Math.random()*4|0,v=rnd(.05,.09),pitch=rnd(.85,1.2);
      const note=(t,dur,f0,f1,vib=0)=>{
        const o=ctx.createOscillator(),g=ctx.createGain();o.type='sine';
        o.frequency.setValueAtTime(f0*pitch,t);o.frequency.exponentialRampToValueAtTime(f1*pitch,t+dur);
        if(vib){const l=ctx.createOscillator(),lg=ctx.createGain();l.frequency.value=24;lg.gain.value=vib;l.connect(lg).connect(o.frequency);l.start(t);l.stop(t+dur+.02);}
        g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(v,t+Math.min(.012,dur*.3));g.gain.exponentialRampToValueAtTime(.0001,t+dur);
        o.connect(g).connect(dest);o.start(t);o.stop(t+dur+.02);
      };
      if(kind===0){const n=2+(Math.random()*3|0);for(let i=0;i<n;i++)note(t0+i*.13,.07,3100,4300);}
      else if(kind===1){const n=8+(Math.random()*7|0);for(let i=0;i<n;i++)note(t0+i*.045,.028,5200-i*60,4600-i*60);}
      else if(kind===2){note(t0,.13,3900,3800);note(t0+.2,.2,3150,3000);}
      else note(t0,.38,2900,3300,380);
      setTimeout(()=>dest.disconnect(),2500);
    }
    // A small plop somewhere on the pond.
    function plop(x,z){
      const t=ctx.currentTime+.02,dest=panner(x,0,z,3),o=ctx.createOscillator(),g=ctx.createGain();
      o.type='sine';o.frequency.setValueAtTime(rnd(280,380),t);o.frequency.exponentialRampToValueAtTime(rnd(900,1300),t+.07);
      g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(.045,t+.008);g.gain.exponentialRampToValueAtTime(.0001,t+.1);
      o.connect(g).connect(dest);o.start(t);o.stop(t+.12);setTimeout(()=>dest.disconnect(),1000);
    }
    // A frog by the pond at night: two or three low croaks.
    function frog(x,z){
      const t0=ctx.currentTime+.02,dest=panner(x,.1,z,3),n=2+(Math.random()*2|0),f=rnd(95,140);
      for(let i=0;i<n;i++){const t=t0+i*.22,o=ctx.createOscillator(),lp=filter('lowpass',650,3),g=ctx.createGain();
        o.type='sawtooth';o.frequency.setValueAtTime(f*1.15,t);o.frequency.exponentialRampToValueAtTime(f,t+.12);
        g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(.07,t+.02);g.gain.exponentialRampToValueAtTime(.0001,t+.14);
        o.connect(lp).connect(g).connect(dest);o.start(t);o.stop(t+.16);}
      setTimeout(()=>dest.disconnect(),2000);
    }
    const set=(param,v,tc=.4)=>param.setTargetAtTime(v,ctx.currentTime,tc);
    function halt(){
      if(!beds)return;
      for(const s of sources){try{s.stop();s.disconnect();}catch(_){}}sources=[];
      for(const k in beds){try{beds[k].disconnect?.();}catch(_){}}for(const p of beds.cricketPans)p.disconnect();beds=null;
    }
    const api={
      get running(){return !!beds;},
      // Levels now (for tests): rain, crickets, and how many calls and plops so far.
      get levels(){return beds?{rain:beds.rain.gain.value,crickets:beds.cricket.gain.value,calls}:null;},
      // Leaving the headset: fade out at once and stop.
      stop(){if(!ctx)return;set(out.gain,0,.08);offFor=0;setTimeout(()=>{if(offFor>=0&&out.gain.value<.05)halt();},500);},
      update(dt,on,eye){
        const a=audio();if(!a||a.state!=='running')return;
        if(!ctx){ctx=a;out=gain(0);out.connect(ctx.destination);}
        if(on){offFor=0;if(!beds)beds=start();}
        // Off for a while (out of the headset or in mixed reality): stop everything until it's back.
        else{offFor+=dt;if(beds&&offFor>3)halt();}
        set(out.gain,on?.7:0,.6);
        if(!beds||!on){lastT=ctx.currentTime;return;}
        // Calls run on the audio clock, so a slow frame never holds them back.
        dt=clamp(ctx.currentTime-(lastT||ctx.currentTime),0,.5);lastT=ctx.currentTime;
        const w=nature.weather||{},night=nature.night||0,rain=clamp(w.rain||0,0,1),snow=clamp(w.snow||0,0,1);
        // Rain hisses softly while it rains; snow falls in silence.
        set(beds.rain.gain,rain*rain*.03*(1-snow*.9),.8);
        set(beds.cricket.gain,night*.06*(1-rain*.8)*(1-snow),1.5);
        if(eye){
        // Crickets sit around you, a few metres off.
          beds.cricketPans.forEach((pan,i)=>{const a=i*2.1+.4;place(pan,eye.x+Math.cos(a)*(5+i*2),.3,eye.z+Math.sin(a)*(5+i*2));});
        }
        // Birds sing by day when it's dry, from a tree not too far away.
        const day=(1-night)*(1-rain*.9)*(1-snow);
        wait.bird-=dt;if(wait.bird<=0){wait.bird=rnd(1.2,4.5)/Math.max(.3,day);
          if(day>.2&&eye){const near=(nature.treeSpots||[]).map(s=>[Math.hypot(s.x-eye.x,s.z-eye.z),s]).sort((a,b)=>a[0]-b[0]).slice(0,10).map(e=>e[1]);
            const s=near.length?near[Math.random()*near.length|0]:{x:eye.x+rnd(-20,20),z:eye.z-20};bird(s.x,rnd(3.5,6),s.z);}}
        const p=nature.pond;
        wait.plop-=dt;if(wait.plop<=0){wait.plop=rnd(2.5,7);if(snow<.5&&eye&&Math.hypot(eye.x-p.x,eye.z-p.z)<p.rz+14){calls++;const a=Math.random()*Math.PI*2,r=Math.sqrt(Math.random())*.8;plop(p.x+Math.cos(a)*p.rx*r,p.z+Math.sin(a)*p.rz*r);}}
        wait.frog-=dt;if(wait.frog<=0){wait.frog=rnd(3,8);if(night>.5&&snow<.3){const a=Math.random()*Math.PI*2;frog(p.x+Math.cos(a)*p.rx*1.05,p.z+Math.sin(a)*p.rz*1.05);}}
      }
    };
    return api;
  };
})();
