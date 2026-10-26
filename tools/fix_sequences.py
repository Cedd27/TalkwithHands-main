"""Repair sign_sequences.csv: rows with missing frames (NaN) are time-stretched to 30 frames.

Old rows were recorded with fewer than 30 frames (the rest of the columns are empty).
Instead of dropping them, the valid frames are linearly interpolated to 30 frames.

Usage:  python tools/fix_sequences.py --csv data/sign_sequences.csv
Writes: data/sign_sequences_fixed.csv  (original untouched)
"""
import argparse
import numpy as np
import pandas as pd

FRAMES, DIM = 30, 63


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/sign_sequences.csv")
    ap.add_argument("--out", default="data/sign_sequences_fixed.csv")
    args = ap.parse_args()

    df = pd.read_csv(args.csv, low_memory=False)
    labels = df.iloc[:, 0].astype(str).str.strip().values
    vals = df.iloc[:, 1:].apply(pd.to_numeric, errors="coerce").values.astype(np.float64)
    X = vals.reshape(-1, FRAMES, DIM)
    fixed = X.copy()

    keep = np.ones(len(X), dtype=bool)
    stretched = {}
    valid_counts = {}
    for i in range(len(X)):
        valid = ~np.isnan(X[i]).any(axis=1)
        if valid.all():
            continue
        n = int(valid.sum())
        if n < 2:
            keep[i] = False
            continue
        src = X[i][valid]
        old_t = np.linspace(0.0, 1.0, n)
        new_t = np.linspace(0.0, 1.0, FRAMES)
        for d in range(DIM):
            fixed[i, :, d] = np.interp(new_t, old_t, src[:, d])
        stretched[labels[i]] = stretched.get(labels[i], 0) + 1
        valid_counts[n] = valid_counts.get(n, 0) + 1

    print("Rows stretched to 30 frames, per label:")
    for k in sorted(stretched):
        print(f"  {k:<12} {stretched[k]}")
    print("Valid frame counts found in stretched rows (frames: rows):", valid_counts)
    print(f"Rows dropped (fewer than 2 valid frames): {int((~keep).sum())}")

    out = pd.DataFrame(fixed[keep].reshape(int(keep.sum()), -1), columns=df.columns[1:])
    out.insert(0, df.columns[0], labels[keep])
    print("NaN remaining:", bool(np.isnan(out.iloc[:, 1:].values).any()))

    out.to_csv(args.out, index=False, float_format="%.6f")
    print("\nFinal rows per label:")
    for lbl in sorted(set(labels[keep])):
        print(f"  {lbl:<12} {int((labels[keep] == lbl).sum())}")
    print(f"\nWrote {args.out}")


if __name__ == "__main__":
    main()
    