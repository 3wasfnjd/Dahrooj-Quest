import type {World,SessionMode} from '@iwsdk/core';
import type {SaveStore} from '../save/store';
export interface CompleteGame {start(mode:SessionMode):void;export():void;report():unknown;}
export function createCompleteGame(world:World,store:SaveStore):CompleteGame;
