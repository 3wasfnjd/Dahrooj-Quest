/** This game uses its own cached bilingual canvas panels, never UIKitML.
 * Exclude the unused parser/compiler and its unverified license from the runtime.
 * Any accidental future use fails explicitly rather than silently rendering nothing.
 */
export function parse(): never { throw new Error('UIKitML is not part of Dahrooj. Use SpatialUI.'); }
export function instantiate(): never { throw new Error('UIKitML is not part of Dahrooj. Use SpatialUI.'); }
export function resolveKitComponentSets() { return []; }
