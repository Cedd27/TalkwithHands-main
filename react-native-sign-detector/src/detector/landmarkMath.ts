import type { HandLandmark } from './types';

const LANDMARK_COUNT = 21;

export function normalizeLandmarks(landmarks: HandLandmark[]): number[] {
  if (landmarks.length < LANDMARK_COUNT) {
    return [];
  }

  const wrist = landmarks[0];
  let scale = 0;

  for (let i = 0; i < LANDMARK_COUNT; i += 1) {
    const lm = landmarks[i];
    const dx = lm.x - wrist.x;
    const dy = lm.y - wrist.y;
    const dz = lm.z - wrist.z;
    scale = Math.max(scale, Math.sqrt(dx * dx + dy * dy + dz * dz));
  }

  scale = Math.max(scale, 0.0001);

  const values: number[] = [];
  for (let i = 0; i < LANDMARK_COUNT; i += 1) {
    const lm = landmarks[i];
    values.push((lm.x - wrist.x) / scale);
    values.push((lm.y - wrist.y) / scale);
    values.push((lm.z - wrist.z) / scale);
  }

  return values;
}

export function smoothHands(
  currentHands: HandLandmark[][] | null,
  previousHands: HandLandmark[][] | null,
  smoothing = 0.35
): HandLandmark[][] | null {
  if (!currentHands || currentHands.length === 0) {
    return null;
  }

  if (!previousHands || previousHands.length !== currentHands.length) {
    return currentHands.map((hand) => hand.map((lm) => ({ ...lm })));
  }

  return currentHands.map((hand, handIndex) => {
    const previous = previousHands[handIndex];
    if (!previous || previous.length !== hand.length) {
      return hand.map((lm) => ({ ...lm }));
    }

    return hand.map((lm, index) => {
      const prior = previous[index];
      return {
        x: prior.x + (lm.x - prior.x) * smoothing,
        y: prior.y + (lm.y - prior.y) * smoothing,
        z: lm.z
      };
    });
  });
}
