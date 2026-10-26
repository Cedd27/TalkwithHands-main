# Native VisionCamera Plugin: `detectHandLandmarks`

The React Native detector calls:

```ts
VisionCameraProxy.initFrameProcessorPlugin('detectHandLandmarks', {})
```

The native plugin should return this shape:

```ts
{
  hands: [
    [
      { x: 0.1, y: 0.2, z: -0.03 },
      ...
      // 21 landmarks total
    ]
  ]
}
```

## Android Direction

Implement a VisionCamera frame processor plugin in Kotlin:

1. Receive the camera `Frame`.
2. Convert/use the YUV image for MediaPipe Hand Landmarker.
3. Run MediaPipe with `numHands = 1` for A-Z/number mode or `2` if you later need two-hand words.
4. Return only landmark floats to JS, never the full frame.

Suggested native settings:

```text
delegate: CPU first
minHandDetectionConfidence: 0.55
minTrackingConfidence: 0.5
runningMode: LIVE_STREAM or VIDEO/frame mode depending on the MediaPipe binding
```

## iOS Direction

Implement the same plugin in Swift:

1. Read the CMSampleBuffer from VisionCamera.
2. Run MediaPipe Hand Landmarker.
3. Return the same `{ hands: HandLandmark[][] }` payload.

## Why Native

The current Flutter page lags because MediaPipe + camera + UI rebuilds compete in one app path. The React Native architecture keeps the camera preview native, processes frames in a frame processor, and sends only 63 numbers per detected hand back to UI.
