import type {World,SessionMode,Object3D} from '@iwsdk/core';
import type {SaveStore} from '../save/store';
export interface CompleteGame {start(mode:SessionMode):void;export():void;report():unknown;
 inspectRendering():{mode:string;kind:string|null;stage?:Object3D;nature?:Object3D;weather:{time:string;weather:string}|null;menu:string};
}
export function createCompleteGame(world:World,store:SaveStore):CompleteGame;
