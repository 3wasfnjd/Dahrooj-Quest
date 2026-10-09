// One rack, one launched ball. A blaster or second throw invalidates that rack.
export function createThrowAttempt(){
 let owner=0,valid=true,touched=false;
 return {
  reset(){owner=0;valid=true;touched=false;},
  launch(id){if(!id){valid=false;return;}if(owner&&owner!==id)valid=false;else owner=id;},
  contact(id,intact){if(!id){valid=false;return;}if(!owner)valid=false;if(owner!==id||(!touched&&!intact))valid=false;touched=true;},
  invalidate(){valid=false;},
  complete(){return valid&&owner>0&&touched;}
 };
}
// Attempt-scoped progress may fall; earned achievements stay earned.
export function challengeValue(id,current,goal,next){
 if(current>=goal)return goal;
 const value=Math.max(0,Math.min(goal,next));
 return id==='hoop3'||id==='fair25'?value:Math.max(current,value);
}
