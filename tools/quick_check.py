"""Quick sanity check: does sign_sequences.csv contain learnable signal?

Trains a RandomForest (no LSTM) on the same normalized sequences.
Usage:  python tools/quick_check.py --csv data/sign_sequences.csv
"""
import argparse
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

FRAMES, LM, C = 30, 21, 3


def normalize_sequence(seq):
    out = np.empty_like(seq)
    for f in range(seq.shape[0]):
        frame = seq[f].reshape(LM, C).copy()
        frame -= frame[0].copy()
        scale = max(float(np.max(np.linalg.norm(frame, axis=1))), 1e-4)
        out[f] = (frame / scale).flatten()
    return out


def evaluate(name, X, y, label_names):
    try:
        Xtr, Xva, ytr, yva = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y)
    except ValueError:
        Xtr, Xva, ytr, yva = train_test_split(
            X, y, test_size=0.2, random_state=42)
    clf = RandomForestClassifier(n_estimators=300, random_state=42, n_jobs=-1)
    clf.fit(Xtr, ytr)
    pred = clf.predict(Xva)
    acc = (pred == yva).mean()
    print(f"\n=== {name} ===  val accuracy: {acc:.3f}")
    present = sorted(set(yva) | set(pred))
    print(classification_report(
        yva, pred, labels=present,
        target_names=[label_names[i] for i in present], zero_division=0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/sign_sequences.csv")
    args = ap.parse_args()

    df = pd.read_csv(args.csv, low_memory=False)
    labels = df.iloc[:, 0].astype(str).str.strip()
    values = df.iloc[:, 1:].values.astype(np.float32)

    names = sorted(labels.unique().tolist())
    idx = {n: i for i, n in enumerate(names)}
    y = np.array([idx[l] for l in labels])

    X = values.reshape(-1, FRAMES, LM * C)
    Xn = np.array([normalize_sequence(s) for s in X], dtype=np.float32)

    chance = np.bincount(y).max() / len(y)
    print(f"Samples: {len(y)}  |  majority-class baseline: {chance:.3f}")

    evaluate("Flattened (30x63 = 1890 features)", Xn.reshape(len(Xn), -1), y, names)
    stats = np.concatenate([Xn.mean(axis=1), Xn.std(axis=1)], axis=1)
    evaluate("Mean + std over frames (126 features)", stats, y, names)


if __name__ == "__main__":
    main()