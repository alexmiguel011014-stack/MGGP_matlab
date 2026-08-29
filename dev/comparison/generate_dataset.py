"""generate_dataset.py — Valida siso_ref.csv gerado pelo MATLAB.

Lê data/siso_ref.csv e imprime estatísticas básicas para confirmar que o
Python está lendo os mesmos dados que o MATLAB usou para treinar.

Uso:
    python generate_dataset.py          # valida data/siso_ref.csv
"""
import os
import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR   = os.path.join(SCRIPT_DIR, 'data')
CSV_PATH   = os.path.join(DATA_DIR, 'siso_ref.csv')


def load_dataset(split=0.7):
    df   = pd.read_csv(CSV_PATH)
    y    = df['y'].values
    u1   = df['u1'].values
    n    = len(y)
    n_id = round(n * split)
    return (y[:n_id], u1[:n_id]), (y[n_id:], u1[n_id:]), n


if __name__ == '__main__':
    if not os.path.exists(CSV_PATH):
        raise FileNotFoundError(
            f"Dataset nao encontrado: {CSV_PATH}\n"
            "Execute generate_dataset.m no MATLAB primeiro."
        )

    (y_id, u_id), (y_val, u_val), n = load_dataset()

    print(f"Dataset: {CSV_PATH}")
    print(f"  N total = {n}")
    print(f"  N id    = {len(y_id)}  (70%)")
    print(f"  N val   = {len(y_val)}  (30%)")
    print(f"  y  mean={y_id.mean():.4f}  std={y_id.std():.4f}  "
          f"min={y_id.min():.4f}  max={y_id.max():.4f}")
    print(f"  u1 mean={u_id.mean():.4f}  std={u_id.std():.4f}  "
          f"min={u_id.min():.4f}  max={u_id.max():.4f}")
    print("OK — dataset pronto para bench_python.py")
