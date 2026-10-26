"""Find and remove rows with NaN/missing values in sign_sequences.csv.

Usage:  python tools/find_nan.py --csv data/sign_sequences.csv
Writes a cleaned copy to data/sign_sequences_clean.csv (original untouched).
"""
import argparse
import re
import pandas as pd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/sign_sequences.csv")
    ap.add_argument("--out", default="data/sign_sequences_clean.csv")
    args = ap.parse_args()

    df = pd.read_csv(args.csv, low_memory=False)
    labels = df.iloc[:, 0].astype(str).str.strip()
    vals = df.iloc[:, 1:].apply(pd.to_numeric, errors="coerce")

    bad_cells = vals.isna()
    bad_rows = bad_cells.any(axis=1)

    print(f"Total rows:            {len(df)}")
    print(f"Rows with NaN/missing: {int(bad_rows.sum())}")
    print(f"NaN cells total:       {int(bad_cells.values.sum())}")

    print("\nPer label (total / bad):")
    for lbl in sorted(labels.unique()):
        m = labels == lbl
        print(f"  {lbl:<12} {int(m.sum()):>4} / {int((m & bad_rows).sum()):>4}")

    if bad_rows.any():
        print("\nFirst bad rows (CSV line number, label, #NaN cells, frames affected):")
        for i in list(df.index[bad_rows])[:10]:
            cols = list(vals.columns[bad_cells.loc[i].values])
            frames = sorted({int(re.match(r"f(\d+)_", c).group(1))
                             for c in cols if re.match(r"f(\d+)_", c)})
            print(f"  line {i + 2:<5} {labels[i]:<12} {len(cols):>5} cells  frames {frames[:12]}")

    clean = df[~bad_rows]
    clean.to_csv(args.out, index=False)

    print(f"\nKept {len(clean)} rows, dropped {int(bad_rows.sum())}.")
    print("Remaining per label:")
    cl = clean.iloc[:, 0].astype(str).str.strip()
    for lbl in sorted(labels.unique()):
        print(f"  {lbl:<12} {int((cl == lbl).sum()):>4}")
    print(f"\nWrote {args.out}")


if __name__ == "__main__":
    main()