# result_regression.py
#
# Script untuk mencari rumus Result paling mendekati via:
# - Linear Regression
# - Ridge Regression (L2)
# - Lasso Regression (L1)
#
# Output:
# - Bobot setiap parameter
# - R^2 score untuk tiap model
# - Rumus Result paling akurat
#
# Cara pakai:
# 1. Taruh CSV MT5 kamu di folder yang sama
# 2. Ubah FILE_PATH sesuai nama file
# 3. Jalanin: python result_regression.py

import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.linear_model import LinearRegression, Ridge, Lasso
from sklearn.metrics import r2_score
from sklearn.preprocessing import StandardScaler

# ================================
# KONFIG & INPUT CSV
# ================================
FILE_PATH = "optimization_results.csv"  # ubah sesuai nama file CSV
TARGET = "Result"  # kolom target Result

# Kolom kandidat fitur (jangan sentuh kalau nama sama)
FEATURES = [
    "Profit",
    "Expected Payoff",
    "Profit Factor",
    "Recovery Factor",
    "Sharpe Ratio",
    "Equity DD %",
    "Trades",
]

# ================================
# LOAD DATA
# ================================
df = pd.read_csv(FILE_PATH, engine="python")
df.columns = df.columns.str.strip()

# Pastikan semua kolom tersedia
for c in [TARGET] + FEATURES:
    if c not in df.columns:
        print(f"[WARNING] Kolom '{c}' tidak ditemukan di CSV.")

df = df[[TARGET] + FEATURES].dropna()

X = df[FEATURES].values
y = df[TARGET].values

# Normalisasi fitur (biar tidak bias ke angka besar)
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# ================================
# TRAIN 3 MODEL
# ================================
models = {
    "Linear": LinearRegression(),
    "Ridge (L2)": Ridge(alpha=1.0),
    "Lasso (L1)": Lasso(alpha=0.05),
}

results = {}

print("\n=======================")
print(" FITTING MODELS ")
print("=======================\n")

for name, model in models.items():
    model.fit(X_scaled, y)
    preds = model.predict(X_scaled)
    r2 = r2_score(y, preds)
    coef = model.coef_

    print(f"\n=== {name} Regression ===")
    print(f"R² score: {r2:.4f}")
    print("Coefficients:")
    for fname, w in zip(FEATURES, coef):
        print(f"  {fname:18s} : {w:+.6f}")

    print("\nEstimated formula:")
    print("Result ≈ ", end="")
    parts = []
    for fname, w in zip(FEATURES, coef):
        parts.append(f"({w:+.4f}) * {fname}_scaled")
    print(" + ".join(parts))

    results[name] = (r2, coef)

# ================================
# PILIH MODEL TERBAIK
# ================================
best_name = max(results, key=lambda m: results[m][0])
best_r2, best_coef = results[best_name]

print("\n=======================")
print(" MODEL TERBAIK ")
print("=======================")
print(f"Model: {best_name}")
print(f"R² terbaik: {best_r2:.4f}\n")

print("Rumus paling akurat:")
print(
    "Result ≈",
    " + ".join(
        [f"({w:+.4f}) * {fname}_scaled" for fname, w in zip(FEATURES, best_coef)]
    ),
)

print("\nCatatan:")
print("- _scaled berarti nilai sudah dinormalisasi StandardScaler")
print("- Koef Lasso yang 0 artinya fitur tersebut kemungkinan TIDAK dipakai MT5")
