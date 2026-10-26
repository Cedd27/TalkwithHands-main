"""Debug: why does Keras not learn from sign_sequences.csv while RandomForest does?

Usage:  python tools/debug_keras.py --csv data/sign_sequences.csv
Prints: input stats, 1-NN, logistic regression, and a small Keras Dense net
(all on the SAME normalized + standardized flattened sequences).
"""
import argparse
import numpy as np
import pandas as pd

FRAMES, LM, C = 30, 21, 3


def normalize_sequence(seq):
    out = np.empty_like(seq)
    for f in range(seq.shape[0]):
        frame = seq[f].reshape(LM, C).copy()
        frame -= frame[0].copy()
        scale = max(float(np.max(np.linalg.norm(frame, axis=1))), 1e-4)
        out[f] = (frame / scale).flatten()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/sign_sequences.csv")
    args = ap.parse_args()

    df = pd.read_csv(args.csv, low_memory=False)
    labels = df.iloc[:, 0].astype(str).str.strip()
    values = df.iloc[:, 1:].values.astype(np.float32)
    names = sorted(labels.unique().tolist())
    idx = {n: i for i, n in enumerate(names)}
    y = np.array([idx[l] for l in labels], dtype=np.int32)

    X = values.reshape(-1, FRAMES, LM * C)
    Xn = np.array([normalize_sequence(s) for s in X], dtype=np.float32)
    Xn = Xn.reshape(len(y), -1)

    from sklearn.model_selection import train_test_split
    Xtr, Xva, ytr, yva = train_test_split(
        Xn, y, test_size=0.15, random_state=42, stratify=y)

    print("=== Input stats (train) ===")
    print("shape:", Xtr.shape, "dtype:", Xtr.dtype)
    print("has NaN:", bool(np.isnan(Xtr).any()), "| has Inf:", bool(np.isinf(Xtr).any()))
    print("min/max:", float(Xtr.min()), float(Xtr.max()))
    print("mean per-feature std:", float(Xtr.std(axis=0).mean()))
    print("features with ~zero std:", int((Xtr.std(axis=0) < 1e-6).sum()), "of", Xtr.shape[1])

    mu = Xtr.mean(axis=0)
    sd = Xtr.std(axis=0) + 1e-6
    Xtr_s = (Xtr - mu) / sd
    Xva_s = (Xva - mu) / sd

    from sklearn.neighbors import KNeighborsClassifier
    knn = KNeighborsClassifier(n_neighbors=1).fit(Xtr_s, ytr)
    print(f"\n1-NN val accuracy:               {knn.score(Xva_s, yva):.3f}")

    from sklearn.linear_model import LogisticRegression
    lr = LogisticRegression(max_iter=500).fit(Xtr_s, ytr)
    print(f"LogisticRegression train acc:    {lr.score(Xtr_s, ytr):.3f}")
    print(f"LogisticRegression val acc:      {lr.score(Xva_s, yva):.3f}")

    import tensorflow as tf
    tf.keras.utils.set_random_seed(42)
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(Xtr_s.shape[1],)),
        tf.keras.layers.Dense(256, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.Dense(len(names), activation="softmax"),
    ])
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="sparse_categorical_crossentropy",
                  metrics=["accuracy"])
    h = model.fit(Xtr_s, ytr, validation_data=(Xva_s, yva),
                  epochs=60, batch_size=32, verbose=0)

    print("\nKeras Dense (standardized flattened input)")
    for e in [0, 4, 9, 19, 29, 44, 59]:
        print(f"  epoch {e + 1:>2}: train acc {h.history['accuracy'][e]:.3f}  "
              f"val acc {h.history['val_accuracy'][e]:.3f}  "
              f"loss {h.history['loss'][e]:.3f}")


if __name__ == "__main__":
    main()