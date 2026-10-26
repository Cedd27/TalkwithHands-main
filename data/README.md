# Sign landmark training data

Place collected landmark samples here before training.

Expected file:

- `sign_landmarks.csv`

CSV format:

```csv
label,x0,y0,z0,x1,y1,z1,x2,y2,z2,...,x20,y20,z20
A,0.48,0.72,-0.01,0.50,0.68,-0.02,...
```

Each row is one detected hand pose. Use the same 21 MediaPipe hand landmarks
from the Flutter app, in order. Aim for many samples per class, from different
users, angles, lighting, and distances.
