# TensorFlow Lite sign classifier assets

This folder is reserved for the trained landmark classifier.

Expected generated files:

- `sign_landmark_classifier.tflite`
- `labels.txt`

Generate them with:

```powershell
python tools/train_sign_landmark_model.py --csv data/sign_landmarks.csv
```

The app can still run without the `.tflite` file. In that case it falls back to
the existing rule-based classifier.
