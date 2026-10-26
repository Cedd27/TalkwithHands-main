"""Train a landmark-based sign classifier and export it to TensorFlow Lite.

Expected CSV format:

label,x0,y0,z0,x1,y1,z1,...,x20,y20,z20
A,0.48,0.72,-0.01,...

The 63 landmark values should come from the same MediaPipe/hand_landmarker
order used by the Flutter app.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from pathlib import Path


LANDMARK_VALUE_COUNT = 21 * 3


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to landmark CSV data.")
    parser.add_argument(
        "--out-dir",
        default="assets/ml",
        help="Output directory for .tflite, labels.txt, and metadata.",
    )
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--validation-split", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


def normalize_landmarks(values: list[float]) -> list[float]:
    points = [values[i : i + 3] for i in range(0, LANDMARK_VALUE_COUNT, 3)]
    wrist = points[0]
    centered = [
        [point[0] - wrist[0], point[1] - wrist[1], point[2] - wrist[2]]
        for point in points
    ]
    scale = max(
        max((x * x + y * y + z * z) ** 0.5 for x, y, z in centered),
        0.0001,
    )
    return [value / scale for point in centered for value in point]


def load_csv(csv_path: Path) -> tuple[list[list[float]], list[str]]:
    features: list[list[float]] = []
    labels: list[str] = []
    with csv_path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle)
        first_row = next(reader, None)
        if first_row is None:
            raise ValueError("CSV file is empty.")

        has_header = first_row[0].strip().lower() == "label"
        rows = reader if has_header else [first_row, *reader]

        for row_number, row in enumerate(rows, start=2 if has_header else 1):
            if not row or not row[0].strip():
                continue
            label = row[0].strip()
            raw_values = [float(value) for value in row[1:]]
            if len(raw_values) != LANDMARK_VALUE_COUNT:
                raise ValueError(
                    f"Row {row_number} has {len(raw_values)} values; "
                    f"expected {LANDMARK_VALUE_COUNT}."
                )
            labels.append(label)
            features.append(normalize_landmarks(raw_values))

    if not features:
        raise ValueError("No training rows found.")
    return features, labels


def main() -> None:
    args = parse_args()

    import numpy as np
    import tensorflow as tf

    random.seed(args.seed)
    np.random.seed(args.seed)
    tf.random.set_seed(args.seed)

    csv_path = Path(args.csv)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    features, labels = load_csv(csv_path)
    label_names = sorted(set(labels))
    label_to_index = {label: index for index, label in enumerate(label_names)}

    x = np.asarray(features, dtype=np.float32)
    y = np.asarray([label_to_index[label] for label in labels], dtype=np.int64)

    # Split each label independently. A global random split can place all
    # samples for a small class in validation, leaving the model unable to
    # learn that sign at all.
    train_indices: list[int] = []
    validation_indices: list[int] = []
    for label_index in range(len(label_names)):
        label_indices = np.flatnonzero(y == label_index)
        np.random.shuffle(label_indices)
        validation_count = (
            max(1, int(len(label_indices) * args.validation_split))
            if len(label_indices) >= 5
            else 0
        )
        validation_indices.extend(label_indices[:validation_count])
        train_indices.extend(label_indices[validation_count:])

    np.random.shuffle(train_indices)
    np.random.shuffle(validation_indices)
    x_train = x[train_indices]
    y_train = y[train_indices]
    x_val = x[validation_indices]
    y_val = y[validation_indices]

    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(LANDMARK_VALUE_COUNT,)),
            tf.keras.layers.Dense(128, activation="relu"),
            tf.keras.layers.Dropout(0.25),
            tf.keras.layers.Dense(64, activation="relu"),
            tf.keras.layers.Dropout(0.15),
            tf.keras.layers.Dense(len(label_names), activation="softmax"),
        ]
    )
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=12,
            restore_best_weights=True,
        )
    ]
    history = model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val) if len(x_val) else None,
        epochs=args.epochs,
        batch_size=args.batch_size,
        callbacks=callbacks,
        verbose=2,
    )

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    (out_dir / "sign_landmark_classifier.tflite").write_bytes(tflite_model)
    (out_dir / "labels.txt").write_text("\n".join(label_names) + "\n", encoding="utf-8")
    (out_dir / "training_metadata.json").write_text(
        json.dumps(
            {
                "labels": label_names,
                "samples": len(features),
                "train_samples": len(x_train),
                "validation_samples": len(x_val),
                "final_accuracy": history.history["accuracy"][-1],
                "final_val_accuracy": history.history["val_accuracy"][-1],
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    print(f"Wrote {out_dir / 'sign_landmark_classifier.tflite'}")
    print(f"Wrote {out_dir / 'labels.txt'}")


if __name__ == "__main__":
    main()
