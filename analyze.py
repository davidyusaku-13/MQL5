import pandas as pd

data = []
with open("log.txt", "r") as f:
    lines = f.readlines()

for i in range(0, len(lines), 4):
    if i + 3 < len(lines):
        range_line = lines[i].strip()
        profit_line = lines[i + 1].strip()
        balance_line = lines[i + 2].strip()
        sep_line = lines[i + 3].strip()

        # Extract date from range_line
        parts = range_line.split()
        if len(parts) >= 9 and parts[7] == "Range:":
            date = parts[5] + " " + parts[6]
            range_val = int(parts[8])

            # Profit
            profit_str = profit_line.split("Profit: ")[1]
            profit_val = float(profit_str.replace("$", "").replace("+", ""))

            # Balance
            balance_str = balance_line.split("Current Balance: ")[1]
            balance_val = float(balance_str.replace("$", ""))

            data.append(
                {
                    "Date": date,
                    "Range": range_val,
                    "Profit": profit_val,
                    "Balance": balance_val,
                }
            )

df = pd.DataFrame(data)
print(df)
df.to_csv("DailyBreakout-RESULT.csv", index=False)
