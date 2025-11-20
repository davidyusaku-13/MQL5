# result_rf_feature_importance.py
#
# Analisis pengaruh tiap parameter ke "Result" MT5
# menggunakan RandomForestRegressor (non-linear) + feature importance.
#
# Cara pakai:
# 1. Taruh file CSV MT5 di folder yang sama, misal: optimization_results.csv
# 2. Sesuaikan FILE_PATH kalau perlu
# 3. Jalankan: python result_rf_feature_importance.py
#
# Output:
# - R² train dan test
# - Ranking feature importance (print di terminal)
# - Bar chart importance disimpan ke result_rf_feature_importance.png

import pandas as pd
import numpy as np
from pathlib import Path
import matplotlib.pyplot as plt

from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score

# ================================
# KONFIGURASI
# ================================
FILE_PATH = "optimization_results.csv"  # ganti kalau nama file beda
TARGET = "Result"

FEATURES = [
    "Profit",
    "Expected Payoff",
    "Profit Factor",
    "Recovery Factor",
    "Sharpe Ratio",
    "Equity DD %",
    "Trades",
]

OUTPUT_FIG = "result_rf_feature_importance.png"

# ================================
# LOAD DATA
# ================================
csv_path = Path(FILE_PATH)
if not csv_path.exists():
    raise FileNotFoundError(f"CSV tidak ditemukan: {csv_path.resolve()}")

df = pd.read_csv(csv_path, engine="python")
df.columns = df.columns.str.strip()

print("Kolom di CSV:")
for c in df.columns:
    print(" -", c)
print()

# pastikan kolom yang kita mau ada semuanya
missing = [c for c in [TARGET] + FEATURES if c not in df.columns]
if missing:
    raise ValueError(f"Kolom berikut tidak ditemukan di CSV: {missing}")

data = df[[TARGET] + FEATURES].dropna()

X = data[FEATURES].values
y = data[TARGET].values

# ================================
# TRAIN / TEST SPLIT
# ================================
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# ================================
# RANDOM FOREST MODEL
# ================================
rf = RandomForestRegressor(
    n_estimators=500,
    random_state=42,
    n_jobs=-1,
    max_depth=None,
    min_samples_split=2,
    min_samples_leaf=1,
)

rf.fit(X_train, y_train)

y_pred_train = rf.predict(X_train)
y_pred_test = rf.predict(X_test)

r2_train = r2_score(y_train, y_pred_train)
r2_test = r2_score(y_test, y_pred_test)

print("=== RandomForestRegressor ===")
print(f"R² train : {r2_train:.4f}")
print(f"R² test  : {r2_test:.4f}")
print()

# ================================
# FEATURE IMPORTANCE
# ================================
importances = rf.feature_importances_
indices = np.argsort(importances)[::-1]  # sort desc

print("=== Feature Importances (descending) ===")
for rank, idx in enumerate(indices, start=1):
    fname = FEATURES[idx]
    imp = importances[idx]
    print(f"{rank:2d}. {fname:18s} : {imp:.4f}")
print()

# ================================
# PLOT BAR CHART
# ================================
sorted_features = [FEATURES[i] for i in indices]
sorted_importances = importances[indices]

plt.figure(figsize=(10, 6))
plt.bar(range(len(sorted_features)), sorted_importances)
plt.xticks(range(len(sorted_features)), sorted_features, rotation=45, ha="right")
plt.ylabel("Feature Importance")
plt.title("RandomForest – Feature Importance for MT5 Result")
plt.tight_layout()

plt.savefig(OUTPUT_FIG, dpi=200)
print(f"Gambar feature importance disimpan ke: {Path(OUTPUT_FIG).resolve()}")

plt.show()
