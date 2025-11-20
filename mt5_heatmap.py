# mt5_heatmap.py
#
# Cara pakai:
# 1. Taruh file CSV MT5 kamu di folder yang sama, misal: optimization_results.csv
# 2. Ubah nama FILE_PATH di bawah kalau perlu
# 3. Jalankan:  python mt5_heatmap.py
#
# Script ini:
# - otomatis deteksi kolom yang relevan (Result, Profit, Expected Payoff, dll)
# - hitung korelasi
# - print matrix korelasi
# - bikin heatmap dan simpan ke PNG

import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# ==========================
# KONFIGURASI
# ==========================
FILE_PATH = "optimization_results.csv"  # ganti kalau namanya beda
OUTPUT_FIG = "mt5_correlation_heatmap.png"

# Kalau mau pakai subset kolom tertentu, isi list ini.
# Kalau kosong [], script akan otomatis ambil yang tersedia.
PREFERRED_COLUMNS = [
    "Result",  # complex criterion (kalau ada)
    "Profit",
    "Expected Payoff",
    "Profit Factor",
    "Recovery Factor",
    "Sharpe Ratio",
    "Equity DD %",
    "Trades",  # Number of Deals
]


# ==========================
# MAIN
# ==========================
def main():
    csv_path = Path(FILE_PATH)
    if not csv_path.exists():
        raise FileNotFoundError(f"File CSV tidak ditemukan: {csv_path.resolve()}")

    # Baca CSV, biarkan pandas auto-detect delimiter
    # Kalau locale kamu pakai ; sebagai pemisah, ini tetap aman
    df = pd.read_csv(csv_path, engine="python")

    # Bersihkan nama kolom (hapus spasi di depan/belakang)
    df.columns = df.columns.str.strip()

    print("Kolom yang ditemukan di CSV:")
    for c in df.columns:
        print(" -", c)
    print()

    # Pilih kolom yang mau dianalisis
    if PREFERRED_COLUMNS:
        # ambil hanya kolom yang memang ada di file
        cols = [c for c in PREFERRED_COLUMNS if c in df.columns]
    else:
        # kalau tidak didefinisikan, ambil semua kolom numerik
        cols = df.select_dtypes(include="number").columns.tolist()

    if not cols:
        raise ValueError(
            "Tidak ada kolom yang cocok / numerik untuk dihitung korelasinya."
        )

    print("Kolom yang dipakai untuk korelasi:")
    for c in cols:
        print(" -", c)
    print()

    # Ambil hanya kolom-kolom tersebut dan drop baris yang ada NaN
    sub = df[cols].dropna()

    # Hitung korelasi Pearson
    corr = sub.corr(method="pearson")

    print("=== Correlation Matrix (Pearson) ===")
    print(corr.round(3))
    print()

    # Kalau ada kolom 'Result', cetak korelasi Result vs yang lain, di-sort
    if "Result" in corr.columns:
        print("=== Korelasi terhadap Result (diurutkan) ===")
        result_corr = corr["Result"].sort_values(ascending=False)
        print(result_corr.round(3))
        print()

    # Plot heatmap pakai matplotlib biasa
    plt.figure(figsize=(10, 8))
    im = plt.imshow(corr, aspect="auto")
    plt.title("MT5 Optimization – Correlation Heatmap")
    plt.xticks(range(len(cols)), cols, rotation=45, ha="right")
    plt.yticks(range(len(cols)), cols)

    # Tambah nilai korelasi di tiap kotak (optional, bisa di-comment)
    for i in range(len(cols)):
        for j in range(len(cols)):
            value = corr.iloc[i, j]
            plt.text(
                j,
                i,
                f"{value:.2f}",
                ha="center",
                va="center",
                fontsize=7,
            )

    plt.colorbar(im, fraction=0.046, pad=0.04)
    plt.tight_layout()

    # Simpan ke file
    plt.savefig(OUTPUT_FIG, dpi=200)
    print(f"Heatmap disimpan ke: {Path(OUTPUT_FIG).resolve()}")

    # Tampilkan di layar juga
    plt.show()


if __name__ == "__main__":
    main()
