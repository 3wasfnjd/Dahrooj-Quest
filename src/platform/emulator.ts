import { XRDevice, metaQuest3 } from 'iwer';
/** Only reached by the development automation build. Never imported in production. */
export function installEmulator() { const device = new XRDevice(metaQuest3, { stereoEnabled: false }); device.installRuntime({ forceInstall: true }); (window as unknown as {
    IWER_DEVICE: XRDevice;
}).IWER_DEVICE = device; }
