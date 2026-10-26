"""Import Basic Words .npy sequences into the app sequence CSV.

The source folder is expected to contain one directory per label, with .npy
files shaped like (frames, 46, 3), (frames, 21, 3), or flattened equivalents.
The app sequence model currently consumes one hand: 30 frames x 21 landmarks x
3 coordinates, so 46-point samples are reduced to the most active 21-point hand.

Usage:
    python tools/import_basic_words_sequences.py ^
        --source "C:\\Users\\Mary Jasmine\\Downloads\\Basic Words" ^
        --existing data/sign_sequences.csv ^
        --out data/sign_sequences.csv
"""

import argparse
import csv
from pathlib import Path

import numpy as np
import pandas as pd


LANDMARKS = 21
COORDS = 3

LABEL_ALIASES = {
    "birds": "bird",
    "cats": "cat",
    "monkeys": "monkey",
    "pigs": "pig",
    "snakes": "snake",
    "reciept": "receipt",
    "recieve": "receive",
}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--existing", default="data/sign_sequences.csv")
    parser.add_argument("--out", default="data/sign_sequences.csv")
    parser.add_argument("--frames", type=int, default=30)
    parser.add_argument("--max-samples-per-label", type=int, default=0)
    parser.add_argument(
        "--keep-existing-rows",
        type=int,
        default=0,
        help="Keep only the first N rows from --existing before importing.",
    )
    return parser.parse_args()


def header(frames):
    columns = ["label"]
    for frame in range(frames):
        for landmark in range(LANDMARKS):
            for coord in ("x", "y", "z"):
                columns.append(f"f{frame}_{coord}{landmark}")
    return columns


def label_from_dir(path):
    label = path.name.strip()
    if len(label) == 1 and label.isalpha():
        return label.upper()
    normalized = " ".join(label.replace("_", " ").split()).lower()
    return LABEL_ALIASES.get(normalized, normalized)


def as_frames_points_coords(array):
    arr = np.asarray(array, dtype=np.float32)
    arr = np.squeeze(arr)
    if arr.ndim == 3 and arr.shape[-1] >= COORDS:
        return arr[:, :, :COORDS]
    if arr.ndim == 2:
        if arr.shape[1] % COORDS == 0:
            return arr.reshape(arr.shape[0], arr.shape[1] // COORDS, COORDS)
        if arr.shape[0] % COORDS == 0:
            reshaped = arr.reshape(arr.shape[0] // COORDS, COORDS, arr.shape[1])
            return np.moveaxis(reshaped, 2, 0)
    raise ValueError(f"unsupported shape {arr.shape}")


def block_score(block):
    finite = np.isfinite(block).all(axis=2)
    nonzero = np.linalg.norm(block, axis=2) > 1e-6
    present = finite & nonzero
    if not present.any():
        return -1.0
    wrist_motion = float(np.nanstd(block[:, 0, :2]))
    tip_motion = float(np.nanstd(block[:, 8, :2]))
    return float(present.mean()) + wrist_motion + tip_motion


def choose_hand(points):
    point_count = points.shape[1]
    if point_count < LANDMARKS:
        raise ValueError(f"only {point_count} landmarks")
    if point_count >= 46:
        left = points[:, 4 : 4 + LANDMARKS, :]
        right = points[:, 4 + LANDMARKS : 4 + LANDMARKS * 2, :]
        return right if block_score(right) > block_score(left) else left
    if point_count >= LANDMARKS * 2:
        left = points[:, :LANDMARKS, :]
        right = points[:, LANDMARKS : LANDMARKS * 2, :]
        return right if block_score(right) > block_score(left) else left
    return points[:, :LANDMARKS, :]


def resample_frames(seq, frames):
    if seq.shape[0] == frames:
        return seq
    if seq.shape[0] <= 1:
        return np.repeat(seq[:1], frames, axis=0)
    source = np.linspace(0.0, 1.0, seq.shape[0])
    target = np.linspace(0.0, 1.0, frames)
    out = np.empty((frames, seq.shape[1], seq.shape[2]), dtype=np.float32)
    for landmark in range(seq.shape[1]):
        for coord in range(seq.shape[2]):
            out[:, landmark, coord] = np.interp(
                target,
                source,
                seq[:, landmark, coord],
            )
    return out


def load_sample(path, frames):
    arr = np.load(path, allow_pickle=False)
    points = as_frames_points_coords(arr)
    hand = choose_hand(points)
    hand = np.nan_to_num(hand, nan=0.0, posinf=0.0, neginf=0.0)
    return resample_frames(hand, frames).reshape(-1).astype(np.float32)


def iter_import_rows(source, frames, max_samples_per_label):
    total = 0
    skipped = 0
    per_label = {}
    for label_dir in sorted(p for p in source.iterdir() if p.is_dir()):
        label = label_from_dir(label_dir)
        files = sorted(label_dir.glob("*.npy"))
        if max_samples_per_label > 0:
            files = files[:max_samples_per_label]
        for file_path in files:
            try:
                values = load_sample(file_path, frames)
            except Exception as exc:
                skipped += 1
                print(f"Skipping {file_path}: {exc}")
                continue
            total += 1
            per_label[label] = per_label.get(label, 0) + 1
            yield [label, *values.tolist()]
    print(f"Imported Basic Words samples: {total}")
    print(f"Skipped Basic Words samples: {skipped}")
    print(f"Imported labels: {len(per_label)}")


def main():
    args = parse_args()
    source = Path(args.source)
    existing = Path(args.existing)
    out = Path(args.out)
    columns = header(args.frames)

    rows = []
    if existing.exists():
        current = pd.read_csv(existing, low_memory=False)
        if list(current.columns) != columns:
            raise ValueError(
                f"{existing} does not match the expected {len(columns)} columns"
            )
        if args.keep_existing_rows > 0:
            current = current.head(args.keep_existing_rows)
        rows.extend(current.values.tolist())
        print(f"Kept existing samples: {len(current)}")

    rows.extend(
        iter_import_rows(source, args.frames, args.max_samples_per_label)
    )

    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        writer.writerows(rows)

    labels = sorted({str(row[0]).strip() for row in rows})
    print(f"Wrote {len(rows)} total samples -> {out}")
    print(f"Total labels: {len(labels)}")


if __name__ == "__main__":
    main()
