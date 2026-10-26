"""
Diagnostic: check what % of frames per label are all-zero (no hand detected)
in data/sign_sequences.csv. Run from your project root:

    python tools/diagnose_sequences.py --csv data/sign_sequences.csv
"""
import argparse
import numpy as np
import pandas as pd

p = argparse.ArgumentParser()
p.add_argument('--csv', default='data/sign_sequences.csv')
p.add_argument('--frames', type=int, default=30)
args = p.parse_args()

LANDMARKS = 21
COORDS = 3
n_features = LANDMARKS * COORDS

df = pd.read_csv(args.csv)
labels = df.iloc[:, 0].astype(str).str.strip()
values = df.iloc[:, 1:].values.astype(np.float32)
X = values.reshape(-1, args.frames, n_features)

print(f"{'Label':<15}{'Samples':<10}{'Avg % zero frames':<20}{'Fully-zero samples'}")
for lbl in sorted(labels.unique()):
    idx = (labels == lbl).values
    seqs = X[idx]  # (n_samples, frames, 63)
    # a frame is "zero" if every value in it is ~0
    frame_is_zero = np.all(np.abs(seqs) < 1e-6, axis=2)  # (n_samples, frames)
    pct_zero_per_sample = frame_is_zero.mean(axis=1) * 100
    avg_pct_zero = pct_zero_per_sample.mean()
    fully_zero_samples = int((pct_zero_per_sample > 95).sum())
    print(f"{lbl:<15}{idx.sum():<10}{avg_pct_zero:<20.1f}{fully_zero_samples}")