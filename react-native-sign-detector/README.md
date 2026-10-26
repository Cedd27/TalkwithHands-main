# React Native Live Sign Detector

This folder is a focused React Native detector module for the current Talk with Hands pipeline:

1. Open the camera with `react-native-vision-camera`.
2. Detect 21 hand landmarks in a VisionCamera frame processor.
3. Normalize landmarks the same way as the Flutter classifier.
4. Run the existing `.tflite` model with `react-native-fast-tflite`.
5. Display the predicted sign with confidence and a stable hold/capture flow.

It reuses the current model files from the main repo:

```text
../assets/ml/sign_landmark_classifier.tflite
../assets/ml/sign_sequence_classifier.tflite
../assets/ml/labels.txt
../assets/ml/sequence_labels.txt
```

For a standalone RN project, copy those files into this module:

```powershell
npm run copy-model-assets
```

## Native Piece Still Required

`src/vision/handLandmarkerFrameProcessor.ts` expects a VisionCamera frame processor plugin named `detectHandLandmarks`.

That plugin must be implemented natively for Android/iOS using MediaPipe Hand Landmarker. Keep it native/JSI because sending full camera frames into JS every frame will lag. The React Native UI receives only small landmark arrays, not raw images.

See `src/vision/NATIVE_PLUGIN_TODO.md` for the expected plugin payload and implementation direction.

## Performance Defaults

- Camera target: front camera, 30 FPS.
- Inference throttle: about 10 FPS by default.
- Processed data per frame: 21 landmarks x 3 floats.
- Sequence buffer: 30 frames, matching the current Flutter LSTM flow.

## Run

Install dependencies first:

```powershell
npm install
```

Then run Android:

```powershell
npm run android
```

iOS requires a Mac/Xcode:

```bash
npm run ios
```
