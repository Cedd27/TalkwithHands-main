export type DetectionMode = 'words' | 'az' | 'num' | 'motion';

export type MotionCategory = 'words' | 'az' | 'num';

export type HandLandmark = {
  x: number;
  y: number;
  z: number;
};

export type SignResult = {
  label: string;
  confidence: number;
  type: 'alphabet' | 'number' | 'word' | 'sequence';
  isModelConfidence: boolean;
};

export type DetectorStatus =
  | 'loading-models'
  | 'requesting-camera'
  | 'camera-ready'
  | 'camera-denied'
  | 'native-plugin-missing'
  | 'error';
