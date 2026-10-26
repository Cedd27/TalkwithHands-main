import type { Frame } from 'react-native-vision-camera';
import { VisionCameraProxy } from 'react-native-vision-camera';

import type { HandLandmark } from '../detector/types';

type NativeHandResult = {
  hands: HandLandmark[][];
};

const plugin = VisionCameraProxy.initFrameProcessorPlugin('detectHandLandmarks', {});

export function hasHandLandmarkerPlugin() {
  return plugin != null;
}

export function detectHandLandmarks(frame: Frame): NativeHandResult {
  'worklet';

  if (plugin == null) {
    return { hands: [] };
  }

  const result = plugin.call(frame) as NativeHandResult | undefined;
  return result ?? { hands: [] };
}
